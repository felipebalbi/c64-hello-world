	!cpu 6502
	!to "hello.prg",cbm

	;; Helper labels
	CASSETTE_BUFFER		= $0340
	SCREEN_RAM		= $0400

	VIC_BASE		= $d000
	VIC_SPRITE_X_POSITION	= VIC_BASE + $00
	VIC_SPRITE_Y_POSITION	= VIC_BASE + $01
	VIC_SPRITE_X_MSB	= VIC_BASE + $10
	VIC_SCREEN_CTRL_REG	= VIC_BASE + $11
	VIC_RASTER_LINE		= VIC_BASE + $12
	VIC_SPRITE_ENABLE	= VIC_BASE + $15
	VIC_INTR_STATUS_REG	= VIC_BASE + $19
	VIC_INTR_MASK_REG	= VIC_BASE + $1a
	VIC_BORDER_COLOR	= VIC_BASE + $20
	VIC_SCREEN_COLOR	= VIC_BASE + $21
	VIC_SPRITE_COLOR	= VIC_BASE + $27

	CIA1_BASE		= $dc00
	CIA1_DATA_PORT_A	= CIA1_BASE + $00
	CIA1_INTR_REG		= CIA1_BASE + $0d

	CIA2_BASE		= $dd00
	CIA2_INTR_REG		= CIA2_BASE + $0d

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

	!macro spriteline .v {
		!byte .v >> 16, (.v >> 8) & $ff, .v & $ff
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
	jsr init_sprite		; Initialize a sprite

        ldy #$7f		; $7f = %01111111
        sty CIA1_INTR_REG	; clear all CIA1 interrupts
        sty CIA2_INTR_REG	; clear all CIA2 interrupts
        lda CIA1_INTR_REG	; flush posted writes
        lda CIA2_INTR_REG	; flush posted writes

        lda #$01		; Enable Bit 0
        sta VIC_INTR_MASK_REG	; Bit0 = Rasterbeam interrupt

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
	ldx #39			; load X index with 39
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

init_sprite:
	;; Copy Sprite to Casette buffer
	ldx #$7f
loop:
	lda sprite,x
	sta CASSETTE_BUFFER,x
	dex
	bpl loop

	ldx #$0d
	stx $07f8

	lda $01
	sta VIC_SPRITE_ENABLE	; Enable Sprite #0

	ldx #$02
	stx VIC_SPRITE_COLOR + 0

	lda #$64		; Sprite Position
	sta VIC_SPRITE_X_POSITION
	sta VIC_SPRITE_Y_POSITION
	rts

	!zone {
joy_handler:
	lda CIA1_DATA_PORT_A
	ldx VIC_SPRITE_X_POSITION
	ldy VIC_SPRITE_Y_POSITION
	lsr
	bcs .down
	dey
.down:
	lsr
	bcs .left
	iny
.left:
	lsr
	bcs .right
	dex
.right:
	lsr
	bcs .fire
	inx
.fire:
	lsr
	bcs .update_xy
	inc VIC_BORDER_COLOR

.update_xy:
	stx VIC_SPRITE_X_POSITION
	sty VIC_SPRITE_Y_POSITION

	rts
	}

irq:
	dec VIC_INTR_STATUS_REG	; Clear the Interrupt Status
	jsr color_wash		; Call our color wash subroutine
	jsr play_sid		; Play sid tune
	jsr joy_handler		; Update sprite position
	jmp $ea81		; Jump to system IRQ handler

message:	
	!scr "              hello world!              "

color:
        !byte $09, $09, $09, $09, $01
        !byte $01, $01, $01, $01, $01
        !byte $01, $01, $01, $01, $01
        !byte $01, $01, $01, $01, $01
        !byte $01, $01, $01, $01, $01
        !byte $01, $01, $01, $01, $01
        !byte $01, $01, $01, $01, $01
        !byte $01, $01, $01, $01, $01

sprite:
	+spriteline %........................
	+spriteline %.#......................
	+spriteline %.##.....................
	+spriteline %.###....................
	+spriteline %.####...................
	+spriteline %.#####..................
	+spriteline %.######.................
	+spriteline %.#######................
	+spriteline %.########...............
	+spriteline %.#########..............
	+spriteline %.########...............
	+spriteline %.######.................
	+spriteline %.######.................
	+spriteline %.##..##.................
	+spriteline %.#....##................
	+spriteline %......##................
	+spriteline %.......##...............
	+spriteline %.......##...............
	+spriteline %........##..............
	+spriteline %........##..............
	+spriteline %........................
	!byte $00			; Pad to 64-byte block

	!zone {
joy_right:
	lda VIC_SPRITE_X_POSITION
	clc
	adc #$01
	sta VIC_SPRITE_X_POSITION
	bcc .done
	lda VIC_SPRITE_X_MSB
	eor #$01
	sta VIC_SPRITE_X_MSB
.done:
	rts
	}

	;; Load SID file to load address listed in File Header. The header ends
	;; at $7c and starts with a two-byte load address, hence the skip of
	;; $7c+2
	* = $1000
	!bin "assets/future_cowboy.sid",,$7c+2

