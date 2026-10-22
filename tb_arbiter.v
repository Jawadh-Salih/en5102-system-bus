`timescale 1ns/1ps
module tb_arbiter;

  reg        clock = 0;
  reg        reset_n;
  reg  [1:0] request;
  wire [1:0] grant;
  integer    errors = 0;

  arbiter dut (.clock(clock), .reset_n(reset_n),
               .request(request), .grant(grant));

  always #5 clock = ~clock;                 // 100 MHz

  task check (input [1:0] expected, input [8*48-1:0] what);
    begin
      if (grant !== expected) begin
        $display("FAIL t=%0t  %0s : grant=%b expected=%b", $time, what, grant, expected);
        errors = errors + 1;
      end else
        $display("pass t=%0t  %0s : grant=%b", $time, what, grant);
    end
  endtask

  initial begin
    $dumpfile("wave.vcd"); $dumpvars(0, tb_arbiter);

    // 1. RESET TEST
    reset_n = 0; request = 2'b00;
    #12 check(2'b00, "reset forces grant to 00");
    reset_n = 1;

    // 2. IDLE
    @(posedge clock); #1 check(2'b00, "idle: nobody requests");

    // 3. SINGLE MASTER REQUEST
    request = 2'b01;
    @(posedge clock); #1 check(2'b01, "M0 alone requests");
    request = 2'b00;
    @(posedge clock); #1 check(2'b00, "M0 releases");

    request = 2'b10;
    @(posedge clock); #1 check(2'b10, "M1 alone requests");

    // 4. TWO MASTER REQUESTS  (M1 already owns the bus)
    request = 2'b11;
    @(posedge clock); #1 check(2'b10, "both request: M1 HOLDS its transfer");
    @(posedge clock); #1 check(2'b10, "still held next cycle");
    request = 2'b01;
    @(posedge clock); #1 check(2'b01, "M1 done, M0 takes over");

    // 5. TWO MASTER REQUESTS from idle (priority decides)
    request = 2'b00; @(posedge clock); #1;
    request = 2'b11;
    @(posedge clock); #1 check(2'b01, "both from idle: M0 wins on priority");

    // 6. ASYNC RESET mid-operation
    #2 reset_n = 0;
    #1 check(2'b00, "async reset clears grant without a clock edge");
    reset_n = 1;

    if (errors == 0) $display("\n=== ALL %0d CHECKS PASSED ===", 10);
    else             $display("\n=== %0d CHECK(S) FAILED ===", errors);
    $finish;
  end

  initial begin #2000 $display("TIMEOUT"); $finish; end

endmodule
