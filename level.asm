;==============================================================================
; LEVEL FORMAT ////////////////////////////////////////////////////////////////
;==============================================================================

; Currently, the specifications of the level arrangements are intertwined
; with the level-playing logic in level.asm.  It would be better to have
; a standardized format for specifying a level arrangement which would
; be understood by this logic, allowing the level arrangements to be
; developed and implemented separately.
;
; Previous formats have included separate fields to specify the various
; components of a level arrangement.  For example, a bitmap has been used to
; specify which cells of the board are walls, and then separate fields have
; specified where empty cells or ghosts are to be staged.  This leads to a
; fairly compact, but complicated, representation.
;
; An alternative approach which makes rather the opposite tradeoffs is to
; use an ASCII-based grid representation.  For example, the standard first
; level arrangement would be specified as
;
;       ################
;       #o............o#
;       #.#.#.####.#.#.#
;       #.#.#.#gg#.#.#.#
;       #.#.#.    .#.#.#
;       #.#.#.#gg#.#.#.#
;       #.#.#.####.#.#.#
;       #o.....p......o#
;       ################
;
; where
;
;       '#'     represents a wall cell,
;       '.'     represents a small dot cell,
;       'o'     represents a big dot cell,
;       ' '     represents an empty cell,
;       'g'     represents the starting position of a ghost, and
;       'p'     represents the starting position of Pacman.
;

;       0000000000000000
;       0o............o0
;       0.0.0.0000.0.0.0
;       0.0.0.0gg0.0.0.0
;       0.0.0.    .0.0.0
;       0.0.0.0gg0.0.0.0
;       0.0.0.0000.0.0.0
;       0o.....p......o0
;       0000000000000000

;;;============================================================================
;;; INTERFACE /////////////////////////////////////////////////////////////////
;;;============================================================================

#define LEVEL_STATUS_PLAY       0
#define LEVEL_STATUS_WIN        1
#define LEVEL_STATUS_LOSE       2
#define LEVEL_STATUS_QUIT       3

levelPlay:
        ;; INPUT:
        ;;   C -- number of level to play
        ;;   <keyboard> -- accepts input from user
        ;;
        ;; OUTPUT:
        ;;   ACC -- result of play (win, lose, or quit)
        ;;   <screen buffer> -- affected during play
        ;;   <LCD> -- affected during play
        ;;
        PUSH    HL                             ; STACK: [PC HL]
        CALL    levelStatusSetup               ; initialize status
        CALL    levelClockSetup                ; initialize clock
        CALL    levelPacmanSetup               ; initialize Pacman
        CALL    levelGhostsSetup               ; initialize ghosts
        CALL    levelBoardSetup                ; initialize board
        CALL    drawClearScreen                ; clear screen buffer
        CALL    boardDraw                      ; draw the board
        CALL    screenUpdate                   ; flush to screen
levelPlay_loop:                                ;
        CALL    levelClockWait                 ; wait for level clock
        CALL    boardUpdate                    ; draw and flush board
        CALL    keyboardRead                   ; ACC = keypress
        CALL    levelHandleKeypress            ; handle keypress
        CALL    levelPacmanUpdate              ; update Pacman
        CALL    levelGhostsUpdate              ; update ghosts
        CALL    levelWinCheck                  ; check for win
        CALL    levelGhostCollisionCheck       ; check for ghost collision
        CALL    levelPlay_assertNoOverflow     ; quit if timer overflowed
        LD      A, (levelStatus)               ; repeat loop if still playing
        CP      LEVEL_STATUS_PLAY              ;
        JR      Z, levelPlay_loop              ;
        POP     HL                             ; STACK: [PC]
        RET                                    ; return
        ;;
levelPlay_assertNoOverflow:
        PUSH    DE                             ; STACK: [PC DE]
        PUSH    HL                             ; STACK: [PC DE HL]
        CALL    timerGet                       ; HL = timer value
        LD      DE, (levelTicks)               ; subtract ticks from timer
        OR      A                              ;
        SBC     HL, DE                         ; carry if timer < ticks
        CCF                                    ; carry if timer >= ticks
        POP     HL                             ; STACK: [PC DE]
        POP     DE                             ; STACK: [PC]
        RET     NC                             ; return if no overflow
        LD      A, LEVEL_STATUS_QUIT           ; otherwise, status = QUIT
        LD      (levelStatus), A               ;
        RET                                    ; return
        ;;
