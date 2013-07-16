.PHONY: all clean

all: bf

bf: bf.yy.c bf.h queue.h
	cc -O -o bf bf.yy.c strtonum.c -ll

bf.yy.c: bf.l
	lex -obf.yy.c bf.l

clean:
	rm -f bf bf.yy.c
