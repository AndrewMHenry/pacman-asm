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
        POP     HL              ; STACK: [PC]
        RET                     ; return
