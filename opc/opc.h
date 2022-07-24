#ifndef OPC_H
#define OPC_H

extern int position;
extern int incr; 
extern int lineno;
extern char *yytext;
extern int n_expr;


#include "expr.h"

void yyerror(char*);
int label();
expr* op_add_sub(char*, int, bool, int, bool);
expr* op_mult_div_mod(char*, int, bool, int, bool);
bool glob_existe(char*);
int ch_litt_lab(char*);

#define N_EXPR 512

extern int deb_esp_loc[];
extern int n_esp_loc;
#define DEB_LOCAL deb_esp_loc[n_esp_loc - 1]

#endif

