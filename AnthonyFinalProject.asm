; AddTwo.asm - adds two 32-bit integers.
; Chapter 3 example

INCLUDE Irvine32.inc
.stack 4096
ExitProcess proto,dwExitCode:dword



.data

;; Main Struct. Size 20
hashItem STRUCT
    address DWORD ?
    key BYTE 20 DUP(0) ; Byte array for the key
    value BYTE 20 DUP(0) ; Byte array for the value
hashItem ENDS




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Global Heap variable to be used throughout
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
hHeap HANDLE ?
tempHeap HANDLE ?  ;; this will store the old one
bucketStart DWORD ?
temp DWORD ?
hashItemStartVariable DWORD ?
keyVar BYTE 20 DUP(0)
valueVar BYTE 20 DUP(0)
hashSize DWORD 0
bucketSize DWORD 15 ;; change this to change the bucket size. Set default to 15
resizeValue DWORD 11

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Printing messages
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
hashSizeMessage BYTE "The number of items in the hashmap is ",0
deleteSuccessMessage BYTE "Hashmap item was delete succesfully!",0
itemNotFoundMessage BYTE "There is no value in the hashmap with that key",0
itemExistMessage BYTE "There is already a value with that key ",0
keyPrint BYTE "      Key  : ",0
valuePrint BYTE "      Value: ",0
enterKeyString BYTE "Enter key:  ",0
enterValueString BYTE "Enter value:  ",0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Menu varaibles
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

msgMenu BYTE "---- Calo Hashmap ----",0dh,0ah
	BYTE 0dh,0ah
	BYTE "1. Insert a key value pair"     ,0dh,0ah
	BYTE "2. Search a value"      ,0dh,0ah
	BYTE "3. Remove a value"       ,0dh,0ah
	BYTE "4. Print entire hashmap"     ,0dh,0ah
	BYTE "5. Exit program"      ,0dh,0ah
	BYTE " "      ,0dh,0ah
    BYTE "Enter Choice: ",0
.code
;
;; returns value in eax



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Hashmap functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CalculateHash PROC
    ;; Recieves a key value
    ;; loops over characters and adds them then does a mod by the bucket size
    ;; returns value ine eax
    push EBP
	mov EBP, ESP
    mov ESI, [EBP + 8]
    mov EDI, ESI
    mov EDX, ESI
    call StrLength
    mov ECX, EAX; mov length of string into ecx
    xor EAX, EAX ; Clear eax (initialize hash value to 0)
    xor EDX, EDX; Clear eax (initialize hash value to 0)
    mov EBX, [EBP + 8]
    calculate_loop:
        ; Load the current byte into ebx
        mov al, [EBX]
        add EDX,EAX 
        inc EBX
        loop calculate_loop
    mov EAX, EDX
    mov EDX, 0           
    mov EBX, [bucketSize]          ;; this is the bucket size

    div EBX     ; Move the remainder from EAX to EDX
    mov EAX, EDX
    pop ebp
    ret 4
CalculateHash ENDP 

;; Initiallizes a bucket with size of bucketSize time 4
;; stores the bucket size variable number of address
createHashmapBucket PROC
    invoke GetProcessHeap
    mov hHeap, EAX
    mov EBX, [bucketSize]
    imul EBX, 4
    invoke HeapAlloc, hHeap, HEAP_ZERO_MEMORY, EBX;; allocate memory on the heap size of bs * 4
    mov bucketStart, EAX
    ret
createHashmapBucket ENDP

GetStringLength PROC
    xor  ECX, ECX; Clear ECX register (counter for string length)
countLoop:
    mov  al, [EDX + ECX]        ; Load the byte at the current position into AL register
    cmp  al, 0                  ; Compare it with null terminator (end of string)
    je   done                   ; If it's null terminator, exit the loop
    inc  ECX                    ; Increment counter
    jmp  countLoop              ; Continue looping
done:
    mov  EAX, ECX               ; Move the length stored in ECX to EAX (return value)
    ret                         ; Return from the procedure
GetStringLength ENDP



