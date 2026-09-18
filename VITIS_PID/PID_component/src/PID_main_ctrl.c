#include <stdio.h>
#include "platform.h"
#include "xgpio.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "xiltimer.h"
#include "xscugic.h"
#include <math.h>    
#include <stdint.h>
#include "sleep.h"

#define GPIO_DEVICE_ID     XPAR_AXI_GPIO_0_DEVICE_ID
#define GPIO_INT_VEC_ID    61   // = 29, required interrupt enabled on GPIO
#define GPIO_CHANNEL       1                     // channel the pulse input is wired to
#define INTC_DEVICE_ID     XPAR_SCUGIC_SINGLE_DEVICE_ID
#define XGPIO_IR_CH1_MASK    0x1   /* Mask for the 1st channel */
#define PULSES_PER_REV   12

#define PID_BASEADDR          XPAR_PID_CONTOLLER_0_BASEADDR

#define REG_SETPOINT_OFFSET   0x00
#define REG_FEEDBACK_OFFSET   0x04
#define REG_KP_OFFSET         0x08
#define REG_KI_OFFSET         0x0C
#define REG_KD_OFFSET         0x10
#define REG_START_OFFSET      0x14
#define REG_UOUT_OFFSET   0x18   // word 6: 6*4 = 0x18
#define REG_DONE_OFFSET   0x1C   // word 7: 7*4 = 0x1C

const int16_t setpoint_q8_8 = 20.0 * 256;
const int16_t kp = 1 * 256;
const int16_t ki = 0;
const int16_t kd = 0;
const int16_t start = 1;

XGpio EncoderA;
static XScuGic      InterruptController;


volatile uint32_t pulse_count = 0;   // shared between ISR and main loop
void GpioIsr(void *CallbackRef);


// ISR interrupt code
int SetupInterruptSystem(void) {
    int Status;

    Status = XGpio_Initialize(&EncoderA, XPAR_AXI_GPIO_0_BASEADDR);
    if (Status != XST_SUCCESS) return XST_FAILURE;


    XGpio_SetDataDirection(&EncoderA, GPIO_CHANNEL, 1); // input
    xil_printf("SIS: gpio OK, looking up GIC config\r\n");

    // 2. Initialize the GIC (the actual interrupt controller on the CPU side)
    XScuGic_Config *IntcConfig = XScuGic_LookupConfig(INTC_DEVICE_ID);
        if (IntcConfig == NULL) {
        xil_printf("SIS: GIC LookupConfig FAILED (NULL)\r\n");
        return XST_FAILURE;
    }
    xil_printf("SIS: GIC config found, CfgInitialize\r\n");
    
    Status = XScuGic_CfgInitialize(&InterruptController, IntcConfig, IntcConfig->CpuBaseAddress);
    if (Status != XST_SUCCESS) return XST_FAILURE;
        if (Status != XST_SUCCESS) {
        xil_printf("SIS: GIC CfgInitialize FAILED\r\n");
        return XST_FAILURE;
    }
    xil_printf("SIS: GIC init OK\r\n");
    

    // Tell the GIC: "when interrupt line GPIO_INT_VEC_ID fires,
    Status = XScuGic_Connect(&InterruptController, GPIO_INT_VEC_ID,(Xil_InterruptHandler)GpioIsr, (void *)&EncoderA);
    if (Status != XST_SUCCESS) return XST_FAILURE;
    xil_printf("SIS: GIC connect OK\r\n");
    
    XScuGic_SetPriorityTriggerType(&InterruptController, GPIO_INT_VEC_ID, 0xA0, 0x1);    // Enable that specific interrupt line at the GIC
    XScuGic_Enable(&InterruptController, GPIO_INT_VEC_ID);

    // Enable interrupts at the EncoderA peripheral itself (device-level enable)
    XGpio_InterruptEnable(&EncoderA, XGPIO_IR_CH1_MASK);
    XGpio_InterruptGlobalEnable(&EncoderA);
    
    xil_printf("GIER = 0x%08X\r\n",
           Xil_In32(XPAR_AXI_GPIO_0_BASEADDR + XGPIO_GIE_OFFSET));

    xil_printf("IPIER = 0x%08X\r\n",
            Xil_In32(XPAR_AXI_GPIO_0_BASEADDR + XGPIO_IER_OFFSET));


           
    //Hook the GIC into the CPU's exception table (once per program)
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
        (Xil_ExceptionHandler)XScuGic_InterruptHandler,
        &InterruptController);
    xil_printf("SIS: exception handler registered\r\n");
    

    // Globally enable interrupts on the CPU (ARM-level, last step)
    Xil_ExceptionEnable();
    xil_printf("SIS: all interrupt setup complete\r\n");

    return XST_SUCCESS;
}


int16_t double_to_q8_8(double value) {
    // Q8.8 signed range: -128.0 to +127.99609375 (raw: -32768 to 32767)
    const double Q8_8_MAX = 127.99609375;
    const double Q8_8_MIN = -128.0;


    if (value > Q8_8_MAX) value = Q8_8_MAX;
    if (value < Q8_8_MIN) value = Q8_8_MIN;


    return (int16_t)round(value * 256.0);
}


