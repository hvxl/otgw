		title		"Opentherm Gateway Diagnostics"
		list		p=16F1847, b=8, r=dec

;Copyright (c) 2022 - Schelte Bron

;This firmware can perform several tests for analyzing different problems with
;the Opentherm Gateway hardware. The following tests are currently available:
;1) LED test. The four LEDS will each light in turn, creating a scanning effect
;2) Measure and report pulse widths on the Opentherm Master interface
;3) Measure and report pulse widths on the Opentherm Slave interface
;4) Loop delay test. This test requires the two Opentherm interfaces to be
;   connected together.
;5) Measure and report voltages detected on the Opentherm interfaces
;6) Measure periods of no activity on the opentherm lines.
;
#define		version		"2.0"

		__config	H'8007', B'00101111111100'
		__config	H'8008', B'01101011111111'

		errorlevel	-302

#include "p16f1847.inc"

#define		RXD	PORTB,2

#define		EOS	26	;^Z
#define		ANALOG0	0 << 2
#define		ANALOG1	1 << 2
#define		ANALOG2	2 << 2
#define		DACVREF	30 << 2
#define		FVRBUF1	31 << 2

		UDATA_SHR

Bank0data	UDATA
testnum		res	1
flags		res	1	;Flags to be used by different tests

txtemp		res	1
txhead		res	1
txtail		res	1

loopcounter	res	1
temp		res	1
oldvalueh	res	1
oldvaluel	res	1
newvalueh	res	1
newvaluel	res	1
bcdbuffer	res	4		;A 24-bit binary fits in 8 BCD digits

counter		res	1
valuel		res	1
valueh		res	1
valueu		res	1
valuex		res	1
accual		res	1
accuah		res	1
accuau		res	1
accubl		res	1
accubh		res	1
accubu		res	1
supplyl		res	1		;Power supply voltage
supplyh		res	1

Bank1data	UDATA

Bank2data	UDATA
input		res	80

Bank6data	UDATA
ccpsavel	res	1
ccpsaveh	res	1

;Variables used by test 1
testdata	UDATA_OVR
ledcounter	res	1
leds		res	1

;Variables used by test 2 & 3
testdata	UDATA_OVR
compsave	res	1
compmask	res	1
bufferhead	res	1
buffertail	res	1
#define		avail		flags,0
#define		measure		flags,1
#define		leadingzero	flags,2
#define		printpending	flags,3
#define		decimaldot	flags,4

;Variables used by test 5
testdata	UDATA_OVR
prevvalue	res	1
loopcounter2	res	1
levels		res	16

;Variables used by test 6
testdata	UDATA_OVR
idleflags	res	1
millisecs1	res	1
millisecs2	res	1
#define		IdleComparator	idleflags,7
#define		IdleDataAvail	idleflags,6
#define		IdleSubsequent	idleflags,5

;The linker has trouble assigning linear memory space, so we hack it
;Linear memory address range is 0x2000 - 0x23EF
linear0		udata	0x2200		;32 bytes into bank 6
txbuffer	res	0		;Serial transmit buffer (256 bytes)
linear1		udata	0x2300		;48 bytes into bank 9
buffer		res	0		;Space for 120 transitions, 2 bytes each

Print		macro	String
		banksel	EEADRH
		movlw	high String
		movwf	EEADRH
		movlw	low String
		movwf	EEADRL
		call	PrintString
		endm

		extern	SelfProg
		global	Voltages, BitLenMaster

ResetVector	code	0x0000
		pagesel	SelfProg
		call	SelfProg	;Always allow a firmware update on boot
		pagesel	Start
		goto	Start		;Start the opentherm measure program

InterruptVector	code	0x0004
		banksel	testnum		;Bank 0
		movfw	testnum
		brw
		retfie
		retfie
		bra	MasterInt	;Measure pulses on the Master interface
		bra	SlaveInt	;Measure pulses on the Slave interface
		retfie
		retfie
		retfie

MasterInt	clrf	TMR0
		bcf	PIR3,CCP3IF
		movlw	high buffer
		movwf	FSR0H
		lslf	bufferhead,W
		movwf	FSR0L
		incf	bufferhead,F
		banksel	CCP3CON		;Bank 6
		movlw	b'1'
		xorwf	CCP3CON,F
		movfw	CCPR3L
		movwi	FSR0++
		movfw	CCPR3H
		movwi	FSR0++
		retfie

