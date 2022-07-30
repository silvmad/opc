.PHONY: op pasm opc

all : op pasm opc

recompile : clean all

clean : op_clean pasm_clean opc_clean

debug : op_debug pasm_debug opc_debug

install : op_install pasm_install opc_install

uninstall : op_uninstall pasm_uninstall opc_uninstall

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

op_install :
	$(MAKE) -C op/ install

pasm_install :
	$(MAKE) -C pasm/ install

opc_install :
	$(MAKE) -C opc/ install

op_uninstall :
	$(MAKE) -C op/ uninstall

pasm_uninstall :
	$(MAKE) -C pasm/ uninstall

opc_uninstall :
	$(MAKE) -C opc/ uninstall

