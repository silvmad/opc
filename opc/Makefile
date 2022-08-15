CFLAGS = -Wall

all : opc

debug : CFLAGS += -g
debug : clean all

opc : opc.tab.o lex.yy.o main.o expr.o
	gcc -o opc main.o lex.yy.o opc.tab.o expr.o

main.o : main.c opc.h expr.h
	gcc -c $(CFLAGS) main.c

lex.yy.o : lex.yy.c opc.tab.h expr.h
	gcc -c $(CFLAGS) lex.yy.c

opc.tab.o : opc.tab.c
	gcc -c $(CFLAGS) opc.tab.c -o opc.tab.o

expr.o : expr.c expr.h opc.h
	gcc -c $(CFLAGS) expr.c

opc.tab.c : opc.y
	bison --defines opc.y

lex.yy.c : opc.l
	flex opc.l

install : opc
	install opc ~/.local/bin/opc

uninstall : 
	-rm ~/.local/bin/opc

.PHONY : clean

clean :
	-rm opc opc.tab.h opc.tab.c lex.yy.c lex.yy.o opc.tab.o main.o 
