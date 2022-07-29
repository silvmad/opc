/*
IED L3 Informatique
Développement de logiciel libre
Projet final
Victor Matalonga
Numéro étudiant 18905451

fichier : opc.y

Analyseur syntaxique du langage microbe pour l'ordinateur en papier.
*/

%{
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "opc.h"
#include "expr.h"

#define YYDEBUG 1

extern int yylex();

int position;
int incr;
int n_push = 0;

char *globales[256];
int glob_taille[256];
int n_glob = 0;

char *fonction;

 struct { char *ch; int lab; } ch_litt[256];
int n_ch_litt = 0;

int deb_esp_loc[256] = { 0 };
int n_esp_loc = 1;

int if_np, else_np;
int n_ifnp = 0, n_elnp = 0;

%}
			
%union {
    int i;
    char *s;
    expr *e;
    struct { int i; int np; } inp;
}

%token	<s>		NOM CHAINE
%token	<i>		NOMBRE CARAC
%token SI SINON TANTQUE POUR VAR RETOUR ET OU EGAL INEG SUPEG INFEG FONC AFFC AFFV ENTRE

%type	<e>		expr affectation arg
%type	<i>		args
%type	<inp>		si_debut
%nonassoc ')'
%nonassoc SI_SANS_SINON
%nonassoc SINON
%right '='
%left OU
%left ET
%left INEG EGAL
%left '<' '>' SUPEG INFEG
%left '+' '-'
%left '*' '/' '%'
%right FORT
%expect 0
%start prog

%%

prog : decl_ou_fonc_list
;

decl_ou_fonc_list :
	| 	decl_ou_fonc_list decl_ou_fonc
	|	decl_ou_fonc_list error ';'
;

decl_ou_fonc : glob_decl
	|	fonc
;

glob_decl : VAR NOM ';'
            {
		if (glob_existe($2))
		  {
		    yyerror("Une variable globale de ce nom existe déjà");
		    YYERROR;
		  }
		if (n_glob > 255)
		  {
		    yyerror("Nombre maximum de variables globales atteint\n"
			    "le programme ne tiendra pas en mémoire");
		    YYABORT;
		  }
		printf("globl %s\n", $2);
		glob_taille[n_glob] = 1;
		globales[n_glob++] = $2;
	    }
	|	VAR NOM '=' expr ';'
                {
		    if (glob_existe($2))
		      {
		        yyerror("Une variable globale de ce nom existe déjà");
		        YYERROR;
		      }
		    if (n_glob > 255)
		      {
		        yyerror("Nombre maximum de variables globales atteint\n"
			        "le programme ne tiendra pas en mémoire");
		        YYABORT;
		      }
		    if (!$4->cst)
		      {
			  fprintf(stderr, "%i : Erreur : Initialisation d'une variable globale avec une expression non constante.\n", lineno);
			  YYERROR;
		      }
		    printf("globl %s %i\n", $2, $4->pos);
		    globales[n_glob++] = $2; 
		}
	|	VAR NOM '[' NOMBRE ']' ';'
                {   
		    if (glob_existe($2))
		      {
		        yyerror("Une variable globale de ce nom existe déjà");
		        YYERROR;
		      }
		    if (n_glob > 255)
		      {
		        yyerror("Nombre maximum de variables globales atteint\n"
			        "le programme ne tiendra pas en mémoire");
		        YYABORT;
		      }
		      printf("globl %s \"", $2);
                      /* Un tableau global est déclaré comme une chaîne 
                       littérale de zéros par l'assembleur. */ 
                      for (int i = 0; i < $4; ++i)
		      {
		        putchar('\0');
                      }
                      printf("\"\n");
		      glob_taille[n_glob] = $4;
                      globales[n_glob++] = $2; }
/*	|	VAR NOM '[' ']' '=' CHAINE ';'
		{   printf("globl %s \"%s\"", $2, $6);
                    globales[n_glob++] = $2; }*/
;

fonc : FONC NOM 
       {   printf("func %1$s\n%1$s:\n", $2);
           fonction = $2;
           position = 2;
           incr = 1; }
       '(' list_decl_args ')' '{'
       {   position = 0; incr = -1; }
       listinstr '}'
       {
	   printf("fin%s:\n\tMSP #%i\n\tRET\n", $2, -n_push);
	   n_expr = 0;
	   n_push = 0;
       }
