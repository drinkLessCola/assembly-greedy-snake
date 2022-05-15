DATAS SEGMENT
  ;此处输入数据段代码 
  count db 18 
  gameover db 1
	; 上0 右1 下2 左3
	dir db 1
	snake_max_len db 200

	;方向键
	keyUp db 77h
	keyDown db 73h
	keyLeft db 61h
	keyRight db 64h
	keyEnter db 0dh
	keyEsc db 27

	; 蛇的信息
	; snake 每个元素占 4 个字节，其中
	; 第一个字节表示结点的 y 坐标
	; 第二个字节表示结点的 x 坐标

	snake db 05,14,200 dup(?,?)
	snake_len dw 1
	snake_head_dir db 1
	snake_tail_dir db 1

	; 食物信息
	food_pos dw 1A08h

	; 游戏状态信息
	score dw 0
	gameover_msg db 'Game over! (Esc)','$'
	gameready_msg db 'Press [Enter] to start the game','$'
	score_msg db 'Score:','$'

	oldX db ?
	oldY db	?
  old1ch dd 0
DATAS ENDS

STACKS SEGMENT
    ;此处输入堆栈段代码
STACKS ENDS

CODES SEGMENT
  ASSUME CS:CODES,DS:DATAS,SS:STACKS
;-----------------------------------
; main
;-----------------------------------
main proc far
	START:
	MOV AX,DATAS
	MOV DS,AX
	
	call printGameReadyMsg
	waitToStart:
	mov ah,01
	int 21h
	cmp al,keyEnter
	jnz waitToStart

	;保存旧的 1CH 中断向量
	MOV AL,1CH
	MOV AH,35H
	int 21h
	mov word ptr old1ch, es
	mov word ptr old1ch+2,bx
	push ds
    
	;设置新的 1CH 中断向量
	mov dx,offset new_int_1ch
	mov ax,seg new_int_1ch
	mov ds,ax
	mov al,1ch
	mov ah,25h
	int 21h
	
	
	pop ds
	in al,21h
	and al,11111110b
	out 21h,al
	sti
	
	;游戏进行中
	playing:
	cmp gameover,0
	jz main_end
	
	call listenKeyPress
	cmp al,keyUp
	jz setUp
	cmp al,keyDown
	jz setDown
	cmp al,keyLeft
	jz setLeft
	cmp al,keyRight
	jz setRight
	jmp playing

	;设置方向
	setUp:
	mov dir,0
	jmp playing
	setRight:
	mov dir,1
	jmp playing
	setDown:
	mov dir,2
	jmp playing
	setLeft:
	mov dir,3
	jmp playing


	;恢复 1CH 中断向量
	main_end:
	mov dx,word ptr old1ch
	mov ds,word ptr old1ch+2
	mov al,1ch
	mov ah,25h
	int 21h

	waitToExit:
	mov ah,01h
	int 21H
	cmp al,keyEsc
	jnz waitToExit
	
	mov dl,'u'
	mov ah,02h
	int 21h

	MOV AH,4CH
	INT 21H
main endp

;-----------------------------------
; new_int_1ch 新的时钟中断处理程序
;-----------------------------------
new_int_1ch proc near
	push ds
	push ax
	push bx
	push cx
	push dx

	mov ax,datas
	mov ds,ax
	cmp gameover,0
	je exit
	sti

	; 0.5s 执行一次
	dec count
	jnz exit
	mov count,9
	call clearScreen			;清屏
	call drawFood					;渲染食物
	call printScoreMsg		;打印分数
	call snakeMove				;蛇移动一格
	call drawSnake				;渲染蛇

	call checkSnake				;检测碰撞,返回值为al
	cmp al,0
	je checkNext

	;发生了碰撞
	mov gameover,0
	;打印结束信息	
	call clearScreen
	call printGameOverMsg
	jmp exit

	checkNext:
	call didEatFood				;检测是否吃了食物
	cmp al,0
	je exit

	;吃到了食物
	call createFoodPos
	call addSnakeLen
	inc word ptr [score]
	
 ;中断返回
  exit:
	cli
	pop dx
	pop cx
	pop	bx
	pop ax
	pop ds
	iret
new_int_1ch endp

;-------------------------------------
; 打印信息
;-------------------------------------
printGameOverMsg proc near
	mov dh,10
	mov dl,25
	mov bh,0
	mov ah,2
	int 10h
	mov dx,seg gameover_msg
	mov ds,dx
	mov dx,offset gameover_msg
	mov ah,09h
	int 21h
	ret
printGameOverMsg endp

printGameReadyMsg proc near
	mov dh,10
	mov dl,25
	mov bh,0
	mov ah,2
	int 10h
	mov dx,seg gameready_msg
	mov ds,dx
	mov dx,offset gameready_msg
	mov ah,09h
	int 21h
	ret
