#ifndef OP_H
#define OP_H
#endif

#include <stdbool.h>

void usage(char *);
int charger_hexcode(char *, char*);
void executer(unsigned char*, char*, char*, char*, int*);
char strtoc(char*);
char recup_entree(void);
void step(unsigned char, char, char*);
void get_user_input(unsigned char*, int*, char*);
void parse_input(char*, unsigned char*, int*, char*);
void print_mem(char*);
bool adresse(char *);
void print_instruction(unsigned char, char, unsigned char);