SlaveInt	clrf	TMR0
		bcf	PIR3,CCP4IF
		movlw	high buffer
		movwf	FSR0H
		lslf	bufferhead,W
		movwf	FSR0L
		incf	bufferhead,F
		banksel	CCP4CON		;Bank 6
		movlw	b'1'
		xorwf	CCP4CON,F
		movfw	CCPR4L
		movwi	FSR0++
		movfw	CCPR4H
		movwi	FSR0++
		retfie

Main		code
Start
		banksel	OSCCON		;Bank 1
		movlw	b'01101010'	;Internal oscillator set to 4MHz
		movwf	OSCCON		;Configure the oscillator

		;Configure digital I/O
		banksel	TRISA
		movlw	b'11100111'
		movwf	TRISA
		movlw	b'00100111'
		movwf	TRISB

		;Configure analog I/O
		banksel	ANSELA
		movlw	b'00000111'
		movwf	ANSELA
		clrf	ANSELB

		;Configure fixed voltage reference
		banksel	FVRCON		;Bank 2
		movlw	b'10001010'	;Buf1 = 2.048V, Buf2 = 2.048V
		movwf	FVRCON
		;Configure the digital to analog converter
		movlw	b'10001000'	;Vsrc- = Vss, Vsrc+ = FVR Buf2
		movwf	DACCON0
		movlw	23		;2.048 * 23 / 32 = 1.472V
		movwf	DACCON1		;Set the reference voltage

		;Configure the serial interface
		banksel	SPBRGL		;Bank 3
		movlw	25
		movwf	SPBRGL
		bsf	TXSTA,BRGH	;9600 baud
		bcf	TXSTA,SYNC	;Asynchronous
		bsf	TXSTA,TXEN	;Enable transmit
		bsf	RCSTA,SPEN	;Enable serial port
		bsf	RCSTA,CREN	;Enable receive

		banksel	T1CON		;Bank 0
		clrf	T1CON
		clrf	txhead
		clrf	txtail

MainLoop	bcf	INTCON,GIE	;Disable interrupts
		;Configure timer 0
		banksel	OPTION_REG	;Bank 1
		movlw	b'11010111'	;1:256 prescaler
		movwf	OPTION_REG
		;Configure comparators
		banksel	CM1CON0		;Bank 2
		movlw	b'00010000'	;In+ = DAC, In- = RA0, no interrupts
		movwf	CM1CON1
		movlw	b'00010001'	;In+ = DAC, In- = RA1, no interrupts
		movwf	CM2CON1
		movlw	b'10100110'	;Enabled, not inverted, output on CxOUT
		movwf	CM1CON0		;Configure comparator 1
		movwf	CM2CON0		;Configure comparator 2

		banksel	PIE2		;Bank 1
		bsf	PIE2,C1IE
		bsf	PIE2,C2IE
		;Display the menu
		Print	Banner
		Print	Prompt
		movlw	high input
		movwf	FSR0H
		movlw	low input
		movwf	FSR0L
		banksel	RCSTA		;Bank 3
		btfss	RCSTA,OERR
		bra	MainSkip
		;Clear overrun error
		movfw	RCREG
		bcf	RCSTA,CREN
		bsf	RCSTA,CREN
MainSkip
		banksel	PIR1
		clrf	testnum
		;Wait for input
MainLoop1	clrwdt
		call	IdleTasks	;Perform standard tasks
		call	Receiver	;Check for serial commands
		tstf	testnum
		skpnz
		goto	MainLoop1
		goto	MainLoop

Receiver	btfss	PIR1,RCIF
		return
		banksel	RCSTA		;Bank 3
		btfss	RCSTA,FERR
		bra	ReceivedChar
		movfw	RCREG
		banksel	PORTA		;Bank 0
		skpz			;A BREAK condition occurred?
		return			;Discard bad character
Break		clrwdt
		btfss	RXD		;Check the serial receive line
		bra	Break		;Wait for the BREAK condition to end
		reset

ReceivedChar	movfw	RCREG		;Get the received character
		movwf	INDF0
		banksel	0		;Bank 0
		andlw	~b'11111'
		skpnz
		bra	ControlChar
ControlDone	movlw	input +	79
		subwf	FSR0L,W
		skpnc
		return
		moviw	FSR0++
		call	PrintChar
		return
ControlChar	movfw	INDF0
		brw
ControlTable	return
		return
		return
		return
		return
		return
		return
		return
		bra	BackSpace	;Backspace
		return			;Tab
		return			;Newline
		return
		return
		bra	Enter		;Carriage return
		return
		return
		return
		return
		return
		return
		return
		return			;Ctrl-U
		return
		return
		return
		return
		return
		return
		return
		return
		return

