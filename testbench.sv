`timescale 1ns/1ps

module tb_scheduler;
  reg MAX10_CLK1_50 = 0;
  reg [1:0] KEY = 2'b11;
  reg [9:0] SW = 0;
  wire [9:0] LEDR;
  wire [6:0] HEX0, HEX1, HEX5, HEX4, HEX3;
  integer failures = 0, checks = 0;
  integer i, expected_pos, pulse, phase, k;
  reg [22:0] saved_t3_count, saved_t4_count;
  reg [3:0] saved_t3_pos, saved_t4_pos;
  reg saved_t4_dir;
  reg [9:0] saved_leds;

  final_3201P dut (
    .MAX10_CLK1_50(MAX10_CLK1_50), .KEY(KEY), .SW(SW),
    .LEDR(LEDR), .HEX0(HEX0), .HEX1(HEX1),
    .HEX5(HEX5), .HEX4(HEX4), .HEX3(HEX3)
  );
  always #10 MAX10_CLK1_50 = ~MAX10_CLK1_50;

  task check_led;
    input [9:0] expected;
    input [8*80-1:0] label;
    begin
      checks = checks + 1;
      if (LEDR !== expected) begin
        failures = failures + 1;
        $display("FAIL: %0s LEDR=%b expected=%b",label,LEDR,expected);
      end else $display("PASS: %0s",label);
    end
  endtask
  task check_hex5;
    input [6:0] expected;
    input [8*80-1:0] label;
    begin
      checks = checks + 1;
      if (HEX5 !== expected) begin
        failures = failures + 1;
        $display("FAIL: %0s HEX5=%b expected=%b",label,HEX5,expected);
      end else $display("PASS: %0s",label);
    end
  endtask
  task check_true;
    input condition;
    input [8*80-1:0] label;
    begin
      checks = checks + 1;
      if (condition !== 1'b1) begin
        failures = failures + 1;
        $display("FAIL: %0s",label);
      end else $display("PASS: %0s",label);
    end
  endtask
  task reset_scheduler;
    begin
      SW = 0;
      // Guarantee an actual falling reset edge even if reset was already low.
      KEY[0] = 1'b1;
      #1 KEY[0] = 1'b0;
      repeat (2) @(negedge MAX10_CLK1_50);
      #1 KEY[0] = 1'b1;
      repeat (2) @(negedge MAX10_CLK1_50);
      #1;
    end
  endtask
  task scheduler_tick;
    begin
      @(negedge MAX10_CLK1_50);
      force dut.tick = 1'b1;
      @(posedge MAX10_CLK1_50); #1;
      release dut.tick;
      #1;
    end
  endtask
  task t3_step;
    begin
      @(negedge MAX10_CLK1_50);
      force dut.t3.step = 1'b1;
      @(posedge MAX10_CLK1_50); #1;
      release dut.t3.step; #1;
    end
  endtask
  task t4_step;
    begin
      @(negedge MAX10_CLK1_50);
      force dut.t4.step = 1'b1;
      @(posedge MAX10_CLK1_50); #1;
      release dut.t4.step; #1;
    end
  endtask
  task sos_tick;
    begin
      @(negedge MAX10_CLK1_50);
      force dut.tick_4hz = 1'b1;
      @(posedge MAX10_CLK1_50); #1;
      release dut.tick_4hz; #1;
    end
  endtask
  task select_second;
    input [5:0] s;
    begin
      force dut.seconds = s;
      #1;
    end
  endtask
  task stop_selecting;
    begin
      release dut.seconds;
      #1;
    end
  endtask
  task task_at;
    input [5:0] s;
    input [6:0] expected;
    begin
      select_second(s);
      $display("  schedule second %0d",s);
      check_hex5(expected,"task selection");
      stop_selecting();
    end
  endtask
  task task2_at;
    input [5:0] s;
    begin
      select_second(s);
      $display("  Task 2 at second %0d",s);
      check_hex5(7'b0100100,"Task 2 display");
      check_led(10'b1111111111,"Task 2 all LEDs ON");
      stop_selecting();
    end
  endtask

  // Independent SOS reference: nine pulses = ... --- ...
  // Each pulse has 1 off-tick following it. A dot is 1 on-tick;
  // a dash is 3 on-ticks. Sample outputs after every accelerated tick.
  task test_sos_pattern;
    integer p, j, on_ticks;
    begin
      reset_scheduler();
      $display("\n===== SOS DOT/DASH PATTERN =====");
      // Capture the active task output immediately before SOS takes control.
      saved_leds = LEDR;
      SW[0] = 1'b1;
      #1;
      check_led(10'b0000000000,"SOS starts OFF");
      for (p = 0; p < 9; p = p + 1) begin
        on_ticks = ((p >= 3) && (p <= 5)) ? 3 : 1;
        $display("  SOS pulse %0d expected %0s",p+1,
                 on_ticks == 1 ? "DOT" : "DASH");
        for (j = 0; j < on_ticks; j = j + 1) begin
          sos_tick();
          check_led(10'b1111111111,"SOS ON tick");
        end
        sos_tick();
        check_led(10'b0000000000,"SOS OFF tick");
      end
      SW[0] = 1'b0;
      #1;
      check_led(saved_leds,"Previous task restores saved LEDs after SOS");
    end
  endtask

  task test_sos_repeats;//does SOS countinue while SW0 is on
    integer cycle, p, j, on_ticks;
    reg [9:0] before_sos;
    begin
      reset_scheduler();
      $display("\n===== SOS CONTINUOUS REPETITION =====");
      t3_step(); t3_step();
      before_sos = LEDR;
      SW[0] = 1'b1; #1;
      for (cycle=0; cycle<2; cycle=cycle+1) begin
        // The RTL has an additional OFF state (state 18) between messages.
        if (cycle != 0) begin
          sos_tick();
          check_led(10'b0,"SOS inter-message OFF tick");
        end
        for (p=0; p<9; p=p+1) begin
          on_ticks = (p>=3 && p<=5) ? 3 : 1;
          for (j=0; j<on_ticks; j=j+1) begin
            sos_tick();
            check_led(10'b1111111111,"Repeated SOS ON phase");
          end
          sos_tick();
          check_led(10'b0,"Repeated SOS OFF phase");
        end
      end
      check_true(dut.t3.pos===4'd2,"Task 3 position frozen through two SOS messages");
      SW[0]=1'b0; #1;
      check_led(before_sos,"Task 3 restores after repeated SOS");
    end
  endtask

  task test_interrupt_transitions;//Does SOS take precedence
    reg [9:0] before_interrupt;
    reg [3:0] pos_before;
    reg [22:0] count_before;
    reg dir_before;
    begin
      reset_scheduler();
      $display("\n===== INTERRUPT TRANSITIONS =====");
      select_second(11);
      t4_step(); t4_step();
      before_interrupt=LEDR;
      pos_before=dut.t4.pos;
      count_before=dut.t4.slow_count;
      dir_before=dut.t4.dir;
      SW[1]=1; #1;
      check_led(10'b1010101010,"Warning takes over Task 4");
      SW[0]=1; #1;
      check_true({HEX5,HEX4,HEX3}===
        {7'b0010010,7'b1000000,7'b0010010},"SOS overrides Warning");
      sos_tick();
      check_led(10'b1111111111,"SOS LED output overrides Warning");
      repeat(3) scheduler_tick();
      check_true(dut.t4.pos===pos_before &&
                 dut.t4.slow_count===count_before &&
                 dut.t4.dir===dir_before,"Task 4 frozen across both interrupts");
      SW[0]=0; #1;
      check_led(10'b1010101010,"Warning returns while SW1 remains ON");
      SW[1]=0; #1;
      check_led(before_interrupt,"Task 4 resumes at saved LED after both interrupts");
      t4_step();
      check_true(dut.t4.pos===pos_before-1,"Task 4 continues after interrupt transitions");
      stop_selecting();
    end
  endtask

  task test_resets_during_activity;
    begin
      $display("\n===== RESET DURING ACTIVE STATES =====");
      reset_scheduler();
      select_second(0);
      repeat(7) t3_step();
      check_true(dut.t3.pos===4'd7,"Task 3 advanced before reset");
      KEY[0]=0; #1;
      check_true(dut.t3.pos===4'd0 && dut.seconds===6'd0,
                 "Reset clears active Task 3");
      KEY[0]=1; #1; stop_selecting();

      reset_scheduler();
      select_second(11);
      repeat(12) t4_step();
      check_true(dut.t4.pos===4'd3 && dut.t4.dir===1'b1,
                 "Task 4 reversed before reset");
      KEY[0]=0; #1;
      check_true(dut.t4.pos===4'd9 && dut.t4.dir===1'b0,
                 "Reset restores Task 4 position and direction");
      KEY[0]=1; #1; stop_selecting();

      reset_scheduler();
      SW[1]=1;
      @(negedge MAX10_CLK1_50);
      force dut.warn_cnt=25'd25_000_000;
      @(posedge MAX10_CLK1_50); #1;
      release dut.warn_cnt; #1;
      check_true(dut.warn_led===1'b1,"Warning changed phase before reset");
      KEY[0]=0; #1;
      check_true(dut.warn_led===1'b0 && dut.seconds===6'd0,
                 "Reset clears Warning state");
      KEY[0]=1; #1;
      check_true(SW[1]===1'b1,"Warning switch remains asserted after reset");
      SW[1]=0;

      reset_scheduler();
      SW[0]=1;
      repeat(9) sos_tick();
      check_true(dut.sos_step!==5'd0,"SOS active before reset");
      KEY[0]=0; #1;
      check_true(dut.sos_step===5'd0 && dut.sos_count===4'd0 &&
                 dut.sos_led===1'b0,"Reset clears SOS state");
      KEY[0]=1; #1;
      sos_tick();
      check_true(dut.sos_step===5'd1 && dut.sos_led===1'b1,
                 "SOS restarts from first dot while SW0 remains ON");
      SW[0]=0;
    end
  endtask

  // Optional full-speed timing test: +FULL_TIMING. This uses NO force on
  // divider signals. It simulates one real second (50 million 50-MHz clocks),
  // which can take a long time in browser simulators.
  task test_real_timing;
    integer ticks_1hz, ticks_4hz, warning_flips, n;
    reg previous_warning;
    begin
      reset_scheduler();
      $display("\n===== REAL CLOCK TIMING (NO FORCED TICKS) =====");
      ticks_1hz=0; ticks_4hz=0; warning_flips=0;
      SW[1]=1;
      previous_warning=dut.warn_led;
      for (n=0; n<50_000_000; n=n+1) begin
        @(posedge MAX10_CLK1_50); #1;
        if (dut.tick===1'b1) ticks_1hz=ticks_1hz+1;
        if (dut.tick_4hz===1'b1) ticks_4hz=ticks_4hz+1;
        if (dut.warn_led!==previous_warning) begin
          warning_flips=warning_flips+1;
          previous_warning=dut.warn_led;
        end
      end
      check_true(ticks_1hz===1,"Exactly one 1 Hz tick per 50 million clocks");
      check_true(ticks_4hz===4,"Exactly four 4 Hz ticks per 50 million clocks");
      check_true(warning_flips>=1 && warning_flips<=2,
                 "Warning changes phase at its 2 Hz interval");
      SW[1]=0;
    end
  endtask

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0,tb_scheduler);
    reset_scheduler();

    $display("\n===== TIMER 0-59 =====");
    dut.seconds = 6'd58;
    scheduler_tick();
    check_true(dut.seconds === 6'd59,"58 -> 59");
    scheduler_tick();
    check_true(dut.seconds === 6'd0,"59 -> 0 rollover");
    scheduler_tick();
    check_true(dut.seconds === 6'd1,"0 -> 1");

    $display("\n===== TASK SELECTION BOUNDARIES =====");
    task_at(9,7'b0110000);  task_at(10,7'b0100100);
    task_at(11,7'b0011001); task_at(19,7'b0011001);
    task_at(20,7'b0100100); task_at(21,7'b0110000);
    task_at(29,7'b0110000); task_at(30,7'b0100100);
    task_at(31,7'b0011001); task_at(39,7'b0011001);
    task_at(40,7'b0100100); task_at(41,7'b0110000);
    task_at(49,7'b0110000); task_at(50,7'b0100100);
    task_at(51,7'b0011001); task_at(59,7'b0011001);
    task_at(0,7'b0110000);

    $display("\n===== TASK 2 ALL LEDS =====");
    task2_at(10); task2_at(20); task2_at(30);
    task2_at(40); task2_at(50);
    // The task display must change immediately after the one-second slot.
    task_at(11,7'b0011001); task_at(21,7'b0110000);
    task_at(31,7'b0011001); task_at(41,7'b0110000);
    task_at(51,7'b0011001);

    reset_scheduler();
    $display("\n===== TASK 3: LED0 -> LED9 -> LED0 =====");
    select_second(0);
    for (i=0; i<=18; i=i+1) begin
      expected_pos = i%10;
      $display("  Task 3 step %0d expected LED%0d",i,expected_pos);
      check_hex5(7'b0110000,"Task 3 display");
      check_led(10'b0000000001 << expected_pos,"Task 3 Wrap");
      if (i<18) t3_step();
    end
    stop_selecting();

    reset_scheduler();
    $display("\n===== TASK 4: LED9 -> LED0 -> LED9 =====");
    select_second(11);
    for (i=0; i<=18; i=i+1) begin
      expected_pos = (i<=9) ? (9-i) : (i-9);
      $display("  Task 4 step %0d expected LED%0d",i,expected_pos);
      check_hex5(7'b0011001,"Task 4 display");
      check_led(10'b0000000001 << expected_pos,"Task 4 bounce");
      if (i<18) t4_step();
    end
    stop_selecting();

    reset_scheduler();
    $display("\n===== WARNING: OUTPUT AND PHASES =====");
    select_second(9);
    SW[1]=1; #1;
    check_led(10'b1010101010,"Warning initial pattern");
    // Accelerate the existing 2 Hz warning counter's terminal count.
    @(negedge MAX10_CLK1_50);
    force dut.warn_cnt = 25'd25_000_000;
    @(posedge MAX10_CLK1_50); #1;
    release dut.warn_cnt; #1;
    check_led(10'b0101010101,"Warning inverted pattern");
    @(negedge MAX10_CLK1_50);
    force dut.warn_cnt = 25'd25_000_000;
    @(posedge MAX10_CLK1_50); #1;
    release dut.warn_cnt; #1;
    check_led(10'b1010101010,"Warning returns to initial pattern");
    scheduler_tick();
    check_true(dut.seconds===6'd9,"Timer pauses during Warning");
    SW[1]=0; #1;
    check_hex5(7'b0110000,"Normal task returns after Warning");
    stop_selecting();

    reset_scheduler();
    $display("\n===== SOS PRIORITY AND TIMER PAUSE =====");
    dut.seconds = 6'd9;
    SW[0]=1; #1;
    check_true({HEX5,HEX4,HEX3} ===
      {7'b0010010,7'b1000000,7'b0010010},"SOS display");
    check_led(10'b0000000000,"SOS initial LED state");
    SW[1]=1; #1;
    check_true({HEX5,HEX4,HEX3} ===
      {7'b0010010,7'b1000000,7'b0010010},"SOS outranks Warning display");
    sos_tick();
    check_led(10'b1111111111,"SOS outranks Warning LEDs when ON");
    scheduler_tick();
    check_true(dut.seconds===6'd9,"Timer pauses during SOS");
    SW[1:0]=0;

    test_sos_pattern();

    reset_scheduler();
    $display("\n===== TASK 3 PAUSE / RESUME =====");
    select_second(0);
    check_led(10'b0000000001,"Task 3 begins at LED0");
    t3_step();
    check_led(10'b0000000010,"Task 3 advances to LED1");
    saved_t3_pos = dut.t3.pos;
    saved_t3_count = dut.t3.slow_count;
    SW[1]=1;
    repeat(3) scheduler_tick();
    check_true(dut.t3.pos===saved_t3_pos &&
               dut.t3.slow_count===saved_t3_count,
               "Task 3 position/counter frozen during Warning");
    check_true(dut.seconds===6'd0,"Timer frozen during Warning");
    SW[1]=0; #1;
    check_led(10'b0000000010,"Task 3 restores LED1");
    t3_step();
    check_led(10'b0000000100,"Task 3 continues to LED2");
    stop_selecting();

    reset_scheduler();
    $display("\n===== TASK 4 PAUSE / RESUME =====");
    select_second(11);
    check_led(10'b1000000000,"Task 4 begins at LED9");
    t4_step();
    check_led(10'b0100000000,"Task 4 advances to LED8");
    saved_t4_pos=dut.t4.pos;
    saved_t4_count=dut.t4.slow_count;
    saved_t4_dir=dut.t4.dir;
    SW[0]=1;
    repeat(3) scheduler_tick();
    check_true(dut.t4.pos===saved_t4_pos &&
               dut.t4.slow_count===saved_t4_count &&
               dut.t4.dir===saved_t4_dir,
               "Task 4 position/counter/direction frozen during SOS");
    check_true(dut.seconds===6'd11,"Timer frozen during SOS");
    SW[0]=0; #1;
    check_led(10'b0100000000,"Task 4 restores LED8");
    t4_step();
    check_led(10'b0010000000,"Task 4 continues to LED7");
    stop_selecting();

    test_sos_repeats();
    test_interrupt_transitions();
    test_resets_during_activity();

    reset_scheduler();
    $display("\n===== ASYNCHRONOUS RESET =====");
    SW=0;
    #1 KEY[0]=0;
    #1;
    check_true(dut.seconds===6'd0 &&
               dut.t3.pos===4'd0 &&
               dut.t4.pos===4'd9 &&
               dut.t4.dir===1'b0 &&
               dut.t3.slow_count===23'd0 &&
               dut.t4.slow_count===23'd0 &&
               dut.sos_step===5'd0 &&
               dut.sos_count===4'd0 &&
               dut.sos_led===1'b0 &&
               dut.warn_led===1'b0,
               "Reset restores checked state");

    $display("\n===== FINAL SUMMARY =====");
    $display("Checks: %0d  Failures: %0d",checks,failures);
    if (failures==0) begin
      $display("ALL SCHEDULER TESTS PASSED");
      $finish;
    end else begin
      $fatal(1,"SCHEDULER TESTS FAILED: %0d failure(s)",failures);
    end
  end
endmodule
