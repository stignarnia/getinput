;   GetInput
;
;       Get console input from both keyboard and mouse
;
;   Antonio Perez Ayala - Version 1.0 - Jan/30/2014
;                       - Version 1.1 - Jan/31/2014 - Preserve console mode, disable quick edit
;                       - Version 1.2 - Feb/01/2014 - Get right button mouse clicks
;                       - Version 1.3 - Feb/04/2014 - Get Alt-keys and Shift-extended keys


        include                 \masm32\include\masm32rt.inc

        Main                    PROTO
        GetStdHandle            PROTO
        GetConsoleMode          PROTO
        SetConsoleMode          PROTO   ;http://msdn.microsoft.com/en-us/library/windows/desktop/ms686033(v=vs.85).aspx
        ReadConsoleInput        PROTO   ;http://msdn.microsoft.com/en-us/library/windows/desktop/ms684961%28v=vs.85%29.aspx

    .code

Main    PROC

        LOCAL   hInput          :DWORD
        LOCAL   lpMode          :DWORD
        LOCAL   lpBuffer        :INPUT_RECORD
        LOCAL   lpEvents        :DWORD

        invoke  GetStdHandle, STD_INPUT_HANDLE  ;EAX = console input handle
        mov     hInput, eax                     ;store it
        ;
        invoke  GetConsoleMode, hInput, ADDR lpMode     ;get current console mode
        ;
        mov     eax, lpMode                                     ;EAX = current mode
        or      eax, ENABLE_MOUSE_INPUT + ENABLE_EXTENDED_FLAGS ;enable mouse events + value...
        ;                                                       ;- required to disable quick edit
        and     eax, NOT (ENABLE_QUICK_EDIT_MODE OR ENABLE_PROCESSED_INPUT) ;disable quick edit and Ctrl-C
        invoke  SetConsoleMode, hInput, eax             ;change console mode
        ;
get_event:                                      ;get the next input event
        invoke  ReadConsoleInput, hInput, ADDR lpBuffer, 1, ADDR lpEvents
        ;
        cmp     lpBuffer.EventType, KEY_EVENT   ;is a key event?
        jne     SHORT check_mouse               ;no: continue
        ;
        cmp     lpBuffer.KeyEvent.bKeyDown,FALSE;the key was pressed?
        je      SHORT get_event                 ;no: ignore key releases
        ;
        movzx   eax, lpBuffer.KeyEvent.AsciiChar;get the key Ascii code
        or      ax, ax                          ;is zero?
        jz      SHORT virtual_key               ;yes: is extended key
        ;
        test    lpBuffer.KeyEvent.dwControlKeyState,LEFT_ALT_PRESSED ;Alt- pressed?
        jz      SHORT end_main                                       ;no: continue
        ;
        cmp     ax, 'z'                         ;is digit/letter?
        jg      SHORT end_main                  ;no: continue
        ;
        add     ax, 160                         ;add 160 as Alt-key signature (Alt-A=225)
        cmp     ax, 256                         ;was lowcase letter?
        jl      SHORT end_main                  ;no: continue
        sub     ax, 'a'-'A'                     ;else: convert to upcase
        jmp     SHORT end_main                  ;and return it
        ;
virtual_key:
        mov     ax, lpBuffer.KeyEvent.wVirtualKeyCode   ;get Virtual Key Code
        ;
        cmp     ax, VK_PRIOR                    ;less than 1st useful block?
        jl      SHORT get_event                 ;yes: ignore it
        cmp     ax, VK_DOWN                     ;in 1st useful block?
        jle     SHORT @F                        ;yes continue
        ;
        cmp     ax, VK_INSERT                   ;less than 2nd useful block?
        jl      SHORT get_event                 ;yes: ignore it
        cmp     ax, VK_DELETE                   ;in 2nd useful block?
        jle     SHORT @F                        ;yes: continue
        ;
        cmp     ax, VK_F1                       ;less than 3rd useful block?
        jl      SHORT get_event                 ;yes: ignore it
        cmp     ax, VK_F12                      ;greater than 3rd useful block?
        jg      SHORT get_event                 ;yes: ignore it
@@:
        add     ax, 256                         ;add 256 as extended-key signature
        ;
        test    lpBuffer.KeyEvent.dwControlKeyState,SHIFT_PRESSED   ;Shift- pressed?
        jz      SHORT end_main                                      ;no: continue
        add     ax, 512                                             ;else: add 512 as Shift- signature
        jmp     SHORT end_main                                      ;and return it
        ;
check_mouse:
        cmp     lpBuffer.EventType, MOUSE_EVENT ;is a mouse event?
        jne     get_event                       ;no: ignore event
        ;                                       ;left or right button pressed?
        test    lpBuffer.MouseEvent.dwButtonState, FROM_LEFT_1ST_BUTTON_PRESSED OR RIGHTMOST_BUTTON_PRESSED
        jz      get_event                       ;no: ignore button releases
        ;
        mov     eax, lpBuffer.MouseEvent.dwMousePosition;get click position as row<<16 + col
        test    lpBuffer.MouseEvent.dwButtonState, FROM_LEFT_1ST_BUTTON_PRESSED ;left button?
        jnz     SHORT neg_pos                                                   ;yes: continue
        or      ah, 80H                                 ;else: add 32768 to col for right button
neg_pos:
        neg     eax                                     ;change result sign as Mouse signature
   ;
end_main:
        mov     ebx, eax                        ;pass result value to EBX
        invoke  SetConsoleMode, hInput, lpMode  ;recover original console mode
        invoke  ExitProcess, ebx                ;and return result value

Main    ENDP

        end     Main