;

list_decl_args :
	|	NOM { fairexpr($1); }
	|	list_decl_args ',' NOM { fairexpr($3); }
;

instr : ';'
	|	'{'
                {
		    if (n_esp_loc > 255)
		    {
			yyerror("Erreur : nombre maximum d'espace locaux atteint.");
			YYABORT;
		    }
		    deb_esp_loc[n_esp_loc++] = n_expr;
		}
                listinstr '}'
                {
		    libere_variables_locales(deb_esp_loc[--n_esp_loc]);
		}
	|	expr ';' { libere($1); }
	|       si_debut instr %prec SI_SANS_SINON
                {
		    printf("sinon%i:\n", $1.i);
		    REMET_PILE_ETAT_ANT($1.np)
		}
	|	si_debut
		instr SINON
 	        {
		    $1.np = n_push - $1.np;
		    incr_n_expr(-$1.np);
		    position += $1.np;
		    n_push -= $1.np;
		    printf("\tMSP #%i\n", -$1.np);
		    $<i>$ = n_push;
		    printf("\tJUMP fin%1$i\nsinon%1$i:\n", $1.i);
		}
                instr
                {
		    $<i>4 = n_push - $<i>4;
		    printf("\tMSP #%i\n", -$<i>4);
		    incr_n_expr(-$<i>4);
		    position += $<i>4;
		    n_push += -$<i>4;
                    printf("fin%i:\n", $1.i);
		}
	|	TANTQUE
                { $<i>$ = n_push; }
                '('
		{ $<i>$  = label(); printf("deb%i:\n", $<i>$); }
                expr
		{
		  CHRG_EXPR($5);
		  libere($5);
		  REMET_PILE_ETAT_ANT($<i>2)
		  printf("\tBRZ fin%i\n", $<i>4);
		  $<i>$ = n_push;
		}
                ')' instr
		{
                  REMET_PILE_ETAT_ANT($<i>6)
		  printf("\tJUMP deb%1$i\nfin%1$i:\n", $<i>4);
		}
	|	POUR
		{
		  if (n_esp_loc > 255)
		    {
			yyerror("Erreur : nombre maximum d'espace locaux atteint.");
			YYABORT;
		    }
		    deb_esp_loc[n_esp_loc++] = n_expr;
		    $<i>$ = n_push;
		} 
                '(' pour_init ';'
		{ printf("deb%i:\n", $<i>$ = label()); }
		{ $<i>$ = n_push; }
                expr ';'
		{
		    CHRG_EXPR($8)
		    libere($8);
		    REMET_PILE_ETAT_ANT($<i>7);
		    printf("\tBRZ fin%i\n", $<i>6);
		    printf("\tJUMP corps%i\n", $<i>6); 
		    printf("incr%i:\n", $<i>6);
		    $<i>$ = n_push;
		}
                listexpr ')'
		{
		    REMET_PILE_ETAT_ANT($<i>10);
		    printf("\tJUMP deb%1$i\ncorps%1$i:\n", $<i>6);
		    $<i>$ = n_push; 
		}
                instr
		{
		    REMET_PILE_ETAT_ANT($<i>13);
		    printf("\tJUMP incr%1$i\nfin%1$i:\n", $<i>6);
		    /*int pour_np = n_push - $<i>2;
		    if (pour_np)
		    {
			printf("\tMSP #%i\n", -pour_np);
			incr_n_expr(-pour_np);
			n_push -= pour_np;
			position += pour_np;
		    }*/
		    libere_variables_locales(deb_esp_loc[--n_esp_loc]); 
		}
	|	RETOUR expr ';'
		{
		    if ($2->cst)
		      {
			printf("\tLOAD #%i\n", $2->pos);
		      }
		    else
		      {
		        printf("\tLOAD %%%i\n", $2->pos + n_push);
		      }
		    printf("\tJUMP fin%s\n", fonction);
		    libere($2);
		}
	|	RETOUR ';' { printf("\tJUMP fin%s\n", fonction); }
	|	decl ';'
	|	AFFC '(' expr ')' ';'
		{
		    if ($3->cst)
		    {
			printf("\tOUTC #%i\n", $3->pos);
		    }
		    else if ($3->glob)
		    {
			printf("\tOUTC %s\n", $3->nom);	
		    }
		    else
		    {
			printf("\tOUTC %%%i\n", $3->pos + n_push);	
		    }
		}
	|	AFFV '(' expr ')' ';'
		{
		    if ($3->cst)
		    {
			printf("\tOUT #%i\n", $3->pos);
		    }
		    else if ($3->glob)
		    {
			printf("\tOUT %s\n", $3->nom);	
		    }
		    else
		    {
			printf("\tOUT %%%i\n", $3->pos + n_push);	
		    }
		}
