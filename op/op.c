/*
IED L3 Informatique
Développement de logiciel libre
Victor Matalonga
Numéro étudiant 18905451

fichier : op.c

Programme qui émule le fonctionnement de l'ordinateur en papier. Prend un 
fichier contenant un programme pour l'ordinateur en papier comme argument. 
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <unistd.h>
#include <stdbool.h>

#include "op.h"

int main(int argc, char *argv[])
{ 
  //Variable qui permet d'activer ou non le stepper.
  bool stepper = false;
  bool custom_rom = false;
  int c;
  char *rom_path, *custom_rom_name;
  char buffer[5000];
  while ((c = getopt(argc, argv, "sr:")) != -1)
    {
      switch (c)
	{
	case 's' :
	  stepper = true;
	  puts("\nStepper activé, commandes disponibles :\n"
	       "memory : affiche l'intégralité de la mémoire\n"
	       "stack : affiche la pile\n"
	       "display X : affiche le contenu de l'adresse X à chaque pas."
	       "display stack : affiche le contenu de la pile à chaque pas."
	       "\nX : affiche le contenu de l'adresse X.\n"
	       "X Y : affiche le contenu de toutes les adresse de X à Y.\n"
	       "quit : arrête l'exécution\n"
	       "Les adresses doivent être données en hexadécimal\n");
	       break;
	case 'r' :
	  custom_rom = true;
	  custom_rom_name = strdup(optarg);
	  break;
	case '?' :
	  sprintf(buffer, "Option %c invalide.", optopt);
	  usage(buffer);
	  break;
	}
    }
  char fichier[4097];
  if (optind == argc - 1) //Le nombre d'arguments est correct.
    {
      strncpy(fichier, argv[optind], 4097);
    }
  else
    {
      snprintf(buffer,
	       5000,
	       "Usage : %s [-s] [-r rom] fichier\nL'option -s active le stepper",
	       argv[0]
	       );
      usage(buffer);
    }

  // Créer le chemin vers la ROM.
  if (custom_rom)
    { /* Chemin vers rom utilisateur : concaténation du chemin vers le 
	 répertoire personnel de l'utilisateur, du chemin vers le répertoire
	 des roms utilisateur et du nom de la rom. */
      rom_path = calloc(sizeof(char), ROM_PATH_MAX_LEN);
      strncpy(rom_path, getenv("HOME"), ROM_PATH_MAX_LEN);
      int len = ROM_PATH_MAX_LEN - strlen(rom_path) - 1;
      strncat(rom_path, CUSTOM_ROM_PATH, len);
      len -= strlen(CUSTOM_ROM_PATH);
      strncat(rom_path, custom_rom_name, len);
      free(custom_rom_name);
    }
  else
    {
      rom_path = DEFAULT_ROM_PATH;
      FILE *r = fopen(rom_path, "r");
      /* Si le chemin par défaut ne donne rien on essaie le chemin local par
	 défaut (si le programme a été compilé avec le makefile, la rom par
	 défaut se trouve là). */
      if (!r)
	{
	  rom_path = calloc(sizeof(char), ROM_PATH_MAX_LEN);
	   strncpy(rom_path, getenv("HOME"), ROM_PATH_MAX_LEN);
	   int len = ROM_PATH_MAX_LEN - strlen(rom_path) - 1;
	   strncat(rom_path, LOCAL_DEFAULT_ROM_PATH, len);
	}
      else
	{
	  fclose(r);
	}
    }

  // Variables d'état de l'ordinateur en papier. 
  int ram[512] = { 0 };  // Mémoire + Pile
  unsigned int PC;       // Compteur de programme.
  int A;                 // Accumulateur.
  int *stack = ram + 256;// Pile.
  int stack_count = 1;   // Compteur de pile.
  int rom[256];          // Mémoire en lecture seule contenant des fonctions.
  int mem_space = RAM;   // Espace mémoire actuel. 
 
  stack[0] = -1;         // Adresse de retour de la fonction main.

  PC = charger_hexcode(fichier, ram);
  charger_hexcode(rom_path, rom);
  
  int op, arg; // Opération à exécuter et son argument
  // Boucle principale.
  while (1)
    {
      if (PC > 255 || PC < 0)
	{
	  return A;
	}
      op = mem_space == RAM ? ram[PC] : rom[PC];
      arg = mem_space == RAM ? ram[PC + 1] : rom[PC + 1];
      if (stepper)
	step(PC, A, ram, op, arg, stack_count);
      PC += 2;
      executer(&PC, &A, ram, stack, &stack_count, op, arg, &mem_space);
    }
  return 0;
}

