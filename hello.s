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
	inc sprite_rotation
	ldx #$00
sprite_rotation_loop:
	lda sprite_locations,x
	beq sprite_rotation_done
	sta VIC_SPRITE_X_POS,x
	inx
	lda sprite_locations,x
	sta VIC_SPRITE_X_POS,x
	inx
	jmp sprite_rotation_loop
sprite_rotation_done:
	rts

animate_sprite:
	jsr update_sprite_rotation
	inc animation_counter
	lda animation_counter
	cmp #20
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
	!byte $00

animation_frame:
	!byte balloon / 64

sprite_rotation:
	!byte $00

sprite_locations:
	!byte $f5,$8c,$dd,$c4,$a5,$dc,$6c,$c4,$55,$8c,$6c,$53,$a4,$3c,$dd,$53,$00
	!byte $f4,$8d,$dc,$c5,$a3,$db,$6b,$c3,$55,$8a,$6d,$52,$a6,$3c,$de,$54,$00
	!byte $f4,$8e,$db,$c6,$a2,$db,$6a,$c2,$55,$89,$6e,$51,$a7,$3c,$df,$55,$00
	!byte $f4,$90,$da,$c7,$a0,$db,$69,$c1,$55,$87,$6f,$50,$a9,$3c,$e0,$56,$00
	!byte $f4,$91,$d9,$c8,$9f,$db,$68,$c0,$55,$86,$70,$4f,$aa,$3c,$e1,$57,$00
	!byte $f4,$92,$d8,$c9,$9e,$db,$67,$bf,$55,$85,$71,$4e,$ab,$3c,$e2,$58,$00
	!byte $f4,$94,$d7,$ca,$9c,$db,$66,$be,$55,$83,$72,$4d,$ad,$3c,$e3,$59,$00
	!byte $f4,$95,$d6,$cb,$9b,$db,$65,$bd,$55,$82,$73,$4c,$ae,$3c,$e4,$5a,$00
	!byte $f4,$97,$d5,$cb,$99,$db,$65,$bc,$55,$80,$74,$4c,$b0,$3c,$e4,$5b,$00
	!byte $f4,$98,$d4,$cc,$98,$db,$64,$bb,$55,$7f,$75,$4b,$b1,$3c,$e5,$5c,$00
	!byte $f3,$99,$d2,$cd,$97,$da,$63,$b9,$56,$7e,$77,$4a,$b2,$3d,$e6,$5e,$00
	!byte $f3,$9b,$d1,$ce,$95,$da,$62,$b8,$56,$7c,$78,$49,$b4,$3d,$e7,$5f,$00
	!byte $f3,$9c,$d0,$cf,$94,$da,$61,$b7,$56,$7b,$79,$48,$b5,$3d,$e8,$60,$00
	!byte $f2,$9d,$cf,$cf,$93,$d9,$61,$b6,$57,$7a,$7a,$48,$b6,$3e,$e8,$61,$00
	!byte $f2,$9f,$ce,$d0,$91,$d9,$60,$b5,$57,$78,$7b,$47,$b8,$3e,$e9,$62,$00
	!byte $f2,$a0,$cd,$d1,$90,$d9,$5f,$b4,$57,$77,$7c,$46,$b9,$3e,$ea,$63,$00
	!byte $f1,$a2,$cb,$d1,$8e,$d8,$5f,$b2,$58,$75,$7e,$46,$bb,$3f,$ea,$65,$00
	!byte $f1,$a3,$ca,$d2,$8d,$d8,$5e,$b1,$58,$74,$7f,$45,$bc,$3f,$eb,$66,$00
	!byte $f1,$a4,$c9,$d3,$8c,$d8,$5d,$b0,$58,$73,$80,$44,$bd,$3f,$ec,$67,$00
	!byte $f0,$a6,$c8,$d3,$8a,$d7,$5d,$af,$59,$71,$81,$44,$bf,$40,$ec,$68,$00
	!byte $f0,$a7,$c6,$d4,$89,$d7,$5c,$ad,$59,$70,$83,$43,$c0,$40,$ed,$6a,$00
	!byte $ef,$a8,$c5,$d5,$88,$d6,$5b,$ac,$5a,$6f,$84,$42,$c1,$41,$ee,$6b,$00
	!byte $ef,$a9,$c4,$d5,$87,$d6,$5b,$ab,$5a,$6e,$85,$42,$c2,$41,$ee,$6c,$00
	!byte $ee,$ab,$c2,$d6,$85,$d5,$5a,$a9,$5b,$6c,$87,$41,$c4,$42,$ef,$6e,$00
	!byte $ee,$ac,$c1,$d6,$84,$d5,$5a,$a8,$5b,$6b,$88,$41,$c5,$42,$ef,$6f,$00
	!byte $ed,$ad,$c0,$d7,$83,$d4,$59,$a7,$5c,$6a,$89,$40,$c6,$43,$f0,$70,$00
	!byte $ec,$af,$bf,$d7,$81,$d3,$59,$a6,$5d,$68,$8a,$40,$c8,$44,$f0,$71,$00
	!byte $ec,$b0,$bd,$d8,$80,$d3,$58,$a4,$5d,$67,$8c,$3f,$c9,$44,$f1,$73,$00
	!byte $eb,$b1,$bc,$d8,$7f,$d2,$58,$a3,$5e,$66,$8d,$3f,$ca,$45,$f1,$74,$00
	!byte $ea,$b2,$bb,$d8,$7e,$d1,$58,$a2,$5f,$65,$8e,$3f,$cb,$46,$f1,$75,$00
	!byte $ea,$b4,$b9,$d9,$7d,$d1,$57,$a0,$5f,$64,$90,$3e,$cd,$46,$f2,$77,$00
	!byte $e9,$b5,$b8,$d9,$7b,$d0,$57,$9f,$60,$62,$91,$3e,$ce,$47,$f2,$78,$00
	!byte $e8,$b6,$b6,$d9,$7a,$cf,$57,$9d,$61,$61,$93,$3e,$cf,$48,$f2,$7a,$00
	!byte $e8,$b7,$b5,$da,$79,$cf,$56,$9c,$61,$60,$94,$3d,$d0,$48,$f3,$7b,$00
	!byte $e7,$b8,$b4,$da,$78,$ce,$56,$9b,$62,$5f,$95,$3d,$d1,$49,$f3,$7c,$00
	!byte $e6,$b9,$b2,$da,$77,$cd,$56,$99,$63,$5e,$97,$3d,$d2,$4a,$f3,$7e,$00
	!byte $e5,$bb,$b1,$db,$75,$cc,$55,$98,$64,$5c,$98,$3c,$d4,$4b,$f4,$7f,$00
	!byte $e4,$bc,$b0,$db,$74,$cb,$55,$97,$65,$5b,$99,$3c,$d5,$4c,$f4,$80,$00
	!byte $e4,$bd,$ae,$db,$73,$cb,$55,$95,$65,$5a,$9b,$3c,$d6,$4c,$f4,$82,$00
	!byte $e3,$be,$ad,$db,$72,$ca,$55,$94,$66,$59,$9c,$3c,$d7,$4d,$f4,$83,$00
	!byte $e2,$bf,$ab,$db,$71,$c9,$55,$92,$67,$58,$9e,$3c,$d8,$4e,$f4,$85,$00
	!byte $e1,$c0,$aa,$db,$70,$c8,$55,$91,$68,$57,$9f,$3c,$d9,$4f,$f4,$86,$00
	!byte $e0,$c1,$a9,$db,$6f,$c7,$55,$90,$69,$56,$a0,$3c,$da,$50,$f4,$87,$00
	!byte $df,$c2,$a7,$db,$6e,$c6,$55,$8e,$6a,$55,$a2,$3c,$db,$51,$f4,$89,$00
	!byte $de,$c3,$a6,$db,$6d,$c5,$55,$8d,$6b,$54,$a3,$3c,$dc,$52,$f4,$8a,$00
	!byte $dd,$c4,$a5,$dc,$6c,$c4,$55,$8c,$6c,$53,$a4,$3c,$dd,$53,$f5,$8b,$00
	!byte $dc,$c5,$a3,$db,$6b,$c3,$55,$8a,$6d,$52,$a6,$3c,$de,$54,$f4,$8d,$00
	!byte $db,$c6,$a2,$db,$6a,$c2,$55,$89,$6e,$51,$a7,$3c,$df,$55,$f4,$8e,$00
	!byte $da,$c7,$a0,$db,$69,$c1,$55,$87,$6f,$50,$a9,$3c,$e0,$56,$f4,$90,$00
	!byte $d9,$c8,$9f,$db,$68,$c0,$55,$86,$70,$4f,$aa,$3c,$e1,$57,$f4,$91,$00
	!byte $d8,$c9,$9e,$db,$67,$bf,$55,$85,$71,$4e,$ab,$3c,$e2,$58,$f4,$92,$00
	!byte $d7,$ca,$9c,$db,$66,$be,$55,$83,$72,$4d,$ad,$3c,$e3,$59,$f4,$94,$00
	!byte $d6,$cb,$9b,$db,$65,$bd,$55,$82,$73,$4c,$ae,$3c,$e4,$5a,$f4,$95,$00
	!byte $d5,$cb,$99,$db,$65,$bc,$55,$80,$74,$4c,$b0,$3c,$e4,$5b,$f4,$97,$00
	!byte $d4,$cc,$98,$db,$64,$bb,$55,$7f,$75,$4b,$b1,$3c,$e5,$5c,$f4,$98,$00
	!byte $d2,$cd,$97,$da,$63,$b9,$56,$7e,$77,$4a,$b2,$3d,$e6,$5e,$f3,$99,$00
	!byte $d1,$ce,$95,$da,$62,$b8,$56,$7c,$78,$49,$b4,$3d,$e7,$5f,$f3,$9b,$00
	!byte $d0,$cf,$94,$da,$61,$b7,$56,$7b,$79,$48,$b5,$3d,$e8,$60,$f3,$9c,$00
	!byte $cf,$cf,$93,$d9,$61,$b6,$57,$7a,$7a,$48,$b6,$3e,$e8,$61,$f2,$9d,$00
	!byte $ce,$d0,$91,$d9,$60,$b5,$57,$78,$7b,$47,$b8,$3e,$e9,$62,$f2,$9f,$00
	!byte $cd,$d1,$90,$d9,$5f,$b4,$57,$77,$7c,$46,$b9,$3e,$ea,$63,$f2,$a0,$00
	!byte $cb,$d1,$8e,$d8,$5f,$b2,$58,$75,$7e,$46,$bb,$3f,$ea,$65,$f1,$a2,$00
	!byte $ca,$d2,$8d,$d8,$5e,$b1,$58,$74,$7f,$45,$bc,$3f,$eb,$66,$f1,$a3,$00
	!byte $c9,$d3,$8c,$d8,$5d,$b0,$58,$73,$80,$44,$bd,$3f,$ec,$67,$f1,$a4,$00
	!byte $c8,$d3,$8a,$d7,$5d,$af,$59,$71,$81,$44,$bf,$40,$ec,$68,$f0,$a6,$00
	!byte $c6,$d4,$89,$d7,$5c,$ad,$59,$70,$83,$43,$c0,$40,$ed,$6a,$f0,$a7,$00
	!byte $c5,$d5,$88,$d6,$5b,$ac,$5a,$6f,$84,$42,$c1,$41,$ee,$6b,$ef,$a8,$00
	!byte $c4,$d5,$87,$d6,$5b,$ab,$5a,$6e,$85,$42,$c2,$41,$ee,$6c,$ef,$a9,$00
	!byte $c2,$d6,$85,$d5,$5a,$a9,$5b,$6c,$87,$41,$c4,$42,$ef,$6e,$ee,$ab,$00
	!byte $c1,$d6,$84,$d5,$5a,$a8,$5b,$6b,$88,$41,$c5,$42,$ef,$6f,$ee,$ac,$00
	!byte $c0,$d7,$83,$d4,$59,$a7,$5c,$6a,$89,$40,$c6,$43,$f0,$70,$ed,$ad,$00
	!byte $bf,$d7,$81,$d3,$59,$a6,$5d,$68,$8a,$40,$c8,$44,$f0,$71,$ec,$af,$00
	!byte $bd,$d8,$80,$d3,$58,$a4,$5d,$67,$8c,$3f,$c9,$44,$f1,$73,$ec,$b0,$00
	!byte $bc,$d8,$7f,$d2,$58,$a3,$5e,$66,$8d,$3f,$ca,$45,$f1,$74,$eb,$b1,$00
	!byte $bb,$d8,$7e,$d1,$58,$a2,$5f,$65,$8e,$3f,$cb,$46,$f1,$75,$ea,$b2,$00
	!byte $b9,$d9,$7d,$d1,$57,$a0,$5f,$64,$90,$3e,$cd,$46,$f2,$77,$ea,$b3,$00
	!byte $b8,$d9,$7b,$d0,$57,$9f,$60,$62,$91,$3e,$ce,$47,$f2,$78,$e9,$b5,$00
	!byte $b6,$d9,$7a,$cf,$57,$9d,$61,$61,$93,$3e,$cf,$48,$f2,$7a,$e8,$b6,$00
	!byte $b5,$da,$79,$cf,$56,$9c,$61,$60,$94,$3d,$d0,$48,$f3,$7b,$e8,$b7,$00
	!byte $b4,$da,$78,$ce,$56,$9b,$62,$5f,$95,$3d,$d1,$49,$f3,$7c,$e7,$b8,$00
	!byte $b2,$da,$77,$cd,$56,$99,$63,$5e,$97,$3d,$d2,$4a,$f3,$7e,$e6,$b9,$00
	!byte $b1,$db,$75,$cc,$55,$98,$64,$5c,$98,$3c,$d4,$4b,$f4,$7f,$e5,$bb,$00
	!byte $b0,$db,$74,$cb,$55,$97,$65,$5b,$99,$3c,$d5,$4c,$f4,$80,$e4,$bc,$00
	!byte $ae,$db,$73,$cb,$55,$95,$65,$5a,$9b,$3c,$d6,$4c,$f4,$82,$e4,$bd,$00
	!byte $ad,$db,$72,$ca,$55,$94,$66,$59,$9c,$3c,$d7,$4d,$f4,$83,$e3,$be,$00
	!byte $ab,$db,$71,$c9,$55,$92,$67,$58,$9e,$3c,$d8,$4e,$f4,$85,$e2,$bf,$00
	!byte $aa,$db,$70,$c8,$55,$91,$68,$57,$9f,$3c,$d9,$4f,$f4,$86,$e1,$c0,$00
	!byte $a9,$db,$6f,$c7,$55,$90,$69,$56,$a0,$3c,$da,$50,$f4,$87,$e0,$c1,$00
	!byte $a7,$db,$6e,$c6,$55,$8e,$6a,$55,$a2,$3c,$db,$51,$f4,$89,$df,$c2,$00
	!byte $a6,$db,$6d,$c5,$55,$8d,$6b,$54,$a3,$3c,$dc,$52,$f4,$8a,$de,$c3,$00
	!byte $a5,$dc,$6c,$c4,$55,$8c,$6c,$53,$a4,$3c,$dd,$53,$f5,$8b,$dd,$c4,$00
	!byte $a3,$db,$6b,$c3,$55,$8a,$6d,$52,$a6,$3c,$de,$54,$f4,$8d,$dc,$c5,$00
	!byte $a2,$db,$6a,$c2,$55,$89,$6e,$51,$a7,$3c,$df,$55,$f4,$8e,$db,$c6,$00
	!byte $a0,$db,$69,$c1,$55,$87,$6f,$50,$a9,$3c,$e0,$56,$f4,$90,$da,$c7,$00
	!byte $9f,$db,$68,$c0,$55,$86,$70,$4f,$aa,$3c,$e1,$57,$f4,$91,$d9,$c8,$00
	!byte $9e,$db,$67,$bf,$55,$85,$71,$4e,$ab,$3c,$e2,$58,$f4,$92,$d8,$c9,$00
	!byte $9c,$db,$66,$be,$55,$83,$72,$4d,$ad,$3c,$e3,$59,$f4,$94,$d7,$ca,$00
	!byte $9b,$db,$65,$bd,$55,$82,$73,$4c,$ae,$3c,$e4,$5a,$f4,$95,$d6,$cb,$00
	!byte $99,$db,$65,$bc,$55,$80,$74,$4c,$b0,$3c,$e4,$5b,$f4,$97,$d5,$cb,$00
	!byte $98,$db,$64,$bb,$55,$7f,$75,$4b,$b1,$3c,$e5,$5c,$f4,$98,$d4,$cc,$00
	!byte $97,$da,$63,$b9,$56,$7e,$77,$4a,$b2,$3d,$e6,$5e,$f3,$99,$d2,$cd,$00
	!byte $95,$da,$62,$b8,$56,$7c,$78,$49,$b4,$3d,$e7,$5f,$f3,$9b,$d1,$ce,$00
	!byte $94,$da,$61,$b7,$56,$7b,$79,$48,$b5,$3d,$e8,$60,$f3,$9c,$d0,$cf,$00
	!byte $93,$d9,$61,$b6,$57,$7a,$7a,$48,$b6,$3e,$e8,$61,$f2,$9d,$cf,$cf,$00
	!byte $91,$d9,$60,$b5,$57,$78,$7b,$47,$b8,$3e,$e9,$62,$f2,$9f,$ce,$d0,$00
	!byte $90,$d9,$5f,$b4,$57,$77,$7c,$46,$b9,$3e,$ea,$63,$f2,$a0,$cc,$d1,$00
	!byte $8e,$d8,$5f,$b2,$58,$75,$7e,$46,$bb,$3f,$ea,$65,$f1,$a2,$cb,$d1,$00
	!byte $8d,$d8,$5e,$b1,$58,$74,$7f,$45,$bc,$3f,$eb,$66,$f1,$a3,$ca,$d2,$00
	!byte $8c,$d8,$5d,$b0,$58,$73,$80,$44,$bd,$3f,$ec,$67,$f1,$a4,$c9,$d3,$00
	!byte $8a,$d7,$5d,$af,$59,$71,$81,$44,$bf,$40,$ec,$68,$f0,$a6,$c8,$d3,$00
	!byte $89,$d7,$5c,$ad,$59,$70,$83,$43,$c0,$40,$ed,$6a,$f0,$a7,$c6,$d4,$00
	!byte $88,$d6,$5b,$ac,$5a,$6f,$84,$42,$c1,$41,$ee,$6b,$ef,$a8,$c5,$d5,$00
	!byte $87,$d6,$5b,$ab,$5a,$6e,$85,$42,$c2,$41,$ee,$6c,$ef,$a9,$c4,$d5,$00
	!byte $85,$d5,$5a,$a9,$5b,$6c,$87,$41,$c4,$42,$ef,$6e,$ee,$ab,$c2,$d6,$00
	!byte $84,$d5,$5a,$a8,$5b,$6b,$88,$41,$c5,$42,$ef,$6f,$ee,$ac,$c1,$d6,$00
	!byte $83,$d4,$59,$a7,$5c,$6a,$89,$40,$c6,$43,$f0,$70,$ed,$ad,$c0,$d7,$00
	!byte $81,$d3,$59,$a6,$5d,$68,$8a,$40,$c8,$44,$f0,$71,$ec,$af,$bf,$d7,$00
	!byte $80,$d3,$58,$a4,$5d,$67,$8c,$3f,$c9,$44,$f1,$73,$ec,$b0,$bd,$d8,$00
	!byte $7f,$d2,$58,$a3,$5e,$66,$8d,$3f,$ca,$45,$f1,$74,$eb,$b1,$bc,$d8,$00
	!byte $7e,$d1,$58,$a2,$5f,$65,$8e,$3f,$cb,$46,$f1,$75,$ea,$b2,$bb,$d8,$00
	!byte $7d,$d1,$57,$a0,$5f,$64,$90,$3e,$cd,$46,$f2,$77,$ea,$b3,$b9,$d9,$00
	!byte $7b,$d0,$57,$9f,$60,$62,$91,$3e,$ce,$47,$f2,$78,$e9,$b5,$b8,$d9,$00
	!byte $7a,$cf,$57,$9d,$61,$61,$93,$3e,$cf,$48,$f2,$7a,$e8,$b6,$b6,$d9,$00
	!byte $79,$cf,$56,$9c,$61,$60,$94,$3d,$d0,$48,$f3,$7b,$e8,$b7,$b5,$da,$00
	!byte $78,$ce,$56,$9b,$62,$5f,$95,$3d,$d1,$49,$f3,$7c,$e7,$b8,$b4,$da,$00
	!byte $77,$cd,$56,$99,$63,$5e,$97,$3d,$d2,$4a,$f3,$7e,$e6,$b9,$b2,$da,$00
	!byte $75,$cc,$55,$98,$64,$5c,$98,$3c,$d4,$4b,$f4,$7f,$e5,$bb,$b1,$db,$00
	!byte $74,$cb,$55,$97,$65,$5b,$99,$3c,$d5,$4c,$f4,$80,$e4,$bc,$b0,$db,$00
	!byte $73,$cb,$55,$95,$65,$5a,$9b,$3c,$d6,$4c,$f4,$82,$e4,$bd,$ae,$db,$00
	!byte $72,$ca,$55,$94,$66,$59,$9c,$3c,$d7,$4d,$f4,$83,$e3,$be,$ad,$db,$00
	!byte $71,$c9,$55,$92,$67,$58,$9e,$3c,$d8,$4e,$f4,$85,$e2,$bf,$ab,$db,$00
	!byte $70,$c8,$55,$91,$68,$57,$9f,$3c,$d9,$4f,$f4,$86,$e1,$c0,$aa,$db,$00
	!byte $6f,$c7,$55,$90,$69,$56,$a0,$3c,$da,$50,$f4,$87,$e0,$c1,$a9,$db,$00
	!byte $6e,$c6,$55,$8e,$6a,$55,$a2,$3c,$db,$51,$f4,$89,$df,$c2,$a7,$db,$00
	!byte $6d,$c5,$55,$8d,$6b,$54,$a3,$3c,$dc,$52,$f4,$8a,$de,$c3,$a6,$db,$00
	!byte $6c,$c4,$55,$8c,$6c,$53,$a4,$3c,$dd,$53,$f5,$8b,$dd,$c4,$a5,$dc,$00
	!byte $6b,$c3,$55,$8a,$6d,$52,$a6,$3c,$de,$54,$f4,$8d,$dc,$c5,$a3,$db,$00
	!byte $6a,$c2,$55,$89,$6e,$51,$a7,$3c,$df,$55,$f4,$8e,$db,$c6,$a2,$db,$00
	!byte $69,$c1,$55,$87,$6f,$50,$a9,$3c,$e0,$56,$f4,$90,$da,$c7,$a0,$db,$00
	!byte $68,$c0,$55,$86,$70,$4f,$aa,$3c,$e1,$57,$f4,$91,$d9,$c8,$9f,$db,$00
	!byte $67,$bf,$55,$85,$71,$4e,$ab,$3c,$e2,$58,$f4,$92,$d8,$c9,$9e,$db,$00
	!byte $66,$be,$55,$83,$72,$4d,$ad,$3c,$e3,$59,$f4,$94,$d7,$ca,$9c,$db,$00
	!byte $65,$bd,$55,$82,$73,$4c,$ae,$3c,$e4,$5a,$f4,$95,$d6,$cb,$9b,$db,$00
	!byte $65,$bc,$55,$80,$74,$4c,$b0,$3c,$e4,$5b,$f4,$97,$d5,$cb,$99,$db,$00
	!byte $64,$bb,$55,$7f,$75,$4b,$b1,$3c,$e5,$5c,$f4,$98,$d4,$cc,$98,$db,$00
	!byte $63,$b9,$56,$7e,$77,$4a,$b2,$3d,$e6,$5e,$f3,$99,$d2,$cd,$97,$da,$00
	!byte $62,$b8,$56,$7c,$78,$49,$b4,$3d,$e7,$5f,$f3,$9b,$d1,$ce,$95,$da,$00
	!byte $61,$b7,$56,$7b,$79,$48,$b5,$3d,$e8,$60,$f3,$9c,$d0,$cf,$94,$da,$00
	!byte $61,$b6,$57,$7a,$7a,$48,$b6,$3e,$e8,$61,$f2,$9d,$cf,$cf,$93,$d9,$00
	!byte $60,$b5,$57,$78,$7b,$47,$b8,$3e,$e9,$62,$f2,$9f,$ce,$d0,$91,$d9,$00
	!byte $5f,$b4,$57,$77,$7c,$46,$b9,$3e,$ea,$63,$f2,$a0,$cc,$d1,$90,$d9,$00
	!byte $5f,$b2,$58,$75,$7e,$46,$bb,$3f,$ea,$65,$f1,$a2,$cb,$d1,$8e,$d8,$00
	!byte $5e,$b1,$58,$74,$7f,$45,$bc,$3f,$eb,$66,$f1,$a3,$ca,$d2,$8d,$d8,$00
	!byte $5d,$b0,$58,$73,$80,$44,$bd,$3f,$ec,$67,$f1,$a4,$c9,$d3,$8c,$d8,$00
	!byte $5d,$af,$59,$71,$81,$44,$bf,$40,$ec,$68,$f0,$a6,$c8,$d3,$8a,$d7,$00
	!byte $5c,$ad,$59,$70,$83,$43,$c0,$40,$ed,$6a,$f0,$a7,$c6,$d4,$89,$d7,$00
	!byte $5b,$ac,$5a,$6f,$84,$42,$c1,$41,$ee,$6b,$ef,$a8,$c5,$d5,$88,$d6,$00
	!byte $5b,$ab,$5a,$6e,$85,$42,$c2,$41,$ee,$6c,$ef,$a9,$c4,$d5,$87,$d6,$00
	!byte $5a,$a9,$5b,$6c,$87,$41,$c4,$42,$ef,$6e,$ee,$ab,$c2,$d6,$85,$d5,$00
	!byte $5a,$a8,$5b,$6b,$88,$41,$c5,$42,$ef,$6f,$ee,$ac,$c1,$d6,$84,$d5,$00
	!byte $59,$a7,$5c,$6a,$89,$40,$c6,$43,$f0,$70,$ed,$ad,$c0,$d7,$83,$d4,$00
	!byte $59,$a6,$5d,$68,$8a,$40,$c8,$44,$f0,$71,$ec,$af,$bf,$d7,$81,$d3,$00
	!byte $58,$a4,$5d,$67,$8c,$3f,$c9,$44,$f1,$73,$ec,$b0,$bd,$d8,$80,$d3,$00
	!byte $58,$a3,$5e,$66,$8d,$3f,$ca,$45,$f1,$74,$eb,$b1,$bc,$d8,$7f,$d2,$00
	!byte $58,$a2,$5f,$65,$8e,$3f,$cb,$46,$f1,$75,$ea,$b2,$bb,$d8,$7e,$d1,$00
	!byte $57,$a0,$5f,$64,$90,$3e,$cd,$46,$f2,$77,$ea,$b3,$b9,$d9,$7d,$d1,$00
	!byte $57,$9f,$60,$62,$91,$3e,$ce,$47,$f2,$78,$e9,$b5,$b8,$d9,$7b,$d0,$00
	!byte $57,$9d,$61,$61,$93,$3e,$cf,$48,$f2,$7a,$e8,$b6,$b6,$d9,$7a,$cf,$00
	!byte $56,$9c,$61,$60,$94,$3d,$d0,$48,$f3,$7b,$e8,$b7,$b5,$da,$79,$cf,$00
	!byte $56,$9b,$62,$5f,$95,$3d,$d1,$49,$f3,$7c,$e7,$b8,$b4,$da,$78,$ce,$00
	!byte $56,$99,$63,$5e,$97,$3d,$d2,$4a,$f3,$7e,$e6,$b9,$b2,$da,$77,$cd,$00
	!byte $55,$98,$64,$5c,$98,$3c,$d4,$4b,$f4,$7f,$e5,$bb,$b1,$db,$75,$cc,$00
	!byte $55,$97,$65,$5b,$99,$3c,$d5,$4c,$f4,$80,$e4,$bc,$b0,$db,$74,$cb,$00
	!byte $55,$95,$65,$5a,$9b,$3c,$d6,$4c,$f4,$82,$e4,$bd,$ae,$db,$73,$cb,$00
	!byte $55,$94,$66,$59,$9c,$3c,$d7,$4d,$f4,$83,$e3,$be,$ad,$db,$72,$ca,$00
	!byte $55,$92,$67,$58,$9e,$3c,$d8,$4e,$f4,$85,$e2,$bf,$ab,$db,$71,$c9,$00
	!byte $55,$91,$68,$57,$9f,$3c,$d9,$4f,$f4,$86,$e1,$c0,$aa,$db,$70,$c8,$00
	!byte $55,$90,$69,$56,$a0,$3c,$da,$50,$f4,$87,$e0,$c1,$a9,$db,$6f,$c7,$00
	!byte $55,$8e,$6a,$55,$a2,$3c,$db,$51,$f4,$89,$df,$c2,$a7,$db,$6e,$c6,$00
	!byte $55,$8d,$6b,$54,$a3,$3c,$dc,$52,$f4,$8a,$de,$c3,$a6,$db,$6d,$c5,$00
	!byte $55,$8c,$6c,$53,$a4,$3c,$dd,$53,$f5,$8b,$dd,$c4,$a5,$dc,$6c,$c4,$00
	!byte $55,$8a,$6d,$52,$a6,$3c,$de,$54,$f4,$8d,$dc,$c5,$a3,$db,$6b,$c3,$00
	!byte $55,$89,$6e,$51,$a7,$3c,$df,$55,$f4,$8e,$db,$c6,$a2,$db,$6a,$c2,$00
	!byte $55,$87,$6f,$50,$a9,$3c,$e0,$56,$f4,$90,$da,$c7,$a0,$db,$69,$c1,$00
	!byte $55,$86,$70,$4f,$aa,$3c,$e1,$57,$f4,$91,$d9,$c8,$9f,$db,$68,$c0,$00
	!byte $55,$85,$71,$4e,$ab,$3c,$e2,$58,$f4,$92,$d8,$c9,$9e,$db,$67,$bf,$00
	!byte $55,$83,$72,$4d,$ad,$3c,$e3,$59,$f4,$94,$d7,$ca,$9c,$db,$66,$be,$00
	!byte $55,$82,$73,$4c,$ae,$3c,$e4,$5a,$f4,$95,$d6,$cb,$9b,$db,$65,$bd,$00
	!byte $55,$80,$74,$4c,$b0,$3c,$e4,$5b,$f4,$97,$d5,$cb,$99,$db,$65,$bc,$00
	!byte $55,$7f,$75,$4b,$b1,$3c,$e5,$5c,$f4,$98,$d4,$cc,$98,$db,$64,$bb,$00
	!byte $56,$7e,$77,$4a,$b2,$3d,$e6,$5e,$f3,$99,$d2,$cd,$97,$da,$63,$b9,$00
	!byte $56,$7c,$78,$49,$b4,$3d,$e7,$5f,$f3,$9b,$d1,$ce,$95,$da,$62,$b8,$00
	!byte $56,$7b,$79,$48,$b5,$3d,$e8,$60,$f3,$9c,$d0,$cf,$94,$da,$61,$b7,$00
	!byte $57,$7a,$7a,$48,$b6,$3e,$e8,$61,$f2,$9d,$cf,$cf,$93,$d9,$61,$b6,$00
	!byte $57,$78,$7b,$47,$b8,$3e,$e9,$62,$f2,$9f,$ce,$d0,$91,$d9,$60,$b5,$00
	!byte $57,$77,$7c,$46,$b9,$3e,$ea,$63,$f2,$a0,$cc,$d1,$90,$d9,$5f,$b4,$00
	!byte $58,$75,$7e,$46,$bb,$3f,$ea,$65,$f1,$a2,$cb,$d1,$8e,$d8,$5f,$b2,$00
	!byte $58,$74,$7f,$45,$bc,$3f,$eb,$66,$f1,$a3,$ca,$d2,$8d,$d8,$5e,$b1,$00
	!byte $58,$73,$80,$44,$bd,$3f,$ec,$67,$f1,$a4,$c9,$d3,$8c,$d8,$5d,$b0,$00
	!byte $59,$71,$81,$44,$bf,$40,$ec,$68,$f0,$a6,$c8,$d3,$8a,$d7,$5d,$af,$00
	!byte $59,$70,$83,$43,$c0,$40,$ed,$6a,$f0,$a7,$c6,$d4,$89,$d7,$5c,$ad,$00
	!byte $5a,$6f,$84,$42,$c1,$41,$ee,$6b,$ef,$a8,$c5,$d5,$88,$d6,$5b,$ac,$00
	!byte $5a,$6e,$85,$42,$c2,$41,$ee,$6c,$ef,$a9,$c4,$d5,$87,$d6,$5b,$ab,$00
	!byte $5b,$6c,$87,$41,$c4,$42,$ef,$6e,$ee,$ab,$c2,$d6,$85,$d5,$5a,$a9,$00
	!byte $5b,$6b,$88,$41,$c5,$42,$ef,$6f,$ee,$ac,$c1,$d6,$84,$d5,$5a,$a8,$00
	!byte $5c,$6a,$89,$40,$c6,$43,$f0,$70,$ed,$ad,$c0,$d7,$83,$d4,$59,$a7,$00
	!byte $5d,$68,$8a,$40,$c8,$44,$f0,$71,$ec,$af,$bf,$d7,$81,$d3,$59,$a6,$00
	!byte $5d,$67,$8c,$3f,$c9,$44,$f1,$73,$ec,$b0,$bd,$d8,$80,$d3,$58,$a4,$00
	!byte $5e,$66,$8d,$3f,$ca,$45,$f1,$74,$eb,$b1,$bc,$d8,$7f,$d2,$58,$a3,$00
	!byte $5f,$65,$8e,$3f,$cb,$46,$f1,$75,$ea,$b2,$bb,$d8,$7e,$d1,$58,$a2,$00
	!byte $5f,$64,$90,$3e,$cd,$46,$f2,$77,$ea,$b3,$b9,$d9,$7d,$d1,$57,$a0,$00
	!byte $60,$62,$91,$3e,$ce,$47,$f2,$78,$e9,$b5,$b8,$d9,$7b,$d0,$57,$9f,$00
	!byte $61,$61,$93,$3e,$cf,$48,$f2,$7a,$e8,$b6,$b6,$d9,$7a,$cf,$57,$9d,$00
	!byte $61,$60,$94,$3d,$d0,$48,$f3,$7b,$e8,$b7,$b5,$da,$79,$cf,$56,$9c,$00
	!byte $62,$5f,$95,$3d,$d1,$49,$f3,$7c,$e7,$b8,$b4,$da,$78,$ce,$56,$9b,$00
	!byte $63,$5e,$97,$3d,$d2,$4a,$f3,$7e,$e6,$b9,$b2,$da,$77,$cd,$56,$99,$00
	!byte $64,$5c,$98,$3c,$d4,$4b,$f4,$7f,$e5,$bb,$b1,$db,$75,$cc,$55,$98,$00
	!byte $65,$5b,$99,$3c,$d5,$4c,$f4,$80,$e4,$bc,$b0,$db,$74,$cb,$55,$97,$00
	!byte $65,$5a,$9b,$3c,$d6,$4c,$f4,$82,$e4,$bd,$ae,$db,$73,$cb,$55,$95,$00
	!byte $66,$59,$9c,$3c,$d7,$4d,$f4,$83,$e3,$be,$ad,$db,$72,$ca,$55,$94,$00
	!byte $67,$58,$9e,$3c,$d8,$4e,$f4,$85,$e2,$bf,$ab,$db,$71,$c9,$55,$92,$00
	!byte $68,$57,$9f,$3c,$d9,$4f,$f4,$86,$e1,$c0,$aa,$db,$70,$c8,$55,$91,$00
	!byte $69,$56,$a0,$3c,$da,$50,$f4,$87,$e0,$c1,$a9,$db,$6f,$c7,$55,$90,$00
	!byte $6a,$55,$a2,$3c,$db,$51,$f4,$89,$df,$c2,$a7,$db,$6e,$c6,$55,$8e,$00
	!byte $6b,$54,$a3,$3c,$dc,$52,$f4,$8a,$de,$c3,$a6,$db,$6d,$c5,$55,$8d,$00
	!byte $6c,$53,$a4,$3c,$dd,$53,$f5,$8b,$dd,$c4,$a5,$dc,$6c,$c4,$55,$8c,$00
	!byte $6d,$52,$a6,$3c,$de,$54,$f4,$8d,$dc,$c5,$a3,$db,$6b,$c3,$55,$8a,$00
	!byte $6e,$51,$a7,$3c,$df,$55,$f4,$8e,$db,$c6,$a2,$db,$6a,$c2,$55,$89,$00
	!byte $6f,$50,$a9,$3c,$e0,$56,$f4,$90,$da,$c7,$a0,$db,$69,$c1,$55,$87,$00
	!byte $70,$4f,$aa,$3c,$e1,$57,$f4,$91,$d9,$c8,$9f,$db,$68,$c0,$55,$86,$00
	!byte $71,$4e,$ab,$3c,$e2,$58,$f4,$92,$d8,$c9,$9e,$db,$67,$bf,$55,$85,$00
	!byte $72,$4d,$ad,$3c,$e3,$59,$f4,$94,$d7,$ca,$9c,$db,$66,$be,$55,$83,$00
	!byte $73,$4c,$ae,$3c,$e4,$5a,$f4,$95,$d6,$cb,$9b,$db,$65,$bd,$55,$82,$00
	!byte $74,$4c,$b0,$3c,$e4,$5b,$f4,$97,$d5,$cb,$99,$db,$65,$bc,$55,$80,$00
	!byte $75,$4b,$b1,$3c,$e5,$5c,$f4,$98,$d4,$cc,$98,$db,$64,$bb,$55,$7f,$00
	!byte $77,$4a,$b2,$3d,$e6,$5e,$f3,$99,$d2,$cd,$97,$da,$63,$b9,$56,$7e,$00
	!byte $78,$49,$b4,$3d,$e7,$5f,$f3,$9b,$d1,$ce,$95,$da,$62,$b8,$56,$7c,$00
	!byte $79,$48,$b5,$3d,$e8,$60,$f3,$9c,$d0,$cf,$94,$da,$61,$b7,$56,$7b,$00
	!byte $7a,$48,$b6,$3e,$e8,$61,$f2,$9d,$cf,$cf,$93,$d9,$61,$b6,$57,$7a,$00
	!byte $7b,$47,$b8,$3e,$e9,$62,$f2,$9f,$ce,$d0,$91,$d9,$60,$b5,$57,$78,$00
	!byte $7c,$46,$b9,$3e,$ea,$63,$f2,$a0,$cc,$d1,$90,$d9,$5f,$b4,$57,$77,$00
	!byte $7e,$46,$bb,$3f,$ea,$65,$f1,$a2,$cb,$d1,$8e,$d8,$5f,$b2,$58,$75,$00
	!byte $7f,$45,$bc,$3f,$eb,$66,$f1,$a3,$ca,$d2,$8d,$d8,$5e,$b1,$58,$74,$00
	!byte $80,$44,$bd,$3f,$ec,$67,$f1,$a4,$c9,$d3,$8c,$d8,$5d,$b0,$58,$73,$00
	!byte $81,$44,$bf,$40,$ec,$68,$f0,$a6,$c8,$d3,$8a,$d7,$5d,$af,$59,$71,$00
	!byte $83,$43,$c0,$40,$ed,$6a,$f0,$a7,$c6,$d4,$89,$d7,$5c,$ad,$59,$70,$00
	!byte $84,$42,$c1,$41,$ee,$6b,$ef,$a8,$c5,$d5,$88,$d6,$5b,$ac,$5a,$6f,$00
	!byte $85,$42,$c2,$41,$ee,$6c,$ef,$a9,$c4,$d5,$87,$d6,$5b,$ab,$5a,$6e,$00
	!byte $87,$41,$c4,$42,$ef,$6e,$ee,$ab,$c2,$d6,$85,$d5,$5a,$a9,$5b,$6c,$00
	!byte $88,$41,$c5,$42,$ef,$6f,$ee,$ac,$c1,$d6,$84,$d5,$5a,$a8,$5b,$6b,$00
	!byte $89,$40,$c6,$43,$f0,$70,$ed,$ad,$c0,$d7,$83,$d4,$59,$a7,$5c,$6a,$00
	!byte $8a,$40,$c8,$44,$f0,$71,$ec,$af,$bf,$d7,$81,$d3,$59,$a6,$5d,$68,$00
	!byte $8c,$3f,$c9,$44,$f1,$73,$ec,$b0,$bd,$d8,$80,$d3,$58,$a4,$5d,$67,$00
	!byte $8d,$3f,$ca,$45,$f1,$74,$eb,$b1,$bc,$d8,$7f,$d2,$58,$a3,$5e,$66,$00
	!byte $8e,$3f,$cb,$46,$f1,$75,$ea,$b2,$bb,$d8,$7e,$d1,$58,$a2,$5f,$65,$00
	!byte $90,$3e,$cd,$46,$f2,$77,$ea,$b3,$b9,$d9,$7d,$d1,$57,$a0,$5f,$63,$00