;

listinstr :
	|	listinstr instr
	|	listinstr error ';'
;

si_debut : SI '(' expr ')'
	   {
	       $$.i = label();
	       CHRG_EXPR($3);
	       libere($3);
	       printf("\tBRZ sinon%i\n", $$.i);
	       $$.np = n_push;
	   }
;

pour_init :
	|	decl
	|	affect_list


decl : VAR listenom_ou_init
;

listenom_ou_init : nom_ou_init
	|	listenom_ou_init ',' nom_ou_init
;

nom_ou_init : NOM
                {
		    if (loc_existe($1))
		      {
			yyerror("Erreur : variable déclarée deux fois");
			YYERROR;
		      }
		    fairexpr($1);
		}
	|	NOM '[' NOMBRE ']'
	        {
		    if (loc_existe($1))
		      {
			yyerror("Erreur : variable déclarée deux fois");
			YYERROR;
		      }
		    expr *e = fairexpr($1);
		    e->tab = true;
		    e->taille = $3;
                    for (int i = 1; i < $3; ++i)
		    {
			fairexpr(NULL);
		    }
		    printf("\tMSP #%i\n", $3);
		    n_push += $3;
		}
	|	NOM 
		{
		    if (loc_existe($1))
		      {
			yyerror("Erreur : variable déclarée deux fois");
			YYERROR;
		      }
		}
                '=' expr
                {
		    expr e4;
		    e4.pos = $4->pos;
		    e4.cst = $4->cst;
                    libere($4);
		    fairexpr($1);
		    if (e4.cst && !recycle)
		      {
			printf("\tPUSH #%i\n", e4.pos);
			++n_push;
		      }
		    else if (e4.cst)
		      {
			printf("\tLOAD #%i\n", e4.pos);
			printf("\tSTORE %%%i\n", exprvar($1)->pos + n_push);
		      }
		    else 
		      {
			printf("\tLOAD %%%i\n", e4.pos + n_push);
			if (recycle)
			  {
			    printf("\tSTORE %%%i\n",
				   exprvar($1)->pos + n_push);
			  }
			else
			  {
			    printf("\tPUSH\n");
			    ++n_push;
			  }
		      }			  	 
		}
;

affect_list : affectation { libere($1); }
	|	affect_list ',' affectation { libere($3); }
;