void usage(char *message)
/*
Fonction qui affiche un message d'erreur puis arrête le programme.
*/
{
  fprintf(stderr, "%s\n", message);
  exit(1);
}

int charger_hexcode(char *nom_fichier, int *mem)
/*
Fonction qui lit un fichier, et charge le code qu'il contient dans le vecteur
mémoire.
Si un offset est précisé le code est chargé à partir de l'indice donné, 
sinon il est chargé à partir de l'indice 0.
Mis à part le premier mot qui peut être "offset", le code doit être composé 
uniquement de nombres hexadécimaux compris entre 00 et FF. Ils sont 
convertis en int avant d'être rangés dans le vecteur mémoire.
Renvoie l'offset.
*/
{
  FILE *flux = fopen(nom_fichier, "r");
  //Si on a pas pu ouvrir le fichier, on arrête le programme.
  if (!flux)
    {
      char tampon[1024];
      snprintf(tampon, 1023, "Impossible d'ouvrir le fichier %s",
	       nom_fichier);
      usage(tampon);
    }
  char tampon[8];
  int i; //indice à partir duquel on charge
  int offset;
  /* On regarde le premier mot pour voir s'il y a un offset. */
  fscanf(flux, " %[^\n ]", tampon);
  if (!strcmp(tampon, "offset"))
    {
      fscanf(flux, " %[^\n ]", tampon); //scan de l'offset
      offset = strtoi(tampon);
      i = offset;
      fscanf(flux, " %[^\n ]", tampon); //scan du 1er code
    }
  /* 
  S'il n'y a pas d'offset, on charge à partir du début (et on a le premier
  code dans le tampon). */
  else 
    {
      offset = 0;
      i = 0;
    }
  //Boucle qui permet de scanner l'intégralité des codes du fichier.
  do
    {
      mem[i++] = strtoi(tampon);
    }
  while (fscanf(flux, " %[^\n ]", tampon) != EOF);
  return offset;
}

void executer(unsigned int *PC_pt, int *A_pt, int *ram, int *stack,
	      int *stack_count_pt, int op, int arg, int *mem_space_pt)
