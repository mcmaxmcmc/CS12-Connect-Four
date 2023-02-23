
;To do:
;
;Printing the whole game
;Translating column number input to piece position
;




; Data Section
; ############

%macro reset 1					;sets [1] to 0 if rbx is 0, increments [1] if rbx is not 0

	;1: The Accused
	;rbx: Decision -- true (!=0) or false (0)
	
	cmp rbx, 0
	jne %%no_reset
		mov qword[ %1 ], 0
		jmp %%reset_end
		
	%%no_reset:
		inc qword[ %1 ]
		
	%%reset_end:
%endmacro


%macro check_pos 5				;Find whether a piece in the specified position is there
	;1: Quadword of piece positions of a player
	;2: A **position** of piece being checked (0-41 in a standard game board -- invalid position resets counter)
	;3: Game board width
	;4: Game board height
	;5: Counter
	;"Output" is the changed Counter value, incrementing it if true and 0 if false
	
	push rcx
	push rbx
	push rax
	
	xor rax, rax
	xor rbx, rbx
	xor rcx, rcx
	
	cmp byte[ %2 ], 0		;check if position is less than zero -- invalid position if so
	jl %%invalid
	
	mov rax, qword[ %3 ]
	mul qword[ %4 ]		;42 -- rax, here, stores the number of bits used to store all the positions of pieces
	dec rax				;41 -- maximum valid position
	
	cmp byte[ %2 ], al		;check if position is more than maximum valid position -- invalid position if so
	jg %%invalid
	
	mov rax, 1
	mov cl, byte[ %2 ]

	inc cl
	shl rax, cl
	shr rax, 1
	mov rbx, qword[ %1 ]
	and rbx, rax
	shl rbx, 1
	shr rbx, cl
	
	reset %5
	
	jmp %%end
	
	%%invalid:
	mov qword[ %5 ], 0
	
	%%end:
	pop rax
	pop rbx
	pop rcx
	
	
%endmacro


%macro check_downward 5		;check whether there is a 4-in-a-row downward from a piece
	;1: quadword of piece positions of a player (1-42)
	;2: Valid **position** of piece being checked (0-41)
	;	as this is downward, the check will start from the top piece only
	;3: Game board width
	;4: Game board height
	;5: Counter (spare variable to pass to check_pos)
	;Output to Counter as true (1) or false (0)
	
	push rdx
	push rcx
	push rbx
	push rax
	push qword[ %2 ]
	
	xor rax, rax
	xor rbx, rbx
	xor rcx, rcx
	xor rdx, rdx
	
	mov rcx, 4		;Checking begins
	
	%%loop:
		check_pos %1, %2, %3, %4, %5
		mov al, byte[ %2 ]
		
		cmp rax, qword[ %3 ]
		jl %%loop_done
		
		sub rax, qword[ %3 ]
		mov byte[ %2 ], al
		
		;loop %%loop
		dec rcx
		cmp rcx, 0
		je %%loop_done
		jmp %%loop
	%%loop_done:
		
	shr qword[ %5 ], 2				;Counter is changed here to be a 1 or 0
	
	pop qword[ %2 ]
	pop rax
	pop rbx
	pop rcx
	pop rdx
	
%endmacro


%macro check_side 5		;check whether there is a 4-in-a-row sideways from a piece -- it's much easier to just check the whole row
	;1: quadword of piece positions of a player (1-42)
	;2: Valid **position** of piece being checked (0-41)
	;3: Game board width
	;4: Game board height
	;5: Counter (spare variable to pass to check_pos)
	;Output to Counter as true (1) or false (0)
	
	push rdx
	push rcx
	push rbx
	push rax
	push qword[ %2 ]
	
	xor rax, rax
	xor rbx, rbx
	xor rcx, rcx
	xor rdx, rdx
	
	mov al, byte[ %2 ]
	div qword[ %3 ]			;rax stores row (bottom row is zero), rdx stores column (first column is zero)
	mul qword[ %3 ]			;rax now stores the index of the first piece in the valid position's row

	mov rcx, qword[ %3 ]		;checks whole row
	%%loop_side:
		mov byte[ %2 ], al
		check_pos %1, %2, %3, %4, %5
		cmp qword[ %5 ], 4
		je %%check_side_complete
		
		inc rax
		
		;loop %%loop_side
		dec rcx
		cmp rcx, 0
		je %%check_side_complete
		jmp %%loop_side

		
	%%check_side_complete:	
	
	shr qword[ %5 ], 2
	
	pop qword[ %2 ]
	pop rax
	pop rbx
	pop rcx
	pop rdx
