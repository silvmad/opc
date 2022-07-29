#ifndef EXPR_H
#define EXPR_H

#include <stdbool.h>

#define MAX_EXPR 256

typedef struct {
  int pos;
  char *nom;
  //  int flags;
  bool libre;
  bool glob;
  bool litt;
  bool cst;
  bool tab;
  int taille;
} expr;

extern bool recycle;

expr* fairexpr(char*);
expr* faire_cst_expr(int);
expr* exprvar(char*);
void libere(expr*);
void libere_n_derniers(int);
void libere_variables_locales(int);
void incr_n_expr(int);
bool loc_existe(char*);

#endif
