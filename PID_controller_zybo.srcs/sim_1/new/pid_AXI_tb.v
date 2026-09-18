`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// Testbench for PID_contoller (AXI4-Lite wrapped PID core)
//
// Register map assumed (word-addressed, C_S00_AXI_ADDR_WIDTH = 5 -> 8 words):
//   0x00  setpoint  (Q8.8, signed, lower 16 bits)
//   0x04  feedback  (Q8.8, signed, lower 16 bits)
//   0x08  kp        (Q8.8, signed, lower 16 bits)
//   0x0C  ki        (Q8.8, signed, lower 16 bits)
//   0x10  kd        (Q8.8, signed, lower 16 bits)
//   0x14  start     (write 1 to trigger; AXI slave is assumed to generate
//                     a single-cycle start_pulse internally on the write)
//
// Adjust ADDR_* below if your actual S00_AXI slave uses different offsets.
//////////////////////////////////////////////////////////////////////////////

module PID_contoller_tb;

    // ------------------------------------------------------------------
    // Parameters / addresses
    // ------------------------------------------------------------------
    localparam C_S00_AXI_DATA_WIDTH = 32;
    localparam C_S00_AXI_ADDR_WIDTH = 5;

    localparam ADDR_SETPOINT = 5'h00;
    localparam ADDR_FEEDBACK = 5'h04;
    localparam ADDR_KP       = 5'h08;
    localparam ADDR_KI       = 5'h0C;
    localparam ADDR_KD       = 5'h10;
    localparam ADDR_START    = 5'h14;

    // ------------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------------
    reg  s00_axi_aclk    = 0;
    reg  s00_axi_aresetn = 0;

    reg  [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_awaddr;
    reg  [2:0]                      s00_axi_awprot;
    reg                             s00_axi_awvalid;
    wire                            s00_axi_awready;

    reg  [C_S00_AXI_DATA_WIDTH-1:0]   s00_axi_wdata;
    reg  [(C_S00_AXI_DATA_WIDTH/8)-1:0] s00_axi_wstrb;
    reg                                s00_axi_wvalid;
    wire                                s00_axi_wready;

    wire [1:0] s00_axi_bresp;
    wire       s00_axi_bvalid;
    reg        s00_axi_bready;

    reg  [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_araddr;
    reg  [2:0]                      s00_axi_arprot;
    reg                             s00_axi_arvalid;
    wire                            s00_axi_arready;

    wire [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_rdata;
    wire [1:0]                      s00_axi_rresp;
    wire                            s00_axi_rvalid;
    reg                             s00_axi_rready;

    wire signed [15:0] u_out;
    wire                start;

    // ------------------------------------------------------------------
    // Clock: 100 MHz
    // ------------------------------------------------------------------
    always #5 s00_axi_aclk = ~s00_axi_aclk;

    // ------------------------------------------------------------------
    // DUT instantiation
    // ------------------------------------------------------------------
    PID_contoller #(
        .MAX_LIMIT   (16'h7FFF),
        .MIN_LIMIT   (16'h8000),
        .I_MAX       (32'h0000_7FFF),
        .I_MIN       (32'hFFFF_8000),
        .U_MAX_Q16   (32'sh007F_FFFF),
        .U_MIN_Q16   (32'shFF80_0000),
        .C_S00_AXI_DATA_WIDTH (C_S00_AXI_DATA_WIDTH),
        .C_S00_AXI_ADDR_WIDTH (C_S00_AXI_ADDR_WIDTH)
    ) dut (
        .u_out   (u_out),
        .start   (start),

        .s00_axi_aclk    (s00_axi_aclk),
        .s00_axi_aresetn (s00_axi_aresetn),
        .s00_axi_awaddr  (s00_axi_awaddr),
        .s00_axi_awprot  (s00_axi_awprot),
        .s00_axi_awvalid (s00_axi_awvalid),
        .s00_axi_awready (s00_axi_awready),
        .s00_axi_wdata   (s00_axi_wdata),
        .s00_axi_wstrb   (s00_axi_wstrb),
        .s00_axi_wvalid  (s00_axi_wvalid),
        .s00_axi_wready  (s00_axi_wready),
        .s00_axi_bresp   (s00_axi_bresp),
        .s00_axi_bvalid  (s00_axi_bvalid),
        .s00_axi_bready  (s00_axi_bready),
        .s00_axi_araddr  (s00_axi_araddr),
        .s00_axi_arprot  (s00_axi_arprot),
        .s00_axi_arvalid (s00_axi_arvalid),
        .s00_axi_arready (s00_axi_arready),
        .s00_axi_rdata   (s00_axi_rdata),
        .s00_axi_rresp   (s00_axi_rresp),
        .s00_axi_rvalid  (s00_axi_rvalid),
        .s00_axi_rready  (s00_axi_rready)
    );

    // ------------------------------------------------------------------
    // AXI4-Lite WRITE task
    //   Drives AW+W concurrently, waits for both *ready, then waits for
    //   the write response (BVALID) and accepts it.
    // ------------------------------------------------------------------
    task axi_write;
        input [C_S00_AXI_ADDR_WIDTH-1:0] addr;
        input [C_S00_AXI_DATA_WIDTH-1:0] data;
        begin
            @(posedge s00_axi_aclk);
            s00_axi_awaddr  <= addr;
            s00_axi_awprot  <= 3'b000;
            s00_axi_awvalid <= 1'b1;
            s00_axi_wdata   <= data;
            s00_axi_wstrb   <= 4'hF;
            s00_axi_wvalid  <= 1'b1;
            s00_axi_bready  <= 1'b1;

            // wait until both address and data channels have been accepted
            // (they may be accepted on different cycles depending on the slave)
            wait (s00_axi_awready === 1'b1 && s00_axi_wready === 1'b1);
            @(posedge s00_axi_aclk);
            s00_axi_awvalid <= 1'b0;
            s00_axi_wvalid  <= 1'b0;

            // wait for the write response
            wait (s00_axi_bvalid === 1'b1);
            @(posedge s00_axi_aclk);
            s00_axi_bready <= 1'b0;

            $display("[%0t] AXI WRITE  addr=0x%0h data=0x%0h bresp=%0d",
                      $time, addr, data, s00_axi_bresp);
        end
    endtask

    // ------------------------------------------------------------------
    // AXI4-Lite READ task
    // ------------------------------------------------------------------
    task axi_read;
        input  [C_S00_AXI_ADDR_WIDTH-1:0] addr;
        output [C_S00_AXI_DATA_WIDTH-1:0] data;
        begin
            @(posedge s00_axi_aclk);
            s00_axi_araddr  <= addr;
            s00_axi_arprot  <= 3'b000;
            s00_axi_arvalid <= 1'b1;
            s00_axi_rready  <= 1'b1;

            wait (s00_axi_arready === 1'b1);
            @(posedge s00_axi_aclk);
            s00_axi_arvalid <= 1'b0;

            wait (s00_axi_rvalid === 1'b1);
            data = s00_axi_rdata;
            @(posedge s00_axi_aclk);
            s00_axi_rready <= 1'b0;

            $display("[%0t] AXI READ   addr=0x%0h data=0x%0h rresp=%0d",
                      $time, addr, data, s00_axi_rresp);
        end
    endtask

    // ------------------------------------------------------------------
    // Convenience: pulse the start register (write 1) and wait for
    // the internal pipeline to produce a result. The pipeline here is
    // 3 stages deep (stage1 -> stage2 -> stage3), so a handful of extra
    // clock cycles after the AXI write is enough margin.
    // ------------------------------------------------------------------
    task run_pid_step;
        input signed [15:0] setpoint_val;
        input signed [15:0] feedback_val;
        begin
            axi_write(ADDR_SETPOINT, {16'd0, setpoint_val});
            axi_write(ADDR_FEEDBACK, {16'd0, feedback_val});
            axi_write(ADDR_START,    32'd1);   // trigger start_pulse

            // give the 3-stage pipeline time to propagate + settle
            repeat (8) @(posedge s00_axi_aclk);

            $display("[%0t] setpoint=%0d feedback=%0d -> u_out=%0d (0x%0h)",
                      $time, setpoint_val, feedback_val, u_out, u_out);
        end
    endtask

    // ------------------------------------------------------------------
    // Read-back verification: confirm each register reads back what
    // was written (sanity check on the AXI slave's register file).
    // ------------------------------------------------------------------
    reg [C_S00_AXI_DATA_WIDTH-1:0] readback;

    task check_register;
        input [C_S00_AXI_ADDR_WIDTH-1:0] addr;
        input [C_S00_AXI_DATA_WIDTH-1:0] expected;
        input [8*32-1:0]                 name; // string label for display
        begin
            axi_read(addr, readback);
            if (readback[15:0] !== expected[15:0])
                $display("  *** MISMATCH %0s: expected 0x%0h, got 0x%0h",
                          name, expected[15:0], readback[15:0]);
            else
                $display("  OK %0s readback matches (0x%0h)", name, readback[15:0]);
        end
    endtask

    // ------------------------------------------------------------------
    // Main test sequence
    // ------------------------------------------------------------------
    initial begin
        // idle drive values
        s00_axi_awaddr  = 0; s00_axi_awprot = 0; s00_axi_awvalid = 0;
        s00_axi_wdata   = 0; s00_axi_wstrb  = 0; s00_axi_wvalid  = 0;
        s00_axi_bready  = 0;
        s00_axi_araddr  = 0; s00_axi_arprot = 0; s00_axi_arvalid = 0;
        s00_axi_rready  = 0;

        // reset
        s00_axi_aresetn = 0;
        repeat (5) @(posedge s00_axi_aclk);
        s00_axi_aresetn = 1;
        repeat (5) @(posedge s00_axi_aclk);

        $display("\n===== Test 1: program gains =====");
        axi_write(ADDR_KP, {16'd0, 16'sh0100});  // kp = 1.0 in Q8.8
        axi_write(ADDR_KI, {16'd0, 16'sh0010});  // ki = 0.0625
        axi_write(ADDR_KD, {16'd0, 16'sh0020});  // kd = 0.125

        $display("\n===== Test 2: readback verification of gain registers =====");
        check_register(ADDR_KP, 32'h0100, "kp");
        check_register(ADDR_KI, 32'h0010, "ki");
        check_register(ADDR_KD, 32'h0020, "kd");

        $display("\n===== Test 3: basic step response (setpoint=5.0, feedback=0.0) =====");
        run_pid_step(16'sh0500, 16'sh0000);  // 5.0, 0.0

        $display("\n===== Test 4: setpoint == feedback (error should be ~0) =====");
        run_pid_step(16'sh0500, 16'sh0500);  // 5.0, 5.0

        $display("\n===== Test 5: negative error (feedback overshoots setpoint) =====");
        run_pid_step(16'sh0200, 16'sh0500);  // 2.0, 5.0 -> negative error

        $display("\n===== Test 6: large positive error, check saturation path =====");
        axi_write(ADDR_KP, {16'd0, 16'sh7F00});  // large kp to try to drive u_out into saturation
        run_pid_step(16'sh7F00, 16'sh8000);      // max setpoint, min feedback -> huge error

        $display("\n===== Test 7: repeated steps to observe integral accumulation =====");
        axi_write(ADDR_KP, {16'd0, 16'sh0000});  // zero out P and D so only I contributes
        axi_write(ADDR_KD, {16'd0, 16'sh0000});
        axi_write(ADDR_KI, {16'd0, 16'sh0100});  // ki = 1.0
        run_pid_step(16'sh0100, 16'sh0000);  // constant small positive error, several times
        run_pid_step(16'sh0100, 16'sh0000);
        run_pid_step(16'sh0100, 16'sh0000);
        run_pid_step(16'sh0100, 16'sh0000);
        $display("  (u_out should trend upward each step as the integral accumulates)");

        $display("\n===== All tests issued, finishing =====");
        repeat (20) @(posedge s00_axi_aclk);
        $finish;
    end

    // ------------------------------------------------------------------
    // Optional: dump waves for GTKWave / Vivado simulator viewing
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("PID_contoller_tb.vcd");
        $dumpvars(0, PID_contoller_tb);
    end

endmodule