BackSpace	movlw	low input
		subwf	FSR0L,W
		skpnz
		return
		decf	FSR0L,F
		movlw	'\b'
		call	PrintChar
		call	PrintChar
		movlw	'\b'
		call	PrintChar
		return

Enter		call	PrintNewline
		clrf	INDF0
		movlw	low input
		movwf	FSR0L
TestNumLoop	tstf	INDF0
		skpnz
		goto	RunTest
		movlw	26
		subwf	testnum,W
		skpnc
		bra	BadTest
		; Multiply testnumber by 10
		movfw	testnum		;1 x testnum
		addwf	testnum,F	;2 x testnum
		rlf	testnum,F	;4 x testnum
		addwf	testnum,F	;5 x testnum
		rlf	testnum,F	;10 x testnum
		; --
		moviw	FSR0++
		sublw	'9'
		sublw	'9' - '0'
		skpc
		bra	BadTest
		addwf	testnum,F
		skpc
		goto	TestNumLoop
BadTest		Print	InvalidTestStr
		comf	testnum,F
		return

IdleTasks	btfsc	printpending	;No characters waiting?
		btfss	PIR1,TXIF	;Transmit register empty?
		return
		goto	PrintFlush

#define	MAXTEST	6
RunTest		movfw	testnum
		sublw	MAXTEST
		sublw	MAXTEST
		skpc
		goto	BadTest
		brw
; Test 0: Reset the gateway to allow starting a firmware update
		goto	ResetGateway
; Test 1: LED test. Light up the LEDS one by one until a CR is received on the
; serial interface.
		goto	LEDTest
; Test 2: Bit lengths master interface. Report bit lengths of the opentherm
; message received on the master interface.
		goto	BitLenMaster
; Test 3: Bit lengths slave interface. Report bit lengths of the opentherm
; message received on the slave interface.
		goto	BitLenSlave
; Test 4: Opto-coupler delay. Report the delays introduced by the opto-coupler.
; The delays for both transitions should be as close to eachother as possible.
; For this test the master and slave interface must be connected together.
		goto	LoopDelay
; Test 5: Measure various voltages
		goto	Voltages
; Test 6: Idle periods
		goto	IdlePeriods

ResetGateway	movlw	input
		subwf	FSR0L,W
		skpnz
		return
		reset

;Test 1:
LEDTest		clrf	leds
		movlw	1
		movwf	ledcounter
		banksel	OPTION_REG	;Bank 1
		movlw	b'11010111'
		movwf	OPTION_REG	;Make timer 0 run as slow as possible
		banksel	ledcounter	;Bank 0
TestLoop1	clrwdt
		call	CheckReturn
		skpnz
		goto	LEDTestEnd
		btfss	INTCON,TMR0IF
		goto	TestLoop1
		bcf	INTCON,TMR0IF
		decfsz	ledcounter,F
		goto	TestLoop1
		movlw	1
		movwf	ledcounter
		clrc
		rlf	leds,F
		tstf	leds
		skpnz
		bsf	leds,3
		btfsc	leds,5
		rlf	leds,F
		movlw	b'11011000'
		iorwf	PORTB,F
		comf	leds,W
		andwf	PORTB,F
		goto	TestLoop1
LEDTestEnd	movlw	b'11011000'
		iorwf	PORTB,F
		return

;Test 2 & 3: Measure the length of the individual pulses and report them over
;the serial interface.
;Take advantage of the fact that the comparator outputs match the CCP3 and
;CCP4 pins. Using a CCP module in capture mode takes care of copying the TMR1
;registers without having to deal with possible overflows between reading
;TMR1L and TMR1H. The data sheet is vague about what happens when the CCP pin
;is configured as an output, but in practice it works just fine.

;Test 2
BitLenMaster	call	BitLenInit
		movwf	CCP3CON		;Capture mode: every falling edge
		banksel	PIR3		;Bank 0
		bcf	PIR3,CCP3IF
		banksel	PIE3		;Bank 1
		bsf	PIE3,CCP3IE
		bra	BitLengths

;Test 3
BitLenSlave	call	BitLenInit
		movwf	CCP4CON		;Capture mode: every falling edge
		banksel	PIR3		;Bank 0
		bcf	PIR3,CCP4IF
		banksel	PIE3		;Bank 1
		bsf	PIE3,CCP4IE

BitLengths	movlw	high buffer
		movwf	FSR0H
		banksel	bufferhead	;Bank 0
		bsf	INTCON,PEIE	;Enable peripheral interrupts
		bsf	INTCON,GIE	;Enable all interrupts
		clrf	accuau
BitLenStart	clrf	bufferhead
		clrf	FSR0L
