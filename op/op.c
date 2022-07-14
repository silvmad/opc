/* 
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
  bool stepper;

  int c;
 
  char buffer[5000];
  while ((c = getopt(argc, argv, "s")) != -1)
    {
      switch (c)
	{
	case 's' :
	  stepper = true;
	  puts("\nStepper activé, commandes disponibles :\n"
	       "memory : affiche l'intégralité de la mémoire\n"
	       "display X : affiche le contenu de l'adresse X à chaque pas."
	       "\nX : affiche le contenu de l'adresse X.\n"
	       "X Y : affiche le contenu de toutes les adresse de X à Y.\n"
	       "quit : arrête l'exécution\n"
	       "Les adresses doivent être données en hexadécimal\n");
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
	       "Usage : %s [-s] fichier\nL'option -s active le stepper",
	       argv[0]
	       );
      usage(buffer);
    }
  
  int ram[512];         // Mémoire + Pile
  unsigned int PC;      // Compteur de programme.
  int A;                // Accumulateur.
  int *stack = ram + 256;       // Pile.
  int stack_count = 0;   // Compteur de pile.
  int rom[256];        // Mémoire en lecture seule contenant des fonctions. 
  PC = charger_hexcode(fichier, ram);
  charger_hexcode(ROM_FILE, rom);
  //int *rom = charger_rom(ROM_FILE);
  
  /* op est un opcode, c'est un unsigned char pour faciliter la conversion 
     décimal => hexadécimal dans la fonction executer (évite les case 
     négatifs). */
  //unsigned char op;
  /*   arg est un argument, c'est un unsigned char car arg est utilisé comme 
     index de ram il ne peut donc être négatif. */
  //unsigned char arg;

  // Boucle principale.
  while (1)
    {
      //op = ram[PC];
      //arg = ram[PC + 1];
       
      if (stepper)
	step(PC, A, ram);
      executer(&PC, &A, ram, stack, &stack_count, rom);
    }
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
convertis en char avant d'être rangés dans le vecteur mémoire.
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
      offset = strtoc(tampon);
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
      mem[i++] = strtoc(tampon);
    }
  while (fscanf(flux, " %[^\n ]", tampon) != EOF);
  return offset;
}

/*int* charger_rom(char *fichier)
{
  FILE *flux = fopen(fichier, "r");
  if (!flux)
    {
      char tampon[1024];
      snprintf(tampon, 1023, "Impossible d'ouvrir le fichier %s",
	       nom_fichier);
      usage(tampon);
    }
  // A FINIR
  return NULL;
  }*/

void executer(unsigned int *PC_pt, int *A_pt, int *ram, int *stack,
	      int *stack_count_pt, int *rom)
