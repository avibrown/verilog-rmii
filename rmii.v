`default_nettype none

module rmii (
    input  wire   clk_50MHz,
    input  wire   reset_n,
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

    /* ------------------ Data Link Layer (Ethernet Frame) ------------------------------ */
    localparam  ETH_PREAMBLE        = 56'h55555555555555;   /* 7 bytes of 0x55 */
    localparam  ETH_SFD             = 8'hD5;                /* Start Frame Delimiter */
    localparam  ETH_DESTINATION_MAC = 48'hFFFFFFFFFFFF;     /* Broadcast MAC address */
    localparam  ETH_SOURCE_MAC      = 48'h010203040506;     /* Source MAC address */
    localparam  ETH_ETHERTYPE       = 16'h0800;             /* Ethertype for IPv4 */
    localparam  ETH_FCS             = 32'hABCDEF22;         /* Frame Check Sequence (placeholder) */

    /* Ethernet frame concatenation */
    localparam [175:0] ETH_HEADER = {
        ETH_PREAMBLE,           // 56 bits
        ETH_SFD,                // 8 bits
        ETH_DESTINATION_MAC,    // 48 bits
        ETH_SOURCE_MAC,         // 48 bits
        ETH_ETHERTYPE           // 16 bits
    };

    /* ------------------ Network Layer (IPv4 Frame) ------------------------------------ */
    localparam  IP_VERSION          = 4'd4;                 /* IPv4 */
    localparam  IP_IHL              = 4'd5;                 /* Header length (5 words) */
    localparam  IP_TOS              = 8'd0;                 /* Type of Service */
    localparam  IP_TOTAL_LENGTH     = 16'd28;               /* Total length (20 bytes header + 8 bytes data) */
    localparam  IP_ID               = 16'd0;                /* Identification */
    localparam  IP_FLAGS            = 3'b010;               /* Don't Fragment flag */
    localparam  IP_FRAG_OFFSET      = 13'd0;                /* Fragment Offset */
    localparam  IP_TTL              = 8'd64;                /* Time to Live */
    localparam  IP_PROTOCOL         = 8'd17;                /* Protocol (UDP) */
    localparam  IP_CHECKSUM         = 16'hb610;             /* Header Checksum */
    localparam  IP_SOURCE_IP        = 32'hC0A80164;         /* 192.168.1.100 */
    localparam  IP_DESTINATION_IP   = 32'hC0A801FF;         /* 192.168.1.255 */

    /* IP header concatenation */
    localparam [159:0] IP_HEADER = {
        // Version and IHL
        IP_VERSION, IP_IHL,
        // Type of Service
        IP_TOS,
        // Total Length
        IP_TOTAL_LENGTH,
        // Identification
        IP_ID,
        // Flags and Fragment Offset
        IP_FLAGS, IP_FRAG_OFFSET,
        // Time to Live
        IP_TTL,
        // Protocol
        IP_PROTOCOL,
        // Header Checksum
        IP_CHECKSUM,
        // Source IP Address
        IP_SOURCE_IP,
        // Destination IP Address
        IP_DESTINATION_IP
    };

    /* ------------------ Transport Layer (UDP Frame) ----------------------------------- */
    localparam  UDP_SOURCE_PORT     = 16'd1234;             /* Source Port */
    localparam  UDP_DEST_PORT       = 16'd1234;             /* Destination Port */
    localparam  UDP_LENGTH          = 16'd10;               /* Length (8 bytes header + 2 bytes payload) */
    localparam  UDP_CHECKSUM        = 16'd0;                /* Checksum (optional) */
    // localparam  UDP_PAYLOAD         = 192'hDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF;             /* Payload data */
    localparam  UDP_PAYLOAD            = 192'hEFBEADDEEFBEADDEEFBEADDEEFBEADDEEFBEADDEEFBEADDE;

    /* UDP packet concatenation */
    localparam [255:0] UDP_PACKET = {
        // Source Port
        UDP_SOURCE_PORT,
        // Destination Port
        UDP_DEST_PORT,
        // Length
        UDP_LENGTH,
        // Checksum
        UDP_CHECKSUM,
        // Payload
        UDP_PAYLOAD
    };

    /* ------- Combined Frame Data ------- */
    localparam TOTAL_FRAME_SIZE = 176 + 160 + 256 + 32; // ETH_HEADER + IP_HEADER + UDP_PACKET + ETH_FCS
    localparam [TOTAL_FRAME_SIZE-1:0] FRAME_DATA = {
        ETH_HEADER,     // 176 bits
        IP_HEADER,      // 160 bits
        UDP_PACKET,     // 255 bits
        ETH_FCS         // 32 bits
    };

    /* ------- FSM ---------- */
    reg [1:0]   state;
    reg [1:0]   next_state;
    localparam  S_IDLE        = 2'd0;
    localparam  S_TRANSMIT    = 2'd1;

    initial begin
        state <= S_IDLE;
    end

    reg [1:0]   tx;
    reg [25:0]  interframe_counter;
    reg [$clog2(TOTAL_FRAME_SIZE):0] bit_counter;

    assign TX0 = tx[0];
    assign TX1 = tx[1];

    /* Main logic */
    always @(posedge clk_50MHz) begin
        if (reset_n) begin
            /* Reset logic */
            MDC                 <= 0;
            TX_EN               <= 0;
            interframe_counter  <= 0;
            state               <= S_IDLE;
            next_state          <= S_IDLE;
            D5                  <= 0;
            tx                  <= 2'b00;
            bit_counter         <= 0;
        end else begin
            state <= next_state;
            case (state)
                S_IDLE: begin
                        TX_EN <= 0;
                    interframe_counter <= interframe_counter + 1;
                    if (interframe_counter >= 10_000_000) begin // Adjusted for 2 times per second
                        D5 <= ~D5;
                        interframe_counter <= 0;
                        bit_counter <= TOTAL_FRAME_SIZE - 2;
                        next_state <= S_TRANSMIT;
                    end
                    tx <= 2'b00;
                end

                S_TRANSMIT: begin
                    TX_EN <= 1;
                    if (bit_counter >= 2) begin
                        tx[0] <= FRAME_DATA[bit_counter];
                        tx[1] <= FRAME_DATA[bit_counter + 1];
                        bit_counter <= bit_counter - 2;
                    end else begin
                        // Last bit(s)
                        tx[0] <= FRAME_DATA[1];
                        tx[1] <= FRAME_DATA[0];
                        next_state <= S_IDLE;
                    end
                end
            endcase
        end
    end
endmodule