/*
Fonction qui exécute une instruction en fonction de l'opcode et de l'argument
fourni.
*/
{ 
  switch (op)
    {
    case 0x0 : *A_pt = arg; break;                        // LOAD #
    case 0x1 : printf("%i", arg); break;                  // OUT #
    case 0x2 : printf("%c", arg); break;                  // OUTC #
    case 0x3 : *A_pt = 256 + *stack_count_pt - arg; break;   // LEA % 
    case 0x4 : *A_pt = stack[--(*stack_count_pt)]; break; // POP
    case 0x5 : stack[(*stack_count_pt)++] = *A_pt; break; // PUSH
    case 0x7 : stack[(*stack_count_pt)++] = arg; break;   // PUSH #
    case 0x8 : *stack_count_pt += arg; break;             // MSP #
    case 0x10 : *PC_pt = arg; break;                      // JUMP
    case 0x11 : if (*A_pt < 0) *PC_pt = arg; break;       // BRN
    case 0x12 : if (!*A_pt) *PC_pt = arg; break;          // BRZ
    case 0x13 : *PC_pt = arg;                             // SJMP
      *mem_space_pt = *mem_space_pt == RAM ? ROM : RAM;
      break;
    case 0x14 : *PC_pt = stack[--(*stack_count_pt)];      // SRET
      *mem_space_pt = *mem_space_pt == RAM ? ROM : RAM;
      break;
    case 0x20 : *A_pt += arg; break;                      // ADD #
    case 0x21 : *A_pt -= arg; break;                      // SUB #
    case 0x22 : *A_pt = ~(*A_pt & arg); break;            // NAND #
    case 0x40 : *A_pt = ram[arg]; break;                  // LOAD a
    case 0x41 : printf("%d", ram[arg]); break;            // OUT a
    case 0x42 : printf("%c", ram[arg]); break;            // OUTC a
    case 0x44 : ram[arg] = stack[--(*stack_count_pt)]; break; // POP a
    case 0x45 : stack[(*stack_count_pt)++] = ram[arg]; break; // PUSH a
    case 0x48 : ram[arg] = *A_pt; break;           // STORE a  
    case 0x49 : ram[arg] = recup_entree(); break;  // IN a
    case 0x60 : *A_pt += ram[arg]; break;          // ADD a
    case 0x61 : *A_pt -= ram[arg]; break;          // SUB a
    case 0x62 : *A_pt = ~(*A_pt & ram[arg]); break;// NAND a
    case 0x80 : *A_pt = stack[(*stack_count_pt) - arg]; break;  // LOAD %a
    case 0x81 : printf("%i", stack[(*stack_count_pt) - arg]); // OUT %a
      break; 
    case 0x82 : printf("%c", stack[(*stack_count_pt) - arg]); // OUTC %a
      break; 
    case 0x88 : stack[(*stack_count_pt) - arg] = *A_pt; break;   // STORE %a
    case 0x89 : stack[(*stack_count_pt) - arg] = recup_entree(); break;
                                                                   // IN %a
    case 0xA0 : *A_pt += stack[(*stack_count_pt) - arg]; break;    // ADD %a
    case 0xA1 : *A_pt -= stack[(*stack_count_pt) - arg]; break;    // SUB %a
    case 0xA2 : *A_pt = ~(*A_pt & stack[(*stack_count_pt) - arg]); // NAND %a
      break;
    case 0xC0 : *A_pt = ram[(unsigned int)ram[arg]]; break;      // LOAD *a
    case 0xC1 : printf("%d", ram[(unsigned int)ram[arg]]); break; // OUT *a
    case 0xC2 : printf("%c", ram[(unsigned int)ram[arg]]); break; // OUTC *a
    case 0xC4 : ram[(unsigned int)ram[arg]] = stack[--(*stack_count_pt)];
      break;                                                     //POP *a
    case 0xC5 : stack[(*stack_count_pt)++] = ram[(unsigned int)ram[arg]];
      break;                                                     //PUSH *a
    case 0xC8 : ram[(unsigned int)ram[arg]] = *A_pt; break;     // STORE *a
    case 0xC9 : ram[(unsigned int)ram[arg]] = recup_entree();   // IN *a
      break;
    case 0xD0 : *A_pt = ram[(unsigned int)stack[(*stack_count_pt) - arg]];
      break;      // LOAD *%a
    case 0xD1 :                                                   // OUT *%a
      printf("%d", ram[(unsigned int)stack[(*stack_count_pt) - arg]]);
      break;
    case 0xD2 :                                                   // OUTC *%a
      printf("%c", ram[(unsigned int)stack[(*stack_count_pt) - arg]]);
      break;
    case 0xD8 : ram[(unsigned int)stack[(*stack_count_pt) - arg]] = *A_pt;
      break;                                                     // STORE *%a
    case 0xD9 :                                                  // IN *%a
      ram[(unsigned int)stack[(*stack_count_pt) - arg]] = recup_entree();
      break;
    case 0xE0 : *A_pt += ram[(unsigned int)ram[arg]]; break;    // ADD *a
    case 0xE1 : *A_pt -= ram[(unsigned int)ram[arg]]; break;    // SUB *a
    case 0xE2 : *A_pt = ~(*A_pt & ram[(unsigned int)ram[arg]]); // NAND *a
      break;
    case 0xF0 : *A_pt += ram[(unsigned int)stack[(*stack_count_pt) - arg]];
      break;                                                     // ADD *%a
    case 0xF1 : *A_pt -= ram[(unsigned int)stack[(*stack_count_pt) - arg]];
      break;                                                     // SUB *%a
    case 0xF2 :                                                  // NAND *%a
      *A_pt = ~(*A_pt & ram[(unsigned int)stack[(*stack_count_pt) - arg]]); 
      break;    default : printf("ligne %i, op : %x\n", *PC_pt, op);
      usage("Erreur : opcode inconnu."); break;
    }
}

