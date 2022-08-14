/*
IED L3 Informatique
Développement de logiciel libre
Victor Matalonga
Numéro étudiant 18905451

fichier : pasm.h

Fichier en-tête pour l'assembleur de l'ordinateur en papier.
*/

#ifndef PASM_H
#define PASM_H

enum { BIN, TEXT };

// Chemin par défaut vers la ROM.
#define ROM_DEFAULT_ADDR_PATH "/usr/share/op/rom_addr"
#define ROM_DEFAULT_PATH "/usr/share/op/rom"
/* Chemin par défaut de la rom pour une application locale (installée avec
   le Makefile et non le paquet .deb. */
#define LOCAL_ROM_DEFAULT_PATH "/.local/share/op/rom"
#define LOCAL_ROM_DEFAULT_ADDR_PATH "/.local/share/op/rom_addr"
/* Chemin vers le répertoire des ROMS définies par l'utilisateur (à accoler
   avec le chemin vers le répertoire personnel de l'utilisateur). */
#define CUSTOM_ROM_PATH "/.local/share/op/"
#define ROM_PATH_MAX_LEN 4096

#define ASCII_PRINTABLE " !\"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"

/* Structure qui lie un nom et une adresse, peut être utilisée pour 
 * représenter un label, une variable ou une fonction de la rom. */
typedef struct {
  int addr;
  char *name;
  int lineno; // La ligne où le nom apparaît dans le fichier source.
} id;

typedef struct {
  int addr;
  char *name;
  bool val_set;
  int val;
} var;

// Variables globales de l'analyseur lexical.
extern int lineno;
extern char *yytext;

// Variables globales du main.
extern id rom_funcs[256];
extern int rf_count;
extern bool make_rom;

// Variables globales de l'analyseur syntaxique
extern int mem_pos;
extern int error_count;
extern bool in_func;
extern char* functions[];
extern int n_func;

#endif
