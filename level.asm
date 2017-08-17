;;;============================================================================
;;; INTERFACE /////////////////////////////////////////////////////////////////
;;;============================================================================

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
        CALL    levelGhostsSetup               ; initialize ghosts
        CALL    drawClearScreen                ; clear screen buffer and LCD
        CALL    screenUpdate                   ;
        JR      levelPlay_skipWait             ;
levelPlay_loop:                                ;
        CALL    timerGet                       ; take time remaining mod 8
        LD      H, 0                           ;
        LD      A, L                           ;
        AND     7                              ;
        LD      L, A                           ;
        CALL    timerSet                       ;
        CALL    timerWait                      ;
levelPlay_skipWait:                            ;
        LD      HL, 8                          ;
        CALL    timerSet                       ;
        CALL    boardUpdate                    ; draw and flush board
        CALL    keyboardRead                   ; ACC = keypress
        CALL    levelHandleKeypress            ; handle keypress
        CALL    levelPacmanUpdate              ; update Pacman
        CALL    levelGhostsUpdate              ; update ghosts
        CALL    levelWinCheck                  ; check for win
        CALL    levelGhostCollisionCheck       ; check for ghost collision
        LD      A, (levelStatus)               ; repeat loop if still playing
        CP      LEVEL_STATUS_PLAY              ;
        JR      Z, levelPlay_loop              ;
        POP     HL                             ; STACK: [PC]
        RET                                    ; return

;;;============================================================================
;;; HELPER ROUTINES ///////////////////////////////////////////////////////////
;;;============================================================================

;;; SETUP......................................................................

levelBoardSetup:
        PUSH    BC                           ; STACK: [PC BC]
        PUSH    DE                           ; STACK: [PC BC DE]
        PUSH    HL                           ; STACK: [PC BC DE HL]
        PUSH    IX                           ; STACK: [PC BC DE HL IX]
        CALL    boardInitialize              ; prepare board for staging
        LD      HL, levelWallMaps            ; stage the wall map
        CALL    boardStageWallMap            ;
        LD      DE, LEVEL_PACMAN_START_CELL  ; stage Pacman on the board
        LD      HL, levelPacmanPicture       ;
        CALL    boardStageSprite             ;
        CALL    boardStageEmptyCell          ; (and stage empty cell there)
        LD      B, LEVEL_NUM_GHOSTS          ; B = number of ghosts
        LD      HL, levelGhostPicture        ; HL = ghost picture
        LD      IX, levelGhostStartCells     ; IX = base of ghost cell array
levelBoardSetup_ghostLoop:                   ;
        LD      E, (IX)                      ; E = column
        INC     IX                           ;
        LD      D, (IX)                      ; D = row
        INC     IX                           ;
        CALL    boardStageEmptyCell          ; stage empty cell
        CALL    boardStageSprite             ; stage ghost sprite
        DJNZ    levelBoardSetup_ghostLoop    ; repeat for each ghost
        LD      B, LEVEL_NUM_EMPTY_CELLs     ; B = number of empty cells
        LD      HL, levelEmptyCells          ; HL = empty cell array base
levelBoardSetup_emptyLoop:                   ;
        LD      E, (HL)                      ; E = cell-wise column
        INC     HL                           ;
        LD      D, (HL)                      ; D = cell-wise row
        INC     HL                           ;
        CALL    boardStageEmptyCell          ; stage empty cell
        DJNZ    levelBoardSetup_emptyLoop    ; repeat for each empty cell
        CALL    boardDeploy                  ; prepare board for gameplay
        POP     IX                           ; STACK: [PC BC DE HL]
        POP     HL                           ; STACK: [PC BC DE]
        POP     DE                           ; STACK: [PC BC]
        POP     BC                           ; STACK: [PC]
        RET                                  ; return

levelPacmanSetup:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   <level data> -- Pacman's data initialized for level
        ;;
        LD      A, LEVEL_PACMAN_START_DIRECTION  ; set Pacman's direction
        LD      (levelPacmanDirection), A        ;
        LD      (levelPacmanNextDirection), A    ;
        RET                                      ; return

levelGhostsSetup:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   <level data> -- Ghosts' data initialized for level
        ;;
        PUSH    BC                             ; STACK: [PC BC]
        PUSH    DE                             ; STACK: [PC BC DE]
        PUSH    HL                             ; STACK: [PC BC DE HL]
        LD      BC, LEVEL_NUM_GHOSTS           ; copy start directions
        LD      DE, levelGhostDirections       ;
        LD      HL, levelGhostStartDirections  ;
        LDIR                                   ;
        POP     HL                             ; STACK: [PC BC DE]
        POP     DE                             ; STACK: [PC BC]
        POP     BC                             ; STACK: [PC]
        RET                                    ; return

;;; UPDATING...................................................................

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
        LD      A, BOARD_DIRECTION_UP          ; next direction = UP
        LD      (levelPacmanNextDirection), A  ;
        RET                                    ; return
        ;;
levelHandleKeypress_right:
        LD      A, BOARD_DIRECTION_RIGHT       ; next direction = RIGHT
        LD      (levelPacmanNextDirection), A  ;
        RET                                    ; return
        ;;
levelHandleKeypress_down:
        LD      A, BOARD_DIRECTION_DOWN        ; next direction = DOWN
        LD      (levelPacmanNextDirection), A  ;
        RET                                    ; return
        ;;
levelHandleKeypress_left:
        LD      A, BOARD_DIRECTION_LEFT        ; next direction = LEFT
        LD      (levelPacmanNextDirection), A  ;
        RET                                    ; return

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

