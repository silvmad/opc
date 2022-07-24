.PHONY: op pasm opc

all : op pasm opc

recompile : clean all

clean : op_clean pasm_clean

debug : op_debug pasm_debug

op :
	$(MAKE) -C op/

pasm :
	$(MAKE) -C pasm/

opc :
	$(MAKE) -C opc/

op_clean :
	$(MAKE) -C op/ clean

pasm_clean :
	$(MAKE) -C pasm/ clean

opc_clean :
	$(MAKE) -C opc/ clean

op_debug :
	$(MAKE) -C op/ debug

pasm_debug :
	$(MAKE) -C pasm/ debug

opc_debug :
	$(MAKE) -C opc/ debug
