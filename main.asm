;
; MIP_project_final.asm
;
; Created: 21/12/2021 11:09:45 pm
; Author : Subata
;

;MODIFIED TOY CAR
; Replace with your application code
.INCLUDE "M32DEF.INC"
.ORG 0
    RJMP MAIN
.ORG 0x02
    RJMP EX0_ISR
.ORG 0x04
    RJMP EX1_ISR
.ORG 0x06
    RJMP EX2_ISR    
MAIN:
    .EQU ASCII_RESULT = 0x210

    LDI R17, HIGH (RAMEND)
    OUT SPH, R17
    LDI R17, LOW (RAMEND)
    OUT SPL, R17 ;initializing stacks

    CBI DDRD, 6 ;input switch to reverse the car or not

;declaring pins for the ultrasonic sensor U2
    SBI PORTD, 2 ;activating pull up resister for interrupt 0 to connect it to echo pin
    SBI DDRA, 7 ;trigger pin

;declaring pins for the ultrasonic sensor U4
    SBI PORTD, 3 ;activating pull up resister for interrupt 1 to connect it to echo pin
    SBI DDRA, 6 ;trigger pin

;declaring pins for the ultrasonic sensor U6
    SBI PORTD, 2 ;activating pull up resister for interrupt 2 to connect it to echo pin
    SBI DDRA, 5 ;trigger pin

    SBI DDRA, 0 ;output pin to indicate object detection
    SBI DDRD, 7 ;output pin to indicate no object

    SBI DDRD, 0
    SBI DDRD, 1 ;inputs for the motor driver
    SBI DDRD, 4 ;OC1B pin to generate wave for one motor
    SBI DDRD, 5 ;OC1A pin to generate wave for the other motor

;declaring the control pins of the lcd
    SBI DDRA, 1 ;RS pin for lcd
    SBI DDRA, 2 ;R/W pin for lcd
    SBI DDRA, 3 ;E pin for lcd

;declaring output port to send data to lcd
    LDI R17, 0xFF
    OUT DDRC, R17 ;output port to transmit data to the lcd

    CBI PORTA, 3
    RCALL DELAY_2ms ;delay for lcd to power on

    LDI R16, 0x38 ;initialize lcd 2 lines and 5x7 matrix
    RCALL CMNDWRT
    RCALL DELAY_2ms ;wait for 2ms

    LDI R16, 0x0E ;display on and cursor blinking
    RCALL CMNDWRT
    RCALL DELAY_2ms ;wait for 2ms

    LDI R16, 0x01 ;clear the lcd screen
    RCALL CMNDWRT
    RCALL DELAY_2ms ;wait for 2ms

    LDI R16, 0x06 ;increment the cursor and shift it to right
    RCALL CMNDWRT
    RCALL DELAY_2ms ;wait for 2ms

    ;writing distance
    LDI R16,'D'                  
    RCALL DATAWRT
    RCALL DELAY_2ms

    LDI R16,'I'                  
    RCALL DATAWRT
    RCALL DELAY_2ms

    LDI R16,'S'                  
    RCALL DATAWRT
    RCALL DELAY_2ms

    LDI R16,'T'                  
    RCALL DATAWRT
    RCALL DELAY_2ms

    LDI R16,'A'                  
    RCALL DATAWRT
    RCALL DELAY_2ms

    LDI R16,'N'                  
    RCALL DATAWRT
    RCALL DELAY_2ms

    LDI R16,'C'                  
    RCALL DATAWRT
    RCALL DELAY_2ms

    LDI R16,'E'                  
    RCALL DATAWRT
    RCALL DELAY_2ms

    LDI R16,':'                  
    RCALL DATAWRT
    RCALL DELAY_2ms
    ;done writing    

    LDI R30, 0x0
    OUT OCR1AH, R30
    OUT OCR1BH, R30 ;setting the high byte of the ocr register to 0, to use the lower 8 bits 

    LDI R30, 0xA1
    OUT TCCR1A, R30
    LDI R30, 0x01
    OUT TCCR1B, R30 ;configuring timer1 for 8 bit phase correct PWM non inverted mode

    LDI R18, 127 ;starting from 50% duty cycle

    CBI PORTD, 0 
    SBI PORTD, 1 ;giving input to the motor driver to control its direction of rotation (clockwise)

INCREASE_SPEED:
    INC R18 ;incrementing the value in the register to increase the speed
    OUT OCR1Bl, R18
    OUT OCR1Al, R18 ;inserting the value in OCR register

