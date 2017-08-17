main:
        ;; INPUT:
        ;;   <various>
        ;;
        ;; OUTPUT:
        ;;   <various>
        ;;
        ;; This is the main entry point for the application.
        ;;
        PUSH    HL              ; STACK: [PC HL]
        LD      HL, fontFBF     ; set font to fontFBF
        CALL    writeSetFont    ;
        CALL    titleScreenRun  ; run the title screen
        CALL    gamePlay        ; play the game
        CALL    mainEndScreen   ; show end screen
        POP     HL              ; STACK: [PC]
        RET                     ; return

;;; END SCREEN.................................................................

mainEndScreen:
        ;; INPUT:
        ;;   ACC -- game result
        ;;   <keyboard> -- user presses key to dismiss
        ;;
        ;; OUTPUT:
        ;;   <screen buffer, LCD> -- cleared, message displayed, cleared again
        ;;
        PUSH    DE                          ; STACK: [PC DE]
        PUSH    HL                          ; STACK: [PC DE HL]
        LD      HL, mainWinString           ; assume win string
        CP      GAME_RESULT_WIN             ; skip to win if result is win
        JR      Z, mainEndScreen_Win        ;
        LD      HL, mainLoseString          ; otherwise, load lose string
mainEndScreen_win:                          ;
        CALL    drawClearScreen             ; clear screen buffer
        LD      DE, MAIN_WIN_LOSE_LOCATION  ; write win or lose string
        CALL    writeString                 ;
        LD      DE, MAIN_YOU_LOCATION       ; write you string
        LD      HL, mainYouString           ;
        CALL    writeString                 ;
        CALL    screenUpdate                ; flush changes
        CALL    keyboardWait                ; wait for keypress
        POP     HL                          ; STACK: [PC DE]
        POP     DE                          ; STACK: [PC]
        RET                                 ; return

#define MAIN_YOU_LOCATION       29 * 256 + 24
#define MAIN_WIN_LOSE_LOCATION  29 * 256 + 48

mainYouString:
        .db     "YOU ", 0
mainWinString:
        .db     "WIN!", 0
mainLoseString:
        .db     "LOSE", 0
