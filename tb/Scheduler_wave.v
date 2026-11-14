
`timescale 1ns/1ps

module tb_scheduler_wave;

reg MAX10_CLK1_50 = 0;
reg [1:0] KEY = 2'b11;
reg [9:0] SW = 10'b0;

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

// 50 MHz clock
always #10 MAX10_CLK1_50 = ~MAX10_CLK1_50;

// Advance Task 3 by one position

task move_task3;
begin
    @(negedge MAX10_CLK1_50);

    // Trigger exactly one Task 3 step
    force dut.t3.step = 1'b1;

    @(posedge MAX10_CLK1_50);
    #1;

    // Remove the forced step before the next clock
    release dut.t3.step;

    @(negedge MAX10_CLK1_50);
end
endtask


// Advance SOS by one 4 Hz event
task advance_sos;
begin
    @(negedge MAX10_CLK1_50);
    force dut.tick_4hz = 1'b1;

    @(posedge MAX10_CLK1_50);
    #1;

    release dut.tick_4hz;
    @(negedge MAX10_CLK1_50);
end
endtask

initial begin

    // Reset
    KEY[0] = 0;
    #25;
    KEY[0] = 1;

    // Keep scheduler in Task 3 interval
    force dut.seconds = 6'd0;

    #20;

    // LED0 -> LED1 -> LED2
    move_task3();
    move_task3();

    #20;

    // Activate SOS
    SW[0] = 1;
    #20;

    // Generate SOS phases
    repeat (8)
        advance_sos();

    #20;

    // Deactivate SOS
    SW[0] = 0;
    #20;

    // Resume Task 3: LED2 -> LED3
    move_task3();

    #40;

    release dut.seconds;

    $stop;

end

endmodule
