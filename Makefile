SRCS		:= $(wildcard *.s)
SYM		:= $(SRCS:%.s=%.sym)
PRG		:= $(SRCS:%.s=%.prg)
D64		:= $(SRCS:%.s=%.d64)
DISK		:= $(basename $(SRCS))

# Pretty print
V		= @
Q		= $(V:1=)
QUIET_AS	= $(Q:@=@echo    '     AS       '$@;)
QUIET_X64	= $(Q:@=@echo    '     X64      '$@;)
QUIET_D64	= $(Q:@=@echo    '     D64      '$@;)
QUIET_CLEAN	= $(Q:@=@echo    '     CLEAN    '$@;)

# Programs
X64		:= $(shell which x64)
AS		:= $(shell which acme)
RM		:= $(shell which rm)
C1541		:= $(shell which c1541)

# Flags
ASFLAGS		:= --color -l $(SYM)
C1541_FLAGS	:= -format $(DISK),1 d64 $(D64) 8 -attach $(D64)	\
                   $(foreach p,$(PRG),-write $(p) $(subst .prg,,$(p)))

# Rules
all: d64

prg: $(SRCS)
	$(QUIET_AS) $(AS) $(ASFLAGS) $(SRCS)

d64: prg
	$(QUIET_D64) $(C1541) $(C1541_FLAGS) 1> /dev/null

test: d64
	$(QUIET_X64) $(X64) -autostart $(D64) -autostart-warp

clean:
	$(QUIET_CLEAN) $(RM) -f *.prg *.d64 *.sym
