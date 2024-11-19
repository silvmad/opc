/*
IED L3 Informatique
Développement de logiciel libre
Victor Matalonga
Numéro étudiant 18905451

fichier : op.h

Fichier en-tête pour l'ordinateur en papier.
*/

#ifndef OP_H
#define OP_H
#endif

#include <stdbool.h>

#define DEFAULT_ROM_PATH "/usr/share/op/rom"
#define LOCAL_DEFAULT_ROM_PATH "/.local/share/op/rom"
#define CUSTOM_ROM_PATH "/.local/share/op/"
#define ROM_PATH_MAX_LEN 4096

/* Pour le futur
typedef struct
{
  int ram[512];
  int *stack;
  int stack_base;
  int stack_count;
  int PC;
  int A;
  int mem_space;
} state;
*/

enum {RAM, ROM};

void usage(char *);
int charger_hexcode(char *, int*);
void executer(unsigned int*, int*, int*, int*, int*, int, int, int*);
int strtoi(char*);
char recup_entree(void);
void step(unsigned int, int, int*, int, int, int);
void get_user_input(unsigned int*, int*, bool*, int*, int);
void parse_input(char*, unsigned int*, int*, bool*, int*, int);
void print_mem(int*);
bool adresse(char *);
void print_instruction(unsigned int, int, unsigned int);
