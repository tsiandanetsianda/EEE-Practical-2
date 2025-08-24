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

@ TODO: Add code, labels and logic for button checks and LED patterns

@ Initialize state variables (only done once at startup)
	MOVS R3, #1				@ R3: Current increment value (default 1)
	MOVS R6, #1				@ R6: Current delay mode (1=long/0.7s, 0=short/0.3s)
	MOVS R7, #0x0F			@ R7: Previous button states (start with all released)
	MOVS R9, #0				@ R9: Freeze mode (0=normal, 1=SW2, 2=SW3)
	MOVS R11, #0			@ R11: Combination state tracking


main_loop:
	@ Read current button states with debouncing
	LDR R0, GPIOA_BASE
	LDR R8, [R0, #0x10]		@ R8: Current button states (raw)
	BL delay_short			@ Debounce delay
	LDR R8, [R0, #0x10]		@ Re-read after debounce
	MOVS R12, #0x0F			@ Mask for buttons 0-3
	ANDS R8, R8, R12		@ R8: Clean button states (bits 0-3 only)
	
	@ Edge detection (XOR previous with current, inverted for active-low)
	MVNS R10, R7			@ Invert previous (for active-low logic)
	MVNS R12, R8			@ Invert current (for active-low logic)
	EORS R10, R10, R12		@ R10: Edge detection (1 = state change)
	MOVS R7, R8				@ Update previous states
	
	@ Check if frozen by SW3 - if so, only process SW3 release
	CMP R9, #2
	BEQ check_sw3_only
	
	@ Process button edges in priority order
	@ Priority: SW2 (pattern) > SW3 (freeze) > SW0/SW1 (increment/delay)
	
check_sw2:
	@ Check SW2 edge (bit 2)
	MOVS R12, R10
	ANDS R12, R12, #0x04	@ Isolate SW2 edge
	BEQ check_sw3			@ No SW2 edge, continue
	
	@ SW2 edge detected - check if press or release
	MOVS R12, R8
	ANDS R12, R12, #0x04	@ Check current SW2 state
	BNE check_sw3			@ SW2 still pressed (0=pressed, so BNE means released)
	
	@ SW2 just pressed
	MOVS R9, #1				@ Set SW2 freeze mode
	MOVS R2, #0xAA			@ Set LED pattern to 0xAA
	B update_leds			@ Skip other processing
	
check_sw3:
	@ Check SW3 edge (bit 3)
	MOVS R12, R10
	ANDS R12, R12, #0x08	@ Isolate SW3 edge
	BEQ check_sw0_sw1		@ No SW3 edge, continue
	
	@ SW3 edge detected - check if press or release
	MOVS R12, R8
	ANDS R12, R12, #0x08	@ Check current SW3 state
	BNE sw3_released		@ SW3 released
	
	@ SW3 just pressed
	MOVS R9, #2				@ Set SW3 freeze mode
	B apply_delay			@ Skip LED update, just delay
	
sw3_released:
	MOVS R9, #0				@ Clear freeze mode
	B check_sw0_sw1			@ Continue to other buttons
	
check_sw3_only:
	@ When frozen by SW3, only check for SW3 release
	MOVS R12, R10
	ANDS R12, R12, #0x08	@ Check SW3 edge
	BEQ apply_delay			@ No edge, stay frozen
	
	@ Check if SW3 released
	MOVS R12, R8
	ANDS R12, R12, #0x08	@ Check current SW3 state
	BEQ apply_delay			@ Still pressed, stay frozen
	
	@ SW3 released
	MOVS R9, #0				@ Clear freeze mode
	B apply_delay			@ Resume normal operation next iteration
	
check_sw0_sw1:
	@ Handle SW0 (increment) and SW1 (delay) - can be pressed together
	@ SW0: changes increment to 2
	@ SW1: changes delay to short (0.3s)
	
	@ Check SW0 state (increment control)
	MOVS R12, R8
	ANDS R12, R12, #0x01	@ Check SW0 current state
	BNE sw0_released		@ SW0 released (0=pressed for active-low)
	MOVS R3, #2				@ SW0 pressed: increment = 2
	B check_sw1
	
sw0_released:
	MOVS R3, #1				@ SW0 released: increment = 1
	
check_sw1:
	@ Check SW1 state (delay control)
	MOVS R12, R8
	ANDS R12, R12, #0x02	@ Check SW1 current state
	BNE sw1_released		@ SW1 released
	MOVS R6, #0				@ SW1 pressed: short delay
	B update_pattern
	
sw1_released:
	MOVS R6, #1				@ SW1 released: long delay
	
update_pattern:
	@ Only update LED pattern if not frozen
	CMP R9, #0
	BNE update_leds			@ Skip pattern update if frozen
	
	@ Check if we're coming out of SW2 freeze
	CMP R9, #1
	BEQ check_sw2_release
	
normal_increment:
	@ Normal increment based on current increment value (R3)
	ADDS R2, R2, R3			@ Add increment value to LED pattern
	B update_leds
	
check_sw2_release:
	@ Check if SW2 was just released
	MOVS R12, R8
	ANDS R12, R12, #0x04	@ Check current SW2 state
	BEQ update_leds			@ SW2 still pressed, keep 0xAA
	
	@ SW2 just released, clear freeze and continue from 0xAA
	MOVS R9, #0				@ Clear SW2 freeze mode
	@ R2 already contains 0xAA, will increment next iteration
	
update_leds:
	@ Write LED pattern to GPIOB ODR


write_leds:
	STR R2, [R1, #0x14]
	B main_loop

@ LITERALS; DO NOT EDIT
	.align
RCC_BASE: 			.word 0x40021000
AHBENR_GPIOAB: 		.word 0b1100000000000000000
GPIOA_BASE:  		.word 0x48000000
GPIOB_BASE:  		.word 0x48000400
MODER_OUTPUT: 		.word 0x5555

@ TODO: Add your own values for these delays
LONG_DELAY_CNT: 	.word 0
SHORT_DELAY_CNT: 	.word 0

@ Delay function for debouncing (short delay)
delay_short:
	PUSH {R4, R5}
	PUSH {R14}
	LDR R4, SHORT_DELAY_CNT
delay_short_loop:
	SUBS R4, R4, #1
	BNE delay_short_loop
	POP {R14}
	POP {R4, R5}
	BX LR

@ Delay function for main loop (long delay)
delay_long:
	PUSH {R4, R5}
	PUSH {R14}
	LDR R4, LONG_DELAY_CNT
delay_long_loop:
	SUBS R4, R4, #1
	BNE delay_long_loop
	POP {R14}
	POP {R4, R5}
	BX LR
