`default_nettype none

module rmii (
    input clk_50MHz,
    output D5
);

initial begin
    D5 <= 0;
end

reg [26:0] counter;

    always @(posedge clk_50MHz) begin
        counter <= counter + 1;
        if (counter >= 50_000_000) begin
            D5 <= ~D5;
            counter <= 0;
        end
    end

endmodule