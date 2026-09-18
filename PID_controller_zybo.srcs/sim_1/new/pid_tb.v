`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/15/2026 02:37:49 PM
// Design Name: 
// Module Name: pid_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module pid_tb;

// variables
reg clk = 0;
reg rst;
reg start;
reg [15:0] kp;
reg [15:0] ki;
reg [15:0] kd;
reg [15:0] setpoint;
reg [15:0] feedback;
wire [15:0] u_out;
wire pwm_out;

pid_controller dut_pid (
    .clk        (clk),
    .rst_n      (rst),
    .start      (start),
    .setpoint   (setpoint),
    .feedback   (feedback),
    .kp         (kp),
    .ki         (ki),
    .kd         (kd),
    .u_out      (u_out),
    .done       (done)
);

pwm_generator dut_pwm (
    .clk        (clk),
    .rst_n      (rst),
    .u_out      (u_out),
    .pwm_out    (pwm_out)
);

always #5 clk = ~clk;
initial begin
    rst = 0;
    kp = 16'sh0100;
    ki = 16'sh0100;
    kd = 16'sh0100;
    
    #5
    rst = 1;
    
    #100000
    setpoint = 16'sh0500;  // 5.0
    feedback = 16'sh0100;  // 1.0
    start = 1;
    
    #100000
    setpoint = 16'sh0500;  // 5.0
    feedback = 16'sh0300;  // 3.0
    
    #100000
    setpoint = 16'sh0500;  // 5.0
    feedback = 16'sh0500;  // 5.0
        
    $finish;
    
end
endmodule