affectation : NOM '=' expr
	      {
		  expr *e1;
		  /*if ((e1 = exprvar($1)))
		    {
		      if ($3->cst)
		        {
		          printf("\tLOAD #%i\n\tSTORE %%%i\n",
			         $3->pos, e1->pos + n_push);
			  $$ = faire_cst_expr($3->pos);
		        }
		      else
		        {
		          printf("\tLOAD %%%i\n", $3->pos + n_push);
		          printf("\tSTORE %%%i\n", e1->pos + n_push);
		          $$ = $3;
		        }
		    }
		  else if (glob_existe($1))
		    {
		      if ($3->cst)
		        {
		          printf("\tLOAD #%i\n\tSTORE %s\n",
			         $3->pos, $1);
			  $$ = faire_cst_expr($3->pos);
		        }
		      else		        {
		          printf("\tLOAD %%%i\n", $3->pos + n_push);
		          printf("\tSTORE %s\n", $1);
		          $$ = $3;
			}
		    }*/
		  $$ = $3;
		  CHRG_EXPR($3)
		  int i;
		  if ((e1 = exprvar($1)))
		  {
		      if (e1->tab)
		      {
			  yyerror("Impossible d'affecter une valeur à un "
				  "tableau comme cela. Utilisez les "
				  "crochets.");
			  YYERROR;
		      }

		      printf("\tSTORE %%%i\n", e1->pos + n_push);
		  }
		  else if ((i = glob_existe($1)))
		  {
		      if (glob_taille[i] != 1)
		      {
			  yyerror("Impossible d'affecter une valeur à un "
				  "tableau comme cela. Utilisez les "
				  "crochets.");
			  YYERROR;
		      }
		      printf("\tSTORE %s\n", $1);
		  }
		  else
		  {
		      yyerror("Variable non déclarée");
		      YYERROR;
		  }
	      }
	|	NOM '[' expr ']' '=' expr
		{
		  expr *e1;
		  $$ = $6;
		  int i;
		  if ((e1 = exprvar($1)))
		  {
		      if (!e1->tab)
		      {
			  yyerror("Impossible d'indexer une variable qui "
				  "n'est pas un tableau");
			  YYERROR;
		      }
		      printf("\tLEA %%%i\n", e1->pos + n_push);
		      OP_EXPR("ADD", $3);// PLUTOT SUB ?
		      libere($3);
		      printf("\tPUSH\n"); 
		      ++n_push;
		  }
		  else if ((i = glob_existe($1)))
		  {
		      if (glob_taille[i] <= 1)
		      {
			  yyerror("Impossible d'indexer une variable qui "
				  "n'est pas un tableau");
			  YYERROR;
		      }
		      printf("\tLOAD #%s\n", $1);
		      OP_EXPR("ADD", $3);// PLUTOT SUB ?
		      libere($3);
		      printf("\tPUSH\n"); 
		      ++n_push;
		  }
		  else
		  {
		      yyerror("Variable non déclarée");
		      YYERROR;
		  }
		  CHRG_EXPR($6);
		  printf("\tSTORE *%%1\n\tMSP #-1\n");
		  --n_push;
		}   
;

