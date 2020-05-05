	!cpu 6502
	!to "hello.prg",cbm

	;; Helper labels
	SCREEN_RAM = $0400
	SPRITE_POINTER = $07f8
	COLOR_RAM = $d800
	VIC_SPRITE_POS = $d000
	VIC_SCREEN_CTRL_REG = $d011
	VIC_RASTER_LINE = $d012
	VIC_SPRITE_ENABLE = $d015
	VIC_INTR_REG = $d01a
	VIC_SPRITE_MULTICOLOR = $d01c
	VIC_BORDER_COLOR = $d020
	VIC_SCREEN_COLOR = $d021
	VIC_SPRITE_EXTRA_COLOR1 = $d025
	VIC_SPRITE_EXTRA_COLOR2 = $d026
	VIC_SPRITE_COLOR = $d027
	CIA1_INTR_REG = $dc0d
	CIA2_INTR_REG = $dd0d
	IRQ_LOW = $0314
	IRQ_HIGH = $0315
	init_sid = $1000
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
        jsr init_sid		; Initialize music routine
	jsr init_sprites	; Initialize our sprites
	
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
	ldx #$01
	stx VIC_SPRITE_COLOR + 0
	stx VIC_SPRITE_COLOR + 1
	stx VIC_SPRITE_COLOR + 2
	stx VIC_SPRITE_COLOR + 3
	stx VIC_SPRITE_COLOR + 4
	stx VIC_SPRITE_COLOR + 5
	stx VIC_SPRITE_COLOR + 6
	stx VIC_SPRITE_COLOR + 7
	lda #$05
	sta VIC_SPRITE_EXTRA_COLOR1
	lda #$06
	sta VIC_SPRITE_EXTRA_COLOR2

	lda animation_frame	; Address of sprite 0
	sta SCREEN_RAM + $03f8 + 0
	sta SCREEN_RAM + $03f8 + 1
	sta SCREEN_RAM + $03f8 + 2
	sta SCREEN_RAM + $03f8 + 3
	sta SCREEN_RAM + $03f8 + 4
	sta SCREEN_RAM + $03f8 + 5
	sta SCREEN_RAM + $03f8 + 6
	sta SCREEN_RAM + $03f8 + 7

	lda #$ff
	sta VIC_SPRITE_MULTICOLOR; all sprites are multicolor
	sta VIC_SPRITE_ENABLE	 ; all sprites are enabled

	jsr update_sprite_rotation
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
	jsr animate_sprite	; Animate our balloon by multiplexing the 3 sprites
	jmp $ea81		; Jump to system IRQ handler

update_sprite_rotation:
	ldy #$00
sprite_rotation_loop:
	ldx sprite_location_frame
	lda sprite_locations,x
	sta VIC_SPRITE_POS,y
	iny
	inc sprite_location_frame
	lda sprite_location_frame
	and #$0f
	bne sprite_rotation_loop
sprite_rotation_done:
	rts

animate_sprite:
	inc animation_counter
	lda animation_counter
	cmp #32
	bne animation_done
	lda #0
	sta animation_counter
	lda animation_frame
	eor #$01
	sta animation_frame
	sta SCREEN_RAM + $03f8 + 0
	sta SCREEN_RAM + $03f8 + 1
	sta SCREEN_RAM + $03f8 + 2
	sta SCREEN_RAM + $03f8 + 3
	sta SCREEN_RAM + $03f8 + 4
	sta SCREEN_RAM + $03f8 + 5
	sta SCREEN_RAM + $03f8 + 6
	sta SCREEN_RAM + $03f8 + 7
	jsr update_sprite_rotation
animation_done:	
	rts

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

	* = $2000
balloon:
	!byte $00,$00,$00,$00,$14,$00,$00,$55
	!byte $00,$01,$59,$40,$01,$56,$40,$01
	!byte $56,$40,$01,$55,$40,$01,$55,$40
	!byte $00,$55,$00,$00,$55,$00,$00,$14
	!byte $00,$00,$14,$00,$00,$0c,$00,$00
	!byte $0c,$00,$00,$0c,$00,$00,$30,$00
	!byte $00,$30,$00,$00,$c0,$00,$03,$00
	!byte $00,$00,$00,$00,$00,$00,$00,$81
	!byte $00,$00,$00,$00,$14,$00,$00,$55
	!byte $00,$01,$59,$40,$01,$56,$40,$01
	!byte $56,$40,$01,$55,$40,$01,$55,$40
	!byte $00,$55,$00,$00,$55,$00,$00,$14
	!byte $00,$00,$14,$00,$00,$0c,$00,$00
	!byte $0c,$00,$00,$0c,$00,$00,$03,$00
	!byte $00,$03,$00,$00,$00,$c0,$00,$00
	!byte $30,$00,$00,$00,$00,$00,$00,$81
	
animation_counter:
	!byte $10

animation_frame:
	!byte balloon / 64

sprite_location_frame:
	!byte $10

sprite_locations:
	!byte $f5,$8c,$dd,$c4,$a5,$dc,$6c,$c4,$55,$8c,$6c,$53,$a4,$3c,$dd,$53
	!byte $f1,$a2,$cb,$d1,$8e,$d8,$5f,$b2,$58,$75,$7e,$46,$bb,$3f,$ea,$65
	!byte $e8,$b6,$b6,$d9,$7a,$cf,$57,$9d,$61,$61,$93,$3e,$cf,$48,$f2,$7a
	!byte $da,$c7,$a0,$db,$69,$c1,$55,$87,$6f,$50,$a9,$3c,$e0,$56,$f4,$90
	!byte $c8,$d3,$8a,$d7,$5d,$af,$59,$71,$81,$44,$bf,$40,$ec,$68,$f0,$a6
	!byte $b2,$da,$77,$cd,$56,$99,$63,$5e,$97,$3d,$d2,$4a,$f3,$7e,$e6,$b9
	!byte $9c,$db,$66,$be,$55,$83,$72,$4d,$ad,$3c,$e3,$59,$f4,$94,$d7,$ca
	!byte $87,$d6,$5b,$ab,$5a,$6e,$85,$42,$c2,$41,$ee,$6c,$ef,$a9,$c4,$d5
	!byte $73,$cb,$55,$95,$65,$5a,$9b,$3c,$d6,$4c,$f4,$82,$e4,$bd,$ae,$db
	!byte $64,$bb,$55,$7f,$75,$4b,$b1,$3c,$e5,$5c,$f4,$98,$d4,$cc,$98,$db
	!byte $59,$a7,$5c,$6a,$89,$40,$c6,$43,$f0,$70,$ed,$ad,$c0,$d7,$83,$d4
	!byte $55,$91,$68,$57,$9f,$3c,$d9,$4f,$f4,$86,$e1,$c0,$aa,$db,$70,$c8
	!byte $56,$7b,$79,$48,$b5,$3d,$e8,$60,$f3,$9c,$d0,$cf,$94,$da,$61,$b7
	!byte $5e,$66,$8d,$3f,$ca,$45,$f1,$74,$eb,$b1,$bc,$d8,$7f,$d2,$58,$a3
	!byte $6b,$54,$a3,$3c,$dc,$52,$f4,$8a,$de,$c3,$a6,$db,$6d,$c5,$55,$8d
	!byte $7c,$46,$b9,$3e,$ea,$63,$f2,$a0,$cc,$d1,$90,$d9,$5f,$b4,$57,$77