OBJECT_DETECTION:
    
    LDI R17, 0x02
    OUT MCUCR, R17 ;triggering interrupt 0 on the falling edge

    LDI R17, (1<<INT0)
    OUT GICR, R17 ;enabling the interrupt 0

    SEI ;enabling the global interrupts

    CBI PORTA, 7
    NOP
    NOP
    SBI PORTA, 7
    RCALL SDELAY
    CBI PORTA, 7 ;sending a 10 microsecond pulse on the trigger pin 

    LDI R17, 0
    OUT TCNT0, R17
    LDI R17, 0x02
    OUT TCCR0, R17 ;starting the timer0 with an initial count of 0

    RCALL DELAY_6ms

    CPI R18, 255
    BRNE INCREASE_SPEED
    RJMP OBJECT_DETECTION; if after continuous incrementing the speed reaches to 100% duty cycle keep the value instead of rolling over the timer

;external interrupt 1 isr which is connected to the front sensor
EX0_ISR:
    LDI R26, 0x0 ;just a flag to check if the car has turned left or right

    LDI R19, 0
    OUT TCCR0, R19 ;stop the timer

    IN R19, TIFR
    SBRC R19, TOV0 ;checking the flag
    RJMP CLEAR_FLAG1 ;if flag is set it means distance is greater than 32 go to l5

    IN R16, TCNT0 ;get the value in the tcnt register

    LDI R21, 8
    RCALL DIVIDE ;divide the value in the counter by 8 to get the distance

    LDI R16, 0x89                
    RCALL CMNDWRT
    RCALL DELAY_2ms
    MOV R16, R22
    RCALL BIN_ASCII_CONVERT
    RCALL DATAWRT
    LDS R16, 0x210
    RCALL DATAWRT ;display the calculated distance on lcd

    LDI R18, 0
    OUT OCR1AL, R18
    OUT OCR1BL, R18 ;stop the motors to eventually stop the car

    SBI PORTA, 0
    RCALL DELAY_500ms
    CBI PORTA, 0
    RCALL DELAY_500ms ;blink the led

KEEP_POLLING:
    LDI R25, 0x08
    OUT MCUCR, R25
    LDI R25, (1<<INT1)
    OUT GICR, R25
    SEI ;enable external interrupt 1 for falling edge

    CBI PORTA, 6
    NOP
    NOP
    SBI PORTA, 6
    RCALL SDELAY
    CBI PORTA, 6 ;sending 10 microsecond pulse on the trigger pin

    LDI R17, 0
    OUT TCNT2, R17
    LDI R17, 0x02
    OUT TCCR2, R17 ;starting the timer2

    RCALL DELAY_6ms

    CPI R26, 1
    BREQ EXIT1 ; if the isr was executed jump to the end otherwise keep polling

    LDI R25, 0x00
    OUT MCUCSR, R25
    LDI R25, (1<<INT2)
    OUT GICR, R25
    SEI ;enable external interrupt 2 for falling edge

    CBI PORTA, 5
    NOP
    NOP
    SBI PORTA, 5
    RCALL SDELAY
    CBI PORTA, 5 ;sending 10 microsecond pulse on the trigger pin

    LDI R17, 0
    OUT TCNT2, R17
    LDI R17, 0x02
    OUT TCCR2, R17 ;starting the timer2

    RCALL DELAY_6ms

    CPI R26, 1
    BREQ EXIT1

	SBIS PIND, 6
	RJMP DONT_REVERSE

	SBI PORTD, 0 
    CBI PORTD, 1 ;giving input to the motor driver to control its direction of rotation (anticlockwise)

	LDI R28, 127
	OUT OCR1AL, R28
	OUT OCR1BL, R28 ;defining the duty cycle

	RCALL DELAY_1s

DONT_REVERSE:

	CPI R26, 0
    BREQ KEEP_POLLING

    RJMP EXIT1 ;jump to end

CLEAR_FLAG1:

    SBI PORTD, 7
    RCALL DELAY_500ms
    CBI PORTD, 7
    RCALL DELAY_500ms ;indication that there is no object in the way

    LDI R19, (1<<TOV0)
    OUT TIFR, R19 ;clear the overflow flag if overflow has occured

	LDI R16, 0x89                
    RCALL CMNDWRT
    RCALL DELAY_2ms
	
	LDI R16,'-'                  
    RCALL DATAWRT
    RCALL DELAY_2ms

	LDI R16,'-'                  
    RCALL DATAWRT
    RCALL DELAY_2ms

EXIT1:
    CBI PORTD, 0 
    SBI PORTD, 1 ;giving input to the motor driver to control its direction of rotation (clockwise)
