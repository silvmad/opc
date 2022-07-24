/*
IED L3 Informatique
Interprétation et compilation
Projet final
Victor Matalonga
Numéro étudiant 18905451

fichier : pasm.l

Analyseur lexical de l'assembleur pour l'ordinateur en papier.
*/

%{
#include <stdlib.h>
#include <string.h>

#include "pasm.tab.h"

int lineno = 1;
%}
%option noyywrap
%option noinput
%option nounput
						
%%
[ \t]+                    { /* Ignorer les espaces. */ }
;.*\n                     { /* Commentaire */ ++lineno; return '\n'; }
\n                        { ++lineno; return yytext[0]; }
"globl"                   { return GLOBL; }
"func"                    { return FUNC; }
"ADD"                     { return ADD; }
"SUB"                     { return SUB; }
"NAND"                    { return NAND; }
"LOAD"                    { return LOAD; }
"STORE"                   { return STORE; }
"IN"                      { return IN; }
"OUT"                     { return OUT; }
"OUTC"                    { return OUTC; }
"POP"                     { return POP; }
"PUSH"                    { return PUSH; }
"JUMP"                    { return JUMP; }
"BRN"                     { return BRN; }
"BRZ"                     { return BRZ; }
"CALL"                    { return CALL; }
"RET"                     { return RET; }
[*#%:]                    { return yytext[0]; }
-?[0-9]+                  { yylval.i = atoi(yytext); return NUM; }
[\._a-zA-Z][_a-zA-Z0-9]*  { yylval.s = strdup(yytext);
                            return IDENTIFIER; }
\".*\"                    { char *string = yytext + 1;
                            string[strlen(string) - 1] = 0;
                            yylval.s = strdup(string);
                            return STRING; }
%%
