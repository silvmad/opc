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
expr* op_add_sub(char*, expr*, expr*);
expr* op_mult_div_mod(char*, expr*, expr*);
int glob_existe(char*);
int ch_litt_lab(char*);

#define N_EXPR 512

#define ASCII_PRINTABLE " !\"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"

extern int deb_esp_loc[];
extern int n_esp_loc;
#define DEB_LOCAL deb_esp_loc[n_esp_loc - 1]

/* Permet d'écrire le code qui charge la valeur d'une expression dans 
   l'accumulateur en fonction du type d'expression : constante, globale ou 
   locale. */
#define CHRG_EXPR(E)                              \
  if ((E)->cst) 				  \
    { 						  \
      printf("\tLOAD #%i\n", (E)->pos); 	  \
    } 						  \
  else if ((E)->glob) 				  \
    { 						  \
      printf("\tLOAD #%s\n", (E)->nom); 	  \
    } 						  \
  else  					  \
    { 						  \
      printf("\tLOAD %%%i\n", (E)->pos + n_push); \
    }

/* Comme au dessus pour une expression non constante. */
#define CHRG_EXPR_NON_CST(E)                      \
  if ((E)->glob)	     			  \
    { 						  \
      printf("\tLOAD #%s\n", (E)->nom); 	  \
    } 						  \
  else 					          \
    { 						  \
      printf("\tLOAD %%%i\n", (E)->pos + n_push); \
    }


#define OP_EXPR(OP, E)                              \
  if ((E)->cst)                                     \
    {                                               \
      printf("\t%s #%i\n", OP, (E)->pos);           \
    }                                               \
  else if ((E)->glob)                               \
    {                                               \
      printf("\t%s #%s\n", OP, (E)->nom);           \
    }                                               \
  else                                              \
    {                                               \
      printf("\t%s %%%i\n", OP, (E)->pos + n_push); \
    }

/* Écrit le code pour ajouter une expression à la pile comme argument de 
   fonction en fonction du type d'expression : chaine littérale, constante, 
   variable globale ou locale */
#define PUSH_ARG(E)                                       \
  if ((E)->litt) 					  \
    { 							  \
      printf("\tPUSH #%s\n", (E)->nom); 		  \
    } 							  \
  else if ((E)->cst) 					  \
    { 							  \
      printf("\tPUSH #%i\n", (E)->pos); 		  \
    } 							  \
  else if ((E)->glob) 					  \
    { 							  \
      printf("\tPUSH %s\n", (E)->nom);  		  \
    } 						 	  \
  else 					  		  \
    { 							  \
      printf("\tLOAD %%%i\n\tPUSH\n", (E)->pos + n_push); \
    } 							  \
  libere(E);

/* Permet de créer une nouvelle expression temporaire et d'écrire le code qui
   stocke le résultat d'une expression dans cette nouvelle expression. 
   Cette nouvelle expression est stockée dans la variable en argument. */
#define STCK_EXPR(E)                               \
  (E) = fairexpr(NULL); 			   \
  if (recycle)  				   \
    { 						   \
      printf("\tSTORE %%%i\n", (E)->pos + n_push); \
    } 						   \
  else  					   \
    { 						   \
      printf("\tPUSH\n");			   \
      ++n_push;  	 			   \
    }

/* Remet la pile dans un état antérieur. */
#define REMET_PILE_ETAT_ANT(E)                  \
  if (n_push - (E))				\
    { 						\
      printf("\tMSP #%i\n", -(n_push - (E)));	\
      incr_n_expr(-(n_push - (E)));		\
      position += n_push - (E);			\
      n_push -= n_push - (E);			\
    }

#endif

