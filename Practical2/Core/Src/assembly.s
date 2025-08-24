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
