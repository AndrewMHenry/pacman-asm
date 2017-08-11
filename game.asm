;;;============================================================================
;;; INTERFACE /////////////////////////////////////////////////////////////////
;;;============================================================================

#define GAME_RESULT_WIN         0
#define GAME_RESULT_LOSE        1
#define GAME_RESULT_QUIT        2

gamePlay:
        PUSH    BC                   ; STACK: [PC BC]
        LD      BC, GAME_LEVEL_PAIR  ; B, C = level count, first level
gamePlay_loop:                       ;
        LD      A, C                 ; ACC = level
        CALL    levelPlay            ; play the current level
        INC     C                    ; move to next level
        DJNZ    gamePlay_loop        ; repeat loop
        LD      A, GAME_RESULT_WIN   ; default to win
        POP     BC                   ; STACK: [PC]
        RET                          ; return

;;;============================================================================
;;; CONSTANTS /////////////////////////////////////////////////////////////////
;;;============================================================================

#define GAME_LEVEL_FIRST        1
#define GAME_LEVEL_LAST         1
#define GAME_LEVEL_COUNT        GAME_LEVEL_LAST - GAME_LEVEL_FIRST + 1
#define GAME_LEVEL_PAIR         256 * GAME_LEVEL_COUNT + GAME_LEVEL_FIRST

;;;============================================================================
;;; SETUP AND TEARDOWN ////////////////////////////////////////////////////////
;;;============================================================================

gameInit:
        RET

gameExit:
        RET
