`timescale 1ns / 1ps
module tb_address_decoder;

    reg  [13:0] address;
    wire [2:0]  slave;

    integer i;
    integer errors = 0;
    reg [2:0] expected;

    address_decoder dut (
        .address(address),
        .slave(slave)
    );

    // Apply one address and compare the decoder output with what we expect.
    task check (input [13:0] a, input [2:0] exp);
        begin
            address = a;
            #10;
            if (slave === exp)
                $display("PASS: address=%h slave=%b", a, slave);
            else begin
                $display("FAIL: address=%h slave=%b expected=%b", a, slave, exp);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("wave_address_decoder.vcd");
        $dumpvars(0, tb_address_decoder);

        // 1. Edges of every range: the first and last address of each slave,
        //    and the first address of each hole. Bugs hide at the edges.
        check(14'h0000, 3'b001);   // slave 0, first
        check(14'h0FFF, 3'b001);   // slave 0, last
        check(14'h1000, 3'b010);   // slave 1, first
        check(14'h1FFF, 3'b010);   // slave 1, last
        check(14'h2000, 3'b100);   // slave 2, first
        check(14'h27FF, 3'b100);   // slave 2, last (2 KB only)
        check(14'h2800, 3'b000);   // hole after slave 2
        check(14'h3000, 3'b000);   // unused 4 KB block

        // 2. Sweep ALL 16384 addresses against the memory map written in plain decimal:
        //    S0 = 0..4095, S1 = 4096..8191, S2 = 8192..10239, everything else = nobody.
        //    Also confirm that two slaves are never selected together.
        $dumpoff;                  // keep the waveform file to the 8 edge cases above
        for (i = 0; i < 16384; i = i + 1) begin
            address = i;
            #1;
            if      (i < 4096)  expected = 3'b001;
            else if (i < 8192)  expected = 3'b010;
            else if (i < 10240) expected = 3'b100;
            else                expected = 3'b000;

            if (slave !== expected || $countones(slave) > 1) begin
                errors = errors + 1;
                if (errors <= 5)
                    $display("FAIL (sweep): address=%h slave=%b expected=%b", i, slave, expected);
            end
        end

        if (errors == 0) $display("=== ALL CHECKS PASSED (8 edge cases + full 16384-address sweep) ===");
        else             $display("=== %0d CHECK(S) FAILED ===", errors);
        $finish;
    end

endmodule
