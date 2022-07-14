/*
IED L3 Informatique
Interprétation et compilation
Projet final
Victor Matalonga
Numéro étudiant 18905451

fichier : pasm.y

Analyseur syntaxique de l'assembleur pour l'ordinateur en papier.
*/

%{

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "pasm.tab.h"
#include "pasm.h"

void yyerror(char*);
extern int yylex();
int get_var_addr(char*);
int get_lab_addr(char*);
int label_exists(int);
int func_exists(char*);

/* Structure qui lie un nom et une adresse, peut être utilisée pour 
 * représenter un label ou une variable. */
typedef struct {
    int addr;
    char *name;
    int lineno; // La ligne où le nom apparaît dans le fichier source.
} id;

// Variables globales de l'analyseur lexical.
extern int lineno;
extern char *yytext;

// Variables globales de l'analyseur syntaxique.
unsigned char mem[256];
int mem_pos = 0;

id variables[256];
int n_var = 0;
id pending_vars[256];
int n_pvar = 0;

//int stack_count = 0;

id labels[256];
int labels_size = 256;
int n_lab = 0;
id pending_labels[256];
int n_plab = 0;

char *functions[256];
int n_func = 0;
int in_func = 0;

int error_count = 0;

%}
			
%union
{
    int i;
    char *s;
};

%token	<i> NUM
%token  <s> IDENTIFIER
			
%token GLOBL FUNC ADD SUB NAND MUL DIV MOD LOAD STORE IN OUT POP PUSH JUMP BRN BRZ CALL RET

%type	<i> number
%type	<i> address

%expect 0
%start prog
			
%%

prog : instr_or_decl_list
;

instr_or_decl_list :
	|	instr_or_decl_list instr_or_decl
                { 
                  if (mem_pos + n_var > 255)
		    {
                      fprintf(stderr, "Erreur critique : le programme est "
                              "trop grand pour tenir en mémoire");
                      YYABORT;
                    } }
	|	instr_or_decl_list error '\n' { ++error_count; }
;

instr_or_decl : decl
	|	instr
;

decl    :       GLOBL IDENTIFIER '\n'
                { if (get_var_addr($2) == -1)
	            {
                      variables[n_var].name = $2;
                      variables[n_var++].addr = 0;
                    }
                  else
	            {
                      /* C'est un simple warning, pas une erreur : la 
                       * deuxième déclaration est ignorée. */
			fprintf(stderr, "%i: Warning : variable définie deux"
                                " fois : %s\n", lineno - 1, $2);
                    } }
	|	FUNC IDENTIFIER '\n'
                { if (func_exists($2))
  		    { // La deuxième déclaration est ignorée.
			fprintf(stderr, "%i: Warning : fonction définie deux"
                                " fois : %s\n", lineno - 1, $2);
                    }
                  else
         	    {
                      functions[n_func++] = $2;
                    } }
;

instr :         IDENTIFIER ':'
                { if (func_exists($1))
		    {
                      if (in_func)
		        {
			  fprintf(stderr, "%i: Absence de RET en fin de "
                                  "fonction.\n", lineno - 1);
                          YYERROR;
                        }
                      in_func = 1;
                    }
                  if (label_exists(mem_pos))
		    {
                      fprintf(stderr, "%i: Plusieurs labels au même "
                              "emplacement (%s).\n", lineno, $1);
                      YYERROR;
                    }
                  else if (get_lab_addr($1) == -1)
		    {
                      labels[n_lab].name = $1;
                      labels[n_lab++].addr = mem_pos;
                    }
                  else
		    {
                      fprintf(stderr, "%i: Un label de ce nom existe déjà "
                              "(%s)\n", lineno, $1);
                      YYERROR;
                    } }
                op '\n'
	|	IDENTIFIER ':' '\n'
                { if (func_exists($1))
		    {
                      if (in_func)
		        {
			  fprintf(stderr, "%i: Absence de RET en fin de "
                                  "fonction.\n", lineno - 1);
                          YYERROR;
                        }
                      in_func = 1;
                    }
                  if (label_exists(mem_pos))
		    {
                      fprintf(stderr, "%i: Plusieurs labels au même "
                              "emplacement (%s).\n", lineno, $1);
                      YYERROR;
                    }
                  else if (get_lab_addr($1) == -1)
		    {
                      labels[n_lab].name = $1;
                      labels[n_lab++].addr = mem_pos;
                    }
                  else
		    {
                      fprintf(stderr, "%i: Un label de ce nom existe déjà "
                              "(%s)\n", lineno, $1);
                      YYERROR;
                    } }
	| 	op '\n'
	|	'\n'