%endmacro
	


%macro check_TLBR 5		;check whether there is a 4-in-a-row diagonally, top left to bottom right from a piece
	;1: quadword of piece positions of a player
	;2: Valid position of piece being checked
	;	as this is downward, the check will start from the top piece only
	;3: Game board width
	;4: Game board height
	;5: Counter (spare variable to pass to check_pos)
	;Output to Counter as true (1) or false (0)
	
	push rdx
	push rcx
	push rbx
	push rax
	push qword[ %2 ]
	
	xor rax, rax
	xor rbx, rbx
	xor rcx, rcx
	xor rdx, rdx
	
	mov al, byte[ %2 ]
	mov rcx, 3
	mov rbx, rax
	%%bottom:
		xor rax, rax
		xor rdx, rdx
		
		mov rax, rbx
		
		div rax, qword[ %3 ]
		inc rdx
		cmp rdx, qword[ %3 ]		;Last column
		je %%limit_reached
		
		cmp rax, 0				;Bottom row
		je %%limit_reached
		
		mov rax, rbx
		mov rdx, qword[ %3 ]		;7
		dec rdx					;6
		sub rax, rdx
		mov rbx, rax
		
		loop %%bottom
		
	%%limit_reached:
	;rbx now stores the bottom-most position to check
	mov rcx, 7
	%%loop_rcx:
		xor rax, rax
		xor rdx, rdx
		
		mov byte[ %2 ], bl
		check_pos %1, %2, %3, %4, %5
		
		cmp qword[ %5 ], 4
		je %%complete
		
		;Check if rbx is at a boundary -- if it is, jump out of the loop
		mov rax, rbx
		div rax, qword[ %3 ]
		
		inc rax
		cmp rax, qword[ %4 ]
		je %%complete
		
		cmp rdx, 0
		je %%complete
		
		add rbx, qword[ %3 ]
		dec rbx
		
		;loop %%loop_rcx
		dec rcx
		cmp rcx, 0
		je %%complete
		jmp %%loop_rcx

	%%complete:
	shr qword[ %5 ], 2
	pop qword[ %2 ]
	pop rax
	pop rbx
	pop rcx
	pop rdx

%endmacro





%macro check_TRBL 5		;check whether there is a 4-in-a-row diagonally, top right to bottom left from a piece
	;1: quadword of piece positions of a player
	;2: Valid position of piece being checked
	;3: Game board width
	;4: Game board height
	;5: Counter (spare variable to pass to check_pos)
	;Output to Counter as true (1) or false (0)
	
	push rdx
	push rcx
	push rbx
	push rax
	push qword[ %2 ]
	
	xor rax, rax
	xor rbx, rbx
	xor rcx, rcx
	xor rdx, rdx
	
	mov al, byte[ %2 ]
	mov rcx, 3
	mov rbx, rax

	%%bottom:
		xor rax, rax
		xor rdx, rdx
		mov rax, rbx

		div qword[ %3 ]
		
		cmp rdx, 0			;First column
		je %%limit_reached
		
		cmp rax, 0			;Bottom row
		je %%limit_reached
		
		mov rax, rbx

		mov rdx, qword[ %3 ]			;7
		inc rdx						;8
		sub rax, rdx

		mov rbx, rax
		
		loop %%bottom
		
	%%limit_reached:
	;rbx now stores the bottom-most position to check
	
	mov rcx, 7
	%%loop_rcx:
		mov byte[ %2 ], bl
		check_pos %1, %2, %3, %4, %5
		cmp qword[ %5 ], 4
		je %%complete
		
		;Check if rbx is at a boundary -- if it is, jump out of the loop
		mov rax, rbx
		div rax, qword[ %3 ]
		inc rax
		cmp rax, qword[ %4 ]
		je %%complete
		
		inc rdx
		cmp rdx, qword[ %3 ]
		je %%complete
		
		add rbx, qword[ %3 ]
		inc rbx
		
		;loop %%loop_rcx
		dec rcx
		cmp rcx, 0
		je %%complete
		jmp %%loop_rcx

	%%complete:
	shr qword[ %5 ], 2
	
	pop qword[ %2 ]
	pop rax
	pop rbx
	pop rcx
	pop rdx
	
