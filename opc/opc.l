/*
IED L3 Informatique
Développement de logiciel libre
Projet final
Victor Matalonga
Numéro étudiant 18905451

fichier : opc.l

Analyseur lexical du langage microbe pour l'ordinateur en papier.
*/

%{
#include <stdlib.h>
#include <string.h>

#include "expr.h"
#include "opc.tab.h"

int lineno = 1;
%}

%option noyywrap
%option noinput
%option nounput

%%
[ \t]+                    { /* Ignorer les espaces. */ }
\/\/.*\n                  { /* Commentaire type c++ */ ++lineno; }
\/\*([^\*]|(\*+[^\/]))*\*+\/ { ; /* Commentaire type c */ }
\n                        { ++lineno; }
"si"                      { return SI; }
"sinon"                   { return SINON; }
"tant que"                { return TANTQUE; }
"pour"                    { return POUR; }
"var"                     { return VAR; }
"retour"                  { return RETOUR; }
"et"                      { return ET; }
"ou"                      { return OU; }
"=="                      { return EGAL; } 
"!="                      { return INEG; } 
">="                      { return SUPEG; }
"<="                      { return INFEG; }
"fonc"                    { return FONC; }
"affc"                    { return AFFC; }
"affv"                    { return AFFV; }
"entre"                   { return ENTRE; }
[\+\-\*/%=()\[\]{},><;!]  { return yytext[0]; }
[0-9]+                    { yylval.i = atoi(yytext); return NOMBRE; }
[_a-zA-Z][_a-zA-Z0-9]*    { yylval.s = strdup(yytext);
                            return NOM; }
\'(\\n|\\t|.)\'           {
                            if (yytext[1] == '\\')
	                    {
				if(yytext[2] == 'n')
				{
				    yylval.i = '\n';
				}
				else
				{
				    yylval.i = '\t';
				}
			    }
                            else
			    {
				yylval.i = yytext[1];
			    }
                            return CARAC;
                          }
\".*\"                    { char *string = yytext + 1;
                               string[strlen(string) - 1] = 0;
                               yylval.s = strdup(string);
                               return CHAINE; }

%%			