;	

op      :       ADD '#' number { mem[mem_pos++] = 0x20;
                                 mem[mem_pos++] = $3; }
	|	ADD address { mem[mem_pos++] = 0x60;
                              mem[mem_pos++] = $2; }
	|	ADD IDENTIFIER
                { 
                  if (get_var_addr($2) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $2;
                      mem[mem_pos] = 0x60;
                      mem_pos += 2;
                    } }
	|	ADD '%' number { mem[mem_pos++] = 0xA0;
                                 mem[mem_pos++] = $3; }
	|	ADD '*' address { mem[mem_pos++] = 0xE0;
                                  mem[mem_pos++] = $3; }
	|	ADD '*' IDENTIFIER
                { if (get_var_addr($3) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $3;
                      mem[mem_pos] = 0xE0;
                      mem_pos += 2;
                    } }
	|	SUB '#' number { mem[mem_pos++] = 0x21;
                                 mem[mem_pos++] = $3; }
	|	SUB address { mem[mem_pos++] = 0x61;
                              mem[mem_pos++] = $2; }
	|	SUB IDENTIFIER
                {
                  if (get_var_addr($2) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $2;
                      mem[mem_pos] = 0x61;
                      mem_pos += 2;
                    } }
	|	SUB '%' number { mem[mem_pos++] = 0xA1;
                                 mem[mem_pos++] = $3; }
	|	SUB '*' address { mem[mem_pos++] = 0xE1;
                                  mem[mem_pos++] = $3; }
	|	SUB '*' IDENTIFIER
                { 
                  if (get_var_addr($3) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $3;
                      mem[mem_pos] = 0xE1;
                      mem_pos += 2;
                    } }
	|	NAND '#' number { mem[mem_pos++] = 0x22;
                                  mem[mem_pos++] = $3; }
	|	NAND address { mem[mem_pos++] = 0x62;
                               mem[mem_pos++] = $2; }
	|	NAND IDENTIFIER
                {
                  if (get_var_addr($2) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $2;
                      mem[mem_pos] = 0x62;
                      mem_pos += 2;
                    } }
	|	NAND '%' number { mem[mem_pos++] = 0xA2;
                                  mem[mem_pos++] = $3; }
	|	NAND '*' address { mem[mem_pos++] = 0xE2;
                                   mem[mem_pos++] = $3; }
	|	NAND '*' IDENTIFIER
                {
                  if (get_var_addr($3) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $3;
                      mem[mem_pos] = 0xE2;
                      mem_pos += 2;
                    } }