expr : NOM
                {
		    expr *e = exprvar($1);
		    if (!e)
		      {
			if (glob_existe($1))
			  {
			    e = calloc(sizeof(expr), 1);
			    e->nom = $1;
			    e->glob = true;
			  }
			else
			  {
			    yyerror("Variable indéfinie");
			    YYERROR;
			  }
		      }
		    $$ = e;
		}
	|	'(' expr ')' { $$ = $2; }
	|	NOMBRE
                {
		    $$ = calloc(sizeof(expr), 1);
		    $$->cst = true;
		    $$->pos = $1;
		}
	|	CARAC
                {
		    if ((!strchr(ASCII_PRINTABLE, $1)) &&
			$1 != '\n' &&
			$1 != '\t')
		    {
			yyerror("Caractère ne faisant pas partie des caractères ascii imprimables");
			YYERROR;
		    }
		    $$ = calloc(sizeof(expr), 1);
		    $$->cst = true;
		    $$->pos = $1;
		}
	|       affectation
	|	NOM '(' args ')'
		{
		    printf("\tCALL %s\n", $1);
		    if ($3 > 0)
		      {
			printf("\tMSP #%i\n", -$3);
			n_push -= $3;
		      }
                    $$ = fairexpr(NULL);
		    if (recycle)
		      {
			printf("\tSTORE %%%i\n", $$->pos + n_push);
		      }
		    else
		      {
			printf("\tPUSH\n");
			++n_push;
		      }
		}
	|	NOM '[' expr ']'
		{
		  expr *e1;
		  int i;
		  if ((e1 = exprvar($1)))
		  {
		      if (!e1->tab)
		      {
			  yyerror("Impossible d'indexer une variable qui "
				  "n'est pas un tableau");
			  YYERROR;
		      }
		      printf("\tLEA %%%i\n", e1->pos + n_push);
		      OP_EXPR("ADD", $3);// PLUTOT SUB ?
		      libere($3);
		      printf("\tPUSH\n"); 
		      ++n_push;
		  }
		  else if ((i = glob_existe($1)))
		  {
		      if (glob_taille[i] <= 1)
		      {
			  yyerror("Impossible d'indexer une variable qui "
				  "n'est pas un tableau");
			  YYERROR;
		      }
		      printf("\tLOAD #%s\n", $1);
		      OP_EXPR("ADD", $3);
		      libere($3);
		      printf("\tPUSH\n"); 
		      ++n_push;
		  }
		  else
		  {
		      yyerror("Variable non déclarée");
		      YYERROR;
		  }
		  printf("\tLOAD *%%1\n\tMSP #-1\n");
		  --n_push;
		  STCK_EXPR($$);
		}   
		    /*if ($3->cst)
		      {
			int n = $3->pos;
			libere($3);
			$$ = fairexpr(NULL);
			printf("\tPUSH #%i\n\tLOAD *%%1\n",
			       exprvar($1)->pos + n_push + 256);
			if (recycle)
		        {
			    printf("\tSTORE %%%i\nPOP #1\n",
				   $$->pos + n_push);
			}
			else
		        {
			    printf("\tSTORE %%1\n");
			    ++n_push;
			}
		      }
		    else
		      {
                        int p3 = $3->pos + n_push;
			libere($3);
			$$ = fairexpr(NULL);
			printf("\tLOAD #%s\n\tADD %%%i\n\tPUSH\n\tLOAD *%%1\n", $1, p3);
			
			printf("\tPUSH\n\tLOAD *%%1\n\tSTORE %%%i\n");
			++n_push;
		    libere($3);*/
		
	|	'-' expr %prec FORT
		{
		    if ($2->cst)
		      {
			printf("\tLOAD #%i", -$2->pos);
		      }
		    else
		      {
			printf("\tLOAD #0\n\tSUB %%%i\n", $2->pos + n_push);
		      }
		    libere($2);
                    $$ = fairexpr(NULL);
                    if (recycle)
		      {
			printf("\tSTORE %%%i\n", $$->pos + n_push);
		      }
		    else
		      {
			 printf("\tPUSH\n");
			 n_push++;
		      }
		}
	|	expr '+' expr
		{
		    $$ = op_add_sub("ADD", $1, $3);
                }   
	|	expr '-' expr
                {
                    $$ = op_add_sub("SUB", $1, $3);
                }   
	|	expr '*' expr
		{
                    $$ = op_mult_div_mod("mult", $1, $3);
		}
	|	expr '/' expr
		{
                    $$ = op_mult_div_mod("div", $1, $3);
		}
	|	expr '%' expr
		{
                    $$ = op_mult_div_mod("mod", $1, $3);
		}
	|	expr ET expr
		{
		    if (($1->cst && $1->pos == 0) ||
			($3->cst && $3->pos == 0))
		    {
			$$ = faire_cst_expr(0);
			printf("\tLOAD #0\n");

		    }
		    else if ($1->cst && $3->cst)
		    {
			$$ = faire_cst_expr(1);
			printf("\tLOAD #1\n");
		    }
		    else if ($1->cst)
		    {
			CHRG_EXPR_NON_CST($3);
			libere($3);
			STCK_EXPR($$)
		    }
		    else if ($3->cst)
		    {
			CHRG_EXPR_NON_CST($1);
			libere($1);
			STCK_EXPR($$)
		    }
		    else
		    {
			CHRG_EXPR_NON_CST($1);
			libere($1);
			int lab = label();
			printf("\tBRZ sinon%i\n", lab);
			CHRG_EXPR_NON_CST($3)
			libere($3);
			printf("\tBRZ sinon%i\n", lab);
			printf("\tLOAD #1\n\tJUMP end%i\n", lab);
			printf("sinon%1$i:\n\tLOAD #0\nend%1$i:\n", lab);
			STCK_EXPR($$)
		    }
		}
	|	expr OU expr
		{
		    if (($1->cst && $1->pos != 0) ||
			($3->cst && $3->pos != 0))
		    {
			$$ = faire_cst_expr(1);
			printf("\tLOAD #1\n");
		    }
		    else if ($1->cst && $3->cst)
		    {
			$$ = faire_cst_expr(0);
			printf("\tLOAD #0\n");
		    }
		    else if ($1->cst)
		    {
			CHRG_EXPR_NON_CST($1)
			libere($1);
			STCK_EXPR($$)
		    }
		    else if ($3->cst)
		    {
			CHRG_EXPR_NON_CST($3)
			libere($3);
			STCK_EXPR($$)
		    }
		    else
		    {
			CHRG_EXPR_NON_CST($1)
			libere($1);
			int lab = label();
			printf("\tBRZ sinon%1$i_1\n\tJUMP end%1$i\n"
			       "sinon%1$i_1:\n", lab);
			CHRG_EXPR_NON_CST($3)
			libere($3);
			printf("\tBRZ sinon%1$i_2\n\tJUMP end%1$i\n"
			       "sinon%1$i_2:\n", lab);
			printf("\tLOAD #0\n\tJUMP end%i\n", lab);
			printf("sinon%1$i:\n\tLOAD #1\nend%1$i:\n", lab);
			STCK_EXPR($$)
		    }
		}
	|	'!' expr %prec FORT
                {
		    if ($2->cst)
		    {
			$2->pos = $2->pos == 0 ? 1 : 0;
			$$ = $2;
		    }
		    else
		    {
			CHRG_EXPR_NON_CST($2)
			libere($2);
		    }
		    int lab = label();
		    printf("\tBRZ sinon%i\n\tLOAD #0\n", lab);
		    printf("\tJUMP end%1$i\nsinon%1$i:\nLOAD #1\nend%1$i:\n",
			   lab);
		    STCK_EXPR($$)
		}
	|	expr EGAL expr
	        {
		    CHRG_EXPR($1);
		    libere($1);
		    OP_EXPR("SUB", $3);
		    libere($3);
		    int lab = label();
		    printf("\tBRZ sinon%1$i\n\tLOAD #0\n\tJUMP end%1$i\n", lab);
		    printf("sinon%1$i:\n\tLOAD #1\nend%1$i:\n", lab);
		    STCK_EXPR($$)
		}
	|	expr INEG expr
		{
		    CHRG_EXPR($1);
		    libere($1);
		    OP_EXPR("SUB", $3);
		    libere($3);
		    STCK_EXPR($$);
		}
	|	expr '>' expr
		{
		    CHRG_EXPR($1);
		    libere($1);
		    OP_EXPR("SUB", $3);
		    libere($3);
		    int lab = label();
		    printf("\tBRN sinon%1$i\n\tBRZ sinon%1$i\n\tLOAD #1\n"
			   "\tJUMP end%1$i\n", lab);
		    printf("sinon%1$i:\n\tLOAD #0\nend%1$i:\n", lab);
		    STCK_EXPR($$)
		}
	|	expr '<' expr
		{
		    CHRG_EXPR($1);
		    libere($1);
		    OP_EXPR("SUB", $3);
		    libere($3);
		    int lab = label();
		    printf("\tBRN sinon%1$i\n\tLOAD #0\n\tJUMP end%1$i\n",
			   lab);
		    printf("sinon%1$i:\n\tLOAD #1\nend%1$i:\n", lab);
		    STCK_EXPR($$)
		}
	|	expr SUPEG expr
		{
		    CHRG_EXPR($1);
		    libere($1);
		    OP_EXPR("SUB", $3);
		    libere($3);
		    int lab = label();
		    printf("\tBRN sinon%1$i\n\tLOAD #1\n\tJUMP end%1$i\n", lab);
		    printf("sinon%1$i:\n\tLOAD #0\nend%1$i:\n", lab);
		    STCK_EXPR($$);
		}
	|	expr INFEG expr
		{
		    CHRG_EXPR($1);
		    libere($1);
		    OP_EXPR("SUB", $3);
		    libere($3);
		    int lab = label();
		    printf("\tBRN sinon%1$i\n\tBRZ sinon%1$i\n\tLOAD #0\n"
			   "\tJUMP end%1$i\n", lab);
		    printf("sinon%1$i:\n\tLOAD #1\nend%1$i:\n", lab);
		    STCK_EXPR($$);
		}
	|	ENTRE '(' ')'
		{
		    $$ = fairexpr(NULL);
		    if (!recycle)
		    {
			printf("\tPUSH\n");
			++n_push;
		    }
		    printf("\tIN %%%i\n", $$->pos + n_push);
		}