levelPlay_getLevelTicks:
        RET                                    ; return

;;;============================================================================
;;; TIMING CONSIDERATIONS /////////////////////////////////////////////////////
;;;============================================================================

#define LEVEL_TICKS     4 * BOARD_MOVE_INCREMENT

;;; Given that the only portable, independent timing mechanism is the ~110 Hz
;;; interrupt clock, 1/110 seconds seems to be the minimum amount of time
;;; between uniformly-timed events.  To put the game on this clock requires us
;;; to fit our game loop code into 6000000 / 110 != 54545 t-states.
;;;
;;; The limiting factor on the code speed seems to be writing to the LCD, so
;;; it makes sense to consider the number of LCD writes required in each game
;;; cycle.  We assume that the following screen areas will need updating:
;;;
;;;     (1) Five sprites, which may be misaligned horizontally or vertically
;;;         or neither,
;;;
;;;     (2) The status bar below the screen, which spans the entire width
;;;         of the screen.
;;;
;;;     (3) One item which appears (aligned) on the board.
;;;
;;; If a sprite is misaligned vertically, its bounding rectangle may span
;;; 2 bytes horizontally and 12 bytes vertically (due to the cells it
;;; touches).  Since both columns require two additional writes to set the
;;; row and column, this gives a total of 28 writes per sprite, for a total
;;; of 140 sprite writes.
;;;
;;; Assuming the entire status bar needs to be updated (which is negotiable),
;;; we need a total of (5 + 2) * 12 = 84 LCD writes to span five rows all the
;;; way across the LCD.
;;;
;;; Finally, an item that appears may require up to (6 + 2) * 2 = 16 additional
;;; writes.
;;;
;;; Adding these values gives 240 LCD writes, which occupy a minimum of
;;; 240 * 10 microseconds = 2.4 milliseconds.  Realistically, the time for
;;; each write might actually be 10 * (1 + 11/60) because the OUT instruction
;;; may not be included in the delay, bumping up the total screen update time
;;; to 2.84 milliseconds.  This certainly fits in the ~9 milliseconds in each
;;; interupt cycle.
;;;
;;; However, there does seem to be a much more efficient way to handle the LCD.
;;; In particular, everything except the sprites is aligned on 6-pixel-wide
;;; boundaries, and the sprites only ever need to occupy two cells at a time.
;;; Therefore, the minimum number of LCD writes if the LCD is in 6-bit mode
;;; is closer to
;;;
;;;     5 * (2 + 6) * 2  // 5 sprites, 8 bytes per column, 2 columns
;;;     + 1 * (2 + 6)    // 1 item, 8 bytes per column
;;;     + 16 * (2 + 5)   // 16 status cells, 7 bytes per column
;;;     = 200
;;;
;;; However, the actual number is likely to be lower because not all of the
;;; status bar characters will need to change.
;;;
;;;
;;; Now we're getting somewhere: in a recent simulation, one iteration of a
;;; game loop took a whopping 430,184 t-states, with over 400,000 of them
;;; due to the call to the boardUpdate routine.  That is, updating the board
;;; takes over SEVEN (!!!) interrupt cycles, with just over one whole
;;; interrupt cycle being taken by updating the screen (which, as of this
;;; writing, still operates by flushing the entire buffer to the LCD).
;;;
;;; In order to fit into one interrupt cycle, we would need to either speed
;;; up the screenUpdate function in the screen.asm library or write custom
;;; LCD code.  However, the part of updating the board excluding the call
;;; to screenUpdate is clearly hogging the lion's share of the t-states,
;;; so this is the part that needs the most work.  This part is also much more
;;; convenient to fix than screen.asm.  In addition, scheduling each loop
;;; iteration for two interrupt cycles instead of one seems like a reasonable
;;; game speed, and this could be achieved without ever changing the screen.asm
;;; code.
;;;
;;;
;;; Tests indicate that a movement speed of 1 pixel per 6 interrupt cycles
;;; looks pretty good.  However, updating the LCD every 6 interrupt cycles
;;; causes Pacman and the ghosts to appear blurry when moving.  It seems that
;;; the only way to cause sprites to move at this speed and prevent this
;;; blurriness is to move the sprites in two-pixel increments.  This will
;;; probably make the movement appear less smooth, but only a field test will
;;; tell whether this is a good tradeoff.
;;;
;;;
;;; On closer inspection, the leading pixels on moving sprites (that is, the
;;; forward-most pixels in the direction of movement) appear blurriest.  This
;;; indicates that pixels are blurry because they are being cleared without
;;; being given enough time to darken.  Therefore, a fix that does not involve
;;; slowing down the game speed might be to turn on pixels before necessary
;;; but leave them on until they would normally be turned off.