/*	|	MUL '#' number { mem[mem_pos++] = 0x23;
                                 mem[mem_pos++] = $3; }
	|	MUL address { mem[mem_pos++] = 0x63;
                              mem[mem_pos++] = $2; }
	|	MUL IDENTIFIER
                {
                  if (get_var_addr($2) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $2;
                      mem[mem_pos] = 0x63;
                      mem_pos += 2;
                    } }
	|	MUL '%' number { mem[mem_pos++] = 0xA3;
                                 mem[mem_pos++] = $3; }
	|	MUL '*' address { mem[mem_pos++] = 0xE3;
                                  mem[mem_pos++] = $3; }
	|	MUL '*' IDENTIFIER
                { 
                  if (get_var_addr($3) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $3;
                      mem[mem_pos] = 0xE3;
                      mem_pos += 2;
                    } }
	|	DIV '#' number { mem[mem_pos++] = 0x24;
                                 mem[mem_pos++] = $3; }
	|	DIV address { mem[mem_pos++] = 0x64;
                              mem[mem_pos++] = $2; }
	|	DIV IDENTIFIER
                {
                  if (get_var_addr($2) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $2;
                      mem[mem_pos] = 0x64;
                      mem_pos += 2;
                    } }
	|	DIV '%' number { mem[mem_pos++] = 0xA4;
                                 mem[mem_pos++] = $3; }
	|	DIV '*' address { mem[mem_pos++] = 0xE4;
                                  mem[mem_pos++] = $3; }
	|	DIV '*' IDENTIFIER
                { 
                  if (get_var_addr($3) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $3;
                      mem[mem_pos] = 0xE4;
                      mem_pos += 2;
                    } }
	|	MOD '#' number { mem[mem_pos++] = 0x25;
                                 mem[mem_pos++] = $3; }
	|	MOD address { mem[mem_pos++] = 0x65;
                              mem[mem_pos++] = $2; }
	|	MOD IDENTIFIER
                {
                  if (get_var_addr($2) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $2;
                      mem[mem_pos] = 0x65;
                      mem_pos += 2;
                    } }
	|	MOD '%' number { mem[mem_pos++] = 0xA5;
                                 mem[mem_pos++] = $3; }
	|	MOD '*' address { mem[mem_pos++] = 0xE5;
                                  mem[mem_pos++] = $3; }
	|	MOD '*' IDENTIFIER
                { 
                  if (get_var_addr($3) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $3;
                      mem[mem_pos] = 0xE5;
                      mem_pos += 2;
                    } }*/
	|	LOAD '#' number { mem[mem_pos++] = 0x0;
                                  mem[mem_pos++] = $3; }
	|	LOAD address { mem[mem_pos++] = 0x40;
                               mem[mem_pos++] = $2; }
	|	LOAD IDENTIFIER
                {
                  if (get_var_addr($2) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $2;
                      mem[mem_pos] = 0x40;
                      mem_pos += 2;
                    } }
	|	LOAD '%' number { mem[mem_pos++] = 0x80;
                                  mem[mem_pos++] = $3; }
	|	LOAD '*' address { mem[mem_pos++] = 0xC0;
                                   mem[mem_pos++] = $3; }
	|	LOAD '*' IDENTIFIER
                {
                  if (get_var_addr($3) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $3;
                      mem[mem_pos] = 0xC0;
                      mem_pos += 2;
                    } }