printGameReadyMsg endp

printScoreMsg proc near
	mov dx,0
	mov bh,0
	mov ah,2
	int 10h
	mov dx,seg score_msg
	mov ds,dx
	mov dx,offset score_msg
	mov ah,09h
	int 21h
	call showScore
	ret
printScoreMsg endp

showScore proc near
	push bx
	push ax
	push dx

	mov bx,10
	mov ax,[score]
show:
	xor dx,dx 
	div bx
	push ax
	add dl,30h
	mov ah,02h
	int 21h
	pop ax
	cmp ax,0
	jne show

	pop dx
	pop ax
	pop bx
	ret
showScore endp
;-------------------------------------
; 清屏
;-------------------------------------
clearScreen proc near
	mov ax,3h
	int 10h
	ret
clearScreen endp

;-------------------------------------
;	addSnakeLen 增加蛇的长度
;-------------------------------------
addSnakeLen proc near
	push ax
	push dx
	push si
	push di

	;	si 新的结点的指针
	mov si,snake_len
	mov di,si
	shl si,1
	;	di 蛇尾结点的指针
	dec di
	shl di,1

	; 复制一份蛇尾结点信息给新结点
	; 然后根据蛇尾的方向改变新结点坐标
	mov ax,word ptr[snake+di]
	mov word ptr [snake+si], ax

	mov al,snake_tail_dir
	cmp al,0	;向上
	je updateUp
	cmp al,1	;向右
	je updateRight
	cmp al,2	;向下
	je updateDown
	cmp al,3	;向左
	je updateLeft

	updateUp:						;向下增加结点，行号++
	inc byte ptr [snake+si]	
	jmp addSnakeLen_end
	updateRight:				;向左增加结点，列号--
	dec byte ptr [snake+si+1]
	jmp addSnakeLen_end
	updateDown:					;向上增加结点，行号--
	dec byte ptr [snake+si]	
	jmp addSnakeLen_end
	updateLeft:					;向右增加结点，列号++
	inc byte ptr [snake+si+1]
	jmp addSnakeLen_end
	
	addSnakeLen_end:
	inc snake_len

	pop di
	pop si
	pop dx
	pop ax
	ret
addSnakeLen endp

;-----------------------------------
; snakeMove 蛇移动
;	先根据前进方向移动蛇头，
; 蛇身的移动直接将坐标设置为前一个结点的旧坐标即可
;	遍历到蛇尾时，需要更新记录蛇尾的方向 snake_tail_dir
;-----------------------------------
snakeMove proc near
	push ax
	push dx
	push si
	push di

	mov si,0
	;记录蛇头坐标
	mov dh,byte ptr[snake]
	mov dl,byte ptr[snake+1]
	mov oldY, dh
	mov oldX, dl

	;----------------
	; 移动蛇头
	;----------------
	;dh 当前移动方向
	;dl 蛇头移动方向
	;比较 dh 和 dl
	mov dh,dir						
	mov dl,snake_head_dir
	
	;1.方向不变，直接前进
	cmp dh,dl							
	je goForward					
	;2.方向相反，不改变移动方向，直接前进
	mov ax,dx							
	sub ah,al
	cmp ah,2
	je goBack
	mov ax,dx
	sub al,ah
	cmp al,2
	je goBack
	;3.根据当前移动方向转向
	jmp goTurn						


	goBack:
	mov byte ptr dir, dl
	jmp goForward

	goTurn:
	mov snake_head_dir,dh
	jmp goForward

	goForward:
	mov al,snake_head_dir
	cmp al,0
	je goUp
	cmp al,1
	je goRight
	cmp al,2
	je goDown
	cmp al,3
	je goLeft

	;更新蛇头坐标
	goUp:
	dec byte ptr[snake]
	jmp nodeMoveEnd
	goRight:
	inc byte ptr[snake+1]
	jmp nodeMoveEnd
	goDown:
	inc byte ptr[snake]
	jmp nodeMoveEnd
	goLeft:
	dec byte ptr[snake+1]
	jmp nodeMoveEnd

	;----------------
	; 移动蛇身
	;----------------
	bodyMove:
	mov di,si
	shl di,1
	mov ah,oldY
	mov al,oldX
	mov dh,byte ptr[snake+di]
	mov dl,byte ptr[snake+di+1]
	mov oldY,dh
	mov oldX,dl
	mov byte ptr[snake+di],ah
	mov byte ptr[snake+di+1],al

	nodeMoveEnd:
	;完成一个结点的坐标更新
	inc si
	;判断是否遍历完成
	cmp si,snake_len
	jne bodyMove

	;记录蛇尾的前进方向
	;ah,al 蛇尾新坐标
	;oldX,oldY 蛇尾旧坐标
	sub ah,oldY
	cmp ah,0
	jg setTailDirDown
	jl setTailDirUp
	sub al,oldX
	cmp al,0
	jg setTailDirRight
	jl setTailDirLeft

	setTailDirUp:
	mov snake_tail_dir,0
	jmp snakeMove_ret
	setTailDirRight:
	mov snake_tail_dir,1
	jmp snakeMove_ret
	setTailDirDown:
	mov snake_tail_dir,2
	jmp snakeMove_ret
	setTailDirLeft:
	mov snake_tail_dir,3
	jmp snakeMove_ret
	snakeMove_ret:
	pop di
	pop si
	pop dx
	pop ax
	ret