;

listexpr : expr { libere($1); }
	|       expr ',' listexpr { libere($1); }
;

args : { $$ = 0; }
	|	arg
                  {
		    $$ = 1;
		    PUSH_ARG($1)
		    ++n_push;
		  }
	|       arg ',' args
                  {
		    $$ = $3 + 1;
		    PUSH_ARG($1)
		    ++n_push;
		  }
;

arg : expr { $$ = $1; }
	|	CHAINE
	        {
		    char *nom_ch = malloc(sizeof(char)*6);
		    int lab;
		    if ((lab = ch_litt_lab($1)) < 0)
		      {
			if (n_ch_litt > 255)
			  {
			    yyerror("Nombre maximal de chaînes littérales "
				    "différentes atteint.\n Le programme ne "
				    "tiendra pas en mémoire");
			    YYABORT;
			  }
			ch_litt[n_ch_litt].ch = $1;
			ch_litt[n_ch_litt].lab = n_ch_litt;
		        printf("globl ch%i \"%s\"\n", n_ch_litt, $1);
			sprintf(nom_ch, "ch%i", n_ch_litt++);
			globales[n_glob++] = nom_ch;
		      }
		    else
		      {
			sprintf(nom_ch, "ch%i", lab);
		      }
                    expr *e = calloc(sizeof(expr), 1);
                    e->nom = nom_ch;
                    e->litt = true;
                    $$ = e;
		}
                    
