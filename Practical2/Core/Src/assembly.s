/*
 * assembly.s
 *
 */
 
 @ DO NOT EDIT
	.syntax unified
    .text
    .global ASM_Main
    .thumb_func

@ DO NOT EDIT
vectors:
	.word 0x20002000
	.word ASM_Main + 1

@ DO NOT EDIT label ASM_Main
ASM_Main:

	@ Some code is given below for you to start with
	LDR R0, RCC_BASE  		@ Enable clock for GPIOA and B by setting bit 17 and 18 in RCC_AHBENR
	LDR R1, [R0, #0x14]
	LDR R2, AHBENR_GPIOAB	@ AHBENR_GPIOAB is defined under LITERALS at the end of the code
	ORRS R1, R1, R2
	STR R1, [R0, #0x14]

	LDR R0, GPIOA_BASE		@ Enable pull-up resistors for pushbuttons
	MOVS R1, #0b01010101
	STR R1, [R0, #0x0C]
	LDR R1, GPIOB_BASE  	@ Set pins connected to LEDs to outputs
	LDR R2, MODER_OUTPUT
	STR R2, [R1, #0]
	MOVS R2, #0         	@ NOTE: R2 will be dedicated to holding the value on the LEDs

@ Initialize state variables (only done once at startup)
	MOVS R3, #1				@ R3: Current increment value (default 1)
	MOVS R4, #1				@ R4: Current delay mode (1=long/0.7s, 0=short/0.3s)
	MOVS R5, #0x0F			@ R5: Previous button states (start with all released)
	MOVS R6, #0				@ R6: Freeze mode (0=normal, 1=SW2, 2=SW3)

main_loop:
	@ Read current button states with debouncing
	LDR R0, GPIOA_BASE
	LDR R1, [R0, #0x10]		@ R1: Current button states (raw)
	BL delay_short			@ Debounce delay
	LDR R1, [R0, #0x10]		@ Re-read after debounce
	MOVS R0, #0x0F			@ Mask for buttons 0-3
	ANDS R1, R1, R0			@ R1: Clean button states (bits 0-3 only)
	
	@ Edge detection (XOR previous with current, inverted for active-low)
	MVNS R0, R5				@ Invert previous (for active-low logic)
	MVNS R7, R1				@ Invert current (for active-low logic)
	EORS R0, R0, R7			@ R0: Edge detection (1 = state change)
	MOVS R5, R1				@ Update previous states for next iteration
	
	@ First priority: Check SW3 current state for freeze control
	@ SW3 freeze works on CURRENT STATE, not edges
	MOVS R7, R1
	MOVS R0, #0x08
	ANDS R7, R7, R0			@ Check current SW3 state
	BEQ sw3_pressed			@ SW3 pressed (0=pressed for active-low)
	
	@ SW3 not pressed - clear any SW3 freeze
	CMP R6, #2				@ Check if currently frozen by SW3
	BNE check_sw2_edge		@ Not SW3 frozen, continue normally
	MOVS R6, #0				@ Clear SW3 freeze
	B check_sw2_edge		@ Continue to other button processing
	
sw3_pressed:
	@ SW3 is currently pressed - set freeze mode
	MOVS R6, #2				@ Set SW3 freeze mode
	@ Continue to process other buttons but skip pattern update
	
check_sw2_edge:
	@ Check SW2 edge detection for press/release
	MOVS R7, R0
	MOVS R0, #0x04
	ANDS R7, R7, R0			@ Isolate SW2 edge
	BEQ check_sw0_sw1		@ No SW2 edge, continue
	
	@ SW2 edge detected - check if press or release
	MOVS R7, R1
	MOVS R0, #0x04
	ANDS R7, R7, R0			@ Check current SW2 state
	BNE sw2_released		@ SW2 released (0=pressed for active-low)
	
	@ SW2 just pressed
	MOVS R6, #1				@ Set SW2 freeze mode
	MOVS R2, #0xAA			@ Set LED pattern to 0xAA
	B write_leds			@ Skip other processing, write LEDs immediately
	
sw2_released:
	@ SW2 just released - clear SW2 freeze mode
	CMP R6, #1				@ Check if currently frozen by SW2
	BNE check_sw0_sw1		@ Not SW2 frozen, continue
	MOVS R6, #0				@ Clear SW2 freeze mode
	@ R2 keeps current value (0xAA), will increment next iteration
	
check_sw0_sw1:
	@ Handle SW0 (increment) and SW1 (delay) - always functional
	@ These work on CURRENT STATE, not edges
	
	@ Check SW0 state (increment control)
	MOVS R7, R1
	MOVS R0, #0x01
	ANDS R7, R7, R0			@ Check SW0 current state
	BNE sw0_released		@ SW0 released (0=pressed for active-low)
	MOVS R3, #2				@ SW0 pressed: increment = 2
	B check_sw1
	
sw0_released:
	MOVS R3, #1				@ SW0 released: increment = 1
	
check_sw1:
	@ Check SW1 state (delay control)
	MOVS R7, R1
	MOVS R0, #0x02
	ANDS R7, R7, R0			@ Check SW1 current state
	BNE sw1_released		@ SW1 released
	MOVS R4, #0				@ SW1 pressed: short delay
	B update_pattern
	
sw1_released:
	MOVS R4, #1				@ SW1 released: long delay
	
update_pattern:
	@ Only update LED pattern if not frozen by SW2 or SW3
	CMP R6, #0
	BNE write_leds			@ Skip pattern update if frozen (R6 != 0)
	
	@ Normal increment based on current increment value (R3)
	ADDS R2, R2, R3			@ Add increment value to LED pattern

write_leds:
	@ Write LED pattern to GPIOB ODR
	LDR R1, GPIOB_BASE		@ Load GPIOB base address
	STR R2, [R1, #0x14]		@ Write R2 to GPIOB ODR register

apply_delay:
	@ Select appropriate delay based on current delay mode (R4)
	CMP R4, #0				@ Check delay mode: 0=short, 1=long
	BEQ call_short_delay	@ Branch to short delay if R4=0
	BL delay_long			@ Call long delay function (0.7s)
	B main_loop				@ Return to main loop
	
call_short_delay:
	BL delay_short			@ Call short delay function (0.3s)
	B main_loop				@ Return to main loop

@ LITERALS; DO NOT EDIT
	.align
RCC_BASE: 			.word 0x40021000
AHBENR_GPIOAB: 		.word 0b1100000000000000000
GPIOA_BASE:  		.word 0x48000000
GPIOB_BASE:  		.word 0x48000400
MODER_OUTPUT: 		.word 0x5555

@ Delay constant values
LONG_DELAY_CNT: 	.word 1866667	@ 0.7 seconds at 8MHz
SHORT_DELAY_CNT: 	.word 800000	@ 0.3 seconds at 8MHz

@ Delay function for debouncing (short delay)
delay_short:
	PUSH {R4, R5}
	LDR R4, =SHORT_DELAY_CNT
	LDR R4, [R4]
delay_short_loop:
	SUBS R4, R4, #1
	BNE delay_short_loop
	POP {R4, R5}
	BX lr

@ Delay function for main loop (long delay)
delay_long:
	PUSH {R4, R5}
	LDR R4, =LONG_DELAY_CNT
	LDR R4, [R4]
delay_long_loop:
	SUBS R4, R4, #1
	BNE delay_long_loop
	POP {R4, R5}
	BX lr