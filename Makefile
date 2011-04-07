
COUNT=count-lines -g
#COUNT=cat

test: 
	perl ./runtests

wc: .wc
	@cat .wc

.wc: FILES Makefile
	@ for i in `./FILES`; do echo -n "$$i "; $(COUNT) < "$$i" | wc -l; done | sort | tabulate > .wc

check:
	@ for i in `./FILES`; do perl -Ilib -cw "$$i"; done
