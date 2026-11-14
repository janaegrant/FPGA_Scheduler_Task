
`timescale 1ns/1ps

module tb_scheduler_timing;

reg MAX10_CLK1_50 = 0;
reg [1:0] KEY = 2'b11;
reg [9:0] SW = 0;

wire [9:0] LEDR;
wire [6:0] HEX0, HEX1, HEX5, HEX4, HEX3;

final_3201P dut (
    .MAX10_CLK1_50(MAX10_CLK1_50),
    .KEY(KEY),
    .SW(SW),
    .LEDR(LEDR),
    .HEX0(HEX0),
    .HEX1(HEX1),
    .HEX5(HEX5),
    .HEX4(HEX4),
    .HEX3(HEX3)
);

// Actual 50 MHz clock
always #10 MAX10_CLK1_50 = ~MAX10_CLK1_50;

time last_tick1 = 0;
time last_tick4 = 0;

integer count1 = 0;
integer count4 = 0;

// Measure 1 Hz tick
always @(posedge dut.tick) begin
    count1 = count1 + 1;

    if (count1 > 1) begin
        if (($time - last_tick1) == 1_000_000_000)
            $display("PASS: 1 Hz tick period = %0t ns",
                     $time - last_tick1);
        else
            $display("FAIL: 1 Hz tick period = %0t ns",
                     $time - last_tick1);
    end

    last_tick1 = $time;
end

// Measure 4 Hz tick
always @(posedge dut.tick_4hz) begin
    count4 = count4 + 1;

    if (count4 > 1) begin
        if (($time - last_tick4) == 250_000_000)
            $display("PASS: 4 Hz tick period = %0t ns",
                     $time - last_tick4);
        else
            $display("FAIL: 4 Hz tick period = %0t ns",
                     $time - last_tick4);
    end

    last_tick4 = $time;
end

initial begin
    KEY[0] = 0;
    #25;
    KEY[0] = 1;

    // Run long enough for multiple pulses
    #2_100_000_000;

    $display("1 Hz pulses observed: %0d", count1);
    $display("4 Hz pulses observed: %0d", count4);

    $stop;
end

endmodule
