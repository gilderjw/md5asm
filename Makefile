all: md5.asm
	nasm -felf64 -g md5.asm
	ld md5.o -o md5

clean:
	rm md5.o
	rm md5
