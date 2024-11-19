/*
IED L3 Informatique
Développement de logiciel libre
Victor Matalonga
Numéro étudiant 18905451

fichier : pasm.y

Analyseur syntaxique de l'assembleur pour l'ordinateur en papier.
*/

%{

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#include "pasm.tab.h"
#include "pasm.h"

void yyerror(char*);
extern int yylex();
int get_var_addr(char*);
int get_lab_addr(char*);
int label_exists(int);
bool func_exists(char*);
int rom_func_addr(char*);
bool is_rom_func(char*);



// Variables globales de l'analyseur syntaxique.
unsigned int mem[256];
int mem_pos = 0;

var variables[256];
int n_var = 0;
id pending_vars[256];
int n_pvar = 0;

id labels[256];
int labels_size = 256;
int n_lab = 0;
id pending_labels[256];
int n_plab = 0;

char *functions[256];
int n_func = 0;
bool in_func = false;
//char *cur_func;

int error_count = 0;

%}
			
%union
{
    int i;
    char *s;
};

%token	<i> NUM
%token  <s> IDENTIFIER
%token	<s> STRING
			
%token GLOBL FUNC ADD SUB NAND LOAD STORE IN OUT OUTC POP MSP PUSH JUMP BRN BRZ CALL RET LEA

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
			fprintf(stderr, "%i: Warning : variable déclarée "
                                "deux fois : %s\n", lineno - 1, $2);
                    } }
	|	GLOBL IDENTIFIER number '\n'
                { if (get_var_addr($2) == -1)
	            {
                      variables[n_var].name = $2;
                      variables[n_var].val = $3;
                      variables[n_var].val_set = true;
                      variables[n_var++].addr = 0;
                    }
                  else
	            {
                      /* Ce coup ci on déclenche une erreur car la valeur de
                         la variable serait perdue si on ignore la deuxième
                         déclaration. */
		      fprintf(stderr, "%i: Erreur : variable définie deux"
                                " fois : %s\n", lineno - 1, $2);
                      YYERROR;
                    } }
	|	GLOBL IDENTIFIER STRING '\n'
                { char *str = $3;
                  for (int i = 0; i < strlen(str); ++i)
		    {
		      if (!strchr(ASCII_PRINTABLE, str[i]))
		        {
			  fprintf(stderr,
                                 "%i : Erreur, les chaînes de caractères littérales ne peuvent contenir que des caractères imprimables ascii. Le caractère incorrect est '%c' dans '%s'.",
                                  lineno - 1, str[i], $3);
                          YYERROR;
                        }
                    }
		  int i = 0;
		  char c;
                  if (get_var_addr($2) == -1)
	            {
		      c = str[i++];
		      if (c == '\\')
		        {
			  if (str[i] == 'n')
			    {
			      c = '\n';
			      ++i;
			    }
			  else if (str[i] == 't')
			    {
			      c = '\t';
			      ++i;
			    }
			  else
			    {
			      c = '\\';
			    }
			}
                      variables[n_var].name = $2;
                      variables[n_var].val = c;
                      variables[n_var].val_set = true;
                      variables[n_var++].addr = 0;
                      // On copie toute la chaîne y compris le 0 final.
                      while (i <= strlen(str))
   		        {
			  c = str[i++];
		          if (c == '\\')
		            {
			      if (str[i] == 'n')
			        {
			          c = '\n';
				  ++i;
			        }
			      else if (str[i] == 't')
			        {
			          c = '\t';
				  ++i;
			        }
			      else
				{
				  c = '\\';
				}
			    }
                          variables[n_var].name = 0;
                          variables[n_var].val = c;
                          variables[n_var].val_set = true;
                          variables[n_var++].addr = 0;
                        }
                    }
                  else
	            {
                      /* Ce coup ci on déclenche une erreur car la valeur de
                         la variable serait perdue si on ignore la deuxième
                         déclaration. */
		      fprintf(stderr, "%i: Erreur : variable définie deux"
                                " fois : %s\n", lineno - 1, $2);
                      YYERROR;
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
                      in_func = true;
                    }
                   if (get_lab_addr($1) == -1)
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
                      in_func = true;
                    }
                  if (get_lab_addr($1) == -1)
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
	|	ADD '*' '%'  address { mem[mem_pos++] = 0xF0;
                                       mem[mem_pos++] = $4; }
	|	ADD '*' '%' IDENTIFIER
                { if (get_var_addr($4) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $4;
                      mem[mem_pos] = 0xF0;
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
	|	SUB '*' '%' address { mem[mem_pos++] = 0xF1;
                                  mem[mem_pos++] = $4; }
	|	SUB '*' '%' IDENTIFIER
                { 
                  if (get_var_addr($4) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $4;
                      mem[mem_pos] = 0xF1;
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
	|	NAND '*' '%' address { mem[mem_pos++] = 0xF2;
                                   mem[mem_pos++] = $4; }
	|	NAND '*' '%' IDENTIFIER
                {
                  if (get_var_addr($4) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $4;
                      mem[mem_pos] = 0xF2;
                      mem_pos += 2;
                    } }
	|	LOAD '#' number { mem[mem_pos++] = 0x0;
                                  mem[mem_pos++] = $3; }
	|	LOAD '#' IDENTIFIER
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
                      mem[mem_pos] = 0x0;
                      mem_pos += 2;
                    } }
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
	|	LOAD '*' '%' address { mem[mem_pos++] = 0xD0;
                                       mem[mem_pos++] = $4; }
	|	LOAD '*' '%' IDENTIFIER
                {
                  if (get_var_addr($4) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $4;
                      mem[mem_pos] = 0xD0;
                      mem_pos += 2;
                    } }
	|	MSP '#' number { mem[mem_pos++] = 0x8;
                                 mem[mem_pos++] = $3; }
	|	LEA '%' number { mem[mem_pos++] = 0x3;
                                 mem[mem_pos++] = $3; }
	|	POP { mem[mem_pos++] = 0x4;
                      mem[mem_pos++] = 0; }
	|	POP address { mem[mem_pos++] = 0x44;
                              mem[mem_pos++] = $2; }
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
	|	POP '*' address { mem[mem_pos++] = 0xC4;
                                  mem[mem_pos++] = $3; }
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
	|	PUSH { mem[mem_pos++] = 0x5;
                       mem[mem_pos++] = 0; }
	|	PUSH '#' number { mem[mem_pos++] = 0x7;
                                  mem[mem_pos++] = $3; }
	|	PUSH '#' IDENTIFIER
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
                      mem[mem_pos] = 0x7;
                      mem_pos += 2;
                    } }
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
	|	STORE '*' '%' address { mem[mem_pos++] = 0xD8;
                                    mem[mem_pos++] = $4; }
	|	STORE '*' '%' IDENTIFIER
                {
                  if (get_var_addr($4) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $4;
                      mem[mem_pos] = 0xD8;
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
	|	IN '*' '%' address { mem[mem_pos++] = 0xD9;
                                 mem[mem_pos++] = $4; }
	|	IN '*' '%' IDENTIFIER
                {
                  if (get_var_addr($4) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $4;
                      mem[mem_pos] = 0xD9;
                      mem_pos += 2;
                    }}
	|	OUT '#' number { mem[mem_pos++] = 0x1;
                                 mem[mem_pos++] = $3; }
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
	|	OUT '*' '%' address { mem[mem_pos++] = 0xD1;
                                  mem[mem_pos++] = $4; }
	|	OUT '*' '%' IDENTIFIER
                {
                  if (get_var_addr($4) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $4;
                      mem[mem_pos] = 0xD1;
                      mem_pos += 2;
                    } }
	|	OUTC '#' number { mem[mem_pos++] = 0x2;
                                 mem[mem_pos++] = $3; }
	|	OUTC address { mem[mem_pos++] = 0x42;
                               mem[mem_pos++] = $2; }
	|	OUTC IDENTIFIER
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
                      mem[mem_pos] = 0x42;
                      mem_pos += 2;
                    } }
	|	OUTC '%' number { mem[mem_pos++] = 0x82;
                                  mem[mem_pos++] = $3; }
	|	OUTC '*' address { mem[mem_pos++] = 0xC2;
                                  mem[mem_pos++] = $3; }
	|	OUTC '*' IDENTIFIER
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
                      mem[mem_pos] = 0xC2;
                      mem_pos += 2;
                    } }
	|	OUTC '*' '%' address { mem[mem_pos++] = 0xD2;
                                       mem[mem_pos++] = $4; }
	|	OUTC '*' '%' IDENTIFIER
                {
                  if (get_var_addr($4) == -1)
		    {
                      yyerror("Variable non déclarée");
                      YYERROR;
                    }
                  else
		    {
                      pending_vars[n_pvar].addr = mem_pos + 1;
                      pending_vars[n_pvar++].name = $4;
                      mem[mem_pos] = 0xD2;
                      mem_pos += 2;
                    } }
	|	JUMP number
                { mem[mem_pos++] = 0x10;
                  mem[mem_pos++] = $2; }
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
                      yyerror("Warning : Fonction non déclarée");
                    }
                  mem[mem_pos++] = 0x7; // PUSH #
                  mem[mem_pos] = mem_pos + 3;
                  ++mem_pos;
                  if (is_rom_func($2))
		    {
                      mem[mem_pos++] = 0x13; // SJUMP
                      mem[mem_pos++] = rom_func_addr($2);
                    }
                  else
		    {
                      mem[mem_pos++] = 0x10; // JUMP
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
                        }
                    } }
	|	RET
                { if (!in_func)
  		    {
                      yyerror("RET à l'extérieur d'une fonction");
                      YYERROR;
                    }
                  if (make_rom)
		    {
                      mem[mem_pos++] = 0x14; // SRET
                      mem[mem_pos++] = 0;
                    }
                  else
		    {
                      mem[mem_pos++] = 0x44; // POP a
                      mem[mem_pos] = mem_pos + 2;
                      ++mem_pos;
                      mem[mem_pos++] = 0x10; // JUMP
                      mem[mem_pos++] = 0;
                    }
                  in_func = false;
                 }
