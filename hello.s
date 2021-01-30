	!cpu 6502
	!to "hello.prg",cbm

	;; Helper labels
	SCREEN_RAM		= $0400
	VIC_SCREEN_CTRL_REG	= $d011
	VIC_RASTER_LINE		= $d012
	VIC_INTR_REG		= $d01a
	VIC_BORDER_COLOR	= $d020
	VIC_SCREEN_COLOR	= $d021
	CIA1_INTR_REG		= $dc0d
	CIA2_INTR_REG		= $dd0d
	IRQ_LOW			= $0314
	IRQ_HIGH		= $0315

	init_sid		= $1000
	play_sid		= $1003

	!macro loader .lineno, .loadaddr {
		!word * + 11	    ; Next basic line
		!word .lineno	    ; Line number
		!byte $9e	    ; SYS
		!text .loadaddr	    ; load address
		!byte $00, $00, $00 ; Terminator
	}

	;; Start of basic loader
	*= $0801

	+loader 2021, "49152"

	* = $c000
main:	
	sei			; Disable interrupts

	jsr init_screen		; Initialize the screen
	jsr init_text		; Write our text to the screen
	jsr init_sid		; Initialize SID routine

        ldy #$7f		; $7f = %01111111
        sty CIA1_INTR_REG	; clear all CIA1 interrupts
        sty CIA2_INTR_REG	; clear all CIA2 interrupts
        lda CIA1_INTR_REG	; flush posted writes
        lda CIA2_INTR_REG	; flush posted writes

        lda #$01		; Enable Bit 0
        sta VIC_INTR_REG	; Bit0 = Rasterbeam interrupt

        lda VIC_SCREEN_CTRL_REG	; Read VIC Screen Control Register
        and #$7f		; Clear BIT7
        sta VIC_SCREEN_CTRL_REG	; Write it back

	lda #<irq		; load low-byte of IRQ routine address
	ldx #>irq		; load high-byte of IRQ routine address
	sta IRQ_LOW		; store system vector LOW
	stx IRQ_HIGH		; store to system vector HIGH

	lda #$00		; load accumulator with 0
	sta VIC_RASTER_LINE	; trigger interrupt on row 0
	
	cli			; Reenable interrupts
	jmp *			; loop forever

init_screen:
	lda #$20		; Load space into accumulator
	ldx #$00		; Load 0 to X index register
	ldy #$00		; Load 0 to Y index register
screen_loop:
	sta SCREEN_RAM+0,x	; Store to SCREEN_RAM[x]
	sta SCREEN_RAM+$100,x	; Store to SCREEN_RAM+256[x]
	sta SCREEN_RAM+$200,x	; Store to SCREEN_RAM+512[x]
	sta SCREEN_RAM+$2e8,x	; Store to SCREEN_RAM+744[x]
	inx			; Increment X index register
	bne screen_loop		; Loop if we're not done

	sty VIC_BORDER_COLOR	; Screen border black
	sty VIC_SCREEN_COLOR	; Screen color black
	rts			; Return from subroutine

init_text:
	ldx #39			; load X index with 0
text_loop:
	lda message,x		; load A with message[x]
	sta $05e0,x		; Store to middle line of screen
	dex			; increment X
	bne text_loop		; If not, we're not done
	rts			; Return from subroutine

color_wash:	
	ldx #$00		; Load X with 0
	lda color,x		; Put first color in X
	tay			; Transfer A to Y
color_loop:
	sta $d9e0,x		; Store to center line of color ram
	lda color+1,x		; Get next color
	sta color,x		; Overwrite current color
	inx			; Increment X index
	cpx #40			; X == 40?
	bne color_loop		; If not, we're not done
	tya			; Pull stored copy of first color from Y
	sta color,x		; Overwrite last color
	rts

irq:
	dec $d019		; Clear the Interrupt Status
	jsr color_wash		; Call our color wash subroutine
	jsr play_sid		; Play sid tune
	jmp $ea81		; Jump to system IRQ handler

message:	
	!scr "              hello world!              "

color:
        !byte $09,$09,$09,$09,$01
        !byte $01,$01,$01,$01,$01
        !byte $01,$01,$01,$01,$01
        !byte $01,$01,$01,$01,$01
        !byte $01,$01,$01,$01,$01
        !byte $01,$01,$01,$01,$01
        !byte $01,$01,$01,$01,$01
        !byte $01,$01,$01,$01,$01

	* = $1000
	!bin "assets/future_cowboy.sid",,$7c+2