%endmacro


%macro place 6		;Puts a piece on the board
	;1: Quadword of piece positions of Player 1 (1-42)
	;2: Quadword of piece positions of Player 2 (1-42)
	;3: Game board width
	;4: Game board height
	;5: Counter (used for check_pos)
	;6: Player position column (0-6)
	;rbx: Player putting the piece (1-2)
	;Output: changes rbx to either 0 or 1, invalid or valid
	;		Player position [6] is also updated to where the piece is placed
	
	push rdx
	push rcx
	push rax
	push qword[ %5 ]
	
	xor rax, rax
	xor rcx, rcx
	xor rdx, rdx
	
	%%scan:
		mov qword[ %5 ], 1
		check_pos %1, %6, %3, %4, %5
		cmp qword[ %5 ], 0
		jne %%unavailable
		
		mov rax, 1
	
		mov qword[ %5 ], 1
		check_pos %2, %6, %3, %4, %5
		cmp qword[ %5 ], 0
		jne %%unavailable
		

		cmp rax, 1
		je %%found
		
		%%unavailable:
		mov al, byte[ %6 ]
		add rax, qword[ %3 ]
		mov byte[ %6 ], al
		xor rax, rax
		
		mov rax, qword[ %3 ]
		mul qword[ %4 ]
		cmp byte[ %6 ], al
		jge %%invalid
		
		jmp %%scan
		
		
	%%found:
	push rcx
		mov cl, byte[ %6 ]
		inc cl
		mov rax, 1
		shl rax, cl
		shr rax, 1
	pop rcx
	
	cmp rbx, 2
	je %%player2
	
	;Player 1
	xor qword[ %1 ], rax
	jmp %%complete
	
	%%player2:
	xor qword[ %2 ], rax
	jmp %%complete
	
	%%complete:
	mov rbx, 1
	jmp %%end
	
	%%invalid:
	mov rbx, 0
	
	%%end:
	pop qword[ %5 ] 
	pop rax
	pop rcx
	pop rdx
	
%endmacro
	
	
%macro find_piece 7		;Determines a piece on the game board. 
	;1: Quadword of piece positions of Player 1 (1-42)
	;2: Quadword of piece positions of Player 2 (1-42)
	;3: Game board width
	;4: Game board height
	;5: Counter (used in finding which row is being printed)
	;6: Position in question (0-41)
	;7: Piece print height
	;Output: Returns which piece exists in position in rsi
	
	push rdx
	push rcx
	push rbx
	push rax
	
	
	xor rax, rax
	xor rbx, rbx
	xor rcx, rcx
	xor rdx, rdx
	
	push qword[ %5 ]
	
	
	mov qword[ %5 ], 1
	check_pos %1, %6, %3, %4, %5
	cmp qword[ %5 ], 0
	jne %%player1
	
	mov qword[ %5 ], 1
	check_pos %2, %6, %3, %4, %5
	cmp qword[ %5 ], 0
	jne %%player2
		
	jmp %%empty
	
	
	
	%%player1:
	pop qword[ %5 ]
	mov rax, qword[ %5 ]
	cmp rax, 1
	je %%player
	cmp rax, qword[ %7 ]
	je %%player
	
	mov rsi, 1
	jmp %%end
	
	
	%%player2:
	pop qword[ %5 ]
	mov rax, qword[ %5 ]
	cmp rax, 1
	je %%player
	cmp rax, qword[ %7 ]
	je %%player
	
	mov rsi, 2
	jmp %%end
	
	
	%%player:	
	mov rsi, 3
	jmp %%end
	
	
	%%empty:
	pop qword[ %5 ]
	mov rsi, 0
	jmp %%end
	
	
	%%end:
	pop rax
	pop rbx
	pop rcx
	pop rdx
	