int strtoi(char * chaine)
/*
Fonction qui convertit un code ou une adresse (nombre hexadécimal entre 00 et
1FF) en un int. Provoque une erreur si l'on essaie de convertir autre
chose.

Prend une chaine en argument et renvoie celle-ci convertie en int.
Des ajustement sont faits pour les nombres négatifs afin de simuler une 
représentation des nombres en complément à deux sur 9 bits. 
 */
{
  int i = 0;
  char * end;
  i += strtol(chaine, &end, 16);
  /* Lorsque strtol rencontre un caractère qu'elle ne peut convertir, elle 
  fait pointer end vers ce caractère, on sait donc que si end pointe vers
  autre chose que 0 la chaine que l'on a essayé de convertir n'était pas
  uniquement en hexadécimal. */
  if (*end != 0)
    {
      usage("Contenu du fichier incorrect : les codes doivent être en "
	    "hexadécimal");
    }
  if (i > 511)
    {
      usage("Contenu du fichier incorrect : les codes doivent être compris "
	    "entre 0 et 1FF.");
    }
  // Simuler le complément à 2 sur 9 bits.
  if (i > 255)
    {
      i -= 512;
    }
  return i;
}

char recup_entree(void)
/*
Fonction qui permet de récupérer l'entrée de l'utilisateur à l'aide de scanf, 
s'il ne propose pas une entrée valide (un nombre entre -256 et 255) celui-ci 
devra recommencer.

Renvoie le nombre entré par l'utilisateur.
*/
{
  char * end;
  long int i;
  char c;
  char tampon[32];
  bool loop = true;
  do
    {
      /* 
      On scanne 31 caractères pour le cas où l'utilisateur entre des zéros 
      non significatifs à gauche du nombre. S'il entre moins de 29 zéros non 
      significatifs, son nombre sera tout de même pris en compte par le 
      programme, au delà non mais on considérera qu'il l'a bien mérité. 
      */
      scanf(" %31s", tampon);
      while ((c = getchar() !='\n') && c != EOF) {}; //vide le flux entrant
      i = strtol(tampon, &end, 10);

      if (i < -256 || i > 255 || (*end != '\n' && *end != 0))
	{
	  puts("Saisissez un nombre entre -256 et 255");
	}
      else
	{
	  loop = false;
	}
    } while (loop);

  return i;
}
 
void step(unsigned int PC, int A, int *ram, int op, int arg, int stack_count)
/* 
Fonction qui affiche les valeurs de A et PC, les adresses dont l'utilisateur
a demandé l'affichage à chaque instruction,  puis l'instruction en cours.
Elle propose ensuite à l'utilisateur d'entrer une commande.
*/
{
  /*Vecteur qui recueille les adresses dont l'utilisateur a demandé
    l'affichage */
  static unsigned int display[256] = {0};
  /*Variable qui conserve l'indice de la prochaine case libre dans le vecteur
    display */
  static int display_count = 0;
  static bool display_stack = false;
  
  printf("A : %x (%i), PC : %x (%i)\n", A >= 0 ? A : A + 512, A, PC, PC);
  if (display_stack)
    {
      int top = ram[256 + stack_count - 1];
      top += top >= 0 ? 0 : 512;
      printf("top ->  %x\n", top);
      for (int i = stack_count -1; i > 0; --i)
	{
	  int n = ram[256 + i - 1];
	  n += n >= 0 ? 0 : 512;
	  printf("\t%x\n", n);
	}
    }
  for (int i = 0; i < display_count; i++)
    printf("%x : %x\n", display[i], ram[display[i]]);
  print_instruction(op, arg, PC);
  get_user_input(display, &display_count, &display_stack, ram, stack_count);
  puts("");
}

void get_user_input(unsigned int *display, int *display_count_pt,
		    bool *display_stack, int *ram, int stack_count)
/*
Fonction qui permet à l'utilisateur d'entrer une commande dans le stepper.
Il peut entrer une commande ou appuyer sur entrée pour passer à l'instruction
suivante. 
*/
{
  char tampon[1024] = {0};
  //boucle tant que l'utilisateur entre quelquechose
  while (strcmp(tampon, "\n"))
    {
      printf("(step) ? ");
      fgets(tampon, 1023, stdin);
      parse_input(tampon, display, display_count_pt, display_stack, ram,
		  stack_count);
    }
}

void parse_input(char *tampon, unsigned int *display, int *display_count_pt,
		 bool *display_stack, int *ram, int stack_count)