HT_InsertHelper PROC
    push ebp
    mov ebp, esp
    ;; allocate heap space matching struct size of hashItem
    invoke HeapAlloc, hHeap, HEAP_ZERO_MEMORY, SIZEOF hashItem
    mov EBX, EAX;; now you have memory location of the newly allocated hashItem on HEAP in EBX

    ;; first get the value off the stack first and write it to location on heap
    mov EDX, [EBP + 8] ;; GETTING environment variables
    call GetStringlength ;; this will write the length of the string into EAX and ECX
    mov ESI, EDX
    mov EAX, EBX
    add EAX, 24
    mov ESI, [EBP + 8]
    mov EDI, EAX;; ebx + 4 is the location of value, EBX contains the start of hashmap. next = 0 spaces key = 4 spaces, value = 24 SPACES
    rep movsb

    mov EDX, [EBP + 12]
    call GetStringLength
    call crlf

    mov ESI, EDX
    mov EAX, EBX
    add EAX, 4 ;; ebx + 8 is the location of key, EBX contains the start of hashmap. next = 0 spaces key = 8 spaces, value = 28 SPACES
    mov EDI, EAX
    rep movsb

    pop ebp
    ret 8
HT_InsertHelper ENDP 

HT_Insert PROC
;; this takes 2 items 1. hash key 2. hash item
    push ebp
    mov ebp, esp
    ;; check if the value exists already, if it does exit
    push [ebp + 12]
    call HT_Search
    cmp EDX, 0
    jnz itemExistsAlready

    push [ebp + 12] ; push key
    push [ebp + 8] ; push value
    call HT_InsertHelper
    ;; at this point the memory location of the newly created hash item will be in ebx
    mov temp, EBX
    push [ebp + 12]
    call CalculateHash ;returns eax with hash number
    imul EAX, 4
    add EAX, bucketStart
    mov EBX, temp
    mov EDX, [EAX]
    cmp EDX, 0   ;; get to the location. If the value of EDXis 0 then that bucket location is empty
    jz noCollision
    mov [EBX], EDX;; this takes the address of the collision and writes it in the next of the struct

    noCollision:
        mov [EAX], EBX  ;; write the value of the newly created hashmap into the proper bucket location
    
    mov EAX, [hashSize]    ; Load the value of myInteger into EAX
    inc EAX                  ; Increment the value in EAX by one
    mov [hashSize], EAX 
    pop ebp
    ret 8
    
    itemExistsAlready:
        call crlf
        mov EDX, OFFSET itemExistMessage
        call writeString
        call crlf
        call crlf
        pop ebp 
        ret 8

HT_Insert ENDP


;; This function takes in the key value to be deleted
;; Finds where it is in the hashmap if it exists
;; Then writes the next value hasah item in the location pointing to the hashItem. Then frees the memory
HT_Remove PROC
    push ebp
    mov ebp, esp
    mov EDX, [ebp+8] ;; Move location of variable string to delete into EDX
    push EDX
    call HT_Search
    cmp EDX, 0
    je itemNotFound
    push [ebp + 8]
    call CalculateHash
    imul EAX, 4
    add EAX, bucketStart ;;this is the memory location of the hashed item. Need to dereference her
    mov EBX, [EAX]
    checkItemInLinkedList:
        mov hashItemStartVariable, EBX
        add EBX, 4
        mov ESI, EBX
        mov EDI,[EBP+8]
        cld
        push EDI
        push ESI
        call Str_compare
        je found ;; the strings are the same
        jmp notFoundYet



    found:
        sub EBX, 4
        ;; the location pointing to the found item is in EAX
        ;; what we need to do is get the next value from the found item and move it into eax
        mov EDX, [EBX]
        mov [EAX], EDX
        call crlf
        mov eax, [hashSize]
        dec eax
        mov [hashSize], eax
        invoke HeapFree, hHeap, 0, [EBX]
        pop ebp 
        ret 4
    
    notfoundYet:
        mov EDX, hashItemStartVariable
        mov EBX, [EDX]
        cmp EBX, 0
        mov EAX, EDX
        jz itemNotFound
        jmp checkItemInLinkedList

    itemNotFound:
        mov EDX, OFFSET itemNotFoundMessage
        call WriteString
        call crlf
        pop ebp
        ret 4
HT_Remove ENDP