BitLenLoop	clrwdt
		call	IdleTasks
		call	CheckReturn
		skpnz
		bra	BitLenCleanUp
		lslf	bufferhead,W
		skpnz
		bra	BitLenLoop	;No data has been collected
		tstf	FSR0L
		skpnz
		bra	BitLenStore	;First transition was found
		btfsc	INTCON,TMR0IF
		bra	BitLenNewline	;Timeout waiting for a transition
		subwf	FSR0L,W
		skpnz
		bra	BitLenLoop	;No unprocessed events
		movfw	FSR0L
		xorlw	2
		movlw	','
		skpz			;Do not print a comma at the start
		call	PrintChar
		movfw	accubl
		subwf	INDF0,W
		movwf	accual
		moviw	1[FSR0]
		movwf	accuah
		movfw	accubh
		subwfb	accuah,F
		call	PrintDecimal
BitLenStore	bcf	INTCON,TMR0IF
		moviw	FSR0++
		movwf	accubl
		moviw	FSR0++
		movwf	accubh
		bra	BitLenLoop
BitLenNewline	movlw	'.'
		call	PrintChar
		call	PrintNewline
		bra	BitLenStart

BitLenInit	movlw	b'00000001'	;On, Fosc/4, 1:1 Prescaler
		movwf	T1CON		;Configure timer 1
		clrf	bufferhead
		banksel	OPTION_REG	;Bank 1
		movlw	b'11010101'	;Fosc/4, 1:64 Prescaler
		movfw	OPTION_REG
		banksel	CCP3CON		;Bank 6
		retlw	b'0100'		;Capture mode: every falling edge

BitLenCleanUp
		banksel	PIE3		;Bank 1
		clrf	PIE3
		banksel	CCP3CON		;Bank 6
		clrf	CCP3CON
		clrf	CCP4CON
		banksel	PIR3		;Bank 0
		return

;Test 4:
LoopDelay
		banksel	CM1CON0		;Bnak 2
		bcf	CM1CON0,C1OE	;Disconnect comparator 1 output
		bcf	CM2CON0,C2OE	;Disconnect comparator 2 output
		banksel	PORTA		;Bank 0
		;Set both interfaces to their high level. This situation does
		;not normally occur, so it's a fairly good way to check if the
		;interfaces have been looped together.
		bcf	PORTA,3
		bcf	PORTA,4
		;Use timer 1 as a guard timer. If the inputs haven't reached
		;their expected levels after 65ms something is wrong.
		clrf	T1CON
		clrf	TMR1L
		clrf	TMR1H		;Reset timer 1
		bcf	PIR1,TMR1IF
		bsf	T1CON,TMR1ON	;Start timer 1
LoopDelayWait	clrwdt
		btfsc	PIR1,TMR1IF	;Check for timeout
		bra	NoLoop
		banksel	CMOUT		;Bank 2
		tstf	CMOUT
		banksel	0		;Bank 0
		skpz
		bra	LoopDelayWait	;Repeat
		Print	Symmetry0Str
		movlw	b'00000010'	;Gate is active low, Comparator 1
		call	Check		;Test OK1A high to low transition
		Print	Symmetry1Str
		movlw	b'01000010'	;Gate is active high, Comparator 1
		call	Check		;Test OK1A low to high transition
		Print	Symmetry2Str
		movlw	b'00000011'	;Gate is active low, Comparator 2
		call	Check		;Test OK1B high to low transition
		Print	Symmetry3Str
		movlw	b'01000011'	;Gate is active high, Comparator 2
		call	Check		;Test OK1B low to hight transition
LoopCleanUp	clrf	T1CON
		clrf	T1GCON
		return
NoLoop		Print	NoLoopError
		bra	LoopCleanUp

Check		clrf	T1CON
		clrf	TMR1L
		clrf	TMR1H
		iorlw	b'10000000'	;Enable timer1 gate
		movwf	T1GCON		;Set up timer 1 gate control
		movlw	b'01000000'	;Fosc
		movwf	T1CON
		movlw	1 << RA3
		btfsc	T1GCON,0
		movlw	1 << RA4
		bcf	PIR1,TMR1IF
		bsf	T1CON,TMR1ON	;Start the timer
		xorwf	PORTA,F		;Switch the output
DelayLoop	clrwdt
		btfsc	PIR1,TMR1IF	;Check for timer overflow
		goto	NoResponse
		btfsc	T1GCON,T1GVAL
		goto	DelayLoop
		lsrf	TMR1H,W
		movwf	accuah
		rrf	TMR1L,W
		movwf	accual
		lsrf	accuah,F
		rrf	accual,F
		clrf	accuau
		call	PrintDecimal
		movlw	'.'
		call	PrintChar
		movfw	TMR1L
		andlw	b'11'
		lslf	WREG,W
		btfsc	TMR1L,1
		iorlw	b'1'
		addlw	'0'
		call	PrintChar
		movlw	'0'
		btfsc	TMR1L,0
		movlw	'5'
		call	PrintChar
		Print	MicroSecStr
		return