/*
Fonction qui exécute une instruction en fonction de l'opcode et de l'argument
fourni.
op étant un unsigned char, les opcodes ont été traduits en décimal dans les 
case.
*/
{
  static int mem_space = RAM;
  unsigned int op, arg;
  op = mem_space == RAM ? ram[(*PC_pt)++] : rom[(*PC_pt)++];
  arg = mem_space == RAM ? ram[(*PC_pt)++] : rom[(*PC_pt)++];
  //  *PC_pt += 2;
  
  char c;
  switch (op)
    {
    case 0x0 : *A_pt = arg; break;                        // LOAD #
    case 0x4 : *A_pt = stack[--(*stack_count_pt)]; break; // POP
    case 0x5 : stack[(*stack_count_pt)++] = *A_pt; break; // PUSH
    case 0x6 : --(*stack_count_pt); break;                // POP #
    case 0x7 : stack[(*stack_count_pt)++] = arg; break;   // PUSH #
    case 0x10 : *PC_pt = arg; break;                      // JUMP
    case 0x11 : if (*A_pt < 0) *PC_pt = arg; break;       // BRN
    case 0x12 : if (!*A_pt) *PC_pt = arg; break;          // BRZ
    case 0x13 : *PC_pt = arg;                             // SJMP
      mem_space = mem_space == RAM ? ROM : RAM;
      break;
    case 0x20 : *A_pt += arg; break;                      // ADD #
    case 0x21 : *A_pt -= arg; break;                      // SUB #
    case 0x22 : *A_pt = ~(*A_pt & arg); break;            // NAND #
      /*    case 0x23 : *A_pt *= arg; break;                      // MUL #
    case 0x24 : *A_pt /= arg; break;                      // DIV #
    case 0x25 : *A_pt %= arg; break;                      // MOD #*/
    case 0x40 : *A_pt = ram[arg]; break;                  // LOAD a
    case 0x41 : printf("out : %d\n", ram[arg]);           // OUT a
      /*arrête la boucle d'exécution le temps pour l'utilisateur de voir la 
        sortie et vide le flux entrant */
      while ((c = getchar() !='\n') && c != EOF) {}; break;
    case 0x44 : ram[arg] = stack[--(*stack_count_pt)]; break; // POP a
    case 0x45 : stack[(*stack_count_pt)++] = ram[arg]; break; // PUSH a
    case 0x48 : ram[arg] = *A_pt; break;           // STORE a  
    case 0x49 : ram[arg] = recup_entree(); break;  // IN a
    case 0x60 : *A_pt += ram[arg]; break;          // ADD a
    case 0x61 : *A_pt -= ram[arg]; break;          // SUB a
    case 0x62 : *A_pt = ~(*A_pt & ram[arg]); break;// NAND a
      /*    case 0x63 : *A_pt *= ram[arg]; break;          // MUL a
    case 0x64 : *A_pt /= ram[arg]; break;          // DIV a
    case 0x65 : *A_pt %= ram[arg]; break;          // MOD a*/
    case 0x80 : *A_pt = stack[(*stack_count) - arg]; break;        // LOAD %a
    case 0x81 : printf("out : %d\n", stack[(*stack_count) - arg]); // OUT %a
      while ((c = getchar() !='\n') && c != EOF) {}; break;
    case 0x88 : stack[(*stack_count) - arg] = *A_pt; break;       // STORE %a
    case 0x89 : stack[(*stack_count) - arg] = recup_entree(); break; // IN %a
    case 0xA0 : *A_pt += stack[(*stack_count) - arg]; break;    // ADD %a
    case 0xA1 : *A_pt -= stack[(*stack_count) - arg]; break;    // SUB %a
    case 0xA2 : *A_pt = ~(*A_pt & stack[(*stack_count) - arg]); // NAND %a
      break;
      /*    case 0xA3 : *A_pt *= stack[(*stack_count) - arg]; break;    // MUL %a
    case 0xA4 : *A_pt /= stack[(*stack_count) - arg]; break;    // DIV %a
    case 0xA5 : *A_pt %= stack[(*stack_count) - arg]; break;    // MOD %a*/
    case 0xC0 : *A_pt = ram[(unsigned int)ram[arg]]; break;      // LOAD *a
    case 0xC1 : printf("out : %d\n", ram[(unsigned int)ram[arg]]);// OUT *a
      while ((c = getchar() !='\n') && c != EOF) {}; break;
    case 0xC4 : ram[(unsigned int)ram[arg]] = stack[--(*stack_count_pt)];
      break;                                                     //POP *a
    case 0xC5 : stack[(*stack_count_pt)++] = ram[(unsigned int)ram[arg]];
      break;                                                     //PUSH *a
    case 0xC8 : ram[(unsigned int)ram[arg]] = *A_pt; break;     // STORE *a
    case 0xC9 : ram[(unsigned int)ram[arg]] = recup_entree();   // IN *a
      break;
    case 0xD0 : *A_pt = ram[(unsigned int)stack[(*stack_count) - arg]]; break;      // LOAD *%a
    case 0xD1 :                                                   // OUT *%a
      printf("out : %d\n", ram[(unsigned int)stack[(*stack_count) - arg]]);
      while ((c = getchar() !='\n') && c != EOF) {}; break;
    case 0xD8 : ram[(unsigned int)stack[(*stack_count) - arg]] = *A_pt;
      break;                                                     // STORE *%a
    case 0xD9 :                                                  // IN *%a
      ram[(unsigned int)stack[(*stack_count) - arg]] = recup_entree();
      break;
    case 0xE0 : *A_pt += ram[(unsigned int)ram[arg]]; break;    // ADD *a
    case 0xE1 : *A_pt -= ram[(unsigned int)ram[arg]]; break;    // SUB *a
    case 0xE2 : *A_pt = ~(*A_pt & ram[(unsigned int)ram[arg]]); // NAND *a
      break;
/*    case 0xE3 : *A_pt *= ram[(unsigned int)ram[arg]]; break;    // MUL *a
    case 0xE4 : *A_pt /= ram[(unsigned int)ram[arg]]; break;    // DIV *a
    case 0xE5 : *A_pt %= ram[(unsigned int)ram[arg]]; break;    // MOD *a*/
    case 0xF0 : *A_pt += ram[(unsigned int)stack[(*stack_count) - arg]];
      break;                                                     // ADD *%a
    case 0xF1 : *A_pt -= ram[(unsigned int)stack[(*stack_count) - arg]];
      break;                                                     // SUB *%a
    case 0xF2 :                                                  // NAND *%a
      *A_pt = ~(*A_pt & ram[(unsigned int)stack[(*stack_count) - arg]]); 
      break;
      /*case 0xF3 : *A_pt *= ram[(unsigned int)stack[(*stack_count) - arg]];
      break;                                                     // MUL *%a
    case 0xF4 : *A_pt /= ram[(unsigned int)stack[(*stack_count) - arg]];
      break;                                                     // DIV *%a
    case 0xF5 : *A_pt %= ram[(unsigned int)stack[(*stack_count) - arg]];
    break;                                                     // MOD *%a*/
    default : printf("ligne %x, op : %x\n", *PC_pt, op);
      usage("Erreur : opcode inconnu."); break;
    }
}