/*
Fonction qui analyse les entrées de l'utilisateur lors du stepper et effectue
le traitement adéquat.
*/
{
  char *elt = strtok(tampon, " ");
  if (!strcmp(elt, "display"))
    {
      char *suite = strtok(NULL, " ");
      if (!strcmp(suite, "stack\n"))
	{
	  *display_stack = true;
	}
      else if (adresse(suite))
	//On ajoute cette adresse au vecteur des adresse à afficher
	display[(*display_count_pt)++] = strtol(suite, NULL, 16);
    }
  else if (!strcmp(elt, "memory\n"))
    print_mem(ram);
  else if (!strcmp(elt, "stack\n"))
    {
      int top = ram[256 + stack_count - 1];
      top += top >=0 ? 0 : 512;
      printf("top ->  %x\n", top);
      for (int i = stack_count -1; i > 0; --i)
	{
	  int n = ram[256 + i - 1];
	  n += n >= 0 ? 0 : 512;
	  printf("\t%x\n", n);
	}
    }
  else if (!strcmp(elt, "quit\n"))
    usage("Arrêt de l'exécution");
  else if (adresse(elt))
    
    {
      char *suite = strtok(NULL, " ");
      /*Si l'utilisateur a entré une adresse valide, on affiche le contenu
      de cette adresse. */
      if (!suite)
	{
	  unsigned char nb = strtol(elt, NULL, 16);
	  printf("%x : %x\n", nb, ram[nb]);
	}
      /*Si l'utilisateur a entré deux adresses valides, on affiche le contenu
        de toutes les adresses entre les deux. */
      else if (adresse(suite))
	{
	  unsigned char n = strtol(suite, NULL, 16);
	  /* i est un long int et non un unsigned char pour éviter une boucle
	     infinie si l'utilisateur entre "0 ff" */
	  for (long int i = strtol(elt, NULL, 16); i <= n; i++)
	    printf("%lx : %x\n", i, ram[i]);
	}
    }
}

void print_mem(int *ram)
/*
Affiche l'intégralité de la mémoire sous forme d'un carré de 16*16.
*/
{
  for (int i = 0; i < 16; i++)
    printf("\t%x", i);
  printf("\n  ");
  for (int i = 0; i < 127; i++)
    printf("-");
  puts("");
  for (int i = 0; i <= 240; i += 16)
    {
      printf("%x |\t", i / 16);
      for (int j = i; j < i + 16; j++)
	{
	  int n = ram[j];
	  n += n >= 0 ? 0 : 512;
	  printf("%x\t", n);
	}
      puts("");
    }
}

bool adresse(char *chaine)
/*
Fonction qui détermine si une chaîne est une adresse valide ou non.
Prend en argument une chaine et renvoie true si cette chaîne est une adresse
valide et false sinon.
*/
{
  char * endptr;
  // Éliminer le cas où la chaîne commence par un retour à la ligne.
  if (*chaine == '\n')
    {
      return false;
      }
  long int nb = strtol(chaine, &endptr, 16);
  if ((*endptr != '\0') && (*endptr != '\n'))
    {
      return false;
    }
  else if (nb >= 0 && nb < 512)
    {
      return true;
    }
  return false;
}

