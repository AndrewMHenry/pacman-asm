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
        PUSH    HL
        CALL    levelBoardSetup           ; setup board for level number in ACC
        CALL    levelPacmanSetup          ; initialize Pacman
        CALL    drawClearScreen           ; clear the screen buffer and LCD
        CALL    screenUpdate              ;
        JR      levelPlay_skipWait        ;
levelPlay_loop:                           ;
        CALL    timerWait                 ;
levelPlay_skipWait:                       ;
        LD      HL, 10                    ;
        CALL    timerSet                  ;
        CALL    levelUpdatePacman         ; update Pacman
        CALL    boardUpdate               ; draw and flush board
        CALL    keyboardRead              ; ACC = keypress
levelPlay_checkUp:                        ;
        CP      skUp                      ; if key == UP:
        JR      NZ, levelPlay_checkDown   ;
        LD      A, LEVEL_DIRECTION_UP     ;     (levelPacmanDirection) = UP
        LD      (levelPacmanDirection), A ;
        JR      levelPlay_loop            ;     continue
levelPlay_checkDown:                      ;
        CP      skDown                    ; elif key == DOWN:
        JR      NZ, levelPlay_checkLeft   ;
        LD      A, LEVEL_DIRECTION_DOWN   ;     (levelPacmanDirection) = DOWN
        LD      (levelPacmanDirection), A ;
        JR      levelPlay_loop            ;     continue
levelPlay_checkLeft:                      ;
        CP      skLeft                    ;
        JR      NZ, levelPlay_checkRight  ;
        LD      A, LEVEL_DIRECTION_LEFT   ;     (levelPacmanDirection) = LEFT
        LD      (levelPacmanDirection), A ;
        JR      levelPlay_loop            ;     continue
levelPlay_checkRight:                     ;
        CP      skRight                   ;
        JR      NZ, levelPlay_checkClear  ;
        LD      A, LEVEL_DIRECTION_RIGHT  ;     (levelPacmanDirection) = RIGHT
        LD      (levelPacmanDirection), A ;
        JR      levelPlay_loop            ;     continue
levelPlay_checkClear:                     ;
        CP      skClear                   ; repeat loop if key not clear
        JR      NZ, levelPlay_loop        ;
        LD      A, LEVEL_RESULT_QUIT      ; result = quit otherwise
        POP     HL
        RET                               ; return

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
        RET                                     ; return

levelUpdatePacman:
        ;; INPUT:
        ;;   <level data> -- determines how to update Pacman
        ;;
        ;; OUTPUT:
        ;;   <board data> -- Pacman changed on board
        ;;
        PUSH    DE
        PUSH    HL
        LD      HL, levelUpdatePacman_dispatch
        LD      A, (levelPacmanDirection)
        ADD     A, A
        LD      E, A
        LD      D, 0
        ADD     HL, DE
        LD      A, (HL)
        INC     HL
        LD      H, (HL)
        LD      L, A
        CALL    levelUpdatePacman_jumpHL
        POP     HL
        POP     DE
        RET
        ;;
levelUpdatePacman_jumpHL:
        JP      (HL)
        ;;
levelUpdatePacman_dispatch:
        .dw     levelUpdatePacman_moveUp
        .dw     levelUpdatePacman_moveRight
        .dw     levelUpdatePacman_moveDown
        .dw     levelUpdatePacman_moveLeft
        ;;
levelUpdatePacman_moveUp:
        LD      A, LEVEL_PACMAN_ID
        CALL    boardCheckMoveSpriteUp
        LD      A, LEVEL_PACMAN_ID
        CALL    NC, boardMoveSpriteUp
        RET
        ;;
levelUpdatePacman_moveRight:
        LD      A, LEVEL_PACMAN_ID
        CALL    boardCheckMoveSpriteRight
        LD      A, LEVEL_PACMAN_ID
        CALL    NC, boardMoveSpriteRight
        RET
        ;;
levelUpdatePacman_moveDown:
        LD      A, LEVEL_PACMAN_ID
        CALL    boardCheckMoveSpriteDown
        LD      A, LEVEL_PACMAN_ID
        CALL    NC, boardMoveSpriteDown
        RET
        ;;
levelUpdatePacman_moveLeft:
        LD      A, LEVEL_PACMAN_ID
        CALL    boardCheckMoveSpriteLeft
        LD      A, LEVEL_PACMAN_ID
        CALL    NC, boardMoveSpriteLeft
        RET

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

#define LEVEL_PACMAN_DIRECTION_SIZE     1

#define levelPacmanDirection    levelData

#define levelDataEnd    levelPacmanDirection + LEVEL_PACMAN_DIRECTION_SIZE

#define LEVEL_DATA_SIZE levelDataEnd - levelData

;;;============================================================================
;;; SETUP AND TEARDOWN ////////////////////////////////////////////////////////
;;;============================================================================

levelInit:
        RET

levelExit:
        RET