;;;============================================================================
;;; HELPER ROUTINES ///////////////////////////////////////////////////////////
;;;============================================================================

;;; BOARD SETUP................................................................

levelBoardSetup:
        ;; INPUT:
        ;;   C -- number of current level
        ;;
        ;; OUTPUT:
        ;;   <board data> -- initialized (via board interface) for level
        ;;
        CALL    boardInitialize              ; prepare board for staging
        CALL    levelStageWallMap            ; stage wall map on board
        CALL    levelStagePacman             ; stage Pacman on board
        CALL    levelStageGhosts             ; stage ghosts on board
        CALL    levelStageEmptyCells         ; stage empty cells on board
        CALL    boardDeploy                  ; prepare board for gameplay
        RET                                  ; return

levelStageWallMap:
        ;; INPUT:
        ;;   C -- level number
        ;;
        ;; OUTPUT:
        ;;   <board data> -- wall map for level staged
        ;;
        PUSH    HL                           ; STACK: [PC HL]
        LD      HL, levelWallMaps            ; stage the wall map
        CALL    boardStageWallMap            ;
        POP     HL                           ; STACK: [PC]
        RET                                  ; return

levelStagePacman:
        ;; INPUT:
        ;;   C -- level number
        ;;
        ;; OUTPUT:
        ;;   <board data> -- Pacman staged on board
        ;;
        PUSH    DE                           ; STACK: [PC DE]
        PUSH    HL                           ; STACK: [PC DE HL]
        LD      DE, LEVEL_PACMAN_START_CELL  ; stage Pacman on the board
        CALL    levelGetPacmanPicture        ;
        CALL    boardStageSprite             ;
        CALL    boardStageEmptyCell          ; (and stage empty cell there)
        POP     HL                           ; STACK: [PC DE]
        POP     DE                           ; STACK: [PC]
        RET                                  ; return

levelStageGhosts:
        ;; INPUT:
        ;;   C -- level number
        ;;
        ;; OUTPUT:
        ;;   <board data> -- ghosts staged on board
        ;;
        PUSH    BC                           ; STACK: [PC BC]
        PUSH    DE                           ; STACK: [PC BC DE]
        PUSH    HL                           ; STACK: [PC BC DE HL]
        PUSH    IX                           ; STACK: [PC BC DE HL IX]
        LD      B, LEVEL_NUM_GHOSTS          ; B = number of ghosts
        LD      HL, levelGhostPicture        ; HL = ghost picture
        LD      IX, levelGhostStartCells     ; IX = base of ghost cell array
levelStageGhosts_loop:                       ;
        LD      E, (IX)                      ; E = column
        INC     IX                           ;
        LD      D, (IX)                      ; D = row
        INC     IX                           ;
        CALL    boardStageEmptyCell          ; stage empty cell
        CALL    boardStageSprite             ; stage ghost sprite
        DJNZ    levelStageGhosts_loop        ; repeat for each ghost
        POP     IX                           ; STACK: [PC BC DE HL]
        POP     HL                           ; STACK: [PC BC DE]
        POP     DE                           ; STACK: [PC BC]
        POP     BC                           ; STACK: [PC]
        RET                                  ; return

levelStageEmptyCells:
        ;; INPUT:
        ;;   C -- level number
        ;;
        ;; OUTPUT:
        ;;   <board data> -- empty cells staged on board
        ;;
        PUSH    BC                           ; STACK: [PC BC]
        PUSH    DE                           ; STACK: [PC BC DE]
        PUSH    HL                           ; STACK: [PC BC DE HL]
        LD      B, LEVEL_NUM_EMPTY_CELLS     ; B = number of empty cells
        LD      HL, levelEmptyCells          ; HL = empty cell array base