NoResponse	bcf	T1CON,TMR1ON
BadResponse	Print	DelayLoopError
		return

; Test 5
;Measure FVR1 with NREF = Vss & PREF = Vdd to determine Vdd.
;Vdd = FVR2 * 4095 / ADRES
Voltages
		banksel	ADCON0		;Bank 1
		movlw	b'10010000'	;Right justified, Fosc/8
		movwf	ADCON1		;Configure the AD converter
		movlw	FVRBUF1		;Select FVR 1 (2.048V)
		call	SelectADChannel
;Calculate 2048 * 1024 / AccuB
		movlw	upper (2048 * 1024)
		movwf	valueu		;Load value
		clrf	valueh
		clrf	valuel
		call	AnalogValue	;Get measurement in accu B
		call	divide		;Calculate value / accub
		Print	PowerStr
		;Save the measured supply voltage for future calculations
		movfw	accual
		movwf	supplyl
		movfw	accuah
		movwf	supplyh

		call	PrintDotted
		call	PrintNewline

		movlw	DACVREF
		call	SelectADChannel
		Print	Analog2Str
		call	AnalogValue
;Calculate Supply * AccuB / 1024
		movfw	supplyl
		movwf	accual
		movfw	supplyh
		movwf	accuah
		call	multiply	;AccuA * AccuB => Value
		movlw	high 1024
		movwf	accubh
		clrf	accubl
		call	divide		;Value / AccuB => AccuA
		call	PrintDotted
		call	PrintNewline

		Print	Analog0Str
		movlw	ANALOG0
		call	SelectADChannel
		call	FindLevels	;Find all stable voltage levels
		Print	Analog1Str
		movlw	ANALOG1
		call	SelectADChannel
		call	FindLevels	;Find all stable voltage levels
		return

SelectADChannel	;Common ADC configuration
		banksel	ADCON0		;Bank 1
		iorlw	1 << ADON
		movwf	ADCON0		;Select the A/D channel
		banksel	0		;Bank 0
		return

;The required acquisition time @20 degrees is less than 4us.
;Assume enough time has elapsed due to subroutine call overhead.
AnalogValue
		banksel	ADCON0		;Bank 1
		bsf	ADCON0,GO	;Start the conversion
Conversion	btfsc	ADCON0,GO
		goto	Conversion	;Wait for conversion to complete
		movfw	ADRESL
		banksel	accubl		;Bank 0
		movwf	accubl
		banksel	ADRESH		;Bank 1
		movfw	ADRESH
		banksel	accubh		;Bank 0
		movwf	accubh
		clrf	accubu
		return

FindLevels	movlw	16
		movwf	loopcounter
		movlw	levels
		clrf	FSR0H
		movwf	FSR0L
		movlw	-1
FindLevelInit	movwi	FSR0++
		decfsz	loopcounter,F
		goto	FindLevelInit
		movlw	64
		movwf	loopcounter2
		banksel	ADCON1
		bcf	ADCON1,ADFM	;Left justify the result
		clrf	temp
		call	AnalogValue	;Read analog value
FindLevelLoop1	clrwdt
		call	IdleTasks
		movfw	accubh
		movwf	prevvalue	;Remember value for next round
		call	AnalogValue	;Read analog value
		movfw	accubh
		subwf	prevvalue,W	;Compare with value on last round
		skpc
		sublw	0
		sublw	2		;Difference must be less than 2
		skpc
		clrf	temp
		incf	temp,F
		btfss	temp,3		;Need 4 similar values
		goto	FindLevelNext1
		swapf	accubh,W	;Found a stable value
		andlw	b'1111'
		addlw	levels
		movwf	FSR0L
		swapf	accubh,W
		andlw	b'11110000'
		movwf	INDF0
		swapf	accubl,W
		iorwf	INDF0,F
FindLevelNext1	decfsz	loopcounter,F
		goto	FindLevelLoop1
		decfsz	loopcounter2,F
		goto	FindLevelLoop1
		; Report the levels found
		movlw	':'
		movwf	temp
		movlw	levels
		movwf	FSR0L
