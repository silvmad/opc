/*
IED L3 Informatique
Développement de logiciel libre
Projet final
Victor Matalonga
Numéro étudiant 18905451

fichier : expr.c

Gestion des expressions */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "opc.h"
#include "expr.h"
#include "opc.tab.h"

extern int n_push;

expr expressions[MAX_EXPR];
int n_expr = 0;
bool recycle;

// Pas besoin d'allocation dynamique étant donné la pile limitée à 256.
/*void init_expr()
{
  expressions = calloc(sizeof(expr), MAX_EXPR);
}

void etendre_expr()
{
  expr * nouveau = calloc(sizeof(expr), max_expr + MAX_EXPR);
  memcpy(nouveau, expressions, max_expr * sizeof(expr));
  free(expressions);
  expressions = nouveau;
  max_expr += MAX_EXPR;
  }*/

expr* fairexpr(char *nom)
{
  expr *e;
  // TEST RECYCLE TOUTES EXPR
  /*  if (nom == NULL)
      {*/
      for (int i = 0; i < n_expr; ++i)
	{
	  e = &expressions[i];
	  if (e->libre)
	    {
	      e->nom = nom;
	      e->libre = false;
	      e->cst = false;
	      e->glob = false;
	      recycle = true;
	      return e;
	    }
	}
      //}
  e = &expressions[n_expr++];
  e->pos = position;
  e->nom = nom;
  e->cst = false;
  e->libre = false;
  e->glob = false;
  position += incr;
  recycle = false;
  return e;
}

expr * exprvar(char *nom)
{
  expr *e;
  for (int i = n_expr - 1; i >= 0; --i)
    {
      e = &expressions[i];
      if (e->nom && !strcmp(nom, e->nom))
	{
	  return e;
	}
    }
  fprintf(stderr, "%i : Erreur : variable non déclarée (%s)\n", lineno, nom);
  return NULL;
}

/* libere  --  marque une expression comme libre */
void libere(expr * e)
{
  if (e->nom == 0)
    {
      e->libre = true; 
    }
}

/* Libère les n dernières expressions. */
void libere_n_derniers(int n)
{
  for (int i = n_expr - n; i < n_expr; ++i)
    {
      expressions[i].libre = true;
    }
}

void libere_variables_locales(int n)
{
  expr *e;
  for (int i = n; i < n_expr; ++i)
    {
      e = &expressions[i];
      if (e->nom != NULL)
	{
	  e->libre = true;
	  e->nom = NULL;
	}
    }
}

void incr_n_expr(int n)
{
  if (n > 0)
    {
      for (int i = n_expr; i < n_expr + n; ++i)
	{ 
	  expressions[n_expr].libre = true;
	  expressions[n_expr].nom = NULL;
	}
    }
  n_expr += n;
}
	 
/* Permet de vérifier avant une définition de variable qu'une variable de ce
   nom n'existe pas déjà dans l'espace de nom local. */
bool loc_existe(char *nom)
{
  for(int i = DEB_LOCAL; i < n_expr; ++i)
    {
      if (!strcmp(expressions[i].nom, nom))
	{
	  return true;
	}
    }
  return false;
}