HT_Search PROC
    ;; input is the search key
    push ebp
    mov ebp, esp
    mov EDX, [ebp + 8]
    push EDX
    call CalculateHash
    imul EAX, 4
    add EAX, bucketStart ;;this is the memory location of the hashed item. Need to dereference her
    mov EBX, [EAX]
    cmp EBX, 0
    jz notFound
    ;;
    ;; 5.5 what is need is to retrieve items during hash collission. To achieve this we need to compare the strirngs on line 190/191
    ;; the strings are loaded in esi and edi
    ;;;
    checkItemInLinkedList:
        mov hashItemStartVariable, EBX
        add EBX, 4
        mov ESI, EBX
        mov EDI,[EBP+8]
        cld
        push EDI
        push ESI
        call Str_compare
        je found ;; the strings are the same
        jmp notFoundYet
        

    found:
        mov EAX, [hashItemStartVariable]
        add EAX, 24
        mov EDX, EAX
        pop ebp
        ret 4

    notFoundYet:
        mov EDX, [hashItemStartVariable] ;; THIS PUTS 
        mov EBX, [EDX] ;;
        cmp EBX, 0
        jz notFound
        jmp checkItemInLinkedList


    notFound:
        XOR EDX, EDX
        pop ebp 
        ret 4
HT_Search ENDP



printLL PROC
    ;; one variable is memory address of the item
    ;; print ll means print linkedlist
    push ebp
    mov ebp, esp
    mov EBX, [ebp + 8]
    printItem:
        mov EDX, OFFSET keyPrint
        call WriteString
        ADD EBX, 4
        mov EDX, EBX
        call WriteString
        call crlf
        MOV EDX, OFFSET valuePrint
        call WriteString
        add EBX, 20
        mov EDX, EBX
        call WriteString
        call crlf
        call crlf
    ;; this part checks if there is another item in linkedlist
    sub EBX, 24
    mov EDX, [EBX]
    mov EBX, EDX
    cmp EBX, 0
    jnz printItem  ;; if the value isn't 0 there is another item in linked list. Load it into EBX then jump back to print again
    pop ebp
    ret 4
printLL ENDP

;; This function will traverse the hashmap and print all key value pairs in it
HT_Print PROC
    mov EDX, OFFSET hashSizeMessage
    call writeString
    mov EAX, hashSize
    call WriteDec
    call crlf
    call crlf
    
    mov EAX, [bucketStart]
    mov ECX, [bucketSize] ;; bucketSize
    mainPrintLoop:
        CMP ECX, [bucketSize]
        ja done
        MOV EBX, [EAX]
        CMP EBX, 0
        jz noItem
        push [EAX]
        call printLL
        add EAX, 4
        loop mainPrintLoop
    noItem:
        add EAX, 4
        loop mainPrintLoop
    done:
        ret

HT_Print ENDP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Hashmap functions END
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; MENU functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ChooseProcedure PROC
    mov AH, 0
    cmp AL, 1
    je location1

    cmp AL, 2
    je location2

    cmp AL, 3
    je location3

    cmp AL, 4
    je location4


    location2:
        mov EDX, OFFSET enterKeyString
        call WriteString
        mov EDX, OFFSET keyVar

        mov ECX, 19
        call ReadString 
        call crlf
        push OFFSET keyVar
        call HT_Search
        cmp EDX, 0
        JE notFound
        mov EAX, EDX
        mov EDX, OFFSET valuePrint
        call writeString
        mov EDX, EAX
        call writeString
        call crlf
        call crlf
        ret

        notFound:
            mov EDX, OFFSET itemNotFoundMessage
            call WriteString
            call crlf
            call crlf
        ret

    location1:
        mov EDX, OFFSET enterKeyString
        call WriteString
        mov EDX, OFFSET keyVar

        mov ECX, 19
        call ReadString 

        call crlf
        mov EDX, OFFSET enterValueString
        call writeString
        mov EDX, OFFSET valueVar
        mov ECX, 19
        call ReadString
        push OFFSET keyVar
        push OFFSET valueVar
        call HT_Insert
        ret

    location3:
        mov EDX, OFFSET enterKeyString
        call WriteString
        mov EDX, OFFSET keyVar
        mov ECX, 19
        call ReadString 
        call crlf
        push OFFSET keyVar
        call HT_Remove
        call crlf
        ret

  

    location4:
        call crlf
        call HT_Print
        xor ecx, ecx
        ret

	ret
ChooseProcedure ENDP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; MENU functions END
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;_________________________________________________________________________________________________________________


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; MAIN SECTION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
main proc

    call createHashmapBucket

menu:	
    mov EDX, OFFSET msgMenu
    call WriteString
    call	ReadInt
    call crlf
 	cmp	    al,5						; is selection valid (1-5)?
	je	    quit							; if above 5, go back
    ja      menu
	cmp	    al,1
	jl	    menu
    call ChooseProcedure
    jmp menu


    quit:
        invoke HeapFree, hHeap, 0, bucketStart ;; clean up bucket
        ret

main endp
end main 