FindLevelLoop2	btfsc	INDF0,0
		goto	FindLevelNext2
		movfw	temp
		call	PrintChar
		call	PrintChar
		movlw	levels
		subwf	FSR0L,W
		lsrf	WREG,W
		movwf	accubh
		rrf	INDF0,W
		movwf	accubl
		lsrf	accubh,F
		rrf	accubl,F
;Calculate Supply * AccuB / 1024
		movfw	supplyl
		movwf	accual
		movfw	supplyh
		movwf	accuah
		call	multiply	;AccuA * AccuB => Value
		movlw	high 1024
		movwf	accubh
		clrf	accubl
		call	divide		;Value / AccuB => AccuA
		call	PrintDotted
		movlw	','
		movwf	temp
FindLevelNext2	incf	FSR0L,F
		movlw	levels + 16
		subwf	FSR0L,W
		skpc
		goto	FindLevelLoop2
		call	PrintNewline
		return

; Test 6
IdlePeriods	movlw	b'00000001'	;On, Fosc/4, 1:1 Prescaler
		movwf	T1CON		;Configure timer 1
		banksel	OPTION_REG	;Bank 1
		movlw	b'11010101'	;Fosc/4, 1:64 Prescaler
		movwf	OPTION_REG	;Configure timer 0
		movlw	high CCP3CON
		movwf	FSR0H
IdlePerLoop1
		banksel	CCP3CON		;Bank 6
		movlw	b'0100'		;Capture mode: every falling edge
		movwf	CCP3CON		;Configure CCP3 (thermostat)
		movwf	CCP4CON		;Configure CCP4 (boiler)
		banksel	PIR3		;Bank 0
		clrf	PIR3
		clrf	TMR0
		clrf	idleflags
IdlePerWait	clrwdt
		call	IdleTasks
		call	CheckReturn
		skpnz
		bra	IdlePerCleanUp
		movlw	1 << CCP3IF | 1 << CCP4IF
		andwf	PIR3,W		;Check if a CCP tripped
		skpnz
		bra	IdlePerSkip
		movwf	idleflags	;Save for later use
		xorwf	PIR3,F		;Clear the CCP interrupt flag
		clrf	TMR0		;Restart timer 0
		bcf	INTCON,TMR0IF
IdlePerSkip	tstf	idleflags
		skpz			;Waiting for first activity
		btfss	INTCON,TMR0IF	;Timer 0 overflow means lines are idle
		bra	IdlePerWait	;Wait longer
		movlw	low CCPR3H
		btfss	idleflags,CCP3IF
		movlw	low CCPR4H
		movwf	FSR0L
;Determine if timer 1 has overflowed since the capture. Timer 1 overflows
;every 65536 us. This point is reached a little after 16384 us since the
;last capture. So an overflow can be determined by comparing the MSBs of the
;captured value and the current timer value.
;The TMR1IF bit is used to count subsequent overflows. But because the timer
;is still running, the bit can possibly be set between clearing the flag and
;checking the timer value. To rectify this, the flag is cleared once more if
;an overflow has been found (as indicated by a cleared Z-bit).
		movlw	1		;Value in case of timer 1 overflow
		bcf	PIR1,TMR1IF	;Can't depend on the interrupt flag
		btfss	TMR1H,7		;Current MSB set: No timer overflow
		btfss	INDF0,7		;Captured MSB set: Timer overflow
		clrw			;No timer 1 overflow since the capture
		movwf	accuau		;Initialize upper byte
		skpz			;No overflow was found?
		bcf	PIR1,TMR1IF	;In case the flag was set at a bad time
		moviw	-1[FSR0]	;CCPRxL
		movwf	accual		;Save the last captured value low byte
		moviw	0[FSR0]		;CCPRxH
		movwf	accuah		;Save the last captured value high byte
		banksel	CCP3CON		;Bank 6
		movlw	b'1'
		xorwf	CCP3CON,F	;Start looking for a rising edge
		xorwf	CCP4CON,F	;Start looking for a rising edge
		banksel	PIR3		;Bank 0
		clrf	PIR3		;Clear the CCP interrupt flags
IdlePerLoop2	clrwdt
		call	IdleTasks
		call	CheckReturn
		skpnz
		bra	IdlePerCleanUp
		movlw	1 << CCP3IF | 1 << CCP4IF
		andwf	PIR3,W		;Check if a CCP tripped
		skpz
		bra	IdlePerBusy
		btfss	PIR1,TMR1IF
		bra	IdlePerLoop2
		incf	accuau,F
		bcf	PIR1,TMR1IF
		skpz
		bra	IdlePerLoop2
		bra	IdlePerWait	;Idle time exceeded maximum (16 sec)
