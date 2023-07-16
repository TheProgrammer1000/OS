[org 0x7c00]
; Read some sectors from the boot disk using our disk_read function


MOV bx, DISPLAY_USER
CALL print_text_func

CALL wait_for_keypress_loop







JMP finish


; LOAD FROM HARD DRIVE -------------------------------------------------------------------------------------------
reading_hardware:
   	PUSHA
   	MOV ah, 0x02    ; Function 2: Read sectors
   	MOV al, 1       ; Number of sectors to read
   	MOV ch, 0       ; Cylinder number (starting from 0)
	MOV cl, 2       ; Sector number (starting from 1)
    	MOV dh, 0       ; Head number (starting from 0)


	MOV dl, 0 ; Disk number (0x80 for the first hard drive)
    	MOV bx, 0x0000
	MOV es, bx
	MOV bx, 0x7e00


    	INT 0x13        ; Invoke the disk service

    	JC disk_error ; jc is another jumping instruction , that jumps
    	; only if the carry flag was set

   	; actually read in AL is not equal to the number we expected.
   	CMP al, 1
   	JNE disk_error
	JMP disk_ok

	disk_error:
		MOV bx, DISK_ERROR_MSG
		CALL print_text_func
   		POPA
   		RET
	disk_ok:
		CALL print_text_func
		POPA
		RET






; WRITE TO HARDWARE ------------------------------------------------------------------------------------------------
write_to_disk:
	PUSHA

	MOV ah, 0x03        ; BIOS function to write sector from memory
    	MOV al, 1           ; Number of sectors to write
   	MOV ch, 0           ; Cylinder number
    	MOV cl, 2           ; Sector number
    	MOV dh, 0           ; Head number
    	MOV dl, 0           ; Drive number (0x80 for first hard drive)


	MOV bx, 0x0000
	MOV es, bx	      ; Setting up the es to value 0
	MOV bx, 0x7e00        ; Address of the buffer to write



	MOV bx, LOAD_TEXT_TO_DISK
	PUSHA			; So i can manupulate how i want
	CALL loop_text
	POPA			; I can retrieve to normal values again

	INT 0x13


	JC disk_error_1	; jc is another jumping instruction , that jumps
        ; only if the carry flag was set

        ; actually read in AL is not equal to the number we expected.
        CMP al, 1
        JNE disk_error_1
        JMP disk_ok_1

        disk_error_1:
                MOV bx, DISK_ERROR_MSG
                CALL print_text_func
                POPA
                RET
        disk_ok_1:
		CALL reading_hardware

                POPA
                RET



	POPA
	RET
;-------------------------------------------------------------------------------------------------------------------

; ADD MORE CHAR TO DISK FUNCTION -------------------------------------------------------------------------------------------

loop_text:
	MOV al, [bx]
	CMP al, 0
	JE enditnow
	MOV byte [bx], al
	INC bx
	JMP loop_text
enditnow:
	RET
;--------------------------------------------------------------------------------------------------------------------------------




; PRINT STRING FUNCTION --------------------------------------------------------------------------------------------

print_text_func:
	PUSHA
	MOV ah, 0x0e
	print_text:
		mov al, [bx]
		CMP al, 0
		JE end
		INT 0x10
		INC bx

		JMP print_text
end:
	POPA
	RET
;-------------------------------------------------------------------------------------------------------------------


; NEW LINE FUNCTION -------------------------------------------------------------------------------------------------
nl:
	PUSHA
	MOV ax, 0x0e0a
	INT 0x10
	MOV ax, 0x0e0d
	INT 0x10
	POPA
	RET


;--------------------------------------------------------------------------------------------------------------------

; PRINTING HEXA-DECIMAL FUNCTION
print_hex:
push bp ; Setting up stack
mov bp, sp
mov bx, 4
.loop:
cmp bx, 0
jz .end
dec bx
mov ax, 4
mov cx, 3
sub cx, bx
mul cx

mov cx, ax
mov ax, word [bp+4] ; hex calue arguemnt

shl ax, cl ; 4 nibbles left over we want to print
shr ax, 12

