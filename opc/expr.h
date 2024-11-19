/*
IED L3 Informatique
Développement de logiciel libre
Projet final
Victor Matalonga
Numéro étudiant 18905451

fichier : expr.h

Fichier en-tête pour les expressions. 
*/

#ifndef EXPR_H
#define EXPR_H

#include <stdbool.h>

#define MAX_EXPR 256

typedef struct {
  int pos;
  char *nom;
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
