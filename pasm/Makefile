CFLAGS = -Wall

all : pasm

debug : CFLAGS += -g
debug : clean all

pasm : pasm.tab.o lex.yy.o main.o
	gcc -o pasm main.o lex.yy.o pasm.tab.o

main.o : main.c pasm.h
	gcc -c $(CFLAGS) main.c

lex.yy.o : lex.yy.c pasm.tab.h
	gcc -c $(CFLAGS) lex.yy.c

pasm.tab.o : pasm.tab.c
	gcc -c $(CFLAGS) pasm.tab.c -o pasm.tab.o

pasm.tab.c : pasm.y
	bison --defines pasm.y

lex.yy.c : pasm.l
	flex pasm.l

install : pasm
	install pasm ~/.local/bin/pasm

uninstall : 
	rm ~/.local/bin/pasm

.PHONY : clean

clean :
	-rm pasm.tab.h pasm.tab.c lex.yy.c lex.yy.o pasm.tab.o main.o 
