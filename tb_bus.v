`timescale 1ns / 1ps
module tb_bus;

    // inputs
    reg clock = 0;
    reg reset_n;
    reg [1:0] request;
    reg [13:0] m0_address, m1_address;
    reg m0_write_enable, m1_write_enable;
    reg [7:0] m0_write_data, m1_write_data;
    reg [7:0] s0_read_data, s1_read_data, s2_read_data;

    // outputs
    wire [1:0] grant;
    wire [13:0] bus_address;
    wire bus_write_enable;
    wire [7:0] bus_write_data;
    wire [2:0] slave;
    wire [7:0] bus_read_data;

    bus dut(
        .clock(clock),
        .reset_n(reset_n),
        .request(request),
        .grant(grant),
        .m0_address(m0_address),
        .m1_address(m1_address),
        .m0_write_enable(m0_write_enable),
        .m1_write_enable(m1_write_enable),
        .m0_write_data(m0_write_data),
        .m1_write_data(m1_write_data),
        .bus_address(bus_address),
        .bus_write_enable(bus_write_enable),
        .bus_write_data(bus_write_data),
        .s0_read_data(s0_read_data),
        .s1_read_data(s1_read_data),
        .s2_read_data(s2_read_data),
        .slave(slave),
        .bus_read_data(bus_read_data)
    );

    always #5 clock = ~clock; // 100 MHz

    // Read one address through the bus and check which slave answered and what came back.
    // Nothing here is clocked: once a master owns the bus, the decoder and muxes are pure logic.
    task check_read (input [13:0] a, input [2:0] exp_slave, input [7:0] exp_data);
        begin
            m0_address = a;
            #1;
            if (slave === exp_slave && bus_read_data === exp_data)
                $display("PASS (e): addr=%h slave=%b read=%h", a, slave, bus_read_data);
            else
                $display("FAIL (e): addr=%h slave=%b read=%h (expected slave=%b read=%h)",
                         a, slave, bus_read_data, exp_slave, exp_data);
        end
    endtask

    initial begin
        $dumpfile("wave_bus.vcd");
        $dumpvars(0, tb_bus);

        reset_n = 0;
        request = 2'b00;
        m0_address = 14'h0000;
        m1_address = 14'h0000;
        m0_write_enable = 0;
        m1_write_enable = 0;
        m0_write_data = 8'h00;
        m1_write_data = 8'h00;
        s0_read_data = 8'hA0;
        s1_read_data = 8'hB1;
        s2_read_data = 8'hC2;

        // (a) RESET: held from time 0, grant must be 00 after two clock edges
        #22;
        if (grant !== 2'b00) $display("FAIL (a): reset, grant=%b expected=00", grant);
        else $display("PASS (a): reset, grant=%b", grant);

        // (b) IDLE: No requests, grant should be 00
        reset_n = 1;
        request = 2'b00;
        repeat (3) @(posedge clock);   // let 3 clock edges pass
        #1;
        if (grant === 2'b00 && bus_write_enable === 1'b0)
            $display("PASS (b): idle, grant=00 and bus quiet");
        else
            $display("FAIL (b): grant=%b we=%b", grant, bus_write_enable);

        // (c) SINGLE MASTER REQUEST
        m0_address = 14'h1004;           // M0's address
        m1_address = 14'h2008;           // M1's address, clearly different
        request = 2'b01;                 // only M0 asks
        @(posedge clock);
        #1;
        if (grant === 2'b01 && bus_address === m0_address)
            $display("PASS (c1): M0 alone, grant=01 bus_address=%h", bus_address);
        else
            $display("FAIL (c1): grant=%b bus_address=%h", grant, bus_address);

        request = 2'b00;                 // release the bus
        @(posedge clock); #1;
        request = 2'b10;                 // only M1 asks
        @(posedge clock);
        #1;
        if (grant === 2'b10 && bus_address === m1_address)
            $display("PASS (c2): M1 alone, grant=10 bus_address=%h", bus_address);
        else
            $display("FAIL (c2): grant=%b bus_address=%h", grant, bus_address);

        // (d1) both ask from IDLE: priority decides
        request = 2'b00;
        repeat (2) @(posedge clock); #1;
        request = 2'b11;
        @(posedge clock); #1;
        if (grant === 2'b01 && bus_address === m0_address)
            $display("PASS (d1): both from idle, M0 wins on priority");
        else
            $display("FAIL (d1): grant=%b bus_address=%h", grant, bus_address);

        // (d2) M1 owns the bus, then M0 joins: M1 must HOLD
        request = 2'b00;
        repeat (2) @(posedge clock); #1;
        request = 2'b10;                // M1 takes the bus
        @(posedge clock); #1;
        request = 2'b11;                // M0 now asks too
        @(posedge clock); #1;
        if (grant === 2'b10 && bus_address === m1_address)
            $display("PASS (d2): M1 holds the bus while M0 also asks");
        else
            $display("FAIL (d2): grant=%b bus_address=%h", grant, bus_address);

        // (d3) M1 finishes: M0 takes over
        request = 2'b01;
        @(posedge clock); #1;
        if (grant === 2'b01 && bus_address === m0_address)
            $display("PASS (d3): M1 released, M0 takes over");
        else
            $display("FAIL (d3): grant=%b bus_address=%h", grant, bus_address);

        // (e) READ PATH: M0 owns the bus and reads one address in each slave
        request = 2'b00;
        repeat (2) @(posedge clock); #1;
        m0_write_enable = 0;                  // reads
        request = 2'b01;                      // M0 takes the bus
        @(posedge clock); #1;
        check_read(14'h0004, 3'b001, 8'hA0);  // slave 0
        check_read(14'h1004, 3'b010, 8'hB1);  // slave 1
        check_read(14'h2008, 3'b100, 8'hC2);  // slave 2
        check_read(14'h27FF, 3'b100, 8'hC2);  // last address of slave 2
        check_read(14'h2800, 3'b000, 8'h00);  // hole: no slave selected, reads 00
        check_read(14'h3000, 3'b000, 8'h00);  // hole: no slave selected, reads 00

        // (f) WRITE PATH: the granted master's write signals reach the bus
        m0_address = 14'h1004;  m0_write_enable = 1;  m0_write_data = 8'h5A;
        m1_address = 14'h2008;  m1_write_enable = 1;  m1_write_data = 8'h3C;
        #1;
        if (bus_write_enable === 1'b1 && bus_write_data === 8'h5A && bus_address === 14'h1004)
            $display("PASS (f1): M0 write reaches the bus, data=%h", bus_write_data);
        else
            $display("FAIL (f1): we=%b data=%h addr=%h", bus_write_enable, bus_write_data, bus_address);

        request = 2'b00;
        @(posedge clock); #1;
        request = 2'b10;                      // M1 takes the bus
        @(posedge clock); #1;
        if (bus_write_enable === 1'b1 && bus_write_data === 8'h3C && bus_address === 14'h2008)
            $display("PASS (f2): M1 write reaches the bus, data=%h", bus_write_data);
        else
            $display("FAIL (f2): we=%b data=%h addr=%h", bus_write_enable, bus_write_data, bus_address);

        request = 2'b00;                      // nobody asks, but both masters still try to write
        @(posedge clock); #1;
        if (bus_write_enable === 1'b0 && bus_write_data === 8'h00 && bus_address === 14'h0000)
            $display("PASS (f3): idle bus ignores both masters' writes");
        else
            $display("FAIL (f3): we=%b data=%h addr=%h", bus_write_enable, bus_write_data, bus_address);

        #20;
        $finish;
    end

endmodule