snakeMove endp
;-------------------------------------
;	判断是否碰撞
; @return al al=1 发生了碰撞
;-------------------------------------
checkSnake proc near
	push dx
	push si
	push di

	mov al,0
	; 记录蛇头的坐标
	mov dh,byte ptr [snake]
	mov dl,byte ptr [snake+1]

	; 检查是否与边界发生碰撞
	checkEage:
	cmp dh,0
	je checkSnake_gameover
	cmp dh,24
	je checkSnake_gameover
	cmp dl,0
	je checkSnake_gameover
	cmp dl,79
	je checkSnake_gameover

	mov si,1
	cmp si,snake_len
	jz checkSnake_ret
	; 检查是否和自己的身体发生碰撞
	checkSelf:
	mov di,si
	shl di,1
	cmp dh,byte ptr [snake+di]
	jnz checkSelf_continue

	cmp dl,byte ptr [snake+di+1]
	jnz checkSelf_continue

	; 发生了碰撞
	checkSnake_gameover:
	mov al,1
	jmp checkSnake_ret

	checkSelf_continue:
	inc si
	cmp si,snake_len
	jnz checkSelf

	checkSnake_ret:
	pop di
	pop si
	pop dx
	ret
checkSnake endp
;-------------------------------------
;	监听键盘按下
;-------------------------------------
listenKeyPress proc near
	mov ah,01
	int 21h
	ret
listenKeyPress endp

;-------------------------------------
;	渲染蛇
;-------------------------------------
drawSnake proc near
	push dx
	push bx
	push ax
	push di

	mov si,0

	drawSnakeNode:
	mov di,si
	shl di,1
	mov dh,byte ptr [snake+di]
	mov dl,byte ptr [snake+di+1]
	mov bh,0
	mov ah,2
	int 10h

	cmp si,0
	jz printHead

	printBody:
	mov dl,'*'
	jmp print

	printHead:
	mov dl,'#'

	print:
	mov ah,02h
	int 21h

	inc si
	cmp si,snake_len
	jne drawSnakeNode
	
	mov bh,0
	mov dx,0
	mov ah,2
	int 10h
	
	pop di
	pop ax
	pop bx
	pop dx
	ret
drawSnake endp
;-------------------------------------
; 随机生成食物的位置
;-------------------------------------
createFoodPos proc near
	push dx
	push ax

	mov ax,0h
	out 43h,al
	in al,40h
	in al,40h
	mov dl,20
	div dl
	mov al,ah
	add al,3
	mov byte ptr [food_pos], al

	mov ax,0h
	out 43h,al
	in al,40h
	mov dl,60
	div dl
	mov al,ah
	add al,10
	mov byte ptr [food_pos + 1], al

	pop ax
	pop dx
	ret
createFoodPos endp
;-------------------------------------
; 渲染食物
;-------------------------------------
drawFood proc near
	push bx
	push dx
	push ax
	mov bh,0
	mov dh,byte ptr [food_pos]
	mov dl,byte ptr [food_pos + 1]
	mov ah,2
	int 10h
	
	mov dl,'@'
	mov ah,02h
	int 21h
	
	pop ax
	pop dx
	pop bx
	ret
drawFood endp

;-------------------------------------
; 判断是否吃到了食物
;-------------------------------------
didEatFood proc near
	push si
	push dx
	push di

	mov al,0
	mov si,0
	mov dh,byte ptr [food_pos]
	mov dl,byte ptr [food_pos+1]
	check:
	mov di,si
	shl di,1
	cmp dh,byte ptr [snake+di]
	jnz check_continue
	cmp dl,byte ptr [snake+di+1]
	jnz check_continue

	eat:
	mov al,1
	jmp check_end

	check_continue:
	inc si
	cmp si,snake_len
	jnz check
	check_end:
	pop di
	pop dx
	pop si
	ret
didEatFood endp
CODES ENDS
	END main