%endmacro
	

%macro print_piece 5		;Prints a section of a piece on the game board, denoted by rsi -- if not denoted correctly, nothing is done.
	;1: Blank spot to print
	;2: Player 1's string to print
	;3: Player 2's string to print
	;4: Player 's "Vertical edge" string
	;5: Piece width
	
	
	
	cmp rsi, 0
	je %%blank
	
	cmp rsi, 3
	je %%player
	
	cmp rsi, 1
	je %%player1
	
	cmp rsi, 2
	je %%player2
	
	jmp %%end
	
	
	
	%%blank:
	mov rsi, %1 
	jmp %%print
	
	%%player:
	mov rsi, %4
	jmp %%print
	
	%%player1:
	mov rsi, %2
	jmp %%print
	
	%%player2:
	mov rsi, %3
	jmp %%print
	
	%%print:
	push rdx
	mov rdx, qword[ %5 ]
	call printByteArray
	pop rdx
	
	%%end:
	
%endmacro
	
%macro check_tie 5			;check whether the game has come to a tie
	;1: Quadword of piece positions of Player 1 (1-42)
	;2: Quadword of piece positions of Player 2 (1-42)
	;3: Game board width
	;4: Game board height
	;5: Counter
	;Output to Counter as true (1) or false (0)
	push rax
	push rbx
	push rcx
	
	mov rax, qword[ %3 ]
	mul qword[ %4 ]
	mov rbx, rax

	mov rax, qword[ %1 ]	
	xor rax, qword[ %2 ]
	inc rax
	mov cl, bl
	shr rax, cl
	mov qword[ %5 ], rax
	
	pop rcx
	pop rbx
	pop rax
	
%endmacro


%macro input_check 2		;check whether the input given is a valid input for the game (column number) -- if it is valid, the input is converted to position number (0-6)
	;1: input being selected
	;2: Game board width
	;Output to rbx as true (1) or false (0)
	
	push rax
	
	xor rax, rax
	mov al, byte[ %1 ]
	and rax, 0xF0
	
	cmp rax, 0x30
	je %%valid
	cmp rax, 0x40
	je %%valid
	cmp rax, 0x60
	je %%valid

	jmp %%invalid
	
	
	%%valid:
	xor rax, rax
	mov al, byte[ %1 ]
	and rax, 0xF
	
	cmp rax, 0
	je %%invalid
	
	cmp rax, qword[ %2 ]
	jg %%invalid
	
	dec al
	mov byte[ %1 ], al
	mov rbx, 1
	jmp %%end
	
	
	
	%%invalid:
	mov rbx, 0
	jmp %%end

	
	%%end:
	pop rax
%endmacro





section 	.data

; ###############################################
; external function references from CS12-Lib
; ###############################################
extern getByteArray
extern printByteArray
extern printEndl
extern exitNormal
extern printRAX
extern printRBX
extern printRCX
extern printRDX
extern printReg
extern printSpace

; ###############################################
; Variable Definitions
; ###############################################
helloMsg  db  "CS12"
helloLen  dq  4

piece_width dq 5
player_piece db " @@@ "
player1_piece db "@   @"
player2_piece db "@@@@@"
blank_piece db "     "

introduction db "Hello, and welcome to Connect Four!"
introduction_len dq 35
instruction db "This program accepts numerical inputs or letters corresponding to the columns."
instruction_len dq 78
credits db "This program was coded by Nithid Veravit as the Santa Rosa Junior College's CS12 project in Fall 2021."
credits_len dq 102
thanks db "Thanks for playing!"
thanks_len dq 19

