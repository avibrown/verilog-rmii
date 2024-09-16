`default_nettype none

module rmii (
    input  wire   clk_50MHz,
    input  wire   CRS,
    input  wire   RX0,
    input  wire   RX1,
    input  wire   MDIO,
    output reg    TX_EN,
    output wire   TX0,
    output wire   TX1,
    output reg    MDC,
    output reg    D5
);

    /* ------------------ data link layer stuff (Ethernet frame) ---------------------------------- */
    localparam  ETH_PREAMBLE        = 56'h55555555555555;   /* 7 bytes of 55                        */
    localparam  ETH_SFD             = 8'hD5;                /* 1 byte start frame delimiter         */
    localparam  ETH_DESTINATION_MAC = 48'hFFFFFFFFFFFF;     /* 6 bytes - broadcast MAC address      */
    localparam  ETH_SOURCE_MAC      = 48'hDEADBEEFBABE;     /* 6 bytes - made up source MAC address */
    localparam  ETH_ETHERTYPE       = 16'h0800;             /* for IPv4                             */
    localparam  ETH_FRC             = 32'hABCDEF22;         /* a random frame check sequence        */
    localparam  ETH_START_CLKS      = 88;                   /* (56+8+48+48+16) / 2                  */
    localparam  ETH_STOP_CLKS       = 16;                   /* 32 / 2                               */
    reg [175:0] eth_start_buf;
    reg [31:0]  eth_stop_buf;
    /* -------------------------------------------------------------------------------------------- */

    /* ------------------ network layer stuff (IPv4 frame) ---------------------------------------- */
    localparam  IP_VERSION          = 4'd4;                 /* IPv4                                 */
    localparam  IP_IHL              = 4'd5;                 /* IHL(5) == 20 bytes length            */
    localparam  IP_TOS              = 16'd0;                /* type of service 0 -> normal          */
    localparam  IP_TOTAL_LENGTH     = 8'h28;                /* 20 byte header 20 bytes data         */
    localparam  IP_ID               = 16'd0;                /* fragmentation not considered         */
    localparam  IP_FRAG_OFFSET      = 16'h4000;             /* Don't Fragment (DF)                  */
    localparam  IP_TTL              = 8'h40;                /* 64, common time to live              */
    localparam  IP_PROTOCOL         = 8'h11;                /* UDP                                  */
    localparam  IP_SOURCE_IP        = 32'hc0a80164;         /* 192.168.1.100                        */
    localparam  IP_DESTINATION_IP   = 32'hc0a801FF;         /* broadcast 192.168.1.255              */
    localparam  IP_CHECKSUM         = 16'hb610;             /* calculated using script in this dir  */
    localparam  IP_CLKS             = 72;                   /* (4+4+16+8+16+16+8+8+32+32) / 2       */ 
    reg [143:0] ip_buf;
    /* -------------------------------------------------------------------------------------------- */

    /* ------------------ transport layer stuff (UDP frame) --------------------------------------- */
    localparam  UDP_SOURCE_PORT     = 16'd1234;             /* example port                         */
    localparam  UDP_DEST_PORT       = 16'd1234;             /* example port                         */
    localparam  UDP_LENGTH          = 8'd8 + 8'h2;          /* 8 header bytes + 4 payload bytes     */
    localparam  UDP_CHECKSUM        = 16'd0;                /* optional checksum                    */
    localparam  UDP_PAYLOAD         = 16'hDEAD;             /* example payload                      */
    localparam  UDP_CLKS            = 21;                   /* (16+16+8+16+16) / 2                  */
    reg [71:0]  udp_buf;
    /* -------------------------------------------------------------------------------------------- */

    /* ------- FSM ---------- */
    reg [1:0]   state;
    reg [1:0]   next_state;
    localparam  S_ETH_START   = 0;
    localparam  S_IP          = 1;
    localparam  S_UDP         = 2;
    localparam  S_ETH_STOP    = 3;

    reg [1:0]   tx;
    reg [25:0]  interframe_counter;
    reg [10:0]  state_counter;
    reg [7:0]   tx_counter;

    assign TX0 = tx[0];
    assign TX1 = tx[1];

    initial begin
        eth_start_buf       = {ETH_ETHERTYPE, 
                               ETH_SOURCE_MAC, 
                               ETH_DESTINATION_MAC, 
                               ETH_SFD, 
                               ETH_PREAMBLE};
        eth_stop_buf        <= {ETH_FRC};
        ip_buf              <= {IP_DESTINATION_IP,         
                               IP_SOURCE_IP,             
                               IP_CHECKSUM,             
                               IP_PROTOCOL,    
                               IP_TTL,              
                               IP_FRAG_OFFSET,     
                               IP_ID,             
                               IP_TOTAL_LENGTH, 
                               IP_TOS,     
                               IP_IHL,       
                               IP_VERSION};
        udp_buf             <= {UDP_PAYLOAD,
                               UDP_CHECKSUM,  
                               UDP_LENGTH,     
                               UDP_DEST_PORT,   
                               UDP_SOURCE_PORT};

        MDC                 <= 0;
        TX_EN               <= 0;
        interframe_counter  <= 0;
        tx_counter          <= 0;
        state_counter       <= 0;
        state               <= S_ETH_START;
        next_state          <= S_ETH_START;
        D5                  <= 0;
        tx[0]               <= 0;
        tx[1]               <= 0;
    end

    always @(posedge clk_50MHz) begin
        state <= next_state;
    end

    always @(posedge clk_50MHz) begin
        interframe_counter <= interframe_counter + 1;
        if (interframe_counter >= 50_000_00) begin
            TX_EN <= 1;
            D5 <= ~D5;
            case (state)
                /* --- */
                S_ETH_START: begin
                    tx[1:0]        <= eth_start_buf[tx_counter +: 2];
                    state_counter  <= state_counter + 1;
                    if (state_counter == (ETH_START_CLKS - 1)) begin
                        tx_counter <= 0;
                        next_state <= S_IP;
                    end else begin
                        tx_counter <= tx_counter + 2;
                    end
                end

                /* --- */
                S_IP: begin
                    tx[1:0]        <= ip_buf[tx_counter +: 2];
                    state_counter  <= state_counter + 1;
                    if (state_counter == (ETH_START_CLKS + IP_CLKS- 1)) begin
                        next_state <= S_UDP;
                        tx_counter <= 0;
                    end else begin
                        tx_counter <= tx_counter + 2;
                    end
                end

                /* --- */
                S_UDP: begin
                    tx[1:0]        <= udp_buf[tx_counter +: 2];
                    state_counter  <= state_counter + 1;
                    if (state_counter == (ETH_START_CLKS + IP_CLKS + UDP_CLKS- 1)) begin
                        next_state <= S_ETH_STOP;
                        tx_counter <= 0;
                    end else begin
                        tx_counter <= tx_counter + 2;
                    end
                end

                /* --- */
                S_ETH_STOP: begin
                    tx[1:0]        <= eth_stop_buf[tx_counter +: 2];
                    state_counter  <= state_counter + 1;
                    if (state_counter == (ETH_START_CLKS + IP_CLKS + UDP_CLKS + ETH_STOP_CLKS- 1)) begin
                        tx_counter         <= 0;
                        state_counter      <= 0;
                        interframe_counter <= 0;
                        next_state         <= S_ETH_START;
                    end else begin
                        tx_counter <= tx_counter + 2;
                    end
                end
            endcase
        end else begin
            tx[1:0] <= 2'b00;
            TX_EN   <= 0;
        end
    end
endmodule
