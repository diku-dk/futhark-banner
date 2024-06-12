FUTHARK_BACKEND=multicore

all: futhark-banner

lib: futhark.pkg
	futhark pkg sync

text.c: text.fut lib
	futhark $(FUTHARK_BACKEND) --library text.fut

text.o: text.c
	cc -c text.c -O

futhark-banner.o: futhark-banner.c text.c
	cc -c futhark-banner.c -O

futhark-banner: text.o futhark-banner.o
	cc -o futhark-banner text.o futhark-banner.o -Wall -Wextra -pedantic -pthread

clean:
	rm -f futhark-banner *.o text.{c,h,json}