/*	|	LFS number { mem[mem_pos++] = 0x3;
                             mem[mem_pos++] = $2; }*/
	|	POP { mem[mem_pos++] = 0x4;
                      mem[mem_pos++] = 0; }
                      //--stack_count; }
	|	POP address { mem[mem_pos++] = 0x44;
                              mem[mem_pos++] = $2; }
                              //--stack_count; }
	|	POP IDENTIFIER
                {
                  if (get_var_addr($2) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $2;
                      mem[mem_pos] = 0x44;
                      mem_pos += 2;
                    } }
                  //--stack_count; }
	|	POP '*' address { mem[mem_pos++] = 0xC4;
                                  mem[mem_pos++] = $3; }
                                  //--stack_count; }
	|	POP '*' IDENTIFIER
                {
                  if (get_var_addr($3) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $3;
                      mem[mem_pos] = 0xC4;
                      mem_pos += 2;
                    } }
                  //--stack_count; }
	|	PUSH { mem[mem_pos++] = 0x5;
                       mem[mem_pos++] = 0; }
                       //++stack_count; }
	|	PUSH address { mem[mem_pos++] = 0x45;
                              mem[mem_pos++] = $2; }
                              //++stack_count; }
	|	PUSH IDENTIFIER
                {
                  if (get_var_addr($2) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $2;
                      mem[mem_pos] = 0x45;
                      mem_pos += 2;
                    } }
                  //++stack_count; }
	|	PUSH '*' address { mem[mem_pos++] = 0xC5;
                                   mem[mem_pos++] = $3; }
                                   //++stack_count; }
	|	PUSH '*' IDENTIFIER
                {
                  if (get_var_addr($3) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $3;
                      mem[mem_pos] = 0xC5;
                      mem_pos += 2;
                    } }
                  //++stack_count; }
	|	STORE address { mem[mem_pos++] = 0x48;
                                mem[mem_pos++] = $2; }
	|	STORE IDENTIFIER
                {
                  if (get_var_addr($2) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $2;
                      mem[mem_pos] = 0x48;
                      mem_pos += 2;
                    } }
	|	STORE '%' number { mem[mem_pos++] = 0x88;
                                   mem[mem_pos++] = $3; }
	|	STORE '*' address { mem[mem_pos++] = 0xC8;
                                    mem[mem_pos++] = $3; }
	|	STORE '*' IDENTIFIER
                {
                  if (get_var_addr($3) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $3;
                      mem[mem_pos] = 0xC8;
                      mem_pos += 2;
                    } }
	|	IN address { mem[mem_pos++] = 0x49;
                             mem[mem_pos++] = $2; }
	|	IN IDENTIFIER
                {
                  if (get_var_addr($2) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $2;
                      mem[mem_pos] = 0x49;
                      mem_pos += 2;
                    } }
	|	IN '%' number { mem[mem_pos++] = 0x89;
                                mem[mem_pos++] = $3; }
	|	IN '*' address { mem[mem_pos++] = 0xC9;
                                 mem[mem_pos++] = $3; }
	|	IN '*' IDENTIFIER
                {
                  if (get_var_addr($3) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $3;
                      mem[mem_pos] = 0xC9;
                      mem_pos += 2;
                    }}
	|	OUT address { mem[mem_pos++] = 0x41;
                              mem[mem_pos++] = $2; }
	|	OUT IDENTIFIER
                {
                  if (get_var_addr($2) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $2;
                      mem[mem_pos] = 0x41;
                      mem_pos += 2;
                    } }
	|	OUT '%' number { mem[mem_pos++] = 0x81;
                                  mem[mem_pos++] = $3; }
	|	OUT '*' address { mem[mem_pos++] = 0xC1;
                                  mem[mem_pos++] = $3; }
	|	OUT '*' IDENTIFIER
                {
                  if (get_var_addr($3) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $3;
                      mem[mem_pos] = 0xC1;
                      mem_pos += 2;
                    } }
	|	JUMP IDENTIFIER
                { mem[mem_pos++] = 0x10;
                  int addr = get_lab_addr($2);
                  if (addr == -1)
            	    {
                      pending_labels[n_plab].lineno = lineno;
                      pending_labels[n_plab].addr = mem_pos++;
                      pending_labels[n_plab++].name = $2;
                    }
                  else
		    {
                      mem[mem_pos++] = addr;
                    } }
	|	BRN IDENTIFIER
                { mem[mem_pos++] = 0x11;
                  int addr = get_lab_addr($2);
                  if (addr == -1)
            	    {
                      pending_labels[n_plab].lineno = lineno;
                      pending_labels[n_plab].addr = mem_pos++;
                      pending_labels[n_plab++].name = $2;
                    }
                  else
		    {
                      mem[mem_pos++] = addr;
                    } }
	|	BRZ IDENTIFIER 
                { mem[mem_pos++] = 0x12;
                  int addr = get_lab_addr($2);
                  if (addr == -1)
            	    {
                      pending_labels[n_plab].lineno = lineno;
                      pending_labels[n_plab].addr = mem_pos++;
                      pending_labels[n_plab++].name = $2;
                    }
                  else
		    {
                      mem[mem_pos++] = addr;
                    } }
 	|	CALL IDENTIFIER
                { if (!func_exists($2))
  		    {
                      yyerror("Fonction non déclarée");
                      YYERROR;
                    }
                  if (in_func)
  		    {
                      yyerror("Appel de fonction à l'intérieur d'une "
                              "fonction");
                      YYERROR;
                    }
                 /* if (get_var_addr("%ret") == -1)
		    {
                      variables[n_var].name = "%ret";
                      variables[n_var++].addr = 0;
                    }*/
                  mem[mem_pos] = 0x0; // LOAD
                  mem[mem_pos + 1] = mem_pos + 6;
                  mem_pos += 2;
                  mem[mem_pos++] = 0x5; // PUSH
                  mem[mem_pos++] = 0; // Valeur quelconque.
/*                  pending_vars[n_pvar].addr = mem_pos++;
                  pending_vars[n_pvar++].name = "%ret";*/
                  mem[mem_pos++] = 0x10; // JUMP
                  //++stack_count;
                  int addr = get_lab_addr($2);
                  if (addr == -1)
		    {
                      pending_labels[n_plab].lineno = lineno;
                      pending_labels[n_plab].addr = mem_pos++;
                      pending_labels[n_plab++].name = $2;
                    }
                  else
		    {
                      mem[mem_pos++] = addr;
                    } } 
	|	RET
                { if (!in_func)
  		    {
                      yyerror("RET à l'extérieur d'une fonction");
                      YYERROR;
                    }
/*                  if (get_var_addr("%ret") == -1)
		    {
                      variables[n_var].name = "%ret";
                      variables[n_var++].addr = 0;
                    }*/
                  mem[mem_pos++] = 0x44; // POP
                  mem[mem_pos] = mem_pos + 2;
                  ++mem_pos; 
/*                  pending_vars[n_pvar].addr = mem_pos++;
                  pending_vars[n_pvar++].name = "%ret";
                  mem[mem_pos++] = 0x48; // STORE
                  mem[mem_pos] = mem_pos + 2;
                  ++mem_pos;*/
                  mem[mem_pos++] = 0x10; // JUMP
                  mem[mem_pos++] = 0;
                  in_func = 0;
                  //--stack_count;
                 }
