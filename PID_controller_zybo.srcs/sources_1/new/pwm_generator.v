`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/15/2026 02:30:15 PM
// Design Name: 
// Module Name: pwm_generator
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


module pwm_generator
#(
		// Users to add parameters here
        parameter integer CLK_FREQ_HZ = 100_000_000,
        parameter integer PWM_FREQ_HZ = 20_000
)(
        input wire clk,
        input wire rst_n,
        input wire [15:0] u_out,
        output wire pwm_out
    );
    localparam integer PERIOD = CLK_FREQ_HZ / PWM_FREQ_HZ;
    reg [31:0]         counter;
	wire [15:0]        magnitude;
	wire [9:0]         duty;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 32'd0;
        end
        else begin
            if (counter >= PERIOD - 1)
                counter <= 32'd0;
            else
                counter <= counter + 1'b1;
        end
    end

    assign magnitude = u_out[15] ? (~u_out + 1'b1) : u_out;
    assign duty = (magnitude * 1000) / 32768;
    // when counter reaches threshold, go to 0, the threshold is PERIOD * duty / 1000 (percentage)
    assign pwm_out = (counter < ((PERIOD * duty) / 1000))? 1'b1 : 1'b0;
	// User logic ends

	endmodule
