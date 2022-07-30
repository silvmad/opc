CFLAGS = -Wall

all : op

debug : CFLAGS += -g
debug : clean all

release : CFLAGS += -O3
release : clean all

op : op.c op.h
	gcc $(CFLAGS) -o op op.c op.h

install : op
	install op ~/.local/bin/op

uninstall : 
	rm ~/.local/bin/op

.PHONY : clean

clean :
	-rm op 