int main() {
    init_platform();
    xil_printf("BOOT: after init_platform\r\n");

    
    if (SetupInterruptSystem() != XST_SUCCESS) {
        xil_printf("Interrupt setup failed\r\n");
        cleanup_platform();
        return -1;
    }

    xil_printf("Interrupt setup success\r\n");

    usleep(1000);
    
    uint32_t last_count = 0;
    XTime last_time, now;
    XTime_GetTime(&last_time);
    const double CLOCK_FREQ = COUNTS_PER_SECOND;
   

    while (1) {
        XTime_GetTime(&now);
        double elapsed_sec = (double)(now - last_time) / CLOCK_FREQ;
        
        usleep(1000);
        if (elapsed_sec >= 0.1) {
            uint32_t current_count = pulse_count;

            uint32_t delta = current_count - last_count;
            double actualPulsesPerSecond = (double)delta / elapsed_sec;
            double actualRPM = actualPulsesPerSecond * 60.0 / PULSES_PER_REV;
            int16_t feedback_q8_8 = double_to_q8_8(actualRPM);
            xil_printf("feedback Q8.8 =%d actual_rpm=%d\r\n", feedback_q8_8, (int)actualRPM);


            last_count = current_count;
            last_time  = now;
            
            

            // feed actualPulsesPerSecond into your PID's `feedback` input
            Xil_Out32(PID_BASEADDR + REG_SETPOINT_OFFSET, (uint32_t)(uint16_t)setpoint_q8_8);
            Xil_Out32(PID_BASEADDR + REG_FEEDBACK_OFFSET,  (uint32_t)(uint16_t)feedback_q8_8);
            Xil_Out32(PID_BASEADDR + REG_KP_OFFSET,        (uint32_t)(uint16_t)kp);
            Xil_Out32(PID_BASEADDR + REG_KI_OFFSET,        (uint32_t)(uint16_t)ki);
            Xil_Out32(PID_BASEADDR + REG_KD_OFFSET,        (uint32_t)(uint16_t)kd);
            Xil_Out32(PID_BASEADDR + REG_START_OFFSET, 1);
          uint32_t feedback_raw;
            uint32_t u_out_raw;
            int16_t feedback_readback;
            int16_t u_out_readback;


            // feed actualPulsesPerSecond into your PID's `feedback` input
            feedback_raw = Xil_In32(PID_BASEADDR + REG_FEEDBACK_OFFSET);
            feedback_readback = (int16_t)(feedback_raw & 0xFFFF);

            /* Read u_out */
            u_out_raw = Xil_In32(PID_BASEADDR + REG_UOUT_OFFSET);
            u_out_readback = (int16_t)(u_out_raw & 0xFFFF);

            /* Convert Q8.8 to integer-ish decimal */
            xil_printf("FEEDBACK Q8.8: %d.%02d\r\n",
           feedback_readback / 256,
           ((feedback_readback < 0 ? -feedback_readback : feedback_readback) % 256) * 100 / 256);

            xil_printf("U_OUT Q8.8: %d.%02d\r\n",
           u_out_readback / 256,
           ((u_out_readback < 0 ? -u_out_readback : u_out_readback) % 256) * 100 / 256);
    
            
            /*
            // --- readback of everything just written ---
            int16_t  rb_setpoint = (int16_t)Xil_In32(PID_BASEADDR + REG_SETPOINT_OFFSET);
            int16_t  rb_feedback = (int16_t)Xil_In32(PID_BASEADDR + REG_FEEDBACK_OFFSET);
            int16_t  rb_kp       = (int16_t)Xil_In32(PID_BASEADDR + REG_KP_OFFSET);
            int16_t  rb_ki       = (int16_t)Xil_In32(PID_BASEADDR + REG_KI_OFFSET);
            int16_t  rb_kd       = (int16_t)Xil_In32(PID_BASEADDR + REG_KD_OFFSET);
            uint32_t rb_start    = Xil_In32(PID_BASEADDR + REG_START_OFFSET);

            xil_printf("RB: setpoint=%d feedback=%d kp=%d ki=%d kd=%d start=%d\r\n",
                    rb_setpoint, rb_feedback, rb_kp, rb_ki, rb_kd, rb_start);

            
            uint32_t u_out_raw32 = Xil_In32(PID_BASEADDR + REG_UOUT_OFFSET);
            int16_t u_out_val = (int16_t)(u_out_raw32 & 0xFFFF);
            uint32_t done_val = Xil_In32(PID_BASEADDR + REG_DONE_OFFSET);

            
            // Convert Q8.8 raw value back to real units
            int u_out_whole = u_out_val / 256;                    // integer part
            int u_out_frac  = (u_out_val % 256) * 1000 / 256;      // 3 decimal digits of fraction
            if (u_out_frac < 0) u_out_frac = -u_out_frac;          // handle negative fraction sign correctly

            xil_printf("u_out_raw = %d  u_out_real = %d.%03d  done = %d\r\n",
                    u_out_val, u_out_whole, u_out_frac, done_val);*/

        }
    }
}



// GPIO ISR code
void GpioIsr(void *CallbackRef) {
    XGpio *GpioPtr = (XGpio *)CallbackRef;
    pulse_count++;
    XGpio_InterruptClear(GpioPtr, XGPIO_IR_CH1_MASK);
}