char strtoi(char * chaine)
/*
Fonction qui convertit un code ou une adresse (nombre hexadécimal entre 00 et
FF) en un int. Provoque une erreur si l'on essaie de convertir autre
chose.

Prend une chaine en argument et renvoie celle-ci convertie en int.
 */
{
  if (strlen(chaine) != 2)
    usage("Contenu du fichier incorrect : les codes doivent avoir une "
	  "longueur de deux caractères");
  int i;
  unsigned int * end;
  i = strtol(chaine, &end, 16);
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
  return c;
}

char recup_entree(void)
/*
Fonction qui permet de récupérer l'entrée de l'utilisateur à l'aide de scanf, 
s'il ne propose pas une entrée valide (un nombre entre -128 et 127) celui-ci 
devra recommencer.

Renvoie le nombre entré par l'utilisateur.
*/
{
  char * end;
  long int i;
  //char c;
  char tampon[32];
  bool loop = true;
  do
    {
      printf("in ? ");
      /* 
      On scanne 31 caractères pour le cas où l'utilisateur entre des zéros 
      non significatifs à gauche du nombre. S'il entre moins de 29 zéros non 
      significatifs, son nombre sera tout de même pris en compte par le 
      programme, au delà non mais on considérera qu'il l'a bien mérité. 
      */
      scanf(" %31s", tampon);
      while ((c = getchar() !='\n') && c != EOF) {}; //vide le flux entrant
      i = strtol(tampon, &end, 10);

      if (i < -128 || i > 127 || (*end != '\n' && *end != 0))
	{
	  puts("Saisissez un nombre entre -128 et 127");
	}
      else
	{
	  loop = false;
	}
    } while (loop);
  
  //c = (char) i;
      puts("");
  return i;
}
 
