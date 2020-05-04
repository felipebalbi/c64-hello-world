all: hello.prg

%.prg: %.s
	acme -l hello.sym hello.s

test: hello.prg
	x64sc $<

debug: hello.prg
	x64sc -initbreak 0xc0b6 -nativemonitor $<

clean:
	rm -f *.prg