player1_turn_msg db "Player 1's turn: "
player2_turn_msg db "Player 2's turn: "
player_turn_len dq 17

border db "#", NULL

winner1 db "Player 1 wins!"
winner2 db "Player 2 wins!"
winner_len dq 14
winner0 db "It's a tie!"
winner0_len dq 11

play_again_msg db "Would you like to play again?  Input [Y] to play again, and any other key to exit: "
play_again_msg_len dq 83

;System commands and codes
NULL 		equ 0
SYS_write 	equ 1
STDOUT 		equ 1
LF			equ 10


;Using bits to store whether a piece is there or not
;1st bit is bottom left, 42nd bit is top right in a standard game
player1 dq 0
player1_dump dq 0
player2 dq 0
player2_dump dq 0

;Game board dimensions
width dq 7
height dq 6
piece_height dq 4

;Spare Counter, Position, and Input
counter dq 0
pos db 0
dump_space0 dq 0
player_input db " "
dump_space1 db "                           "
dump db " "
dump_space2 db "                           "

;Invalid input messages
column_full db "The column you have selected is full!  Enter a valid column number: "
column_full_len dq 68
invalid_input db "The input you have entered is invalid!  Enter a valid column number: "
invalid_input_len dq 69

; BSS Section
; ############ 
section		.bss

; ###############################################
; Variable Declarations
; ###############################################


; Code Section
; ############	
section		.text

global printBorder	;From the textbook -- prints the string stated in address in rdi  -- tring to make a printBorder command that uses no registers or memory
printBorder:
	push rax
	push rbx
	push rcx
	push rdx
	push rdi
	push rsi
	
	mov rax, 1
	mov rsi, border
	mov rdi, 1
	mov rdx, 1
	
	syscall
	
	pop rsi
	pop rdi
	pop rdx
	pop rcx
	pop rbx
	pop rax
	ret
	
global input		;Input function -- outputs to player_input the first non-LF character the player inputted
input:
	push rax
	push rbx
	push rcx
	push rdx
	push rdi
	push rsi
	
	input_retry:
	mov rax, 0
	mov rdi, 0
	mov rsi, player_input
	mov rdx, 1
	
	syscall
	
	cmp byte[player_input], LF
	je input_retry
	
	
	
	input_dump_more:
	
	mov rax, 0
	mov rdi, 0
	mov rsi, dump
	mov rdx, 1
	
	syscall
	
	cmp byte[dump], LF
	jne input_dump_more
	
	pop rsi
	pop rdi
	pop rdx
	pop rcx
	pop rbx
	pop rax
	ret
	
	
; ###############################################
; ### Begin Program 
; ###############################################	
global _start

