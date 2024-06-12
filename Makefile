FUTHARK_BACKEND=multicore

all: banner

text.c: text.fut
	futhark $(FUTHARK_BACKEND) --library text.fut

text.o: text.c
	cc -c text.c -O

banner.o: banner.c text.c
	cc -c banner.c -O

banner: text.o banner.o
	cc -o banner text.o banner.o -Wall -Wextra -pedantic -pthread

clean:
	rm -f banner *.o text.{c,h,json}