levelGhostsUpdate:
        ;; INPUT:
        ;;   <level data> -- determines how to update ghosts
        ;;
        ;; OUTPUT:
        ;;   <board data> -- ghosts changed on board
        ;;
        ;; NOTE: This routine will enter an infinite loop if
        ;; each direction is unavailable to any ghost.
        ;;
        PUSH    BC                             ; STACK: [PC BC]
        PUSH    DE                             ; STACK: [PC BC DE]
        PUSH    HL                             ; STACK: [PC BC DE HL]
        LD      B, LEVEL_NUM_GHOSTS            ; B = number of ghosts
        LD      C, LEVEL_GHOST_START_ID        ; C = ID of first ghost
        LD      HL, levelGhostDirections       ; HL = base of ghost directions
levelGhostsUpdate_loop:                        ;
        LD      D, (HL)                        ; D = direction from array
        LD      A, C                           ; ACC = ghost ID
        CALL    boardCheckMoveSprite           ; check movement 
        JR      NC, levelGhostsUpdate_skip     ; skip if ok
levelGhostsUpdate_turnLoop:                    ;
        LD      A, D                           ; D = (D + 1) % 4
        INC     A                              ;
        AND     3                              ;
        LD      D, A                           ;
        LD      A, C                           ; ACC = ghost ID
        CALL    boardCheckMoveSprite           ; check movement
        JR      C, levelGhostsUpdate_turnLoop  ; repeat if disallowed
        LD      (HL), D                        ; set direction to D
levelGhostsUpdate_skip:                        ;
        LD      A, C                           ; ACC = ghost ID
        CALL    boardMoveSprite                ; move
        INC     C                              ; advance ghost ID
        INC     HL                             ; advance direction pointer
        DJNZ    levelGhostsUpdate_loop         ; repeat for each ghost
        POP     HL                             ; STACK: [PC BC DE]
        POP     DE                             ; STACK: [PC BC]
        POP     BC                             ; STACK: [PC]
        RET                                    ; return

;;; CHECKING...................................................................

levelGhostCollisionCheck:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   <level data> -- collision registered
        ;;
        PUSH    BC                                 ; STACK: [PC BC]
        LD      B, LEVEL_NUM_GHOSTS                ; B = ghost count
        LD      C, LEVEL_GHOST_START_ID            ; C = first ghost ID
levelGhostCollisionCheck_loop:                     ;
        LD      A, LEVEL_PACMAN_ID                 ; ACC = Pacman ID
        CALL    boardCheckSpriteCollision          ; check for collision
        JR      C, levelGhostCollisionCheck_break  ; break if carry (true)
        INC     C                                  ; advance to next ghost ID
        DJNZ    levelGhostCollisionCheck_loop      ; repeat for each ghost
        JR      levelGhostCollisionCheck_return    ; return (no collision)
levelGhostCollisionCheck_break:                    ;
        LD      A, LEVEL_STATUS_LOSE               ; level status = LOSE
        LD      (levelStatus), A                   ;
levelGhostCollisionCheck_return:                   ;
        POP     BC                                 ; STACK: [PC]
        RET                                        ; return

levelWinCheck:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   (levelStatus) -- set to WIN if level has been won
        ;;
        CALL    boardGetDotCount     ; return if nonzero dots
        OR      A                    ;
        RET     NZ                   ;
        LD      A, LEVEL_STATUS_WIN  ; otherwise, level status = WIN
        LD      (levelStatus), A     ;
        RET                          ; return

;;;============================================================================
;;; CONSTANTS /////////////////////////////////////////////////////////////////
;;;============================================================================

#define LEVEL_PACMAN_ID                 0
#define LEVEL_GHOST_START_ID            1
#define LEVEL_NUM_GHOSTS                4

#define LEVEL_PACMAN_START_CELL         256 * 7 + 7
#define LEVEL_PACMAN_START_DIRECTION    BOARD_DIRECTION_RIGHT

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


levelGhostStartCells:
        ;; This is an array of two-byte (cell-wise column, cell-wise row)
        ;; pairs representing initial locations for the ghosts.
        ;;
        .db     7, 3
        .db     7, 5
        .db     8, 3
        .db     8, 5

levelGhostStartDirections:
        .db     BOARD_DIRECTION_RIGHT
        .db     BOARD_DIRECTION_UP
        .db     BOARD_DIRECTION_DOWN
        .db     BOARD_DIRECTION_LEFT

#define LEVEL_NUM_EMPTY_CELLS   4

levelEmptyCells:
        .db     6, 4
        .db     7, 4
        .db     8, 4
        .db     9, 4

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

levelGhostPicture:
        .db     01110000b       ;  XXX
        .db     10101000b       ; X X X
        .db     11111000b       ; XXXXX
        .db     11111000b       ; XXXXX
        .db     10101000b       ; X X X
        .db     00000000b       ;

;;;============================================================================
;;; VARIABLE DATA /////////////////////////////////////////////////////////////
;;;============================================================================

#define levelStatus                     levelData
#define levelPacmanDirection            levelStatus + 1
#define levelPacmanNextDirection        levelPacmanDirection + 1
#define levelGhostDirections            levelPacmanNextDirection + 1

#define levelDataEnd                    levelGhostDirections + LEVEL_NUM_GHOSTS
#define LEVEL_DATA_SIZE                 levelDataEnd - levelData

;;;============================================================================
;;; SETUP AND TEARDOWN ////////////////////////////////////////////////////////
;;;============================================================================

levelInit:
        RET

levelExit:
        RET
