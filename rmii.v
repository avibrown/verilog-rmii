`default_nettype none

module rmii (
    input  wire   clk_50MHz,
    input  wire   CRS,
    input  wire   RX0,
    input  wire   RX1,
    input  wire   MDIO,
    output wire   TX_EN,
    output wire   TX0,
    output wire   TX1,
    output wire   MDC,
    output        D5
);

    /* ------------------ data link layer stuff (Ethernet frame) ---------------------------------- */
    localparam  ETH_PREAMBLE        = 56'h55555555555555;   /* 7 bytes of 55                        */
    localparam  ETH_SFD             = 8'hD5;                /* 1 byte start frame delimiter         */
    localparam  ETH_DESTINATION_MAC = 48'hFFFFFFFFFFFF;     /* 6 bytes - broadcast MAC address      */
    localparam  ETH_SOURCE_MAC      = 48'hDEADBEEFBABE;     /* 6 bytes - made up source MAC address */
    localparam  ETH_ETHERTYPE       = 16'h0080;             /* for IPv4                             */

    /* ------------------ network layer stuff (IPv4 frame) ---------------------------------------- */
    localparam  IP_VERSION          = 4'd4;                 /* IPv4                                 */
    localparam  IP_IHL              = 4'd5;                 /* IHL(5) == 20 bytes length            */
    localparam  IP_TOS              = 0;                    /* type of service 0 -> normal          */
    localparam  IP_TOTAL_LENGTH     = 8'h28;                /* 20 byte header 20 bytes data         */
    localparam  IP_ID               = 0;                    /* fragmentation not considered         */
    localparam  IP_FRAG_OFFSET      = 16'h4000;             /* Don't Fragment (DF)                  */
    localparam  IP_TTL              = 8'h40;                /* 64, common time to live              */
    localparam  IP_PROTOCOL         = 8'h11;                /* UDP                                  */
    localparam  IP_SOURCE_IP        = 32'hc0a80164;         /* 192.168.1.100                        */
    localparam  IP_DESTINATION_IP   = 32'hc0a801FF;         /* broadcast 192.168.1.255              */
    localparam  IP_CHECKSUM         = 16'hb610;             /* calculated using script in this dir  */

    /* ------------------ transport layer stuff (UDP frame) --------------------------------------- */
    localparam  UDP_SOURCE_PORT     = 16'd1234;             /* example port                         */
    localparam  UDP_DEST_PORT       = 16'd1234;             /* example port                         */
    localparam  UDP_LENGTH          = 8'd8 + 8'h4;          /* 8 header bytes + 4 payload bytes     */
    localparam  UDP_CHECKSUM        = 16'd0;                /* optional checksum fuck yeah          */


    reg         clk, crs, mdio, tx_en, mdc, led;
    reg [1:0]   tx,  rx;
    reg [25:0]  counter;

    assign clk_50MHz = clk;
    assign CRS       = crs;
    assign MDIO      = mdio;
    assign TX_EN     = tx_en;
    assign MDC       = mdx;
    assign TX0       = tx[0];
    assign TX1       = tx[1];
    assign RX0       = rx[0];
    assign RX1       = rx[1];
    assign D5        = led;

    initial begin
        counter <= 0;
    end

    always @(posedge clk) begin
        counter <= counter + 1;
        if (counter == 50_000_000) begin
            led <= ~led;
            counter <= 0;
        end
    end

endmodule
