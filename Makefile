.PHONY: op pasm opc

all : op pasm opc

recompile : clean all

clean : op_clean pasm_clean opc_clean

debug : op_debug pasm_debug opc_debug

install : op_install pasm_install opc_install install_doc install_rom

uninstall : op_uninstall pasm_uninstall opc_uninstall uninstall_doc uninstall_rom

install_doc : install_op_doc install_pasm_doc install_opc_doc install_asm_papier_doc install_microbe_doc

uninstall_doc : uninstall_op_doc uninstall_pasm_doc uninstall_opc_doc uninstall_asm_papier_doc uninstall_microbe_doc

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

install_op_doc :
	if [ ! -d ~/.local/share/man/man1 ]; then mkdir ~/.local/share/man/man1; fi
	install -m 0644 doc/op.1 ~/.local/share/man/man1
	gzip ~/.local/share/man/man1/op.1

uninstall_op_doc : 
	-rm ~/.local/share/man/man1/op.1.gz

install_pasm_doc :
	if [ ! -d ~/.local/share/man/man1 ]; then mkdir ~/.local/share/man/man1; fi
	install -m 0644 doc/pasm.1 ~/.local/share/man/man1
	gzip ~/.local/share/man/man1/pasm.1

uninstall_pasm_doc : 
	-rm ~/.local/share/man/man1/pasm.1.gz

install_asm_papier_doc :
	if [ ! -d ~/.local/share/man/man7 ]; then mkdir ~/.local/share/man/man7; fi
	install -m 0644 doc/asm-papier.7 ~/.local/share/man/man7
	gzip ~/.local/share/man/man7/asm-papier.7

uninstall_asm_papier_doc :
	-rm ~/.local/share/man/man7/asm-papier.7.gz

install_opc_doc :	
	if [ ! -d ~/.local/share/man/man1 ]; then mkdir ~/.local/share/man/man1; fi
	install -m 0644 doc/opc.1 ~/.local/share/man/man1
	gzip ~/.local/share/man/man1/opc.1

uninstall_opc_doc : 
	-rm ~/.local/share/man/man1/opc.1.gz

install_microbe_doc :
	if [ ! -d ~/.local/share/man/man7 ]; then mkdir ~/.local/share/man/man7; fi
	install -m 0644 doc/microbe.7 ~/.local/share/man/man7
	gzip ~/.local/share/man/man7/microbe.7

uninstall_microbe_doc :
	-rm ~/.local/share/man/man7/microbe.7.gz

install_rom :
	if [ ! -d ~/.local/share/op/ ]; then mkdir ~/.local/share/op; fi
	install rom/rom ~/.local/share/op/
	install rom/rom_addr ~/.local/share/op

uninstall_rom :
	-rm ~/.local/share/op/rom ~/.local/share/op/rom_addr
	-rmdir ~/.local/share/op
