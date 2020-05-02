all: hello.prg

%.prg: %.s
	acme hello.s

test: hello.prg
	x64sc $<

clean:
	rm -f *.prg