;

%%

/* Fonction qui permet d'afficher des information sur une erreur syntaxique
   ou sémantique. */
void yyerror(char *msg)
{
    fprintf(stderr, "%i: %s : %s\n", lineno, msg, yytext);
}

expr* op_add_sub(char *op, expr *e1, expr *e2)
{
  expr *e;
  if (e1->cst && e2->cst)
    {
      if (!strcmp(op, "ADD"))
	{
	  e = faire_cst_expr(e1->pos + e2->pos);
	}
      else
	{
	  e = faire_cst_expr(e1->pos - e2->pos);
	}
      free(e1);
      free(e2);
    }
  else
    {
      CHRG_EXPR(e1);
      libere(e1);
      OP_EXPR(op, e2);
      libere(e2);
      STCK_EXPR(e);
    }
  return e;
}

expr* op_mult_div_mod(char *op, expr *e1, expr *e2)
{
  expr *e;
  if (e1->cst && e2->cst)
    {
      if (!strcmp(op, "mult"))
	{
	  e = faire_cst_expr(e1->pos * e2->pos);
	}
      else if (!strcmp(op, "div"))
	{
	  e = faire_cst_expr(e1->pos / e2->pos);
	}
      else
	{
	  e = faire_cst_expr(e1->pos % e2->pos);
	}
    }
  else
    {
	/*e = fairexpr(NULL);
      if (c1)
	{
	  printf("\tLOAD #%i\n", a1);
	}
      else
	{
	  printf("\tLOAD %%%i\n", a1 + n_push);
	  }*/
      CHRG_EXPR(e1);
      libere(e1);
      printf("\tPUSH\n");
      ++n_push;
      /*if (c2)
	{
	  printf("\tLOAD #%i\n", a2);
	}
      else
	{ // +1 pour le push précédent.
	  printf("\tLOAD %%%i\n", a2 + n_push + 1);
	  
	  }*/
      CHRG_EXPR(e2);
      libere(e2);
      printf("\tPUSH\n\tCALL %s\n\tMSP #-2\n", op);//Le MSP #-2 annule les push.
      --n_push;
      /*if (recycle)
	{
	  printf("\tSTORE %%%i\n", e->pos + n_push);
	}
      else
	{
	  printf("\tPUSH\n");
	  n_push++;
	  }*/
      STCK_EXPR(e);
    }
  return e;
}

/* Renvoie un nouveau numéro de label. Ce numéro est incrémenté à chaque 
   appel. */
 int label()
 {
   static int lab = 0;
   return lab++;
 }


/* Détermine si une variable globale existe déjà.
   nom : le nom de la variable
   Retour : l'index de la variable dans le tableau des globales si une 
   variable globale de ce nom existe et -1 sinon. */
int glob_existe(char *nom)
{
  for (int i = 0; i < n_glob; ++i)
    {
      if(!strcmp(globales[i], nom))
	{
	  return i;
	}
    }
  return -1;
}

/* Renvoie le label d'une chaîne littérale, ou -1 si cette chaîne n'existe
   pas encore */
int ch_litt_lab(char *ch)
{
  for (int i = 0; i < n_ch_litt; ++i)
    {
      if (!strcmp(ch_litt[i].ch, ch))
	{
	  return ch_litt[i].lab;
	}
    }
  return -1;
}
