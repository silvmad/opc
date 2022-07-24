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
int n_glob;

char *fonction;

 struct { char *ch; int lab; } ch_litt[256];
int n_ch_litt;

int deb_esp_loc[256] = { 0 };
int n_esp_loc = 1;
/*struct { int cond1_np; int cond2_np; } cond_mem[256];
int cond_mem_count = -1;
#define COND_MEM cond_mem[cond_mem_count]
#define COND1_NP COND_MEM.cond1_np
#define COND2_NP COND_MEM.cond2_np*/

int if_np, else_np;
int n_ifnp = 0, n_elnp = 0;

%}
			
%union {
    int i;
    char *s;
    expr *e;
    struct { int i; int np; } inp;
}

%token	<s>		NOM
%token	<i>		NOMBRE
%token	<s>		CHAINE
%token SI SINON TANTQUE POUR VAR RETOUR ET OU EGAL INEG SUPEG INFEG FONC

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
                      putchar('"');
                      globales[n_glob++] = $2; }
	|	VAR NOM '[' ']' '=' CHAINE ';'
		{   printf("globl %s \"%s\"", $2, $6);
                    globales[n_glob++] = $2; }
;

fonc : FONC NOM 
       {   printf("func %1$s\n%1$s:\n", $2);
           fonction = $2;
           position = 1;
           incr = 1; }
       '(' list_decl_args ')' '{'
       {   position = 0; incr = -1; }
       listinstr '}'
       {   printf("fin%s:\n\tRET\n", $2); n_expr = 0; n_push = 0; }
;

list_decl_args :
	|	NOM { fairexpr($1); }
	|	list_decl_args ',' NOM { fairexpr($3); }
;