;

number : NUM { if ($1 > 255 || $1 < -256)
		 {
                   yyerror("Nombre de trop grande taille");
                   YYERROR;
                 }
               else
		 {
                   $$ = $1;
                 } }
;

address : NUM { if ($1 < 0 || $1 > 511)
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
	if (variables[i].name == NULL)
	{
	  continue;
	}
	else if (!strcmp(varname, variables[i].name))
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

/* Fonction qui renvoie true s'il existe une fonction ayant le nom donné en 
   argument et false sinon.*/
bool func_exists(char *name)
{
  for (int i = 0; i < n_func; ++i)
    {
      if (!strcmp(name, functions[i]))
	{
	  return true;
	}
    }
  return false;
}

/* Renvoie true si le nom donné en argument correspond à une fonction de la
   rom et false sinon. */
bool is_rom_func(char *name)
{
  for (int i = 0; i < rf_count; ++i)
    {
      if (!strcmp(name, rom_funcs[i].name))
	{
	  return true;
	}
    }
  return false;
}

/* Renvoie l'adresse de la rom correspondant à la fonction de la rom dont le 
   nom est donné en argument. */
int rom_func_addr(char *name)
{
  for (int i = 0; i < rf_count; ++i)
    {
      if (!strcmp(name, rom_funcs[i].name))
	{
	  return rom_funcs[i].addr;
	}
    }
  return -1;
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
      variables[i].addr = mem_pos;
      if (variables[i].val_set)
	{
	  mem[mem_pos] = variables[i].val;
	}
      ++mem_pos;
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
	  int n = mem[i];
	  if (n >= 0)
	    {
	      printf("%02x ", n);
	    }
	  else
	    {
              printf("%03x ", n + 512);
	    }
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
