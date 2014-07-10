.PHONY: all install clean

all: bf

bf: bf.yy.c bf.h queue.h
	cc -Wall -Werror -O -o bf bf.yy.c strtonum.c -ll

bf.yy.c: bf.l
	lex -obf.yy.c bf.l

install:
	install bf /usr/local/bin/bf

clean:
	rm -f bf bf.yy.c
