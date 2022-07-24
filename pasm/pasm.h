#ifndef PASM_H
#define PASM_H

enum { BIN, TEXT };

#define ROM_DEFAULT_ADDR_PATH "/usr/share/op/rom_addr"
#define ROM_DEFAULT_PATH "/usr/share/op/rom"
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

#endif