cmp al, 10 ; Checking whether its a decimal asscii or aplhabetical ascii
jl .num
mov ah, 55
jmp .char
.num:
mov ah, 48
.char:
add al, ah
mov ah, 0x0e
int 0x10
jmp .loop
.end:

pop bp
ret 2
;----------------------------------------------------------------------------------

; WAITING FOR KEY PRESS ----------------------------------------------------------------------------------------------------
wait_for_keypress_loop:
		PUSHA

		MOV dx, 0				; Counter

	 	MOV si, MAKE_DIR_COMMAND

		MOV bx, 0x7e00				; This memory location we want to store our value in
		PUSH bx					; We push it because we want to use this later when we loop our text

		key_press_loop:
                MOV ah,0h				; BIOS key press
                INT 16h

                CMP al, 0Dh       			;if you pressed a enter-key then do following
                JE wait_for_keypress_end
		JMP print_keypress


		wait_for_keypress_end:
			MOV byte [bx], 0		; Denna blir san, du kan kolla null terminator 0 på slutet av texten som vi skrev in


			CALL nl


			MOV ax, bx ; Taking the memory location value from bx to ax
			PUSH ax ; Pushing ax so this function work

			CALL nl
			MOV bx, MEMORY_LOCATION_TEXT
			CALL print_text_func
			CALL print_hex			; Then writting out the memory location value to the screen

			POP bx				; POP the bx value of so we can loop through and see when the value is 0 then we close the looop

			MOV cl, MAKE_DIR_COMMAND
			; Loop through text and compare


			compare_input_text:
				lodsb

				CMP dx, 1
				JE forward

				CMP al, 0
				JE exit_finish
				JNE continue

				forward:
					CALL nl
					CALL nl


					ADD byte [bx], 0


					PUSH bx
					MOV bx, MAKE_DIR_TEXT
					CALL print_text_func
					POP bx

					map_name_loop:
					MOV al, [bx]
					CMP byte [bx], 0
					JE exit_finally_finish
					INT 0x10
					INC bx
					JMP map_name_loop

				exit_finally_finish:
					CALL nl
					CALL nl
					MOV ah, 0x0e
					MOV al, 'F'			; indicate it is finished
					INT 0x10
					POPA
					RET


			exit_finish:
				ADD dx, 1
				JMP compare_input_text

			continue:
				CMP al, [bx]		; bl is the text that user writes in
				JE good                                 ; MAKE_DIR_COMMAND is the value that we will compare with
				JNE exit				; Here we want more then just make dir command

			good:
				ADD bx, 1
				JMP compare_input_text


			exit:				; Exit it and displays message to the user
				CALL nl
				CALL nl
				CALL print_text_func

				MOV bx, ERROR_MSG
				CALL print_text_func

				POPA
				RET



		print_keypress:
			MOV byte [bx], al		; Storing the value in memory location 0x7e00
			MOV al, [bx]

			MOV ah, 0x0e
			INT 0x10			; Writting out what we stored in that memory location

			ADD bx, 1			; Adding plus 1 to the memory location, so next time we can add another value to the right place

			JMP key_press_loop		; Contiuning wait for any key to be pressed


;--------------------------------------------------------------------------------------------------------------------------


; finish here infinite loop
finish:
	jmp $





; Data Initalized data
DISK_ERROR_MSG:
	 db 'Disk read error!', 0

LOAD_TEXT_TO_DISK:
	db 'loading this text to disk!', 0


MEMORY_LOCATION_TEXT:
	db 'Memory location value now: ', 0


MAKE_DIR_COMMAND:
	db 'mkdir ', 0

MAKE_DIR_TEXT:
	db 'Created map! With name: ', 0


ERROR_MSG:
	db ': command didnt exist', 0

DISPLAY_USER:
	db 'user@user/root/$ ', 0



		; BootLoader info
times 510-($-$$) db 0   ; Pad remainder of boot sector with 0s
dw 0xAA55               ; The standard PC boot signature
; boot-loader 512 bytes





INPUT_TEXT:
	times 512 db 0