_start:
; ###############################################
; ###  Print out Header 'CS12' 
; ###############################################
    ; print out the message
	mov rdx, qword [helloLen]   ; load the length of the output
	mov rsi, helloMsg           ; load the message
	call printByteArray         ; print the message
	call printEndl              ; print an endline
	
	mov rdi, 0			;Major flag: 0: Game start		1: Player 1 win		2: Player 2 Win		3: Tie	4: Player 1 Turn	5: Player 2 Turn
	retry:
	xor rax, rax
	mov qword[player1], rax
	mov qword[player2], rax
	game:
		mov rbx, qword[height]
		dec rbx				;height index of top row
		push rdi
		
		;PRINT SECTION START --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		print:
			mov qword[counter], 1
			print_row:
				mov rax, rbx
				mul qword[width]
				mov qword[pos], rax
				mov rcx, qword[width]
				call printBorder
				
				print_line:
					call printSpace
					
					push rsi
					find_piece player1, player2, width, height, counter, pos, piece_height
					print_piece blank_piece, player1_piece, player2_piece, player_piece, piece_width
					pop rsi
					
					inc qword[pos]

					dec rcx
					cmp rcx, 0
					je no_jump_print_line
					jmp print_line
					
					no_jump_print_line:
				call printSpace
				call printBorder
				
				call printEndl
				
				inc qword[counter]
				mov rdx, qword[counter]
				cmp rdx, qword[piece_height]
				jle print_row
			
			call printBorder
			
			push rax
			push rcx
			
			mov rax, qword[piece_width]
			inc rax
			mul qword[width]
			inc rax
			mov rcx, rax
			space_loop:
				call printSpace
				loop space_loop
			
			pop rcx
			pop rax
			
			call printBorder
			call printEndl
			
			dec rbx
			cmp rbx, 0
			jge print
		
		
		push rax
		push rcx
		
		mov rax, qword[piece_width]
		inc rax
		mul qword[width]
		add rax, 3
		mov rcx, rax
		border_loop:
			call printBorder
			loop border_loop
		call printEndl
		
		pop rcx
		pop rax
		;PRINT SECTION END --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		
		pop rdi

		cmp rdi, 0		;Introduction check
		jne progress
		
		;GAME INTRODUCTION START---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		mov rsi, introduction
		mov rdx, qword [introduction_len]
		call printByteArray
		call printEndl
		
		mov rsi, instruction
		mov rdx, qword [instruction_len]
		call printByteArray
		call printEndl
		
		mov rdi, 4
		
		push rax
		xor rax, rax
		mov qword[player1], rax
		mov qword[player2], rax
		pop rax
		;GAME INTRODUCTION END---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		
		progress:
		cmp rdi, 4	;GAME END CHECK
		jl ending
		
		cmp rdi, 4
		je player1_turn
		
		cmp rdi,5
		je player2_turn
		
		jmp ending		;Jumps to win if value isn't 0, 4, or 5 -- safety net
		
		
		;PLAYER 1's INPUT START------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		player1_turn:
		mov rsi, player1_turn_msg
		mov rdx, qword[player_turn_len]
		call printByteArray
		
		player1_turn_input:
			push rbx
			
			xor rbx, rbx
			call input
			input_check player_input, width		
			
			cmp rbx, 0
			jne input_check_valid1
		
				push rdx
				push rsi
			
				mov rsi, invalid_input
				mov rdx, qword[invalid_input_len]
				call printByteArray
		
				pop rsi
				pop rdx
				pop rbx
				
				jmp player1_turn_input
			
			input_check_valid1:

			mov rbx, rdi
			sub rbx, 3

			place player1, player2, width, height, counter, player_input
			
			cmp rbx, 1
			je player1_turn_input_complete
			
				push rdx
				push rsi
				
				mov rsi, column_full
				mov rdx, qword[column_full_len]
				call printByteArray
		
				pop rsi
				pop rdx
				
				pop rbx
				
				jmp player1_turn_input
			
			player1_turn_input_complete:
			pop rbx
			
			jmp player1_board_check
		;PLAYER 1's INPUT END------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		
		
		;PLAYER 2's INPUT START------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		player2_turn:
		mov rsi, player2_turn_msg
		mov rdx, qword[player_turn_len]
		call printByteArray
		
		player2_turn_input:
			push rbx
			
			xor rbx, rbx
			call input
			input_check player_input, width		
			
			cmp rbx, 0
			jne input_check_valid2
		
				push rdx
				push rsi
			
				mov rsi, invalid_input
				mov rdx, qword[invalid_input_len]
				call printByteArray
		
				pop rsi
				pop rdx
				pop rbx
				
				jmp player2_turn_input
			
			input_check_valid2:

			mov rbx, rdi
			sub rbx, 3

			place player1, player2, width, height, counter, player_input
			
			cmp rbx, 1
			je player2_turn_input_complete
			
				push rdx
				push rsi
				
				mov rsi, column_full
				mov rdx, qword[column_full_len]
				call printByteArray
		
				pop rsi
				pop rdx
				
				pop rbx
				
				jmp player2_turn_input
			
			player2_turn_input_complete:
			pop rbx
			
			jmp player2_board_check
		;PLAYER 2's INPUT END------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		
		
		;PLAYER 1's BOARD CHECK START------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		player1_board_check:		;Game board check -- player_input has the position of the newest piece
		
		mov qword[counter], 0
		check_downward player1, player_input, width, height, counter
		cmp qword[counter], 0
		jne game_complete1
		
		mov qword[counter], 0
		check_side player1, player_input, width, height, counter
		cmp qword[counter], 0
		jne game_complete1
		
		mov qword[counter], 0
		check_TLBR player1, player_input, width, height, counter
		cmp qword[counter], 0
		jne game_complete1
		
		mov qword[counter], 0
		check_TRBL player1, player_input, width, height, counter
		cmp qword[counter], 0
		jne game_complete1

		mov qword[counter], 0
		check_tie player1, player2, width, height, counter
		cmp qword[counter], 0
		jne game_tied1
		
		push rax
		xor rax, rax
		mov rax, 1
		xor rdi, rax
		pop rax
		
		jmp game
		
		;Game finished:
		game_tied1:
		mov rdi, 6
		jmp game_complete1

		game_complete1:
		sub rdi, 3
		jmp game
		;PLAYER 1's BOARD CHECK END------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		
		
		;PLAYER 2's BOARD CHECK START------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		player2_board_check:
		
		mov qword[counter], 0
		check_downward player2, player_input, width, height, counter
		cmp qword[counter], 0
		jne game_complete2
		
		mov qword[counter], 0
		check_side player2, player_input, width, height, counter
		cmp qword[counter], 0
		jne game_complete2
		
		mov qword[counter], 0
		check_TLBR player2, player_input, width, height, counter
		cmp qword[counter], 0
		jne game_complete2
		
		mov qword[counter], 0
		check_TRBL player2, player_input, width, height, counter
		cmp qword[counter], 0
		jne game_complete2
		
		mov qword[counter], 0
		check_tie player1, player2, width, height, counter
		cmp qword[counter], 0
		jne game_tied2
		
		push rax
		xor rax, rax
		mov rax, 1
		xor rdi, rax
		pop rax
		
		jmp game
		
		;Game finished:
		game_tied2:
		mov rdi, 6
		jmp game_complete2

		game_complete2:
		sub rdi, 3
		jmp game
		;PLAYER 2's BOARD CHECK END------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	;ENDING START------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	ending:
	
	;Checks who won
	cmp rdi, 1
	je player1_win
	cmp rdi, 2
	je player2_win
	jmp tie
	
	player1_win:
	mov rsi, winner1
	mov rdx, qword[winner_len]
	call printByteArray
	call printEndl
	jmp play_again
	
	player2_win:
	mov rsi, winner2
	mov rdx, qword[winner_len]
	call printByteArray
	call printEndl
	jmp play_again
	
	tie:
	mov rsi, winner0
	mov rdx, qword[winner0_len]
	call printByteArray
	call printEndl
	jmp play_again
	
	;Asks the player if they want to play the game again
	play_again:
	mov rsi, play_again_msg
	mov rdx, qword[play_again_msg_len]
	call printByteArray
	
	;Input to question
	call input
	push rax
	
	;Input sort
	mov al, byte[player_input]
	and rax, 0xF
	cmp rax, 0x9
	jne exit
	
	mov al, byte[player_input]
	and rax, 0xF0
	cmp rax, 0x50
	je retry_commence
	
	cmp rax, 0x70
	je retry_commence
	
	;If player does not want to play again
	jmp exit
	
	;If player does want to play again
	retry_commence:
	xor rdi, rdi
	mov rdi, 4
	jmp retry
	
	;Final message and credits
	exit:
	mov rsi, thanks
	mov rdx, qword[thanks_len]
	call printByteArray
	call printEndl
	mov rsi, credits
	mov rdx, qword[credits_len]
	call printByteArray
	call printEndl
	
	jmp last
	;ENDING END------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	

; ###############################################
; exit with an exit code of 0
; ###############################################
	last:
	call	exitNormal
