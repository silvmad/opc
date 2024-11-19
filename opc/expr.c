/*
IED L3 Informatique
Développement de logiciel libre
Projet final
Victor Matalonga
Numéro étudiant 18905451

fichier : expr.c

Gestion des expressions 
*/

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

/* Fabrique une expressions. 
   Essaie au maximum de réutiliser des expressions libres. 
   Renvoie l'expression créée. */
expr* fairexpr(char *nom)
{
  expr *e;
  //On essaye de recycler une expression libre avant d'en créer une nouvelle.
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
	  /* Si on a recyclé une position en dehors de l'espace local, 
	     on ajuste l'espace local pour qu'il inclue cette position.
	  */
	  if (i < DEB_LOCAL)
	    {
	      DEB_LOCAL = i; 
	    }
	  return e;
	}
    }
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

/* Crée une expression correspondant à une constant. 
   Cette expression n'est pas ajoutée au tableau des expression. */
expr* faire_cst_expr(int val)
{
  expr *e = calloc(sizeof(expr), 1);
  e->cst = true;
  e->pos = val;
  return e;
}

/* Renvoie l'expression correspondant à la variable dont le nom est donnée en 
   argument. */
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
  return NULL;
}

/* Libère une expression.
   S'il s'agit d'une expression correspondant à une constante, une variable
   globale ou une chaîne littérale et qui n'a donc pas été ajoutée au tableau
   expression, la mémoire correspondant à cette expression est simplement 
   libérée. 
   Sinon l'expression est marquée comme libre pour pouvoir être réutilisée. */
void libere(expr * e)
{
  if (e->cst || e->litt || e->glob)
    {
      free(e);
    }
  else if (e->nom == 0)
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

/* Permet de libérer les expressions correspondant à des variables locales dont
   on a quitté l'espace. 
   n : le début de l'espace locale que l'on vient de quitter. */
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
	 
/* Permet de vérifier avant une définition de variable qu'une variable de ce
   nom n'existe pas déjà dans l'espace de nom local. */
bool loc_existe(char *nom)
{
  for(int i = DEB_LOCAL; i < n_expr; ++i)
    {
      if (expressions[i].nom && !strcmp(expressions[i].nom, nom))
	{
	  return true;
	}
    }
  return false;
}

/* Ajoute n à la valeur de n_expr.
   Si n_expr est positif, toutes les expressions dans les cases n_expr à 
   n_expr + n sont libérées et leur nom est supprimé. */
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
