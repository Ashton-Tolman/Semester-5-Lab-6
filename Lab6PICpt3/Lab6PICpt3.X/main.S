// Ashton Tolman
// RCET3373
// Lab6PICpt3
// https://github.com/Ashton-Tolman/Semester-5-Lab-6.git
// linker code:-Wl,-presetVect=0000h,-pisrVect=0004h,-pcode=0008h

; PIC16F883 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = XT             ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>

W_TEMP EQU 0x70		    ; Temporary W register in global GR
STATUS_TEMP EQU 0x71	    ; Temporary Status register in global GR
Intersection_State EQU 0x72 ; Global GR for the state of the intersection
State_Count EQU 0x73	    ; Global GR for the State count External INT
 
; Reset Vector at 000h. Execution starts here after reset 
PSECT resetVect,class=CODE,delta=2
ResetVector:
    goto Setup
    
    
; Interrupt Vector at 0004h. Execution starts here after an interrupt.
PSECT isrVect,class=CODE,delta=2
InterruptVector:
    goto ISRHandler
    
; Main code section starts at 0008h. User code goes here
PSECT code,class=CODE,delta=2

Setup:
    ; add device setup here
    BSF  0x03, 06	;
    BSF  0x03, 05	; Set bank 3 active
    CLRF 0x189		; ANSELH analog/digital select portB pins as digital
    CLRF 0x188		; ANSEL analog/digital select portA pins as digital
    
    BSF  0x03, 06	;
    BCF  0x03, 5	; Set bank 2 active
    
    BCF  0x03, 06	;
    BSF  0x03, 05	; Set bank 1 active 
    CLRF 0x85		; TrisA sets all portA pins as outputs
    CLRF 0x87		; TrisC sets all portC pins as outputs
    BSF 0x8C,0		; PIE1 Enable Timer1 interrupt 


    BCF  0x03, 06	;
    BCF  0x03, 05	; Set bank 0 active
    CLRF 0x05		; Clear port A
    CLRF 0x07		; Clear port C
    MOVLW 0b00110000	; Put binary register in W
    MOVWF 0x10		; TMR1 prescaler to 1:8 
    MOVLW 0xDC		; Move count placement in W
    MOVWF 0x0E		; Move W into TMR1L
    MOVLW 0x0B		; Move count placement in W
    MOVWF 0x0F		; Move W into TMR1H
		     
    ;Interrupt setup
    CLRF 0x0B		; Clear INTCON to disable all interrupts by default
			; Disable PortB interrupt on change
	    		; Disable External interrupts
    BSF 0x10,0		; Begin TMR1 counting
    BSF 0x0B,6		; Enable Peripheral Interrupts
    BSF 0x8B,7		; Enable Global interrups
    
    BCF  0x03, 06	;
    BCF  0x03, 05	; Set bank 0 active
    goto Main
    

Main:
    MOVF Intersection_State,W	    ; Copy byte to W
    MOVWF PORTC			    ; Display Intersection_State on PortC
    
    CALL DecodeLights
    
    BTFSC Intersection_State,3   ; already in yellow?
    goto YellowWait

    BTFSS Intersection_State,7   ; green: wait for count 10
    goto Main
    BTFSS Intersection_State,5
    goto Main
    CALL Decide
    goto Main

YellowWait:
    BTFSS Intersection_State,6   ; count reached 12 (1 s of yellow)
    goto Main

    
Transition:
    BTFSS Intersection_State,0	; Test which direction we're going
    goto GoEW		; If high Clear the register to change to NS
    
    CLRF Intersection_State
    goto Main
    
    GoEW:
    CLRF Intersection_State	; If low clear the Reg then set the direction bit
    BSF Intersection_State,0	; Set bit to change to EW
    goto Main
    
    
Decide:
    BTFSC    Intersection_State,3  ;is TRANSITION bit set low = skip
    RETURN		           ;dont do anything
    BTFSS    Intersection_State,0  ;look which direction is green N/S=0, E/W=1
    goto     NSLogic               
    
EWLogic:
    BTFSC Intersection_State,1	    ; Test the NS flag 
    goto SetTransition		    ; If high, will toggle so set bit 3
    BTFSC Intersection_State,2	    ; Test the EW flag to check for Remain
    goto Remain			    ; If high, Remain EW 
    goto SetTransition		    ; If low toggle so set bit 3
    