instr : ';'
	|	'{'
                {
		    deb_esp_loc[n_esp_loc++] = n_expr;/*$<i>$ = n_expr;*/
		}
                listinstr '}'
                {
		    /*libere_variables_locales($<i>2);*/
		    libere_variables_locales(deb_esp_loc[--n_esp_loc]);
		}
	|	expr ';' { libere($1); }
	|       si_debut instr %prec SI_SANS_SINON
                {
		    printf("sinon%i:\n", $1.i); 
		    $1.np = n_push - $1.np;
		    incr_n_expr(-$1.np);
		    position += $1.np;
		    n_push -= $1.np;
		}
	|	si_debut
		instr SINON
 	        {
		    /* Calcul du nombre de push de la première condition et 
		       remise en état des variables des expressions  pour la 
		       seconde condition. */
		    /*COND1_NP = n_push - COND1_NP;
		    incr_n_expr(-COND1_NP);
		    position += COND1_NP;
		    n_push -= COND1_NP;
		    COND2_NP = n_push;*/
		    $1.np = n_push - $1.np;
		    incr_n_expr(-$1.np);
		    position += $1.np;
		    n_push -= $1.np;
		    printf("\tMSP #%i\n", -$1.np);
		    printf("\tJUMP eq%1$i\nsinon%1$i:\n", $1.i);
		}
                instr
                {
		    //COND2_NP = n_push - COND2_NP;
		    $<inp>4.np = n_push - $<inp>4.np;
		    int diff = $1.np - $<inp>4.np;
		    //if (diff > 0)
		      //{
			printf("\tMSP #%i\n", diff);
		      //}
		    printf("JUMP fin%i\n", $1.i);
		    //printf("eq%i:\n", $1);
		    //if (diff < 0)
		      //{
			//printf("\tMSP #%i\n", diff);
		      //}
		    incr_n_expr(diff);
		    position += diff;
		    n_push += diff;
                    printf("fin%i:\n", $1.i);
		    /* Si on a plusieurs conditions imbriquées, on 
		       transfère le nombre de push à la condition du 
		       dessus. INUTILE */ 
                    /*if (cond_mem_count > 0)
		      {
			if (SUB_COND_MEM.cond2_np == -1)
			  {
                            SUB_COND_MEM.cond1_np +=
				diff > 0 ? COND1_NP : COND2_NP;
			  }
			else
			  {
			    SUB_COND_MEM.cond2_np += 
				diff > 0 ? COND1_NP : COND2_NP;
			  }
		      }*/
		    //--cond_mem_count;
		}
	|	TANTQUE
                { $<i>$ = n_push; }
                '('
		{ $<i>$  = label(); printf("deb%i:\n", $<i>$); }
                expr
		{
		    printf("\tLOAD %%%i\n\tBRZ fin%i\n",
			 $5->pos + n_push,
			 $<i>4);
		    libere($5);
		}
                ')' instr
		{
		  int tq_np = n_push - $<i>2;
		  if (tq_np)
		  {
		      printf("\tMSP #%i\n", -tq_np);
		      incr_n_expr(-tq_np);
		      n_push -= tq_np;
		      position += tq_np;
		      printf("\tJUMP deb%1$i\nfin%1$i:", $<i>4);
		  }
		}
	|	POUR
		{ $<i>$ = n_push; } 
                '(' pour_init ';'
		{ printf("deb%i:\n", $<i>$ = label()); }
                expr ';'
		{
		    printf("\tLOAD %%%i\n\tBRZ fin%i\n",
			   $7->pos + n_push,
			   $<i>6);
		    libere($7);
		    printf("\tJUMP corps%i\n", $<i>6); 
		    printf("incr%i:\n", $<i>6);
		    $<i>$ = n_push;
		}
                listexpr ')'
		{
		    int incr_np = n_push - $<i>9 ;
                    if (incr_np)
		    {
			printf("\tMSP #%i\n", -incr_np);
			incr_n_expr(-incr_np);
			n_push -= incr_np;
			position += incr_np; 
		    }
		    printf("\tJUMP deb%1$i\ncorps%1$i:\n", $<i>6);
		    $<i>$ = n_push; 
		}
                instr
		{
		    int corps_np = n_push - $<i>12;
		    if (corps_np)
		    {
			printf("\tMSP #%i\n", -corps_np);
			incr_n_expr(-corps_np);
			n_push -= corps_np;
			position += corps_np;
		    }
		    printf("\tJUMP incr%1$i\nfin%1$i:", $<i>6);
		    int pour_np = n_push - $<i>2;
		    if (pour_np)
		    {
			printf("\tMSP #%i\n", -pour_np);
			incr_n_expr(-pour_np);
			n_push -= pour_np;
			position += pour_np;
		    }
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
	|	decl ';'
;

listinstr :
	|	listinstr instr
	|	listinstr error ';'
;

si_debut : SI '(' expr ')'
	   {
	       $$.i = label();
	       printf("\tLOAD %%%i\n\tBRZ sinon%i\n", $3->pos + n_push, $<i>$);
	       libere($3);
	       $$.np = n_push;
	       //++cond_mem_count;
               //COND1_NP = n_push;
	       /* Permet de signaler qu'on est dans la première condition au 
                  cas ou on entre dans une autre condition avant la fin de
		  celle-ci */
	       //COND2_NP = -1;
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
		  if ((e1 = exprvar($1)))
		    {
		      if ($3->cst)
		        {
		          printf("\tLOAD #%i\n\tSTORE %%%i\n",
			         $3->pos, e1->pos + n_push);
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
			         $3->pos, e1->nom);
		        }
		      else
		        {
		          printf("\tLOAD %%%i\n", $3->pos + n_push);
		          printf("\tSTORE %s\n", e1->nom);
		          $$ = $3;
			}
		    }
		  else
		    {
		      yyerror("Variable non déclarée");
		      YYERROR;
		    }
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
		    $$ = calloc(sizeof(expr), 1);//fairexpr(NULL);
		    $$->cst = true;
		    $$->pos = $1;/*
		    if (recycle)
		      {
			printf("\tLOAD #%i\n", $1);
			printf("\tSTORE %%%i\n", $$->pos + n_push);
		      }
		    else
		      {
			printf("\tPUSH #%i\n", $1);
			++n_push;
		      }*/
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
/*	|	NOM '[' expr ']'
		{
		    if ($3->cst)
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
		    libere($3);
		}*/
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
		    int p1 = $1->pos, p3 = $3->pos;
		    bool c1 = $1->cst, c3 = $3->cst;
		    libere($1);
		    libere($3);
		    $$ = op_add_sub("ADD", p1, c1, p3, c3);
                }   
	|	expr '-' expr
                {
		    int p1 = $1->pos, p3 = $3->pos;
		    bool c1 = $1->cst, c3 = $3->cst;
		    libere($1);
		    libere($3);
                    $$ = op_add_sub("SUB", p1, c1, p3, c3);
                }   
	|	expr '*' expr
		{
		    int p1 = $1->pos, p3 = $3->pos;
		    bool c1 = $1->cst, c3 = $3->cst;
		    libere($1);
		    libere($3);
                    $$ = op_mult_div_mod("mult", p1, c1, p3, c3);
		}
	|	expr '/' expr
		{
		    int p1 = $1->pos, p3 = $3->pos;
		    bool c1 = $1->cst, c3 = $3->cst;
		    libere($1);
		    libere($3);
                    $$ = op_mult_div_mod("div", p1, c1, p3, c3);
		}
	|	expr '%' expr
		{
		    int p1 = $1->pos, p3 = $3->pos;
		    bool c1 = $1->cst, c3 = $3->cst;
		    libere($1);
		    libere($3);
                    $$ = op_mult_div_mod("mod", p1, c1, p3, c3);
		}
	|	expr ET expr
		{
		    if (($1->cst && $1->pos == 0) ||
			($3->cst && $3->pos == 0))
		    {
			printf("\tLOAD #0\n");
		    }
		    else if ($1->cst && $3->cst)
		    {
			printf("\tLOAD #1\n");
		    }
		    else if ($1->cst)
		    {
			if ($3->glob)
			{
			    printf("\tLOAD %s\n", $3->nom);
			}
			else 
			{
			    printf("\tLOAD %%%i\n", $3->pos + n_push);
			}
		    }
		    else if ($3->cst)
		    {
			if ($1->glob)
			{
			    printf("\tLOAD %s\n", $1->nom);
			}
			else 
			{
			    printf("\tLOAD %%%i\n", $1->pos + n_push);
			}
		    }
		    else
		    {
			if ($1->glob)
			{
			    printf("\tLOAD %s\n", $1->nom);
			}
			else 
			{
			    printf("\tLOAD %%%i\n", $1->pos + n_push);
			}
			int lab = label();
			printf("\tBRZ else%i\n", lab);
			if ($3->glob)
			{
			    printf("\tLOAD %s\n", $3->nom);
			}
			else 
			{
			    printf("\tLOAD %%%i\n", $3->pos + n_push);
			}
			printf("\tBRZ else%i\n", lab);
			printf("\tLOAD #1\n\tJUMP end%i\n", lab);
			printf("else%1$i\n\tLOAD #0\nend%1$i\n", lab);
			libere($1);
			libere($3);
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
		}
	|	expr OU expr
		{
		    if (($1->cst && $1->pos != 0) ||
			($3->cst && $3->pos != 0))
		    {
			printf("\tLOAD #1\n");
		    }
		    else if ($1->cst && $3->cst)
		    {
			printf("\tLOAD #0\n");
		    }
		    else if ($1->cst)
		    {
			if ($3->glob)
			{
			    printf("\tLOAD %s\n", $3->nom);
			}
			else 
			{
			    printf("\tLOAD %%%i\n", $3->pos + n_push);
			}
		    }
		    else if ($3->cst)
		    {
			if ($1->glob)
			{
			    printf("\tLOAD %s\n", $1->nom);
			}
			else 
			{
			    printf("\tLOAD %%%i\n", $1->pos + n_push);
			}
		    }
		    else
		    {
			if ($1->glob)
			{
			    printf("\tLOAD %s\n", $1->nom);
			}
			else 
			{
			    printf("\tLOAD %%%i\n", $1->pos + n_push);
			}
			int lab = label();
			printf("\tBRZ else%1$i-1\n\tJUMP end%1$i\n"
			       "else%1$i-1:\n", lab);
			if ($3->glob)
			{
			    printf("\tLOAD %s\n", $3->nom);
			}
			else 
			{
			    printf("\tLOAD %%%i\n", $3->pos + n_push);
			}
			printf("\tBRZ else%1$i-2\n\tJUMP end%1$i\n"
			       "else%1$i-2:\n", lab);
			printf("\tLOAD #0\n\tJUMP end%i\n", lab);
			printf("else%1$i:\n\tLOAD #1\nend%1$i\n", lab);
			libere($1);
			libere($3);
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
		}
	|	'!' expr %prec FORT
                {
		    if ($2->cst)
		    {
			$2->pos = $2->pos == 0 ? 1 : 0;
			$$ = $2;
		    }
		    else if ($2->glob)
		    {
		        printf("\tLOAD %s\n", $2->nom);
		    }
		    else
		    {
			printf("\tLOAD %%%i\n", $2->pos + n_push);
		    }
		    int lab = label();
		    printf("\tBRZ else%i\n\tLOAD #0\n", lab);
		    printf("\tJUMP end%1$i\nelse%1$i:\nLOAD #1\nend%1$i\n",
			   lab);
		    libere($2);
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
	|	expr EGAL expr
	        {
		    if ($1->cst)
		    {
			printf("\tLOAD #%i\n", $1->pos);
		    }
		    else if ($1->glob)
		    {
			printf("\tLOAD %s\n", $1->nom);
		    }
		    else
		    {
			printf("\tLOAD %%%i\n",$1->pos + n_push);
		    }
		    if ($3->cst)
		    {
			printf("\tSUB #%i\n", $3->pos);
		    }
		    else if ($3->glob)
		    {
			printf("\tSUB %s\n", $3->nom);
		    }
		    else
		    {
			printf("\tSUB %%%i\n", $3->pos + n_push);
		    }
		    int lab = label();
		    printf("\tBRZ else%1$i\n\tLOAD #0\n\tJUMP end%1$i", lab);
		    printf("else%1$i:\n\tLOAD #1\nend%1$i:\n", lab);
		    libere($1);
		    libere($3);
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
	|	expr INEG expr
		{
		    if ($1->cst)
		    {
			printf("\tLOAD #%i\n", $1->pos);
		    }
		    else if ($1->glob)
		    {
			printf("\tLOAD %s\n", $1->nom);
		    }
		    else
		    {
			printf("\tLOAD %%%i\n",$1->pos + n_push);
		    }
		    if ($3->cst)
		    {
			printf("\tSUB #%i\n", $3->pos);
		    }
		    else if ($3->glob)
		    {
			printf("\tSUB %s\n", $3->nom);
		    }
		    else
		    {
			printf("\tSUB %%%i\n", $3->pos + n_push);
		    }
		    libere($1);
		    libere($3);
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
	|	expr '>' expr
		{
		    if ($1->cst)
		    {
			printf("\tLOAD #%i\n", $1->pos);
		    }
		    else if ($1->glob)
		    {
			printf("\tLOAD %s\n", $1->nom);
		    }
		    else
		    {
			printf("\tLOAD %%%i\n",$1->pos + n_push);
		    }
		    if ($3->cst)
		    {
			printf("\tSUB #%i\n", $3->pos);
		    }
		    else if ($3->glob)
		    {
			printf("\tSUB %s\n", $3->nom);
		    }
		    else
		    {
			printf("\tSUB %%%i\n", $3->pos + n_push);
		    }
		    int lab = label();
		    printf("\tBRN else%1$i\n\tBRZ else%1$i\tLOAD #1\n"
			   "\tJUMP end%1$i", lab);
		    printf("else%1$i:\n\tLOAD #0\nend%1$i:\n", lab);
		    libere($1);
		    libere($3);
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
	|	expr '<' expr
		{
		    if ($1->cst)
		    {
			printf("\tLOAD #%i\n", $1->pos);
		    }
		    else if ($1->glob)
		    {
			printf("\tLOAD %s\n", $1->nom);
		    }
		    else
		    {
			printf("\tLOAD %%%i\n",$1->pos + n_push);
		    }
		    if ($3->cst)
		    {
			printf("\tSUB #%i\n", $3->pos);
		    }
		    else if ($3->glob)
		    {
			printf("\tSUB %s\n", $3->nom);
		    }
		    else
		    {
			printf("\tSUB %%%i\n", $3->pos + n_push);
		    }
		    int lab = label();
		    printf("\tBRN else%1$i\n\tLOAD #0\n\tJUMP end%1$i\n",
			   lab);
		    printf("else%1$i:\n\tLOAD #1\nend%1$i:\n", lab);
		    libere($1);
		    libere($3);
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
	|	expr SUPEG expr
		{
		    if ($1->cst)
		    {
			printf("\tLOAD #%i\n", $1->pos);
		    }
		    else if ($1->glob)
		    {
			printf("\tLOAD %s\n", $1->nom);
		    }
		    else
		    {
			printf("\tLOAD %%%i\n",$1->pos + n_push);
		    }
		    if ($3->cst)
		    {
			printf("\tSUB #%i\n", $3->pos);
		    }
		    else if ($3->glob)
		    {
			printf("\tSUB %s\n", $3->nom);
		    }
		    else
		    {
			printf("\tSUB %%%i\n", $3->pos + n_push);
		    }
		    int lab = label();
		    printf("\tBRN else%1$i\n\tLOAD #1\n\tJUMP end%1$i", lab);
		    printf("else%1$i:\n\tLOAD #0\nend%1$i:\n", lab);
		    libere($1);
		    libere($3);
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
	|	expr INFEG expr
		{
		    if ($1->cst)
		    {
			printf("\tLOAD #%i\n", $1->pos);
		    }
		    else if ($1->glob)
		    {
			printf("\tLOAD %s\n", $1->nom);
		    }
		    else
		    {
			printf("\tLOAD %%%i\n",$1->pos + n_push);
		    }
		    if ($3->cst)
		    {
			printf("\tSUB #%i\n", $3->pos);
		    }
		    else if ($3->glob)
		    {
			printf("\tSUB %s\n", $3->nom);
		    }
		    else
		    {
			printf("\tSUB %%%i\n", $3->pos + n_push);
		    }
		    int lab = label();
		    printf("\tBRN else%1$i\n\tBRZ else%1$i\n\tLOAD #1\n"
			   "\tJUMP end%1$i", lab);
		    printf("else%1$i:\n\tLOAD #0\nend%1$i:\n", lab);
		    libere($1);
		    libere($3);
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
;

listexpr : expr { libere($1); }
	|       expr ',' listexpr { libere($1); }
;

args : { $$ = 0; }
	|	arg
                  {
		    $$ = 1;
                    if ($1->litt)
	              {
		        printf("\tPUSH #%s\n", $1->nom);
	                
                      }
                    else if ($1->cst)
  		      {
		        printf("\tPUSH #%i\n", $1->pos);
                      }
                    else if ($1->glob)
  		      {
		        printf("\tPUSH %s\n", $1->nom);
                      }
                    else
  		      {
		        printf("\tLOAD %%%i\n\tPUSH\n", $1->pos + n_push);
                      }
		    ++n_push;
		    libere($1);
		  }
	|       arg ',' args
                  {
		    $$ = $3 + 1;
                    if ($1->litt)
	              {
		        printf("\tPUSH #%s\n", $1->nom);
                      }
                    else if ($1->cst)
  		      {
		        printf("\tPUSH #%i\n", $1->pos);
                      }
                    else if ($1->glob)
  		      {
		        printf("\tPUSH %s\n", $1->nom);
                      }
                    else
  		      {
		        printf("\tLOAD %%%i\n\tPUSH\n", $1->pos + n_push);
                      }
		    ++n_push;
		    libere($1);
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

expr* op_add_sub(char *op, int a1, bool c1, int a2,  bool c2)
{
  expr *e;
  if (c1 && c2)
    {
      e = calloc(sizeof(expr), 1);
      if (!strcmp(op, "ADD"))
	{
	  e->pos = a1 + a2;
	}
      else
	{
	  e->pos = a1 - a2;
	}
      e->cst = true;
    }
  else
    {
      e = fairexpr(NULL);
      if (c1)
	{
	  printf("\tLOAD #%i\n", a1);
	}
      else
	{
	  printf("\tLOAD %%%i\n", a1 + n_push);
	}
      if (c2)
	{
	  printf("\t%s #%i\n", op, a2);
	}
      else
	{
	    printf("\t%s %%%i\n", op, a2 + n_push);
	}
      if (recycle)
	{
	  printf("\tSTORE %%%i\n", e->pos + n_push);
	}
      else
	{
	  printf("\tPUSH\n");
	  n_push++;
	}
    }
  return e;
}

expr* op_mult_div_mod(char *op, int a1, bool c1, int a2, bool c2)
{
  expr *e;
  if (c1 && c2)
    {
      e = calloc(sizeof(expr), 1);
      if (!strcmp(op, "mult"))
	{
	  e->pos = a1 * a2;
	}
      else if (!strcmp(op, "div"))
	{
	  e->pos = a1 / a2;
	}
      else
	{
	  e->pos = a1 % a2;
	}
      e->cst = true;
    }
  else
    {
      e = fairexpr(NULL);
      if (c1)
	{
	  printf("\tLOAD #%i\n", a1);
	}
      else
	{
	  printf("\tLOAD %%%i\n", a1 + n_push);
	}
      printf("\tPUSH\n");
      if (c2)
	{
	  printf("\tLOAD #%i\n", a2);
	}
      else
	{ // +1 pour le push précédent.
	  printf("\tLOAD %%%i\n", a2 + n_push + 1);
	  
	}
      printf("\tPUSH\n\tCALL %s\n\tPOP #2\n", op);//Le POP #2 annule les push.
      if (recycle)
	{
	  printf("\tSTORE %%%i\n", e->pos + n_push);
	}
      else
	{
	  printf("\tPUSH\n");
	  n_push++;
	}
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
   Retour : true si une variable globale de ce nom existe et false sinon. */
bool glob_existe(char *nom)
{
  for (int i = 0; i < n_glob; ++i)
    {
      if(!strcmp(globales[i], nom))
	{
	  return true;
	}
    }
  return false;
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