RETI

EX1_ISR:
    LDI R19, 0
    OUT TCCR2, R19 ;stopping the timer

    IN R19, TIFR
    SBRS R19, TOV2 ;checking the flag
    RJMP EXIT2 ;if flag is set it means distance is greater than 32 clear the flag and exit

    LDI R19, (1<<TOV2)
    OUT TIFR, R19 ;clear the overflow flag if overflow has occured
    LDI R18, 127
    OUT OCR1BL, R18
    RCALL DELAY_1s ;turning the car
    LDI R18, 0
    OUT OCR1BL, R18

    LDI R26, 0x1 ;setting the flag to indicate that isr has been executed

    RJMP EXIT2 ;jump to end

EXIT2:
    LDI R18, 63
    OUT OCR1AL, R18
    OUT OCR1BL, R18 ;put value in the ocr register to start from 25% duty cycle once again
RETI

EX2_ISR:
    LDI R19, 0
    OUT TCCR2, R19 ;stopping the timer
    OUT OCR1BL, R19

    IN R19, TIFR
    SBRS R19, TOV2 ;checking the flag
    RJMP EXIT3 ;if flag is set it means distance is greater than 32 clear the flag and exit

    LDI R19, (1<<TOV2)
    OUT TIFR, R19 ;clear the overflow flag if overflow has occured

    LDI R18, 127
    OUT OCR1AL, R18
    RCALL DELAY_1s ;turning the car
    LDI R18, 0
    OUT OCR1AL, R18

    LDI R26, 0x1 ;setting the flag to indicate that isr has been executed
 
    RJMP EXIT3 ;jump to end

EXIT3:
    LDI R18, 63
    OUT OCR1AL, R18
    OUT OCR1BL, R18 ;put value in the ocr register to start from 25% duty cycle once again
RETI


SDELAY:
    NOP
    NOP
RET

DELAY_50us:
    PUSH R31
    LDI R31, 5
DR0:
    RCALL SDELAY
    DEC R31
    BRNE DR0
    POP R31
RET

DELAY_100us:
    PUSH R31
    LDI R31, 10
DR1:
    RCALL SDELAY
    DEC R31
    BRNE DR1
    POP R31
RET

DELAY_2ms:
    PUSH R31
    LDI R31, 20
DR2:
    RCALL DELAY_100us
    DEC R31
    BRNE DR2
    POP R31
RET

DELAY_6ms:
    PUSH R31
    LDI R31, 2
DR3:
    RCALL DELAY_2ms
    DEC R31
    BRNE DR3
    POP R31
RET

DELAY_500ms:
    PUSH R31
    LDI R31, 250
DR4:
    RCALL DELAY_2ms
    DEC R31
    BRNE DR4
    POP R31
RET

DELAY_1s:
    PUSH R31
    LDI R31, 2
DR5:
    RCALL DELAY_500ms
    DEC R31
    BRNE DR5
    POP R31
RET

DELAY_2s:
    PUSH R31
    LDI R31, 4
DR6:
    RCALL DELAY_500ms
    DEC R31
    BRNE DR6
    POP R31
RET

DIVIDE:
    LDI R22,0
L11:
    INC R22
    SUB R16, R21
    BRCC L11
    DEC R22
    ADD R16, R21
RET

BIN_ASCII_CONVERT:
    LDI XL, LOW (ASCII_RESULT);save results in these loc.
    LDI XH, HIGH (ASCII_RESULT)

    LDI R21, 10
    RCALL DIVIDE ;QUOTIENT=PINA/10 NUM=PiNA810
    ORI R16, 0x30
    ST X+, R16
    MOV R16, R22
    RCALL DIVIDE
    ORI R16, 0x30
    ST X+, R16
    ORI R22, 0x30
    ST X+, R22
RET

CMNDWRT:
    OUT PORTC, R16                
    CBI PORTA, 1                   ;RS=0 for command register
    CBI PORTA, 2                   ;RW=0 to write
    SBI PORTA, 3                   ;E=1 to enable
    RCALL SDELAY
    CBI PORTA, 3                   ;E=0 for a high to low pulse
    RCALL DELAY_100us
RET

DATAWRT:
    OUT PORTC, R16                
    SBI PORTA, 1                   ;RS=1 for data register
    CBI PORTA, 2                   ;RW=0 to write
    SBI PORTA, 3                   ;E=1 to enable
    RCALL SDELAY
    CBI PORTA, 3                   ;E=0 for a high to low pulse
    RCALL DELAY_100us
RET