IdlePerBusy	movwf	idleflags
		movlw	low CCPR3L
		btfss	idleflags,CCP3IF
		movlw	low CCPR4L
		movwf	FSR0L
		movfw	accual
		subwf	INDF0,W
		movwf	accual
		incf	FSR0L
		movfw	accuah
		subwfb	INDF0,W
		movwf	accuah
		skpc
		decf	accuau,F
		incf	accuau,F
		btfsc	INDF0,7
		btfss	PIR1,TMR1IF
		decf	accuau,F
		movlw	'T'
		btfss	idleflags,CCP3IF
		movlw	'B'
		call	PrintChar
		movlw	':'
		call	PrintChar
		call	PrintChar
		call	PrintDotted
		call	PrintNewline
		bra	IdlePerLoop1
IdlePerCleanUp	bcf	T1CON,TMR1ON	;Stop timer 1
		banksel	CCP3CON		;Bank 6
		clrf	CCP3CON
		clrf	CCP4CON
		banksel	PIR3		;Bank 0
		return

CheckReturn	clrz
		btfss	PIR1,RCIF
		return
		banksel	RCREG
		movfw	RCREG
		banksel	0
		sublw	'\r'
		return

PrintNewline	movlw	'\r'
		call	PrintChar
		movlw	'\n'
		goto	PrintChar

PrintString
		banksel	EECON1		;Bank 3
		clrf	EECON1
		bsf	EECON1,EEPGD
		bsf	EECON1,RD
		nop
		nop
		rlf	EEDATL,W
		rlf	EEDATH,W
		call	PrintStrChar
		skpnz
		bra	PrintStrDone
		banksel	EEDATL
		movfw	EEDATL
		call	PrintStrChar
		skpnz
		bra	PrintStrDone
		banksel	EEADRL
		incf	EEADRL,F
		skpnz
		incf	EEADRH,F
		bra	PrintString
PrintStrDone
		banksel	0
		return

PrintStrChar	andlw	b'01111111'
		xorlw	EOS
		skpnz
		return
		xorlw	EOS
		skpz
		call	PrintChar
		clrz
		return

PrintDotted	bsf	decimaldot
PrintDecimal	movlw	24
		banksel	loopcounter
		movwf	loopcounter
		clrf	bcdbuffer
		clrf	bcdbuffer + 1
		clrf	bcdbuffer + 2
		clrf	bcdbuffer + 3
		movlw	high bcdbuffer
		movwf	FSR1H
		bra	bcdskip
bcdloop		movlw	low bcdbuffer
		movwf	FSR1L
		call	bcdadjust
		call	bcdadjust
		call	bcdadjust
		call	bcdadjust
bcdskip		lslf	accual,F
		rlf	accuah,F
		rlf	accuau,F
		rlf	bcdbuffer,F
		rlf	bcdbuffer + 1,F
		rlf	bcdbuffer + 2,F
		rlf	bcdbuffer + 3,F
		decfsz	loopcounter,F
		bra	bcdloop
		bsf	leadingzero		;Skip zeroes
		movfw	bcdbuffer + 3
		call	PrintPackedBCD
		movfw	bcdbuffer + 2
		call	PrintPackedBCD
		movfw	bcdbuffer + 1
		btfss	decimaldot
		call	PrintPackedBCD
		btfsc	decimaldot
		call	PrintDottedBCD
		movfw	bcdbuffer + 0
		call	PrintPackedBCD
		movlw	'0'
		btfsc	leadingzero		;Any digit printed?
		call	PrintChar
		return

bcdadjust	movlw	0x33
		addwf	INDF1,W
		btfss	WREG,3
		addlw	-0x03
		btfss	WREG,7
		addlw	-0x30
		movwi	FSR1++
		return

PrintDottedBCD	bcf	decimaldot
		bcf	leadingzero	;Always print the digit
		movwf	temp
		swapf	temp,W
		call	PrintBCD
		movlw	'.'
		call	PrintChar
		movfw	temp
		bra	PrintBCD
PrintPackedBCD	movwf	temp
		swapf	temp,W
		call	PrintBCD
		movfw	temp
PrintBCD	andlw	b'1111'
		skpnz
		btfss	leadingzero	;Skip leading zero?
		bra	PrintDigit
		return

PrintFloat	movfw	valueh
		call	PrintByte
		movlw	100
		movwf	temp
		movfw	valuel
;		call	Multiply
		btfsc	valuel,7
		incf	valueh,F
		movfw	valueh
		movwf	temp
		movlw	'.'
		goto	PrintFraction

PrintByte	bsf	leadingzero
		movwf	temp
		addlw	-100
		skpc
		goto	PrintByteJ1
		movwf	temp
		movlw	'1'
