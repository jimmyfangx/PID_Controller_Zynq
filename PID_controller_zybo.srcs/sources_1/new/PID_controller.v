`timescale 1ns / 1ps

module pid_controller #(
        parameter signed [15:0] MAX_LIMIT = 16'h7FFF,  // +127.996 (Max Q8.8)
        parameter signed [15:0] MIN_LIMIT = 16'h8000, // -128.000 (Min Q8.8)
        parameter signed [31:0] I_MAX = 32'h0000_7FFF, // Maximum of integral value +127.99998
        parameter signed [31:0] I_MIN = 32'hFFFF_8000, // Minimum of integral value -128.00000
        parameter signed [31:0] U_MAX_Q16 = 32'sh007F_FFFF,
        parameter signed [31:0] U_MIN_Q16 = 32'shFF80_0000
    )(
        input  wire        clk,
        input  wire        rst_n,
        input  wire        start,
        input  wire signed [15:0] setpoint,   // Q8.8
        input  wire signed [15:0] feedback,  // Q8.8 
        input  wire signed [15:0] kp,        // Q8.8
        input  wire signed [15:0] ki,        // Q8.8 
        input  wire signed [15:0] kd,        // Q8.8
        output reg  signed [15:0] u_out,     // Q8.8
        output reg         done
    );

    // pipeline stage 1 reg
    reg signed [15:0] err_reg;
    reg signed [15:0] d_err_reg;
    reg               stage1_valid;

    //  pipeline stage 2 reg
    reg signed [31:0] p_mult; // Q16.16 Intermediate
    reg signed [31:0] i_mult; // Q16.16 Intermediate
    reg signed [31:0] d_mult; // Q16.16 Intermediate
    reg               stage2_valid;

    //  pipeline stage 3 reg
    reg signed [31:0] i_state; // Integrated Accumulator: Q16.16 representation

    // STAGE 1: Error & Derivative Computation
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            err_reg      <= 16'd0;
            d_err_reg    <= 16'd0;
            stage1_valid <= 1'b0;
        end else if (start) begin
            // error calculation
            err_reg      <= setpoint - feedback;
            
            // derivative calculation
            d_err_reg    <= (setpoint - feedback) - err_reg;
            stage1_valid <= 1'b1;
        end else begin
            stage1_valid <= 1'b0;
        end
    end


    // STAGE 2: Multiplication 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_mult       <= 32'd0;
            i_mult       <= 32'd0;
            d_mult       <= 32'd0;
            stage2_valid <= 1'b0;
        end else if (stage1_valid) begin
            p_mult       <= kp * err_reg;
            i_mult       <= ki * err_reg;
            d_mult       <= kd * d_err_reg;
            stage2_valid <= 1'b1;
        end else begin
            stage2_valid <= 1'b0;
        end
    end

    // STAGE 3: Accumulation, Summation & Output
    reg signed [31:0] i_state_next;
    reg signed [31:0] u_sum;

    // Combinational circuit to calculate for integral and u_sum
    always @(*) begin
        i_state_next = i_state + i_mult;
        
        // Anti-Windup Clamping 
        if (i_state_next > I_MAX) 
            i_state_next = I_MAX;
        else if (i_state_next < I_MIN)
            i_state_next = I_MIN;
            
        // Calculate raw control output (all shifted to match Q16.16)
        u_sum = p_mult + i_state_next + d_mult;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_state <= 32'd0;
            u_out   <= 16'd0;
            done    <= 1'b0;
        end else if (stage2_valid) begin
            i_state <= i_state_next;
            done    <= 1'b1;
            
            // Saturation / Clamping logic to 16-bit Q8.8
            if (u_sum > U_MAX_Q16) begin
                u_out <= MAX_LIMIT;
            end
            else if (u_sum < U_MIN_Q16) begin
                u_out <= MIN_LIMIT;
            end
            else begin
                u_out <= u_sum >>> 8;
            end
        end else begin
            done <= 1'b0;
        end
    end

endmodule
