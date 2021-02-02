SRCS		:= $(wildcard *.s)
SYM		:= $(SRCS:%.s=%.sym)
PRG		:= $(SRCS:%.s=%.prg)
D64		:= $(SRCS:%.s=%.d64)
DISK		:= $(basename $(SRCS))

# Pretty print
V		= @
Q		= $(V:1=)
QUIET_AS	= $(Q:@=@echo    '     AS       '$@;)
QUIET_LD	= $(Q:@=@echo    '     LD       '$@;)
QUIET_X64	= $(Q:@=@echo    '     X64      '$@;)
QUIET_D64	= $(Q:@=@echo    '     D64      '$@;)
QUIET_CLEAN	= $(Q:@=@echo    '     CLEAN    '$@;)

# Programs
X64		:= $(shell which x64)
AS		:= $(shell which ca65)
LD		:= $(shell which ld65)
RM		:= $(shell which rm)
C1541		:= $(shell which c1541)

# Flags
ASFLAGS		:= -t c64 -l hello.lst
LDFLAGS		:= -u __EXEHDR__ -C c64-asm.cfg -Ln hello.sym c64.lib
C1541_FLAGS	:= -format $(DISK),1 d64 $(D64) 8 -attach $(D64)	\
                   $(foreach p,$(PRG),-write $(p) $(subst .prg,,$(p)))	\
		   -write assets/future_cowboy.sid sid

# Rules
all: hello.d64

hello.d64: hello.prg
	$(QUIET_D64) $(C1541) $(C1541_FLAGS) 1> /dev/null

hello.prg: hello.o
	$(QUIET_LD) $(LD) -o $@ $(LDFLAGS) $<

hello.o: hello.s
	$(QUIET_AS) $(AS) $(ASFLAGS) -o $@ $<

run:  hello.d64
	$(QUIET_X64) $(X64) -autostart $(D64) -autostart-warp

clean:
	$(QUIET_CLEAN) $(RM) -f *.prg *.d64 *.sym *.o *.lst
