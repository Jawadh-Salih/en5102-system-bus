module arbiter (
    input clock,
    input reset_n,
    input [1:0] request,
    output reg [1:0] grant // assigned inside always block so we should declare it as reg
);

always @(posedge clock or negedge reset_n) begin
    if (reset_n == 1'b0) grant <= 2'b00;
    else begin
        case (request)
            2'b00: grant <= 2'b00;
            2'b01: grant <= 2'b01;
            2'b10: grant <= 2'b10;
            2'b11: grant <= (grant == 2'b10) ? 2'b10 : 2'b01; // Priority to existing grant
            default: grant <= 2'b00;
        endcase
    end
end

endmodule