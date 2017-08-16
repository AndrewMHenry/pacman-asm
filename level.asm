;;;============================================================================
;;; INTERFACE /////////////////////////////////////////////////////////////////
;;;============================================================================

#define LEVEL_RESULT_WIN        0
#define LEVEL_RESULT_LOSE       1
#define LEVEL_RESULT_QUIT       2

#define LEVEL_STATUS_PLAY       0
#define LEVEL_STATUS_WIN        1
#define LEVEL_STATUS_LOSE       2
#define LEVEL_STATUS_QUIT       3

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
        PUSH    HL                             ; STACK: [PC HL]
        LD      A, LEVEL_STATUS_PLAY           ; status = PLAY
        LD      (levelStatus), A               ;
        CALL    levelBoardSetup                ; setup board for level
        CALL    levelPacmanSetup               ; initialize Pacman
        CALL    drawClearScreen                ; clear screen buffer and LCD
        CALL    screenUpdate                   ;
        JR      levelPlay_skipWait             ;
levelPlay_loop:                                ;
        CALL    timerWait                      ;
levelPlay_skipWait:                            ;
        LD      HL, 10                         ;
        CALL    timerSet                       ;
        CALL    levelPacmanUpdate              ; update Pacman
        CALL    boardUpdate                    ; draw and flush board
        CALL    keyboardRead                   ; ACC = keypress
        CALL    levelHandleKeypress            ; handle keypress
        LD      A, (levelStatus)               ; repeat loop if still playing
        CP      LEVEL_STATUS_PLAY              ;
        JR      Z, levelPlay_loop              ;
        POP     HL                             ; STACK: [PC]
        RET                                    ; return

;;;============================================================================
;;; HELPER ROUTINES ///////////////////////////////////////////////////////////
;;;============================================================================

levelBoardSetup:
        PUSH    DE                          ; STACK: [PC DE]
        PUSH    HL                          ; STACK: [PC DE HL]
        CALL    boardInitialize             ; prepare board for staging
        LD      HL, levelWallMaps           ; stage the wall map
        CALL    boardStageWallMap           ;
        LD      DE, LEVEL_PACMAN_START_CELL ; stage Pacman on the board
        LD      HL, levelPacmanPicture      ;
        CALL    boardStageSprite            ;
        CALL    boardStageEmptyCell         ; (and stage empty cell there)
        CALL    boardDeploy                 ; prepare board for gameplay
        POP     HL                          ; STACK: [PC DE]
        POP     DE                          ; STACK: [PC]
        RET                                 ; return

levelPacmanSetup:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   <level data> -- Pacman's data initialized for level
        ;;
        LD      A, LEVEL_PACMAN_START_DIRECTION ; set Pacman's direction
        LD      (levelPacmanDirection), A       ;
        LD      (levelPacmanNextDirection), A   ;
        RET                                     ; return

levelPacmanUpdate:
        ;; INPUT:
        ;;   <level data> -- determines how to update Pacman
        ;;
        ;; OUTPUT:
        ;;   <board data> -- Pacman changed on board
        ;;
        PUSH    DE                             ; STACK: [PC DE]
        LD      A, (levelPacmanNextDirection)  ; D = next direction
        LD      D, A                           ;
        LD      A, LEVEL_PACMAN_ID             ; check move in next direction
        CALL    boardCheckMoveSprite           ;
        JR      C, levelPacmanUpdate_skip      ; if allowed:
        LD      A, D                           ;     direction = next direction
        LD      (levelPacmanDirection), A      ;
        LD      A, LEVEL_PACMAN_ID             ;     move in new direction
        CALL    boardMoveSprite                ;
        JR      levelPacmanUpdate_return       ;     return
levelPacmanUpdate_skip:                        ; else:
        LD      A, (levelPacmanDirection)      ;
        LD      D, A                           ;
        LD      A, LEVEL_PACMAN_ID             ;     try current direction
        CALL    boardCheckMoveSprite           ;
        LD      A, LEVEL_PACMAN_ID             ;
        CALL    NC, boardMoveSprite            ;
levelPacmanUpdate_return:                      ;
        LD      A, LEVEL_PACMAN_ID             ; collect items
        CALL    boardSpriteCollectItems        ;
        POP     DE                             ; STACK: [PC]
        RET                                    ; return

levelHandleKeypress:
        ;; INPUT:
        ;;   ACC -- keypress
        ;;
        ;; OUTPUT:
        ;;   <level data> -- updated based on keypress
        ;;
        CP      skClear                        ; CLEAR dispatch
        JR      Z, levelHandleKeypress_clear   ;
        CP      skUp                           ; UP dispatch
        JR      Z, levelHandleKeypress_up      ;
        CP      skRight                        ; RIGHT dispatch
        JR      Z, levelHandleKeypress_right   ;
        CP      skDown                         ; DOWN dispatch
        JR      Z, levelHandleKeypress_down    ;
        CP      skLeft                         ; LEFT dispatch
        JR      Z, levelHandleKeypress_left    ;
        RET                                    ; return
        ;;
levelHandleKeypress_clear:
        LD      A, LEVEL_STATUS_QUIT           ; status = QUIT
        LD      (levelStatus), A               ;
        RET                                    ; return
        ;;
levelHandleKeypress_up:
        LD      A, LEVEL_DIRECTION_UP          ; next direction = UP
        LD      (levelPacmanNextDirection), A  ;
        RET                                    ; return
        ;;
levelHandleKeypress_right:
        LD      A, LEVEL_DIRECTION_RIGHT       ; next direction = RIGHT
        LD      (levelPacmanNextDirection), A  ;
        RET                                    ; return
        ;;
levelHandleKeypress_down:
        LD      A, LEVEL_DIRECTION_DOWN        ; next direction = DOWN
        LD      (levelPacmanNextDirection), A  ;
        RET                                    ; return
        ;;
levelHandleKeypress_left:
        LD      A, LEVEL_DIRECTION_LEFT        ; next direction = LEFT
        LD      (levelPacmanNextDirection), A  ;
        RET                                    ; return

;;;============================================================================
;;; CONSTANTS /////////////////////////////////////////////////////////////////
;;;============================================================================

#define LEVEL_PACMAN_ID         0

#define LEVEL_DIRECTION_UP      0
#define LEVEL_DIRECTION_RIGHT   1
#define LEVEL_DIRECTION_DOWN    2
#define LEVEL_DIRECTION_LEFT    3

#define LEVEL_PACMAN_START_CELL         256 * 7 + 7
#define LEVEL_PACMAN_START_DIRECTION    LEVEL_DIRECTION_RIGHT

;;;============================================================================
;;; LEVEL DATA ////////////////////////////////////////////////////////////////
;;;============================================================================

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
;;; SPRITE IMAGE DATA /////////////////////////////////////////////////////////
;;;============================================================================

levelPacmanPicture:
        .db     01111000b       ;  XXXX
        .db     11010000b       ; XX X
        .db     11100000b       ; XXX
        .db     11110000b       ; XXXX
        .db     01111000b       ;  XXXX
        .db     00000000b       ;

;;;============================================================================
;;; VARIABLE DATA /////////////////////////////////////////////////////////////
;;;============================================================================

#define levelStatus                     levelData
#define levelPacmanDirection            levelStatus + 1
#define levelPacmanNextDirection        levelPacmanDirection + 1

#define levelDataEnd                    levelPacmanNextDirection + 1
#define LEVEL_DATA_SIZE                 levelDataEnd - levelData

;;;============================================================================
;;; SETUP AND TEARDOWN ////////////////////////////////////////////////////////
;;;============================================================================

levelInit:
        RET

levelExit:
        RET
