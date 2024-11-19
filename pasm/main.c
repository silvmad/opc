/*
IED L3 Informatique
Développement de logiciel libre
Victor Matalonga
Numéro étudiant 18905451

fichier : main.c

Code de lancement de l'assembleur pour l'ordinateur en papier.
*/

#include <getopt.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>

#include "pasm.tab.h"
#include "pasm.h"


id rom_funcs[256];
int rf_count = 0;

bool make_rom = false;

void usage(char*);

int fill_pending_labels(void);
void fill_variables(void);
void print_prog(int, int);
int get_lab_addr(char*);

// Flags des options.
enum { B_OPT = 1, O_OPT = 2, T_OPT = 4, P_OPT = 8, R_OPT = 16, L_OPT = 32, };

int main(int argc, char **argv)
{
  int opt;
  char *output_filename = NULL;
  char *rom_filename = NULL;
  int options = 0;
  int offset = 0;
  while (1)
    {
      static struct option long_options[] =
	{
	  { "offset", optional_argument, 0, 't'},
	  { "binary", no_argument, 0, 'b' },
	  { "print", no_argument, 0, 'p' },
	  { "make_rom", required_argument, 0, 'r' },
	  { "use_rom", required_argument, 0, 'l' },
	  { 0, 0, 0, 0}
	};

      opt = getopt_long(argc, argv, "bo:t:pr:l:", long_options, NULL);

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
	case 'r' :
	  options |= R_OPT;
	  if (!optarg)
	    {
	      usage("L'option -r attend un argument.");
	    }
	  rom_filename = strdup(optarg);
	  make_rom = true;
	  break;
	case 'l' :
	  options |= L_OPT;
	  if (!optarg)
	    {
	      usage("L'option -l attend un argument.");
	    }
	  rom_filename = strdup(optarg);
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
  if (options & R_OPT)
    {
      if (options & L_OPT)
	{
	  fprintf(stderr, "%s: Options -l et -r incompatibles : "
		  "option -l ignorée.\n", argv[0]);
	  options &= ~L_OPT;
	}
      if (options & O_OPT)
	{
	  fprintf(stderr, "%s: Options -o et -r incompatibles : "
		  "option -o ignorée.\n", argv[0]);
	  options &= ~O_OPT;
	}
      if (options & P_OPT)
	{
	  fprintf(stderr, "%s: Options -p et -r incompatibles : "
		  "option -p ignorée.\n", argv[0]);
	  options &= ~P_OPT;
	}
      if (options & B_OPT)
	{
	  fprintf(stderr, "%s: Options -b et -r incompatibles : "
		  "option -b ignorée.\n", argv[0]);
	  options &= ~B_OPT;
	}
      if (options & T_OPT)
	{
	  fprintf(stderr, "%s: Options -t et -r incompatibles : "
		  "option -t ignorée.\n", argv[0]);
	  options &= ~T_OPT;
	}
    }
  
  if (options & T_OPT)
    {
      mem_pos = offset;
    }

  // Créer le chemin vers la ROM.
  char rom_addr_path[ROM_PATH_MAX_LEN] = {0};
  char rom_path[ROM_PATH_MAX_LEN] = {0};
  /* Si options -l ou -r on cherche la ROM dans le répertoire des ROMs 
     utilisateur. Pour cela on concatène le chemin vers le répertoire 
     personnel de l'utilisateur, le chemin vers les ROMs utilisateurs et
     le nom de ROM demandé.  */
  if (options & L_OPT || options & R_OPT)
    {
      char *home_path = getenv("HOME");
      strncpy(rom_addr_path, home_path, ROM_PATH_MAX_LEN - 1);
      strncpy(rom_path, home_path, ROM_PATH_MAX_LEN - 1);
      int len = ROM_PATH_MAX_LEN - 1 - strlen(home_path);
      strncat(rom_addr_path, CUSTOM_ROM_PATH, len);
      strncat(rom_path, CUSTOM_ROM_PATH, len);
      len = len - strlen(CUSTOM_ROM_PATH);
      strncat(rom_addr_path, rom_filename, len);
      strncat(rom_path, rom_filename, len);
      strncat(rom_addr_path, "_addr", len - strlen(rom_filename));
    }
  /* Sinon on utilise la ROM par défaut. */
  else
    {
      strncpy(rom_addr_path, ROM_DEFAULT_ADDR_PATH, ROM_PATH_MAX_LEN);
      strncpy(rom_path, ROM_DEFAULT_PATH, ROM_PATH_MAX_LEN);
      // On teste si la ROM par défaut est présente
      FILE *r = fopen(rom_addr_path, "r");
      // Si elle n'est pas présente on utilise la rom par défaut locale.
      if (!r)
	{
	  char *home_path = getenv("HOME");
	  strncpy(rom_addr_path, home_path, ROM_PATH_MAX_LEN - 1);
	  strncpy(rom_path, home_path, ROM_PATH_MAX_LEN - 1);
	  int len = ROM_PATH_MAX_LEN - 1 - strlen(home_path);
	  strncat(rom_path, LOCAL_ROM_DEFAULT_PATH, len);
	  strncat(rom_addr_path, LOCAL_ROM_DEFAULT_ADDR_PATH, len);
	}
      else
	{
	  fclose(r);
	}
    }
	      
  // Charger les adresses des fonctions de la rom.
  //id rom_funcs[256];
  if (!(options & R_OPT))
    {
      FILE *rom = fopen(rom_addr_path, "r");
      if (!rom)
	{
	  usage("Impossible d'ouvrir le fichier ROM.");
	}
      char buffer[2048];
      char *endptr;
      // Lire un premier mot (un nom de fonction).
      while(fscanf(rom, " %[^\n ]", buffer) != EOF)
	{
	  rom_funcs[rf_count].name = strdup(buffer);
	  // Lire un deuxième mot (l'adresse de début de la fonction). 
	  if (fscanf(rom, " %[^\n ]", buffer) == EOF)
	    {
	      printf("Erreur : contenu du fichier %s incorrect.\n",
		     rom_addr_path);
	    }
	  rom_funcs[rf_count++].addr = strtol(buffer, &endptr, 16);
	  if (*endptr != 0)
	  {
	    printf("Erreur : le fichier %s contient des adresses invalides.\n",
		   rom_addr_path);
	    exit(1);
	  }
	}
      fclose(rom);
      /* Ajouter les fonctions de la rom au tableau des fonctions pour que
	 l'analyseur en ait connaissance. */
      for (int i = 0; i < rf_count; ++i)
	{
	  functions[n_func++] = rom_funcs[i].name;
	}
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
      snprintf(s, 1024, "Impossible d'ouvrir le fichier %s",
	       input_filename);
      usage(s);
    }

      int r = yyparse();
  if (in_func /*& strcmp(cur_func, "main")*/)
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
      // Si -r, redirection vers le fichier donné en argument.
      if (options & R_OPT)	
	{
	  freopen(rom_path, "w", stdout);
	}	  
      // Sinon, si ni -o ni -p ne sont présentes.
      else if (!(options & P_OPT) && !(options & O_OPT))
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
      // Sinon, l'option -o ou -p est présente
      else if (options & O_OPT)
	// Si -o, redirection vers le fichier donné en argument.
	{
	  freopen(output_filename, "w", stdout);
	}
      /* Sinon -p est présente et on écrit sur stdout, il n'y a donc
	 pas de redirection à faire. */
      if (options & B_OPT)
	{
	  print_prog(offset, BIN);
	}
      else
	{
	  print_prog(offset, TEXT);
	}
      // Écrire le fichier des adresses de fonctions de la rom.
      if (options & R_OPT)
	{
	  FILE *rom_addr_file = fopen(rom_addr_path, "w");
	  for (int i = 0; i < n_func; ++i)
	    {
	      char * fname = functions[i];
	      fprintf(rom_addr_file, "%s %02x\n", fname, get_lab_addr(fname));
	    }
	  fclose(rom_addr_file);
	}
    }
}

/* Afficher un message d'erreur et quitter.
   msg : le message à afficher. */
void usage(char *msg)
{
  fprintf(stderr, "%s\n", msg);
  exit(1);
}
