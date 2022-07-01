/*
IED L3 Informatique
Interprétation et compilation
Projet final
Victor Matalonga
Numéro étudiant 18905451

fichier : main.c

Code de lancement de l'assembleur pour l'ordinateur en papier.
*/

#include <getopt.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "pasm.tab.h"
#include "pasm.h"

extern int lineno;
extern int mem_pos;
extern int error_count;
extern int in_func;

void usage(char*);

int fill_pending_labels(void);
void fill_variables(void);
void print_prog(int, int);

// Flags des options.
enum { B_OPT = 1, O_OPT = 2, T_OPT = 4, P_OPT = 8 };

int main(int argc, char **argv)
{
  int opt;
  char *output_filename = NULL;
  int options = 0;
  int offset = 0;
  while (1)
    {
      static struct option long_options[] =
	{
	  { "offset", optional_argument, 0, 't'},
	  { "binary", no_argument, 0, 'b' },
	  { "print", no_argument, 0, 'p' },
	  { 0, 0, 0, 0}
	};

      opt = getopt_long(argc, argv, "bo:t:p", long_options, NULL);

      if (opt == -1)
	break;
      
      switch (opt)
	{
	case 'o':
	  if (!optarg)
	    {
	      usage("L'option -o attend un argument.");
	    }
	  options |= O_OPT;
	  output_filename = strdup(optarg);
	  break;
	case 't':
	  options |= T_OPT;
          // Si pas d'argument on utilise les valeurs par défaut.
	  if (!optarg)
	    {
	      offset = 32;
	    }
	  // Vérifier que l'argument est un nombre.
	  else if (strspn(optarg, "0123456789") != strlen(optarg))
	    {
	      usage("Argument incorrect pour l'option -t.");
	    }
	  else
	    {
	      offset = atoi(optarg);
	      // Vérifier que la taille de l'offset est correcte. 
	      if (offset < 0 || offset > 255)
		{
		  usage("Offset incorrect.");
		}
	    }
	  break;
	case 'b':
	  options |= B_OPT;
	  break;
	case 'p':
	  options |= P_OPT;
	  break;
	case '?': ;
	  char s[1024];
	  snprintf(s, 1024, "Usage : %s [OPTION]... FILE", argv[0]);
	  usage(s);
	default:
	  usage("Une erreur est survenue.");
	}
    }

  if (optind == argc)
    {
      char s[1024];
      snprintf(s, 1024, "Usage : %s [OPTION]... FILE", argv[0]);
      usage(s);
    }

  // Désactivation des options ignorées en cas d'incompatibilité.
  if (options & P_OPT && options & O_OPT)
    {
      fprintf(stderr, "%s: Options -o et -p incompatibles : "
	      "option -o ignorée.\n", argv[0]);
      options &= ~O_OPT;
    }
  if (options & P_OPT && options & B_OPT)
    { 
      fprintf(stderr, "%s: Options -b et -p incompatibles : "
	      "option -b ignorée.\n", argv[0]);
      options &= ~B_OPT;
    }
  
  if (options & T_OPT)
    {
      mem_pos = offset;
    }

  /* Le nom du fichier en entrée doit se terminer par .pasm et doit 
     comporter au moins un caractère avant le point.  */
  char *input_filename = argv[optind];
  int inp_len = strlen(input_filename);
  if (inp_len < 6 || strcmp(input_filename + inp_len - 5, ".pasm"))
    {
      usage("Erreur : format de fichier d'entrée incorrect.");
    }
  // Redirection de l'entrée standard.
  FILE *f = freopen(input_filename, "r", stdin);
  if (f == NULL)
    {
      char s[1024];
      snprintf(s, 1024, "Impossible d'ouvrir le fichier %s", input_filename);
      usage(s);
    }
  int r = yyparse();
  if (in_func)
    {
      fprintf(stderr, "%i: Erreur : absence de RET en fin de fonction\n",
	      lineno);
      ++error_count;
    }
  int r2 = fill_pending_labels();
  if (r == 0 && error_count == 0 && r2 == 0)
    {
      fill_variables();
	  
      // Redirection de la sortie standard
      // Si ni -o ni -p ne sont présentes.
      if (!(options & P_OPT) && !(options & O_OPT))
	/* Détermination du nom du fichier de sortie et redirection vers
	   celui-ci */
	{
	  // Binaire.
	  if (options & B_OPT)
	    {
	      output_filename = strdup(input_filename);
	      // Remplace .pasm par .bin
	      strncpy(output_filename + inp_len - 4, "bin", 4);
	      freopen(output_filename, "wb", stdout);
	    }
	  // Hexadécimal.
	  else
	    {
	      output_filename = malloc(sizeof(char)*(inp_len + 4));
	      strncpy(output_filename, input_filename, inp_len);
	      // Remplace .pasm par .hexcode
	      strncpy(output_filename + inp_len - 4, "hexcode", 9);
	      freopen(output_filename, "w", stdout);
	    }
	}
      // L'option -o ou -p est présente
      else if (!(options & P_OPT))
	// Si -o, redirection vers le fichier donné en argument.
	{
	  freopen(output_filename, "w", stdout);
	} /* Sinon -p est présente et on écrit sur stdout, il n'y a donc
	     rien à faire. */
      if (options & B_OPT)
	{
	  print_prog(offset, BIN);
	}
      else
	{
	  print_prog(offset, TEXT);
	}
    }
}

void usage(char *msg)
{
  fprintf(stderr, "%s\n", msg);
  exit(1);
}
