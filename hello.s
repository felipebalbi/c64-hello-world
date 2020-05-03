	!cpu 6502
	!to "hello.prg",cbm

	;; Helper labels
	SCREEN_RAM = $0400
	SPRITE_POINTER = $07f8
	COLOR_RAM = $d800
	VIC_SPRITE_X_POS = $d000
	VIC_SPRITE_Y_POS = $d001
	VIC_SCREEN_CTRL_REG = $d011
	VIC_RASTER_LINE = $d012
	VIC_SPRITE_ENABLE = $d015
	VIC_INTR_REG = $d01a
	VIC_SPRITE_MULTICOLOR = $d01c
	VIC_BORDER_COLOR = $d020
	VIC_SCREEN_COLOR = $d021
	VIC_SPRITE_EXTRA_COLOR1 = $d025
	VIC_SPRITE_EXTRA_COLOR2 = $d026
	CIA1_INTR_REG = $dc0d
	CIA2_INTR_REG = $dd0d
	IRQ_LOW = $0314
	IRQ_HIGH = $0315
	sid_init = $1000
	sid_play = $1003

	;; Start of basic loader
	*= $0801

	!byte $0d,$08		; Address of next line

	!byte $dc,$07		; Line number: 0x07dc = 2012

	!byte $9e		; opcode for SYS instruction
	!byte $20		; PETSCII space

	!byte $34,$39,$31,$35	; 49152 = 0xc000
	!byte $32		;

	!byte $00,$00,$00	; BASIC block terminator

	* = $c000
main:	
	sei			; Disable interrupts

	jsr init_screen		; Initialize the screen
	jsr init_text		; Write our text to the screen
	jsr init_sprites	; Initialize our sprites
        jsr sid_init		; Initialize music routine
	
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

init_sprites:
	lda #$05
	sta VIC_SPRITE_EXTRA_COLOR1
	lda #$06
	sta VIC_SPRITE_EXTRA_COLOR2

	lda #baloon/64		; Address of sprite 0
	sta SCREEN_RAM + $03f8 + 0
	lda #baloon2/64		; Address of sprite 1
	sta SCREEN_RAM + $03f8 + 1
	lda #baloon3/64		; Address of sprite 2
	sta SCREEN_RAM + $03f8 + 2

	lda #$01		; Sprites 0, 1, 2 are multicolor
	sta VIC_SPRITE_MULTICOLOR

	;; lda #100
	;; sta VIC_SPRITE_X_POS+0
	;; sta VIC_SPRITE_Y_POS+0
	;; sta VIC_SPRITE_X_POS+2
	;; sta VIC_SPRITE_Y_POS+2
	;; sta VIC_SPRITE_X_POS+4
	;; sta VIC_SPRITE_Y_POS+4

	rts

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
	ldx #$00		; load X index with 0
text_loop:
	lda message,x		; load A with message[x]
	sta SCREEN_RAM+12*40,x	; Store to middle line of screen
	lda message+40,x	; load A with message[x]
	sta SCREEN_RAM+13*40,x	; Store to middle line of screen
	inx			; increment X
	cpx #40			; X == 40?
	bne text_loop		; If not, we're not done
	rts			; Return from subroutine

irq:
	dec $d019		; Clear the Interrupt Status
	jsr color_wash		; Call our color wash subroutine
	jsr play_music		; Play tune
	jmp $ea81		; Jump to system IRQ handler

play_music:
	jsr sid_play
	rts

color_wash:	
	ldx #$00		; Load X with 0
	lda color,x		; Put first color in X
	pha			; Push a copy to the stack
color_loop:
	sta COLOR_RAM+12*40,x	; Store to center line of color ram
	sta COLOR_RAM+13*40,x	; Store to center line of color ram
	lda color+1,x		; Get next color
	sta color,x		; Overwrite current color
	inx			; Increment X index
	cpx #40			; X == 40?
	bne color_loop		; If not, we're not done
	pla			; Pull stored copy of first color from Stack
	sta color,x		; Overwrite last color
	rts

message:	
	!scr "            happy birthday!             "
	!scr "                 xxxxx                  "

color:
        !byte $03,$0e,$06,$06,$0e
        !byte $03,$01,$01,$01,$01
        !byte $01,$01,$01,$01,$01
        !byte $01,$01,$01,$01,$01
        !byte $01,$01,$01,$01,$01
        !byte $01,$01,$01,$01,$01
        !byte $01,$01,$01,$01,$01
        !byte $01,$01,$01,$01,$01

	* = $1000
	!bin "happy-birthday.sid",,$7c+2

	* = $3000
baloon:
	!byte $00,$00,$00,$00,$14,$00,$00,$55
	!byte $00,$01,$59,$40,$01,$56,$40,$01
	!byte $56,$40,$01,$55,$40,$01,$55,$40
	!byte $00,$55,$00,$00,$55,$00,$00,$14
	!byte $00,$00,$14,$00,$00,$0c,$00,$00
	!byte $0c,$00,$00,$0c,$00,$00,$30,$00
	!byte $00,$30,$00,$00,$c0,$00,$03,$00
	!byte $00,$00,$00,$00,$00,$00,$00,$81

baloon2:
	!byte $00,$00,$00,$00,$14,$00,$00,$55
	!byte $00,$01,$59,$40,$01,$56,$40,$01
	!byte $56,$40,$01,$55,$40,$01,$55,$40
	!byte $00,$55,$00,$00,$55,$00,$00,$14
	!byte $00,$00,$14,$00,$00,$0c,$00,$00
	!byte $0c,$00,$00,$0c,$00,$00,$0c,$00
	!byte $00,$30,$00,$00,$30,$00,$00,$30
	!byte $00,$00,$00,$00,$00,$00,$00,$81

baloon3:
	!byte $00,$00,$00,$00,$14,$00,$00,$55
	!byte $00,$01,$59,$40,$01,$56,$40,$01
	!byte $56,$40,$01,$55,$40,$01,$55,$40
	!byte $00,$55,$00,$00,$55,$00,$00,$14
	!byte $00,$00,$14,$00,$00,$0c,$00,$00
	!byte $0c,$00,$00,$0c,$00,$00,$03,$00
	!byte $00,$03,$00,$00,$00,$c0,$00,$00
	!byte $30,$00,$00,$00,$00,$00,$00,$81
	
