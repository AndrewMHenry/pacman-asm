;;;============================================================================
;;; INTERFACE /////////////////////////////////////////////////////////////////
;;;============================================================================

#define LEVEL_RESULT_WIN        0
#define LEVEL_RESULT_LOSE       1
#define LEVEL_RESULT_QUIT       2

levelPlay:
        ;; INPUT:
        ;;   ACC -- number of level to play
        ;;   <keyboard> -- accepts input from user
        ;;
        ;; OUTPUT:
        ;;   ACC -- result of play (win, lose, or quit)
        ;;   <screen buffer> -- affected during play
        ;;   <LCD> -- affected during play
        ;;
        CALL    levelBoardSetup       ; setup board for level number in ACC
        CALL    drawClearScreen       ; clear the screen buffer and LCD
        CALL    screenUpdate          ;
        CALL    boardUpdate           ; draw and flush board
levelPlay_loop:                       ;
        CALL    keyboardRead          ; ACC = keypress
levelPlay_checkClear:                 ;
        CP      skClear               ; repeat loop if key not clear
        JR      NZ, levelPlay_loop    ;
        LD      A, LEVEL_RESULT_QUIT  ; result = quit otherwise
        RET                           ; return

;;;============================================================================
;;; HELPER ROUTINES ///////////////////////////////////////////////////////////
;;;============================================================================

levelBoardSetup:
        PUSH    DE
        PUSH    HL
        LD      HL, levelWallMaps
        CALL    boardStageWallMap
        ;; LD      DE, LEVEL_PACMAN_START_CELL
        ;; CALL    boardSetPacmanStartCell
        CALL    boardDeploy
        POP     HL
        POP     DE
        RET

;;;============================================================================
;;; LEVEL DATA ////////////////////////////////////////////////////////////////
;;;============================================================================

#define LEVEL_PACMAN_START_CELL 256 * 7 + 7

levelWallMaps:
        .db     11111111b, 11111111b ; XXXXXXXXXXXXXXXX
        .db     10000000b, 00000001b ; X              X
        .db     10101011b, 11010101b ; X X X XXXX X X X
        .db     10101010b, 01010101b ; X X X X  X X X X
        .db     10101000b, 00010101b ; X X X      X X X
        .db     10101010b, 01010101b ; X X X X  X X X X
        .db     10101011b, 11010101b ; X X X XXXX X X X
        .db     10000000b, 00000001b ; X              X
        .db     11111111b, 11111111b ; XXXXXXXXXXXXXXXX

;;;============================================================================
;;; SETUP AND TEARDOWN ////////////////////////////////////////////////////////
;;;============================================================================

levelInit:
        RET

levelExit:
        RET