levelStageEmptyCells_loop:                   ;
        LD      E, (HL)                      ; E = cell-wise column
        INC     HL                           ;
        LD      D, (HL)                      ; D = cell-wise row
        INC     HL                           ;
        CALL    boardStageEmptyCell          ; stage empty cell
        DJNZ    levelStageEmptyCells_loop    ; repeat for each empty cell
        POP     HL                           ; STACK: [PC BC DE]
        POP     DE                           ; STACK: [PC BC]
        POP     BC                           ; STACK: [PC]
        RET                                  ; return

;;; LEVEL SPRITE SETUP.........................................................

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

;;; LEVEL STATUS...............................................................

levelStatusSetup:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   <level status data> -- initialized for level
        ;;
        LD      A, LEVEL_STATUS_PLAY           ; status = PLAY
        LD      (levelStatus), A               ;
        RET                                    ; return

;;; LEVEL CLOCK................................................................

levelClockSetup:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   <level clock data> -- initialized for level
        ;;
        PUSH    HL                             ; STACK: [PC HL]
        LD      HL, LEVEL_TICKS                ; initialize level ticks, buffer
        LD      (levelTicks), HL               ;
        LD      (levelTicksBuffer), HL         ;
        XOR     A                              ; reset cycle flag
        LD      (levelCycleFlag), A            ;
        POP     HL                             ; STACK: [PC]
        RET                                    ; return

levelClockWait:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   <level clock data> -- possibly updated
        ;;
        PUSH    HL                             ; STACK: [PC HL]
        LD      A, (levelCycleFlag)            ; if not in cycle:
        OR      A                              ;
        JR      NZ, levelClockWait_skip        ;
        LD      HL, 1                          ;     set timer to small value
        CALL    timerSet                       ;
levelClockWait_skip:                           ;
        CALL    timerWait                      ; wait for timer
        LD      HL, (levelTicksBuffer)         ; apply buffered tick count
        LD      (levelTicks), HL               ;
        CALL    timerSet                       ; set timer for new cycle
        LD      A, 1                           ; set cycle flag
        LD      (levelCycleFlag), A            ;
        POP     HL                             ; STACK: [PC]
        RET                                    ; return

;;; UPDATING...................................................................

levelHandleKeypress:
        ;; INPUT:
        ;;   ACC -- keypress
        ;;
        ;; OUTPUT:
        ;;   <level data> -- updated based on keypress
        ;;
        CP      skAdd
        JR      Z, levelHandleKeypress_add
        CP      skSub
        JR      Z, levelHandleKeypress_sub
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
levelHandleKeypress_add:
        PUSH    HL
        LD      HL, (levelTicksBuffer)
        INC     HL
        LD      (levelTicksBuffer), HL
        POP     HL
        RET
        ;;
levelHandleKeypress_sub:
        PUSH    HL
        LD      HL, (levelTicksBuffer)
        DEC     HL
        LD      (levelTicksBuffer), HL
        POP     HL
        RET
        ;;
levelHandleKeypress_clear:
        LD      A, LEVEL_STATUS_QUIT           ; status = QUIT
        LD      (levelStatus), A               ;
        RET                                    ; return
        ;;
levelHandleKeypress_up:
        LD      A, BOARD_DIRECTION_UP          ; next direction = UP
        CALL    levelSetPacmanNextDirection    ;
        RET                                    ; return
        ;;
levelHandleKeypress_right:
        LD      A, BOARD_DIRECTION_RIGHT       ; next direction = RIGHT
        CALL    levelSetPacmanNextDirection    ;
        RET                                    ; return
        ;;
levelHandleKeypress_down:
        LD      A, BOARD_DIRECTION_DOWN        ; next direction = DOWN
        CALL    levelSetPacmanNextDirection    ;
        RET                                    ; return
        ;;
levelHandleKeypress_left:
        LD      A, BOARD_DIRECTION_LEFT        ; next direction = LEFT
        CALL    levelSetPacmanNextDirection    ;
        RET                                    ; return

