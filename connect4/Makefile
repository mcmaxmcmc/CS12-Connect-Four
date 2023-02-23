connect4: connect4.o ../cs12Lib/cs12Lib.o
	ld -g -o connect4 connect4.o ../cs12Lib/cs12Lib.o

connect4.o: connect4.asm
	yasm -Worphan-labels -g dwarf2 -f elf64 connect4.asm -l connect4.lst

clean: 
	rm -f connect4
	rm -f connect4.o 
	rm -f connect4.lst 

