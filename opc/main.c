#include <stdlib.h>
#include <stdio.h>
#include "expr.h"
#include "opc.tab.h"


int main(int argc, char **argv)
{
  freopen(argv[1], "r", stdin);
  yyparse();
  return 0;
}
