#ifndef OP_H
#define OP_H
#endif

#include <stdbool.h>

#define ROM_FILE "/usr/share/op/rom"

enum {RAM, ROM};

void usage(char *);
int charger_hexcode(char *, int*);
void executer(unsigned int*, int*, int*, int*, int*, int*);
char strtoc(char*);
char recup_entree(void);
void step(unsigned int, int, int*);
void get_user_input(unsigned int*, int*, int*);
void parse_input(char*, unsigned int*, int*, int*);
void print_mem(int*);
bool adresse(char *);
void print_instruction(unsigned int, int, unsigned int);