void print_instruction(unsigned int op, int arg, unsigned int PC)
/*
Fonction qui affiche l'instruction correspondant à l'opcode en cours et son
argument.
Prend en argument deux long int correspondant à l'opcode et son argument.
*/
{
  int num_arg = arg;
  /* Ajustement pour simuler la représentation de nombres signés en 
     complément à deux sur 9 bits. */
  num_arg += arg >= 0 ? 0 : 512;
  switch (op)
    {
    case 0x0 : printf("LOAD #%x : A <- %x\n", num_arg, num_arg); break;
    case 0x1 : printf("OUT #%x : out <- %x\n", num_arg, num_arg); break;
    case 0x2 : printf("OUTC #%x : out <- (char) %x\n", num_arg, num_arg);
      break;
    case 0x3 : printf("LEA %%%x : A <- SP - %x\n", arg, arg); break;
    case 0x4 : printf("POP : A <- *(SP), SP--\n"); break;
    case 0x5 : printf("PUSH : *(SP) <- A, SP++\n"); break;
    case 0x7 : printf("PUSH #%x: *(SP) <- %x, SP++\n", num_arg, num_arg);
      break;
    case 0x8 : printf("MSP  #%x : SP += %x\n", num_arg, num_arg); break;
    case 0x10 : printf("JUMP %x : PC <- %x\n", arg, arg); break;
    case 0x11 : printf("BRN %x : if (A < 0) PC <- %x\n", arg, arg); break;
    case 0x12 : printf("BRZ %x : if (A = 0) PC <- %x\n", arg, arg); break;
    case 0x13 : printf("SJMP %x : PC <- %x (changement d'espace mémoire) \n",
		       arg, arg);
      break;
    case 0x14 : printf("SRET : PC <- *(SP), SP-- (changement d'espace mémoire) \n");
      break;
    case 0x20 : printf("ADD #%x : A <- A + %x\n", num_arg, num_arg); break;
    case 0x21 : printf("SUB #%x : A <- A - %x\n", num_arg, num_arg); break;
    case 0x22 : printf("NAND #%x : A <- ~(A & %x)\n", num_arg, num_arg);
      break;
    case 0x40 : printf("LOAD %x : A <- (%x)\n", arg, arg); break;
    case 0x41 : printf("OUT %x : out <- (%x)\n", arg, arg); break;
    case 0x42 : printf("OUTC %x : out <- (char) (%x)\n", arg, arg); break;
    case 0x44 : printf("POP %x: (%x) <- *(SP), SP--\n", arg, arg); break;
    case 0x45 : printf("PUSH %x: *(SP) <- (%x), SP++\n", arg, arg); break;
    case 0x48 : printf("STORE %x : (%x) <- A\n", arg, arg); break;
    case 0x49 : printf("IN %x : (%x) <- in\n", arg, arg); break;
    case 0x60 : printf("ADD %x : A <- A + (%x)\n", arg, arg); break;
    case 0x61 : printf("SUB %x : A <- A - (%x)\n", arg, arg); break;
    case 0x62 : printf("NAND %x : A <- ~ (A & (%x))\n", arg, arg); break;
    case 0x80 : printf("LOAD %%%x : A <- *(SP - %x)\n", arg, arg); break;
    case 0x81 : printf("OUT %%%x : out <- *(SP - %x)\n", arg, arg); break;
    case 0x82 : printf("OUTC %%%x : out <- (char) *(SP - %x)\n", arg, arg);
      break;
    case 0x88 : printf("STORE %%%x : *(SP - %x) <- A\n", arg, arg); break;
    case 0x89 : printf("IN %%%x : *(SP - %x) <- in\n", arg, arg); break;
    case 0xA0 : printf("ADD %%%x : A <- A + *(SP - %x)\n", arg, arg); break;
    case 0xA1 : printf("SUB %%%x : A <- A - *(SP - %x)\n", arg, arg); break;
    case 0xA2 : printf("NAND %%%x : A <- ~(A & *(SP - %x))\n", arg, arg);
      break;
    case 0xC0 : printf("LOAD *%x : A <- *(%x)\n", arg, arg); break;
    case 0xC1 : printf("OUT *%x : out <- *(%x)\n", arg, arg); break;
    case 0xC2 : printf("OUTC *%x : out <- (char) *(%x)\n", arg, arg); break;
    case 0xC4 : printf("POP *%x: *(%x) <- *(SP), SP--\n", arg, arg); break;
    case 0xC5 : printf("PUSH *%x: *(SP) <- *(%x), SP++\n", arg, arg); break;
    case 0xC8 : printf("STORE *%x : *(%x) <- A\n", arg, arg); break;
    case 0xC9 : printf("IN *%x : *(%x) <- in\n", arg, arg); break;
    case 0xD0 : printf("LOAD *%%%x : A <- *(*(SP - %x))\n", arg, arg); break;
    case 0xD1 : printf("OUT *%%%x : out <- *(*(SP - %x))\n", arg, arg);
    case 0xD2 : printf("OUTC *%%%x : out <- (char) *(*(SP - %x))\n",
		       arg, arg); break;
    case 0xD8 : printf("STORE *%%%x : *(*(SP - %x)) <- A\n", arg, arg);
      break;
    case 0xD9 : printf("IN *%%%x : *(*(SP - %x)) <- in\n", arg, arg); break;
    case 0xE0 : printf("ADD *%x : A <- A + *(%x)\n", arg, arg); break;
    case 0xE1 : printf("SUB *%x : A <- A - *(%x)\n", arg, arg); break;
    case 0xE2 : printf("NAND *%x : A <- ~(A & *(%x))\n", arg, arg); break;
    case 0xF0 : printf("ADD *%x : A <- A + *(*(SP - %x))\n", arg, arg);
      break;
    case 0xF1 : printf("SUB *%x : A <- A - *(*(SP - %x))\n", arg, arg);
      break;
    case 0xF2 : printf("NAND *%x : A <- ~(A & *(*(SP - %x)))\n", arg, arg);
      break;
    default : printf("ligne %i, op : %x", PC, op);
      usage("Erreur : opcode inconnu."); break;
    }
}