;

number : NUM { if ($1 > 127 || $1 < -128)
		 {
                   yyerror("Nombre de trop grande taille");
                   YYERROR;
                 }
               else
		 {
                   $$ = $1;
                 } }
;

address : NUM { if ($1 < 0 || $1 > 255)
		  {
                    yyerror("Adresse hors de la mémoire");
                    YYERROR;
                  }
                else
		  {
                    $$ = $1;
                  } }
;
%%

/* Fonction qui renvoie l'adresse correspondant à une variable.
   varname : Le nom de la variable. */
int get_var_addr(char *varname)
{
  for (int i = 0; i < n_var; ++i)
    {
	/*if (variables[i].name == NULL)
	{
	  if (varname == NULL)
	    {
	      return variables[i].addr;
	    }
	}
	else*/ if (/*varname != NULL &&*/ !strcmp(varname, variables[i].name))
        {
	  return variables[i].addr;
	}
    }
  return -1;
}

/* Fonction qui renvoie l'adresse correspondant à un label.
   labname : Le nom du label. */
int get_lab_addr(char *labname)
{
  for (int i = 0; i < n_lab; ++i)
    {
      if (!strcmp(labname, labels[i].name))
        {
	  return labels[i].addr;
	}
    }
  return -1;
}

/* Fonction qui renvoie 1 s'il y a déjà un label correspondant à l'adresse
   donnée en argument et 0 sinon. */
int label_exists(int addr)
{
  for (int i = 0; i < n_lab; ++i)
    {
      if (addr == labels[i].addr)
	{
	  return 1;
	}
    }
  return 0;
}

/* Fonction qui renvoie 1 s'il existe une fonction ayant le nom donné en 
   argument et 0 sinon.*/
int func_exists(char *name)
{
  for (int i = 0; i < n_func; ++i)
    {
      if (!strcmp(name, functions[i]))
	{
	  return 1;
	}
    }
  return 0;
}

/* Fonction qui permet d'afficher des information sur une erreur syntaxique
   ou sémantique. */
void yyerror(char *msg)
{
    fprintf(stderr, "%i: %s : %s\n", lineno, msg, yytext);
}

/* Fonction qui permet de compléter les adresses des labels en attente. */
int fill_pending_labels(void)
{
  int ret = 0;
  for (int i = 0; i < n_plab; ++i)
    {
      char *name = pending_labels[i].name;
      int addr = get_lab_addr(name);
      if (addr == -1)
	{
	  int lineno = pending_labels[i].lineno;
	  fprintf(stderr, "%i: Erreur : label indéfini (%s)\n", lineno,
		  name);
	  ret = -1; /* On ne retourne pas immédiatement pour afficher les 
                       éventuels autres labels indéfinis. */
	}
      else
	{
	  int loc = pending_labels[i].addr;
	  mem[loc] = addr;
	}
    }
  return ret;
}

/* Fonction qui permet de compléter les adresses des variables en attente. */
void fill_variables(void)
{
  for (int i = 0; i < n_var; ++i)
    {
      variables[i].addr = mem_pos++;
    }
  for (int i = 0; i < n_pvar; ++i)
    {
      int loc = pending_vars[i].addr;
      char *name = pending_vars[i].name;
      mem[loc] = get_var_addr(name);
    }
}

/* Fonction qui permet d'imprimer le programme. 
   start_addr : l'adresse de départ du programme. 
   mode : le mode d'impression (texte ou binaire). */
void print_prog(int start_addr, int mode)
{
  /* Permet d'ajouter un retour à la ligne tous les 2 octets imprimés 
     même si le programme commence à une adresse impaire. */
  int mod = start_addr % 2 ? 0 : 1;
  for (int i = start_addr; i < mem_pos; ++i)
    {
      if (mode == TEXT)
	{
	  printf("%02hhx ", mem[i]);
	  if (i%2 == mod)
	    {
	      puts("");
	    }
	}
	else if (mode == BIN)
	{
	    fwrite(mem + i, 1, 1, stdout);
	}
    }
  puts("");
}
