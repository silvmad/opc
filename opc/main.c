/*
IED L3 Informatique
Développement de logiciel libre
Projet final
Victor Matalonga
Numéro étudiant 18905451

fichier : pasm.y

Code de lancement du compilateur pour l'ordinateur en papier.

*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "main.h"
#include "opc.h"
#include "expr.h"
#include "opc.tab.h"


int main(int argc, char **argv)
{
  int opt;
  int options = 0;
  char *outp_filename = NULL;
  char *offset;
  char *rom;
  while ((opt = getopt(argc, argv, "o:sl:bt:")) != -1)
    {
      switch (opt)
	{
	case 'o' :
	  outp_filename = strdup(optarg);
	  break;
	case 's' :
	  options |= S_OPT;
	  break;
	case 'l' :
	  options |= L_OPT;
	  rom = strdup(optarg);
	  break; 
	case 'b' :
	  options |= B_OPT;
	  break;
	case 't' :
	  options |= T_OPT;
	  offset = strdup(optarg);
	  break;
	case '?' : ;
	  char s[1024];
	  snprintf(s, 1024, "Usage : %s [OPTION]... FILE", argv[0]);
	  usage(s);
	default:
	  usage("Une erreur est survenue.");
	}
    }
  
  char *inp_filename;
  if (optind == argc - 1)
    {
      inp_filename = argv[optind];
    }
  else
    {
      char s[4097];
      snprintf(s, 4097, "Usage : %s [OPTION]... FILE", argv[0]);
      usage(s);
    }
  int inp_len = strlen(inp_filename);
  if (inp_len < 6 || strcmp(inp_filename + inp_len - 4, ".mic"))
    {
      usage("Format de fichier d'entrée incorrect.");
    }
  
  if (!outp_filename)
    {
      if (options & S_OPT)
	{
	  int len = strlen(inp_filename);
	  // On ajoute 2 octets pour le 0 final et transformer .mic en .pasm.
	  outp_filename = calloc(sizeof(char), inp_len + 2);
	  strncpy(outp_filename, inp_filename, len);
	  strcpy(outp_filename + inp_len - 3, "pasm");
	}
      else
	{
	  outp_filename = DEFAULT_OUTP_FILENAME;
	}
    }

  FILE *f = freopen(inp_filename, "r", stdin);
  if (f == NULL)
    {
      char s[1024];
      snprintf(s, 1024, "Impossible d'ouvrir le fichier %s", inp_filename);
      usage(s);
    }
  
  if (options & S_OPT)
    {
      freopen(outp_filename, "w", stdout);
      printf("\tJUMP main\n");
      yyparse();
      //printf("end:\n");

    }
  else
    {
      FILE * flux = freopen(TMP_FILE, "w", stdout);
      printf("\tJUMP main\n");
      int t = yyparse();
      if (t == 0)
	{
	  //printf("end:\n");
	  t = fork();
	  if (t == -1)
	    {
	      usage("Erreur : échec du fork.");
	    }
	  else if (t == 0) // Enfant.
	    {
	      char *args[10];
	      make_args(args, options, rom, offset, outp_filename);
      	      execv(ASM_PATH, args);
	    }
	  else // Parent.
	    {
	      fclose(flux);
	    }
	}
    }
  return 0;
}
  
void usage(char *msg)
{
  fprintf(stderr, "%s\n", msg);
  exit(1);
}

void make_args(char **args, int options, char *rom, char *offset,
	      char* outp_filename)
{
  args[0] = ASM_NAME;
  args[1] = TMP_FILE;
  args[2] = "-o";
  args[3] = outp_filename;
  int count = 4;  
  if (options & L_OPT)
    {
      args[count++] = "-l";
      args[count++] = rom;
    }
  if (options & T_OPT)
    {
      args[count++] = "-t";
      args[count++] = offset;
    }
  if (options & B_OPT)
    {
      args[count++] = "-b";
    }
  args[count] = NULL;
}
