[org 100h]
jmp start

xn: dw 0
prev: dw 0
loc: dw 0
running: dw 1
tickcount: dw 0
score: dw 0
step: dw 2
oldisr: dd 0
oldisr1: dd 0

printnum:
    push bp
    mov bp, sp
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax, 0xb800
    mov es, ax
    mov ax, [bp+4]
    mov bx, 10
    mov cx, 0
   
   nextdigit:
        mov dx, 0 ; zero upper half of dividend
        div bx ; divide by 10
        add dl, 0x30 ; convert digit into ascii value
        push dx ; save ascii value on stack
        inc cx ; increment count of values
        cmp ax, 0 ; is the quotient zero
        jnz nextdigit ; if no divide it again
        mov di, [bp+6] ; point di to top left column
 
  nextpos:
        pop dx ; remove a digit from the stack
        mov dh, 0x07 ; use normal attribute
        mov [es:di], dx ; print char on screen
        add di, 2 ; move to next screen location
        loop nextpos ; repeat for all digits on stack
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop bp
    ret 4

multiply:
  push bp
  mov bp,sp
  push ax
  push bx
  push cx
  push dx
  mov ax,0
  mov bx,[bp+4]
  mov cx,[bp+6]
  cmp cx,0
  je skip
  addLoop:
    add ax,bx
    loop addLoop
 
 skip:
  mov [bp+8],ax
  pop dx
  pop cx
  pop bx
  pop ax
  pop bp
  ret 4

mod:
  push bp
  mov bp,sp
  push ax
  push bx
  mov ax,[bp+6]
  mov bx,[bp+4]
 
 modLoop:
    cmp ax,bx
    jb end
    sub ax,bx
    jmp modLoop
 
 end:
  mov [bp+8],ax
  pop bx
  pop ax
  pop bp
  ret 4

rand:
  push bp
  mov bp,sp
  push ax
  push bx
  mov ax,[xn]
  push 0
  push 23
  push ax
  call multiply
  pop ax
  add ax,45
  push 0
  push ax
  push 7901
  call mod
  pop ax
  mov [xn],ax
  push 0
  push ax
  mov bx,[bp+4]
  push bx
  call mod
  pop ax
  mov [bp+6],ax
  pop bx
  pop ax
  pop bp
  ret 2

timer:
  push ax
  push es
  push di
  push dx
  push cx
  push bx
  inc word [cs:tickcount]; increment tick count
  mov ax,[cs:tickcount]
  cmp ax,18
  je printDat
  jmp endSub
 
 printDat:
    mov word[cs:tickcount],0
    mov ax,0xb800
    mov es,ax
    mov di,[cs:prev]
    cmp di,0
    jl endGame
    cmp di,3998
    jg endGame
    mov word[es:di],0x0720
    mov di,[cs:loc]
    mov dx,[es:di]
    mov word[es:di],0x072a
    mov ax,[cs:loc]
    mov [prev],ax
    mov ax,[cs:step]
    add word [cs:loc],ax
    cmp dx,0x2020 ; stepped on green square
    je addScore
      mov ax,[cs:score]
    push 150
    push ax
    call printnum
    cmp dx,0x4020
    jne endSub
   
endGame:
      mov word [cs:running],0
      jmp endSub
   
addScore:
      inc word [cs:score]
      mov ax,[score]
      push 150
      push ax
      call printnum
 
 endSub:
  mov al, 0x20
  out 0x20, al ; end of interrupt
  pop bx
  pop cx
  pop dx
  pop di
  pop es
  pop ax
  iret ; return from interrupt

kbisr:
  push ax
  push es
  push di
  mov ax, 0xb800
  mov es, ax ; point es to video memory
  mov di,0
  in al, 0x60 ; read a char from keyboard port
  cmp al,0x50
  je Down
  cmp al,0x4B
  je Left
  cmp al,0x48
  je Up
  cmp al,0x4D
  je Right
  jmp endKbisr
 
  Down:
    mov ax,0xb800
    mov es,ax
    mov di,[prev]
    mov word [es:di],0x0A20
    add di,160
    mov [loc],di
    mov word [step],160
    jmp endKbisr
 
 Up:
    mov ax,0xb800
    mov es,ax
    mov di,[prev]
    mov word [es:di],0x0A20
    sub di,160
    mov [loc],di
    mov word [step],-160
    jmp endKbisr
 
  Left:
    mov ax,0xb800
    mov es,ax
    mov di,[prev]
    mov word [es:di],0x0A20
    sub di,2
    mov [loc],di
    mov word [step],-2
    jmp endKbisr
 
 Right:
    mov ax,0xb800
    mov es,ax
    mov di,[prev]
    mov word [es:di],0x0A20
    add di,2
    mov [loc],di
    mov word [step],2
 
 endKbisr:
  mov al,0x20
  out 0x20,al
  pop di
  pop es
  pop ax
  iret

start:
  mov ah,0
  int 1ah ; interrupt to get clock ticks till midnight in cx:dx
  mov [xn],dx ; give seed to random number generator
  mov di,0
  mov ax,0xb800
  mov es,ax
  mov bx,2000
 
 outerloop:
    push 0
    push 30
    call rand
    pop ax
    cmp ax,0
    je color
    mov ax,0x2020
    jmp doTheThing
   
   color:
      cmp di,0
      je dont
      mov ax,0x0A20
      jmp doTheThing
     
dont:
      mov ax,0x2020 ;
   
   doTheThing:
      mov [es:di],ax
    add di,2
    dec bx
    jnz outerloop
  mov word[es:0],0x072a
  mov ax,0
  mov es,ax
  cli
  mov ax,[es:8*4]
  mov [oldisr],ax
  mov word [es:8*4],timer
  mov ax,[es:8*4+2]
  mov [oldisr+2],ax
  mov word [es:8*4+2],cs
  mov ax,[es:9*4]
  mov [oldisr1],ax
  mov ax,[es:9*4+2]
  mov [oldisr1+2],ax
  mov word[es:9*4],kbisr
  mov word[es:9*4+2],cs
  sti

  l1:
    mov ax,[running]
    cmp ax,1
    je l1
  cli
   mov ax,[oldisr]
   mov word [es:8*4],ax
   mov ax,[oldisr+2]
   mov word [es:8*4+2],ax
   mov ax,[oldisr1]
   mov word [es:9*4],ax
   mov ax,[oldisr1+2]
   mov word [es:9*4+2],ax
  sti
 
 exit:
  mov ax,0x4c00
  int 21h