NSLogic:
    BTFSS Intersection_State,1	    ; Test the NS flag
    goto SetTransition		    ; If low, will toggle so set bit 3
    BTFSS Intersection_State,2	    ; Test the EW flag to check for Remain
    goto Remain			    ; If low, Remain NS
    
    SetTransition:
	BSF Intersection_State,3    ; Set the transition bit
	RETURN
	
    Remain:
	BTFSS Intersection_State,0  ; Check Direction we're going
	goto ToNS	    ; If low Clear the Reg to remain NS
    ToEW:
	CLRF Intersection_State	    ; If high Clear the Reg
	BSF Intersection_State,0    ; Then set the Direction bit to remain EW
	RETURN
	
    ToNS:
	CLRF Intersection_State	; Clear register to change to NS
	RETURN		
    
DecodeLights:
    BTFSS   Intersection_State,3    ;is TRANSITION yellow flag on
    goto    GreenPhase		    ;no we're in a green/red phase
    goto    YellowPhase		    ;yes we're in a yellow/red phase
GreenPhase:
    BTFSS   Intersection_State,0    ;which way is green?
    goto    SetNSGreen		    ;bit was 0 N/S green
    goto    SetEWGreen		    ;bit was 1 E/W green
YellowPhase:
    BTFSS   Intersection_State,0   
    goto    SetNSYellow
    goto    SetEWYellow
SetNSGreen:
    MOVLW   0b00001100		    ;RA2 on (N/S green), RA3 on (E/W red)
    goto    StoreLights
SetEWGreen:
    MOVLW   0b00100001		    ;RA0 on (N/S red), RA5 on (E/W green)
    goto    StoreLights
SetNSYellow:
    MOVLW   0b00001010		    ;RA1 on (N/S yellow), RA3 on (E/W red)
    goto    StoreLights
SetEWYellow:
    MOVLW   0b00010001		    ;RA0 on (N/S red), RA4 on (E/W yellow)
StoreLights:
    MOVWF   PORTA		    ;takes moved values and then displays on the LEDs
    RETURN
    
ISRHandler:
    MOVWF W_TEMP	    ;Copy W to TEMP register
    SWAPF STATUS,0	    ;Swap status to be saved into W
			    ;Swaps are used because they dont change the status bits
    MOVWF STATUS_TEMP	    ;Save status to bank zero STATUS_TEMP register
    
    BTFSC PIR1,0	    ;Test TMR1 flag bit
    goto TMR1Service
    goto LeaveHandler
    
TMR1Service:
    MOVLW 0xDC		; Move count placement in W
    MOVWF 0x0E		; Move W into TMR1L
    MOVLW 0x0B		; Move count placement in W
    MOVWF 0x0F		; Move W into TMR1H
    
    MOVF Intersection_State,W	; Read the Contents of the register
    MOVWF State_Count		; Place the contents into changeable register
    SWAPF State_Count,1		; Swap upper and lower nibbles for incrementing
    INCF State_Count,1		; Increment Status_Count
    SWAPF State_Count,0		; Swap upper and lower nibbles to return
    MOVWF Intersection_State	; Restore Intersection_State

    BCF PIR1,0		; Clear TMR1 flag bit
    goto LeaveHandler
    
    ;These interrupts are not on but they will be used in later
INTExternalService:
    MOVF Intersection_State,W	; Read the Contents of the register
    MOVWF State_Count		; Place the contents into changeable register
    SWAPF State_Count,1		; Swap upper and lower nibbles for incrementing
    BCF State_Count,3		; Clear the high Status_Count bit for saftey
    INCF State_Count,1		; Increment Status_Count
    SWAPF State_Count,0		; Swap upper and lower nibbles to return
    MOVWF Intersection_State	; Restore Intersection_State
    
    BCF INTCON,1		; Clear the INTExternal flag
    goto LeaveHandler
    
IOCPORTBService:
    BTFSS PORTB,4		; Was N/S pushed?
    BSF Intersection_State, 1	; Set the N/S flag
    BTFSS PORTB,5		; Was E/W pushed?
    BSF Intersection_State,2	; Set the E/W flag
    
    BCF INTCON,0		; Clear the IOCPortB flag
    goto LeaveHandler
    
LeaveHandler:
    SWAPF STATUS_TEMP,0	    ;Swap STATUS_TEMP register into W
			    ;(sets bank to original state)
    MOVWF STATUS	    ;Move W into STATUS register
    SWAPF W_TEMP,1	    ;Swap W_TEMP
    SWAPF W_TEMP,0	    ;Swap W_TEMP into W
    RETFIE		    ;Return from interupt at point of interruption+1
End