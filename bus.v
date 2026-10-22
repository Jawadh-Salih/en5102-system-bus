module bus(
    input clock, reset_n,
    input [1:0] request,
    output [1:0] grant,
    output [2:0] slave, // one-hot slave select from the decoder (000 = no slave)

    // master
    input [13:0] m0_address,  m1_address,
    input m0_write_enable, m1_write_enable,
    input [7:0] m0_write_data,m1_write_data, 
    output reg [13:0] bus_address,
    output reg bus_write_enable,
    output reg [7:0] bus_write_data,


    // slave
    input [7:0]  s0_read_data, s1_read_data, s2_read_data,
    output reg [7:0] bus_read_data

);

arbiter bus_arb (  
    .clock(clock),
    .reset_n(reset_n),
    .request(request),
    .grant(grant)
);

address_decoder bus_addr_dec (
    .address(bus_address),
    .slave(slave)
);

// master to slave data write, read
always @(*) begin
    case (grant)
        2'b01: begin
            bus_address = m0_address;
            bus_write_enable = m0_write_enable;
            bus_write_data = m0_write_data;
        end
        2'b10: begin
            bus_address = m1_address;
            bus_write_enable = m1_write_enable;
            bus_write_data = m1_write_data;
        end
        default: begin
            bus_address = 14'b0;
            bus_write_enable = 1'b0;
            bus_write_data = 8'b0;
        end
    endcase
end

// slave to master data read
always @(*) begin
    case (slave)
        3'b001: bus_read_data = s0_read_data;
        3'b010: bus_read_data = s1_read_data;
        3'b100: bus_read_data = s2_read_data;
        default: bus_read_data = 8'b0;
    endcase
end

endmodule