void step(unsigned int PC, int A, int *ram)
/* 
Fonction qui affiche les valeurs de A et PC, les adresses dont l'utilisateur
a demandé le display puis l'instruction en cours.
Elle propose ensuite à l'utilisateur d'entrer une commande.
*/
{
  /*Vecteur qui recueille les adresses dont l'utilisateur a demandé
    l'affichage */
  static unsigned int display[256] = {0};
  /*Variable qui conserve l'indice de la prochaine case libre dans le vecteur
    display */
  static int display_count = 0;

  unsigned int op = ram[PC];
  unsigned int arg = ram[PC + 1];
  
  printf("A : %x, PC : %x\n", A, PC);
  for (int i = 0; i < display_count; i++)
    printf("%x : %x\n", display[i], ram[display[i]]);
  print_instruction(op, arg, PC);
  get_user_input(display, &display_count, ram);
  puts("");
}

void get_user_input(unsigned int *display, int *display_count_pt, int *ram)
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
      parse_input(tampon, display, display_count_pt, ram);
    }
}

void parse_input(char *tampon, unsigned int *display, int *display_count_pt,
		 int *ram)
/*
Fonction qui analyse les entrées de l'utilisateur lors du stepper et effectue
le traitement adéquat.
*/
{
  char *elt = strtok(tampon, " ");
  if (!strcmp(elt, "display"))
    {
      char *suite = strtok(NULL, " ");
      //Si l'utilisateur a entré display [une adresse valide]
      if (adresse(suite))
	//On ajoute cette adresse au vecteur des adresse à afficher
	display[(*display_count_pt)++] = strtol(suite, NULL, 16);
    }
  //Si l'entrée est memory, on affiche l'ensemble de la mémoire.
  else if (!strcmp(elt, "memory\n"))
    print_mem(ram);
  else if (!strcmp(elt, "stack\n"))
    print_mem(ram + 256);
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
  //printf("\n\t_\t_\t_\t_\t_\t_\t_\t_\t_\t_\t_\t_\t_\t_\t_\t_\n");
  for (int i = 0; i < 127; i++)
    printf("-");
  puts("");
  for (int i = 0; i <= 240; i += 16)
    {
      printf("%x |\t", i / 16);
      for (int j = i; j < i + 16; j++)
	printf("%x\t", ram[j]);
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
    switch (op)
    {
    case 0x0 : printf("LOAD #%x : A <- %x\n", arg, arg); break;
    case 0x4 : printf("POP : A <- *(SP), SP--\n"); break;
    case 0x5 : printf("PUSH : *(SP) <- A, SP++\n"); break;
    case 0x6 : printf("POP # : SP--\n"); break;
    case 0x7 : printf("PUSH # : *(SP) <- %x, SP++\n", arg); break;
    case 0x10 : printf("JUMP %x : PC <- %x\n", arg, arg); break;
    case 0x11 : printf("BRN %x : if (A < 0) PC <- %x\n", arg, arg); break;
    case 0x12 : printf("BRZ %x : if (A = 0) PC <- %x\n", arg, arg); break;
    case 0x13 : printf("SJMP %x : PC <- %x\n (changement d'espace mémoire)",
		       arg);
      break;
    case 0x20 : printf("ADD #%x : A <- A + %x\n", arg, arg); break;
    case 0x21 : printf("SUB #%x : A <- A - %x\n", arg, arg); break;
    case 0x22 : printf("NAND #%x : A <- ~(A & %x)\n", arg, arg); break;
      /*case 0x23 : printf("MUL #%x : A <- A * %x\n", arg, arg); break;
    case 0x24 : printf("DIV #%x : A <- A / %x\n", arg, arg); break;
    case 0x25 : printf("MOD #%x : A <- A % %x\n", arg, arg); break;*/
    case 0x40 : printf("LOAD %x : A <- (%x)\n", arg, arg); break;
    case 0x41 : printf("OUT %x : out <- (%x)\n", arg, arg); break;
    case 0x44 : printf("POP %x: (%x) <- *(SP), SP--\n", arg, arg); break;
    case 0x45 : printf("PUSH %x: *(SP) <- (%x), SP++\n", arg, arg); break;
    case 0x48 : printf("STORE %x : (%x) <- A\n", arg, arg); break;
    case 0x49 : printf("IN %x : (%x) <- in\n", arg, arg); break;
    case 0x60 : printf("ADD %x : A <- A + (%x)\n", arg, arg); break;
    case 0x61 : printf("SUB %x : A <- A - (%x)\n", arg, arg); break;
    case 0x62 : printf("NAND %x : A <- ~ (A & (%x))\n", arg, arg); break;
      /*case 0x63 : printf("MUL %x : A <- A * (%x)\n", arg, arg); break;
    case 0x64 : printf("DIV %x : A <- A / (%x)\n", arg, arg); break;
    case 0x65 : printf("MOD %x : A <- A % (%x)\n", arg, arg); break;*/
    case 0x80 : printf("LOAD %%%x : A <- *(SP - %x)\n", arg, arg); break;
    case 0x81 : printf("OUT %%%x : out <- *(SP - %x)\n", arg, arg); break;
    case 0x88 : printf("STORE %%%x : *(SP - %x) <- A\n", arg, arg); break;
    case 0x89 : printf("IN %%%x : *(SP - %x) <- in\n", arg, arg); break;
    case 0xA0 : printf("ADD %%%x : A <- A + *(SP - %x)\n", arg, arg); break;
    case 0xA1 : printf("SUB %%%x : A <- A - *(SP - %x)\n", arg, arg); break;
    case 0xA2 : printf("NAND %%%x : A <- ~(A & *(SP - %x))\n", arg, arg);
      break;
  /*case 0xA3 : printf("MUL %%%x : A <- A * *(SP - %x)\n", arg, arg); break;
    case 0xA4 : printf("DIV %%%x : A <- A / *(SP - %x)\n", arg, arg); break;
   case 0xA5 : printf("MOD %%%x : A <- A % *(SP - %x)\n", arg, arg); break;*/
    case 0xC0 : printf("LOAD *%x : A <- *(%x)\n", arg, arg); break;
    case 0xC1 : printf("OUT *%x : out <- *(%x)\n", arg, arg); break;
    case 0xC4 : printf("POP *%x: *(%x) <- *(SP), SP--\n", arg, arg); break;
    case 0xC5 : printf("PUSH *%x: *(SP) <- *(%x), SP++\n", arg, arg); break;
    case 0xC8 : printf("STORE *%x : *(%x) <- A\n", arg, arg); break;
    case 0xC9 : printf("IN *%x : *(%x) <- in\n", arg, arg); break;
    case 0xD0 : printf("LOAD *%%%x : A <- *(*(SP - %x))\n", arg, arg); break;
    case 0xD1 : printf("OUT *%%%x : out <- *(*(SP - %x))\n", arg, arg);
      break;
    case 0xD8 : printf("STORE *%%%x : *(*(SP - %x)) <- A\n", arg, arg);
      break;
    case 0xD9 : printf("IN *%%%x : *(*(SP - %x)) <- in\n", arg, arg); break;
    case 0xE0 : printf("ADD *%x : A <- A + *(%x)\n", arg, arg); break;
    case 0xE1 : printf("SUB *%x : A <- A - *(%x)\n", arg, arg); break;
    case 0xE2 : printf("NAND *%x : A <- ~(A & *(%x))\n", arg, arg); break;
      /*case 0xE3 : printf("MUL *%x : A <- A * *(%x)\n", arg, arg); break;
    case 0xE4 : printf("DIV *%x : A <- A / *(%x)\n", arg, arg); break;
    case 0xE5 : printf("MOD *%x : A <- A % *(%x)\n", arg, arg); break;*/
    case 0xF0 : printf("ADD *%x : A <- A + *(*(SP - %x))\n", arg, arg);
      break;
    case 0xF1 : printf("SUB *%x : A <- A - *(*(SP - %x))\n", arg, arg);
      break;
    case 0xF2 : printf("NAND *%x : A <- ~(A & *(*(SP - %x)))\n", arg, arg);
      break;
    default : printf("ligne %x, op : %x", PC, op);
      usage("Erreur : opcode inconnu."); break;
    }
}