PrintFraction	call	PrintChar
		bcf	leadingzero
PrintByteJ1	clrf	loopcounter
		movfw	temp
PrintByteL1	movwf	temp
		addlw	-10
		skpc
		goto	PrintByteJ2
		incf	loopcounter,F
		goto	PrintByteL1
PrintByteJ2	movfw	loopcounter
		skpnz
		btfss	leadingzero
		call	PrintDigit
		movfw	temp
PrintDigit	bcf	leadingzero
		addlw	'0'

PrintChar
		banksel	PIR1		;Bank 0
		btfss	printpending
		btfss	PIR1,TXIF
		bra	PrintBusy
PrintTransmit
		banksel	TXREG
		movwf	TXREG
		banksel	0
		retlw	' '
PrintBusy	movwf	txtemp		;Temporarily save the character
		incf	txhead,W
		subwf	txtail,W
		skpz			;Buffer full?
		bra	PrintQueue
PrintWait	btfss	PIR1,TXIF	;Transmit register is empty?
		bra	PrintWait	;Wait until space becomes available
		call	PrintFlush	;Transmit a character from the queue
PrintQueue	movlw	high txbuffer
		movwf	FSR1H
		movfw	txhead
		movwf	FSR1L		;Point to the first free slot
		movfw	txtemp
		movwf	INDF1		;Put the character in the buffer
		incf	txhead,F
		bsf	printpending	;Some chars are waiting
		btfss	PIR1,TXIF	;Transmit register is empty?
		retlw	' '
PrintFlush	movlw	high txbuffer
		movwf	FSR1H
		movfw	txtail
		movwf	FSR1L		;Point to the first waiting character
		incf	txtail,F	;Move the pointer
		movfw	txtail
		subwf	txhead,W
		skpnz			;More characters waiting?
		bcf	printpending
		movfw	INDF1		;Get the first character in the queue
		bra	PrintTransmit	;Transmit the character

;Double Precision Multiply ( 16x16 -> 32 )
multiply	movlw	16
		movwf	loopcounter
		clrf	valuex
		clrf	valueu
multiplyloop	rrf	accuah,F
		rrf	accual,F
		skpc
		bra	multiplyskip
		movfw	accubl
		addwf	valueu,F
		movfw	accubh
		addwfc	valuex,F
multiplyskip	rrf	valuex,F
		rrf	valueu,F
		rrf	valueh,F
		rrf	valuel,F
		decfsz	loopcounter,F
		bra	multiplyloop
		return

divide		clrf	accuau
		clrf	accuah
		clrf	accual
		clrf	counter
dividealign	incf	counter,F
		btfsc	accubu,7
		bra	divideloop
		lslf	accubl,F
		rlf	accubh,F
		rlf	accubu,F
		bra	dividealign
divideloop	lslf	accual,F
		rlf	accuah,F
		rlf	accuau,F
		movfw	accubl
		subwf	valuel,W
		movfw	accubh
		subwfb	valueh,W
		movfw	accubu
		subwfb	valueu,W
		skpc
		bra	divideskip
		movfw	accubl
		subwf	valuel,F
		movfw	accubh
		subwfb	valueh,F
		movfw	accubu
		subwfb	valueu,F
		incf	accual,F
		skpnz
		incf	accuah,F
		skpnz
		incf	accuau,F
divideskip	lsrf	accubu,F
		rrf	accubh,F
		rrf	accubl,F
		decfsz	counter,F
		bra	divideloop
		return

Strings		code
Banner		da	"\r\nOpentherm gateway diagnostics - Version ", version
		da	"\r\n\n\032"
Prompt		da	"1. LED test\r\n"
		da	"2. Bit timing thermostat\r\n"
		da	"3. Bit timing boiler\r\n"
		da	"4. Delay symmetry\r\n"
		da	"5. Voltage levels\r\n"
		da	"6. Idle times\r\n\n"
		da	"Enter test number: \032"
InvalidTestStr	da	"\r\nInvalid test\032"
NoLoopError	da	"### Error: Interfaces don't appear to be looped\032"
DelayLoopError	da	"### Error\r\n\032"
PowerStr	da	"Power supply: \032"
Analog0Str	da	"Thermostat\032"
Analog1Str	da	"Boiler\032"
Analog2Str	da	"Reference: \032"
Symmetry0Str	da	"OK1A high-to-low: \032"
Symmetry1Str	da	"OK1A low-to-high: \032"
Symmetry2Str	da	"OK1B high-to-low: \032"
Symmetry3Str	da	"OK1B low-to-high: \032"
MicroSecStr	da	"us\r\n\032"

		end