levelPacmanUpdate:
        ;; INPUT:
        ;;   <level data> -- determines how to update Pacman
        ;;
        ;; OUTPUT:
        ;;   <board data> -- Pacman changed on board
        ;;
        PUSH    DE                             ; STACK: [PC DE]
        CALL    levelGetPacmanNextDirection    ; D = next direction
        LD      D, A                           ;
        LD      A, LEVEL_PACMAN_ID             ; check move in next direction
        CALL    boardCheckMoveSprite           ;
        JR      C, levelPacmanUpdate_skip      ; if allowed:
        LD      A, D                           ;     direction = next direction
        CALL    levelSetPacmanDirection        ;
        LD      A, LEVEL_PACMAN_ID             ;     move in new direction
        CALL    boardMoveSprite                ;
        JR      levelPacmanUpdate_return       ;     return
levelPacmanUpdate_skip:                        ; else:
        CALL    levelGetPacmanDirection        ;
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
        ;;
levelGetPacmanDirection:
        LD      A, (levelPacmanDirection)
        RET
        ;;
levelSetPacmanDirection:
        PUSH    HL
        LD      (levelPacmanDirection), A
        CALL    levelGetPacmanPicture
        LD      A, LEVEL_PACMAN_ID
        CALL    boardSetSpritePicture
        POP     HL
        RET
        ;;
levelGetPacmanNextDirection:
        LD      A, (levelPacmanNextDirection)
        RET
        ;;
levelSetPacmanNextDirection:
        LD      (levelPacmanNextDirection), A
        RET
        ;;
levelGetPacmanPicture:
        PUSH    DE
        CALL    levelGetPacmanDirection
        ADD     A, A
        LD      E, A
        LD      D, 0
        LD      HL, levelPacmanPictures
        ADD     HL, DE
        LD      A, (HL)
        INC     HL
        LD      H, (HL)
        LD      L, A
        POP     DE
        RET

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

levelPacmanPictures:
        .dw     levelPacmanPictureUp
        .dw     levelPacmanPictureRight
        .dw     levelPacmanPictureDown
        .dw     levelPacmanPictureLeft
        ;;
levelPacmanPictureUp:
        .db     10001000b       ; X   X
        .db     11011000b       ; XX XX
        .db     10111000b       ; X XXX
        .db     11111000b       ; XXXXX
        .db     01110000b       ;  XXX
        .db     00000000b       ;
        ;;
levelPacmanPictureRight:
        .db     01111000b       ;  XXXX
        .db     11010000b       ; XX X
        .db     11100000b       ; XXX
        .db     11110000b       ; XXXX
        .db     01111000b       ;  XXXX
        .db     00000000b       ;
        ;;
levelPacmanPictureDown:
        .db     01110000b       ;  XXX
        .db     11111000b       ; XXXXX
        .db     10111000b       ; X XXX
        .db     11011000b       ; XX XX
        .db     10001000b       ; X   X
        .db     00000000b       ;
        ;;
levelPacmanPictureLeft:
        .db     11110000b       ; XXXX
        .db     01011000b       ;  X XX
        .db     00111000b       ;   XXX
        .db     01111000b       ;  XXXX
        .db     11110000b       ; XXXX
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
#define levelPacmanDirection            levelData+1
#define levelPacmanNextDirection        levelData+1+1
#define levelGhostDirections            levelData+1+1+1

;;#define levelIncrementIndex             levelData+1+1+1+LEVEL_NUM_GHOSTS
#define levelCycleFlag                  levelData+1+1+1+LEVEL_NUM_GHOSTS
#define levelTicks                      levelData+1+1+1+LEVEL_NUM_GHOSTS+1
#define levelTicksBuffer                levelData+1+1+1+LEVEL_NUM_GHOSTS+1+2
#define levelDataEnd                    levelData+1+1+1+LEVEL_NUM_GHOSTS+1+2+2

#define LEVEL_DATA_SIZE                 levelDataEnd-levelData

;;;============================================================================
;;; SETUP AND TEARDOWN ////////////////////////////////////////////////////////
;;;============================================================================

levelInit:
        RET

levelExit:
        RET
