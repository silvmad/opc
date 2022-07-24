/*
IED L3 Informatique
Développement de logiciel libre
Projet final
Victor Matalonga
Numéro étudiant 18905451

fichier : main.h

Fichier en-tête pour le code de lancement du compilateur pour l'ordinateur
en papier.

*/

#ifndef MAIN_H
#define MAIN_H

#define MAX_FILENAME_SIZE 4096
#define DEFAULT_OUTP_FILENAME "a.out"

enum { S_OPT = 1, L_OPT = 2, B_OPT = 4, T_OPT = 8 };

void usage(char*);
void make_args(char**, int, char*, char*, char*, char*);

#endif

