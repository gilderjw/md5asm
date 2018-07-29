section .text
global _start

_start:
  push rbp
  mov rbp, rsp
  sub rsp, 0xa0 

  ; ; print out greeting
  ; mov rax, 1
  ; mov rdi, 1
  ; mov rsi, msg
  ; mov rdx, len
  ; syscall

  ; check argc
  mov r8, [rbp+8]
  cmp r8, 2
  jne bad_argc

  ; get file name from argv[1]
  mov rsi, [rbp+24]
  call strlen
  mov r8, rdx
  add r8, rsi
  mov byte [r8], 0xa                ; add a new line to end of user input
  add rdx, 1

  ; ; print filename
  ; mov rax, 1
  ; syscall

  mov byte [rsi + rdx - 1], 0       ; null terminate the filename

  ; open file
  mov rax, 2                        ; sys_open
  mov rdi, rsi                      ; file name
  xor rsi, rsi                      ; O_RDONLY
  syscall

  cmp rax, -1
  jle no_file
  mov [rbp-8], rax                  ; save fd

  ; get length of input file
  mov rdi, rax                      ; fd to check
  mov rax, 5                        ; sys_fstat
  lea rsi, [rbp - 0xa0]             ; address to write struct
  syscall

  mov rbx, [rbp - 0x70]             ; rbx = size of file
  mov r8, rbx

  ; calculate how much padding we need
  xor edx, edx
  mov rax, rbx
  mov rcx, 512
  div rcx                           ; rdx = size of file % 512
  sub rcx, rdx                      ; rcx = amount of padding
  add rbx, rcx                      ; rbx = amount of heap to allocate

  ; get heap address
  mov rax, 12                       ; sys_brk
  mov rdi, 0                        ; invalid addr
  syscall

  ; request more heap space
  add rax, rbx                      ; request file length + padding
  mov rdi, rax
  mov rax, 12                       ; sys_brk
  syscall

  ; write file contents to heap
  mov rsi, rax
  sub rsi, rbx                      ; write file on the heap
  mov rax, 0                        ; sys_read
  mov rdi, [rbp-8]                  ; fd
  mov rdx, r8                       ; read file length
  syscall

  ; pad message with 0's
  mov rcx, rbx
set_zero:
  mov byte [rcx + rsi], 0
  cmp rcx, rbx
  loope set_zero

  ; add 1 to the pad
  mov byte [r8 + rsi], 0x80

  ; add the original length to pad
  shl r8, 3
  mov qword [rsi + rbx - 8], r8

  ; print out message
  mov rax, 1
  mov rdi, 1
  mov rdx, rbx
  syscall

  ; set up IV

  mov r12d, 0x67452301  ; a0
  mov r13d, 0xefcdab89  ; b0
  mov r14d, 0x98badcfe  ; c0
  mov r15d, 0x10325476  ; d0

  ; TODO: turn this into a loop for messages > 512 bytes
  mov r8d, r12d   ; A
  mov r9d, r13d   ; B
  mov r10d, r14d  ; C
  mov r11d, r15d  ; D

  xor rcx, rcx
  xor rbx, rbx
main_loop:
  cmp ecx, 48
  jge I48_63
  cmp ecx, 32
  jge I32_47
  cmp ecx, 16
  jge I16_31

I1_15:
  ; F
  mov eax, r11d
  xor eax, r10d
  and eax, r9d
  xor eax, r11d

  ; G
  mov ebx, ecx
  jmp prolog
I16_31:
  ; G
  mov eax, ecx
  mov edx, 5
  mul edx
  inc eax
  xor edx, edx
  mov ebx, 16
  div ebx
  mov ebx, edx

  ; F
  mov eax, r10d
  xor eax, r9d
  and eax, r11d
  xor eax, r10d

  jmp prolog
I32_47:
  ; G
  mov eax, ecx
  mov edx, 3
  mul edx
  add eax, 5
  xor edx, edx
  mov ebx, 16
  div ebx
  mov ebx, edx

  ; F
  mov eax, r9d
  xor eax, r10d
  xor eax, r11d
  jmp prolog
I48_63:
  ; G
  mov eax, ecx
  mov edx, 7
  mul edx
  xor edx, edx
  mov ebx, 16
  div ebx
  mov ebx, edx

  ; F
  mov eax, r11d
  xor eax, 0xFFFFFFFF
  or eax, r9d
  xor eax, r10d

prolog:
  ; F = F + A + K[i] + M[g]

  ; F += M[g]
  shl ebx, 5
  mov ebx, dword [rsi + rbx]
  add eax, ebx

  ; F += A
  add eax, r8d

  ;F += K[i]
  mov edx, ecx
  shl ecx, 2
  add eax, dword [ecx + K]

  mov r8d, r11d
  mov r11d, r10d
  mov r10d, r9d

  mov cl, byte [s + edx]
  rol eax, cl
  add r9d, eax

  mov ecx, edx
  ; int 3
  inc ecx
  cmp ecx, 63
  jle main_loop

  add r12d, r8d
  add r13d, r9d
  add r14d, r10d
  add r15d, r11d


  int 3
  ; exit(0)
  mov eax, 60
  xor rdi, rdi
  syscall


strlen:                             ; rsi -> rdx
  push rbp
  mov rbp, rsp
  lea rdx, [rsi - 1]
  _loop:
    inc rdx
    mov cl, [rdx]
    cmp cl, 0
    jne _loop
  sub rdx, rsi
  leave
  ret

bad_argc:
  mov rax, 1
  mov rdi, 1
  mov rsi, badargc
  mov rdx, badargclen
  syscall

  mov eax, 60
  mov rdi, 1
  syscall

no_file:
  mov rax, 1
  mov rdi, 1
  mov rsi, bfn_msg
  mov rdx, bfn_len
  syscall

  mov eax, 60
  mov rdi, 2
  syscall

section .data
  msg           db 'fap swag', 0xa
  len           equ $ - msg
  badargc       db 'invalid number of arguments', 0xa
  badargclen    equ $ - badargc
  bfn_msg       db 'bad filename', 0xa
  bfn_len       equ $ - bfn_msg
  K             dd 0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee
                dd 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501
                dd 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be
                dd 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821
                dd 0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa
                dd 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8
                dd 0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed
                dd 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a
                dd 0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c
                dd 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70
                dd 0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05
                dd 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665
                dd 0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039
                dd 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1
                dd 0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1
                dd 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
; per-round shift amounts
  s             db 7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22
                db 5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20
                db 4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23
                db 6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21
