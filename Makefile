.PHONY: all clean

all: bf

bf: bf.yy.c bf.h queue.h
	cc -O -o bf bf.yy.c -ll

bf.yy.c: bf.l
	lex -o bf.yy.c bf.l

clean:
	rm -f bf bf.yy.c
