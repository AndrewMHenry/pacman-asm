;;;============================================================================
;;; SETUP AND TEARDOWN ////////////////////////////////////////////////////////
;;;============================================================================

boardInit:
        RET

boardExit:
        RET

;;;============================================================================
;;; HIGH-LEVEL INTERFACE DESCRIPTION //////////////////////////////////////////
;;;============================================================================

;;; This library's interface exposes five categories of routines for
;;; interacting with the game board:
;;;
;;;     (1) INITIALIZING.  This routine prepares the library for the
;;;         staging process.  It is supplied primarily to ensure that staging
;;;         and deploying can be done in an efficient manner without
;;;         complicating the interfaces of those routines.
;;;
;;;     (2) STAGING.  These routines specify various attributes of
;;;         the board to be used.  For example, a staging routine might
;;;         specify the maze layout of the board.
;;;
;;;     (3) DEPLOYING.  This routine signals to the library that
;;;         all attributes have been staged for the current board and
;;;         prepares the board for gameplay accordingly.
;;;
;;;     (4) MANIPULATING.  These routines effect changes to the board
;;;         corresponding to events that occur during gameplay.  For example,
;;;         a manipulation routine might signal that an item should be
;;;         collected or a portion of the board should be redrawn.  This
;;;         category may also include routines which effect no change
;;;         but simply access attributes of the board during gameplay.
;;;
;;;     (5) UPDATING.  This routine applies any changes effected by the
;;;         manipulation routines and ensures they are reflected by the
;;;         image of the board in the screen buffer.

;;;============================================================================
;;; INITIALIZING INTERFACE ////////////////////////////////////////////////////
;;;============================================================================

boardInitialize:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   <board data> -- library prepared for staging process
        ;;
        ;; This routine must be called before staging to guarantee correct
        ;; operation.
        ;;
        ;; This routine is NOT TO BE CONFUSED with boardInit, which is the
        ;; library-level setup function.
        ;;
        CALL    boardSetupArray             ; setup board array
        CALL    boardSetupSprites           ; setup sprites
        LD      A, BOARD_CELL_DOT           ; fill board with dots
        CALL    boardFill                   ;
        RET                                 ; return

;;;============================================================================
;;; STAGING INTERFACE /////////////////////////////////////////////////////////
;;;============================================================================

boardStageWallMap:
        ;; INPUT:
        ;;   HL -- base of wall bitmap
        ;;
        ;; OUTPUT:
        ;;   (boardArray) -- cells specified by bitmap made walls
        ;;
        LD      A, BOARD_CELL_WALL  ; ACC = wall cell value
        CALL    boardApplyMap       ; set cells to wall based on map
        RET                         ; return

boardStageEmptyCell:
        ;; INPUT:
        ;;   D -- cell-wise row of empty cell
        ;;   E -- cell-wise column of empty cell
        ;;
        ;; OUTPUT:
        ;;   <board data> -- empty cell staged at (D, E)
        ;;
        PUSH    HL                      ; STACK: [PC HL]
        CALL    boardGetCellAddress     ; HL = cell address
        LD      A, BOARD_CELL_EMPTY     ; ACC = EMPTY
        CALL    boardSetCellValue       ; set cell D, E to EMPTY
        POP     HL                      ; STACK: [PC]
        RET                             ; return

boardStageSprite:
        ;; INPUT:
        ;;   D -- cell-wise row of sprite's initial cell
        ;;   E -- cell-wise column of sprite's initial cell
        ;;   HL -- base of sprite's initial image
        ;;
        ;; OUTPUT:
        ;;   <board data> -- sprite staged with given properties
        ;;
        ;; NOTE: The order in which sprites are staged determines the
        ;; indices to which they correspond.
        ;;
        PUSH    BC                              ; STACK: [PC BC]
        PUSH    IX                              ; STACK: [PC BC IX]
        CALL    boardAddSprite                  ; add a sprite
        CALL    boardGetSpritePointer           ; IX = sprite pointer
        CALL    boardSetSpriteCell              ; set cell to D, E
        LD      BC, 0                           ; set offsets to 0, 0
        CALL    boardSetSpriteOffsets           ;
        CALL    boardSetSpritePicture           ; set picture to HL
        POP     IX                              ; STACK: [PC BC]
        POP     BC                              ; STACK: [PC]
        RET                                     ; return

;;;============================================================================
;;; DEPLOYING INTERFACE ///////////////////////////////////////////////////////
;;;============================================================================

boardDeploy:
        RET

;;;============================================================================
;;; MANIPULATING INTERFACE ////////////////////////////////////////////////////
;;;============================================================================

;;; SPRITE MOVEMENT............................................................

;;; Whether a given sprite can be moved in a given direction depends on at
;;; least the location of the sprite and the layout of the board.  Therefore,
;;; we must supply some way of determining whether a given movement is
;;; allowed.  To this end, we supply two routines, which both expect ACC to
;;; contain the index of the sprite in question and D to contain the direction
;;; in which the sprite is to move:
;;;
;;;     (1) boardCheckMoveSprite: This routine returns with the carry flag
;;;         RESET if and only if the specified movement is allowed.
;;;
;;;     (2) boardMoveSprite: This routine ASSUMES that the requested movement
;;;         is allowed and carries it out.
;;;
;;; It is important to note that the only way guaranteed by the interface of
;;; ensuring that a given movement is allowed is to use boardCheckMoveSprite.
;;; For example, if C contains the index of a sprite to be moved in the
;;; direction specified by D, the following sequence of instructions safely
;;; carries out the movement only if it is allowed:
;;;
;;;     LD      A, C                  ; ACC = sprite index
;;;     CALL    boardCheckMoveSprite  ; RESET carry iff movement allowed
;;;     LD      A, C                  ; ACC = sprite index (again)
;;;     CALL    NC, boardMoveSprite   ; move ONLY IF ALLOWED
;;;

boardCheckMoveSprite:
        ;; INPUT:
        ;;   ACC -- sprite ID
        ;;   D -- direction in which to move sprite
        ;;
        ;; OUTPUT:
        ;;   carry flag -- RESET if and only if the desired movement is allowed
        ;;
        PUSH    BC
        PUSH    DE
        PUSH    IX
        LD      C, D
        CALL    boardGetSpritePointer
        CALL    boardGetSpriteLocation
        LD      A, C
        CALL    boardMoveDirection
        CALL    boardCheckLocationSpritely
        POP     IX
        POP     DE
        POP     BC
        RET

boardMoveSprite:
        ;; INPUT:
        ;;   ACC -- sprite ID
        ;;   D -- direction in which to move sprite
        ;;
        ;; OUTPUT:
        ;;   <board data> -- sprite moved
        ;;
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IX
        LD      C, D
        CALL    boardGetSpritePointer
        CALL    boardGetSpriteLocation
        LD      L, E
        LD      H, D
        LD      A, C
        CALL    boardMoveDirection
        CALL    boardSetSpriteLocation
        OR      A
        SBC     HL, DE
        CALL    boardGetSpriteCell
boardMoveSprite_LR:
        LD      A, L
        OR      A
        JR      Z, boardMoveSprite_UD
        DEC     E
        CALL    boardTouchCell
        INC     E
        CALL    boardTouchCell
        INC     E
        CALL    boardTouchCell
        JR      boardMoveSprite_return
boardMoveSprite_UD:
        DEC     D
        CALL    boardTouchCell
        INC     D
        CALL    boardTouchCell
        INC     D
        CALL    boardTouchCell
boardMoveSprite_return:
        POP     IX
        POP     HL
        POP     DE
        POP     BC
        RET

;;; SPRITE INTERACTION.........................................................

boardSpriteCollectItems:
        ;; INPUT:
        ;;   ACC -- sprite ID
        ;;
        ;; OUTPUT:
        ;;   <board data> -- items touched by sprite collected
        ;;
        ;; This current implementation of item collection uses a rough
        ;; approximation to the desired collision detection: instead of
        ;; determining intersection at the pixel level, we check only check
        ;; contents of cells with which the sprite is completely aligned.
        ;;
        PUSH    BC                                  ; STACK: [PC BC]
        PUSH    DE                                  ; STACK: [PC BC DE]
        PUSH    HL                                  ; STACK: [PC BC DE HL]
        PUSH    IX                                  ; STACK: [PC BC DE HL IX]
        CALL    boardGetSpritePointer               ; get sprite pointer
        CALL    boardGetSpriteOffsets               ; B, C = offsets
        LD      A, C                                ; no dice if misaligned
        OR      B                                   ;
        JR      NZ, boardSpriteCollectItems_return  ;
        CALL    boardGetSpriteCell                  ; D, E = cell
        CALL    boardGetCellAddress                 ; HL = cell address
        CALL    boardCollectCellItem                ; set cell empty
boardSpriteCollectItems_return:                     ;
        POP     IX                                  ; STACK: [PC BC DE HL]
        POP     HL                                  ; STACK: [PC BC DE]
        POP     DE                                  ; STACK: [PC BC]
        POP     BC                                  ; STACK: [PC]
        RET                                         ; return

boardCheckSpriteCollision:
        ;; INPUT:
        ;;   ACC -- ID of first sprite
        ;;   C -- ID of second sprite
        ;;
        ;; OUTPUT:
        ;;   <carry flag> -- SET if and only if the sprites collide
        ;;
        ;; ROUGH IMPLEMENTATION: Only assess collisions for colocated
        ;; sprites.  Pixel-wise collision detection is probably preferable,
        ;; but this method is vastly simpler.
        ;;
        PUSH    DE                           ; STACK: [PC DE]
        PUSH    HL                           ; STACK: [PC DE HL]
        PUSH    IX                           ; STACK: [PC DE HL IX]
        CALL    boardGetSpritePointer        ; IX = first sprite pointer
        CALL    boardGetSpriteLocation       ; D, E = first sprite location
        EX      DE, HL                       ; H, L = first sprite location
        LD      A, C                         ; ACC = second sprite ID
        CALL    boardGetSpritePointer        ; IX = second sprite pointer
        CALL    boardGetSpriteLocation       ; D, E = second sprite location
        OR      A                            ; compute location difference
        SBC     HL, DE                       ;
        LD      A, L                         ; clear carry, setting Z for HL
        OR      H                            ;
        POP     IX                           ; STACK: [PC DE HL]
        POP     HL                           ; STACK: [PC DE]
        POP     DE                           ; STACK: [PC]
        RET     NZ                           ; return no carry if different
        SCF                                  ; return carry otherwise
        RET                                  ;

;;; MISCELLANEOUS..............................................................

boardGetDotCount:
        ;; INPUT:
        ;;   <board data> -- determines number of dots on board
        ;;
        ;; OUTPUT:
        ;;   ACC -- number of dots on board
        ;;
        LD      A, BOARD_CELL_DOT    ; ACC = DOT
        CALL    boardCountCellValue  ; ACC = count of DOTs in board
        RET                          ; return

;;;============================================================================
;;; UPDATING INTERFACE ////////////////////////////////////////////////////////
;;;============================================================================

boardDraw:
        ;; INPUT:
        ;;   <board data> -- current state of board
        ;;
        ;; OUTPUT:
        ;;   <screen buffer> -- updated to reflect board contents
        ;;
        ;; This routine unconditionally draws everything on the board.
        ;;
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      BC, BOARD_DIMENSIONS
        LD      DE, BOARD_LOCATION
        CALL    drawClearRectangle
        LD      HL, boardDrawCell
        CALL    boardIter
        LD      HL, boardDrawSprite
        CALL    boardSpriteIter
        POP     HL
        POP     DE
        POP     BC
        RET

boardUpdate:
        ;; INPUTS:
        ;;   <board data> -- current state of board
        ;;
        ;; OUTPUTS:
        ;;   <screen buffer> -- updated to reflect board contents
        ;;
        CALL    boardUpdateCells      ; update cells
        CALL    boardDrawSprites      ; draw all sprites
        CALL    screenUpdate          ; flush buffer to LCD
        RET                           ; return

;;;============================================================================
;;;////////////////////////////////////////////////////////////////////////////
;;;----------------------------------------------------------------------------
;;; INTERNAL INTERFACE ////////////////////////////////////////////////////////
;;;----------------------------------------------------------------------------
;;;////////////////////////////////////////////////////////////////////////////
;;;============================================================================

;;;============================================================================
;;; BOARD ARRAY INTERFACE /////////////////////////////////////////////////////
;;;============================================================================

boardSetupArray:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   <board data> -- array prepared for operations
        ;;
        XOR     A                           ; reset touched cell count
        LD      (boardTouchedCellCount), A  ;
        RET                                 ; return

boardFill:
        ;; INPUT:
        ;;   ACC -- cell value to load in all cells
        ;;
        ;; OUTPUT:
        ;;   <board data> -- all board cells given value in ACC
        ;;
        ;; NOTE: The cell value is not necessarily the actual content
        ;; of the memory cell, but rather indicates the kind of thing
        ;; to be loaded into the cells.
        ;;
        PUSH    BC                        ; STACK: [PC BC]
        PUSH    DE                        ; STACK: [PC BC DE]
        PUSH    HL                        ; STACK: [PC BC DE HL]
        LD      BC, BOARD_ARRAY_SIZE - 1  ; BC = board size - 1
        LD      DE, boardArray + 1        ; DE = board base + 1
        LD      HL, boardArray + 0        ; HL = board base
        LD      (HL), A                   ; seed initial value
        LDIR                              ; propagate
        POP     HL                        ; STACK: [PC BC DE]
        POP     DE                        ; STACK: [PC BC]
        POP     BC                        ; STACK: [PC]
        RET                               ; return

boardApplyMap:
        ;; INPUT:
        ;;   ACC -- cell value to load in specified cells
        ;;   HL -- base of cell bitmap
        ;;
        ;; OUTPUT:
        ;;   (boardArray) -- cells specified by bitmap given input value
        ;;
        PUSH    BC                          ; STACK: [PC BC]
        PUSH    DE                          ; STACK: [PC BC DE]
        PUSH    HL                          ; STACK: [PC BC DE HL]
        LD      B, BOARD_MAP_SIZE           ; B = board map counter
        LD      C, A                        ; C = cell value
        LD      DE, boardArray              ; DE = base of board array
boardApplyMap_outer:                        ;
        PUSH    BC                          ; STACK: [PC BC DE HL BC]
        PUSH    HL                          ; STACK: [PC BC DE HL BC HL]
        LD      B, 8                        ; B = bit counter
        LD      L, (HL)                     ; L = map byte
boardApplyMap_inner:                        ;
        RLC     L                           ; rotate bit into carry
        EX      DE, HL                      ; set wall if carry (bit set)
        LD      A, C                        ; set cell value to C
        CALL    C, boardSetCellValue        ;
        EX      DE, HL                      ;
        INC     DE                          ; advance to next board array byte
        DJNZ    boardApplyMap_inner         ; repeat inner loop until byte done
        POP     HL                          ; STACK: [PC BC DE HL BC]
        POP     BC                          ; STACK: [PC BC DE HL]
        INC     HL                          ; advance to next map byte
        DJNZ    boardApplyMap_outer         ; repeat outer loop until map done
        POP     HL                          ; STACK: [PC BC DE]
        POP     DE                          ; STACK: [PC BC]
        POP     BC                          ; STACK: [PC]
        RET                                 ; return

boardCountCellValue:
        ;; INPUT:
        ;;   ACC -- cell value to count
        ;;   <board data> -- contains cells to count
        ;;
        ;; OUTPUT:
        ;;   ACC -- number of cells with given value
        ;;
        PUSH    BC                            ; STACK: [PC BC]
        PUSH    HL                            ; STACK: [PC BC HL]
        LD      BC, BOARD_ARRAY_SIZE << 8     ; B, C = size, 0
        LD      HL, boardArray                ; HL = base of board array
boardCountCellValue_loop:                     ;
        CP      (HL)                          ; set Z if cell is dot
        JR      NZ, boardCountCellValue_skip  ; skip if not
        INC     C                             ; increment C otherwise
boardCountCellValue_skip:                     ;
        INC     HL                            ; advance HL to next cell
        DJNZ    boardCountCellValue_loop      ; repeat for each cell
        LD      A, C                          ; ACC = C (count)
        POP     HL                            ; STACK: [PC BC]
        POP     BC                            ; STACK: [PC]
        RET                                   ; return

boardGetCellAddress:
        ;; INPUT:
        ;;   D -- cell-wise row of cell
        ;;   E -- cell-wise column of cell
        ;;
        ;; OUTPUT:
        ;;   HL -- address of cell in boardArray
        ;;
        PUSH    DE              ; STACK: [PC DE]
        LD      HL, boardArray  ; HL = board array start
        LD      A, D            ; ACC = cell-wise row
        LD      D, 0            ; DE = E (cell-wise column)
        ADD     HL, DE          ; HL += E
        ADD     A, A            ; ACC = cell-wise row * 16 (BOARD_NUM_COLUMNS)
        ADD     A, A            ;
        ADD     A, A            ;
        ADD     A, A            ;
        LD      E, A            ; DE = ACC
        ADD     HL, DE          ; HL += DE
        POP     DE              ; STACK: [PC]
        RET                     ; return

boardSetCellValue:
        ;; INPUT:
        ;;   ACC -- cell value
        ;;   HL -- cell pointer
        ;;
        ;; OUTPUT:
        ;;   (HL) -- cell value set
        ;;
        LD      (HL), A
        RET

boardCollectCellItem:
        ;; INPUT:
        ;;   HL -- cell pointer
        ;;
        ;; OUTPUT:
        ;;   (HL) -- cell emptied (if not already)
        ;;   <board data> -- item (if present) collected
        ;;
        LD      A, BOARD_CELL_EMPTY
        CALL    boardSetCellValue
        RET

boardTouchCell:
        ;; INPUT:
        ;;   D -- cell-wise row
        ;;   E -- cell-wise column
        ;;
        ;; OUTPUT:
        ;;   <board data> -- specified cell touched
        ;;
        PUSH    BC
        PUSH    HL
        LD      A, (boardTouchedCellCount)
        LD      C, A
        LD      B, 0
        INC     A
        LD      (boardTouchedCellCount), A
        LD      HL, boardTouchedCells
        ADD     HL, BC
        ADD     HL, BC
        LD      (HL), E
        INC     HL
        LD      (HL), D
        POP     HL
        POP     BC
        RET

boardUpdateCells:
        ;; INPUT:
        ;;   <board data> -- determines cells to update, and how
        ;;
        ;; OUTPUT:
        ;;   <screen buffer> -- updated pictures drawn
        ;;
        LD      A, (boardTouchedCellCount)  ; ACC = touched cell count
        OR      A                           ;
        RET     Z                           ; return if no touched cells
        PUSH    BC                          ; STACK: [PC BC]
        PUSH    DE                          ; STACK: [PC BC DE]
        PUSH    HL                          ; STACK: [PC BC DE HL]
        LD      B, A                        ; B = touched cell count
        LD      HL, boardTouchedCells       ; HL = base of touched cells
boardUpdateCells_loop:                      ;
        LD      E, (HL)                     ; get row and column
        INC     HL                          ;
        LD      D, (HL)                     ;
        INC     HL                          ;
        CALL    boardDrawCell               ; draw the cell
        DJNZ    boardUpdateCells_loop       ; repeat for each touched cell
        XOR     A                           ; reset touched cell count
        LD      (boardTouchedCellCount), A  ;
        POP     HL                          ; STACK: [PC BC DE]
        POP     DE                          ; STACK: [PC BC]
        POP     BC                          ; STACK: [PC]
        RET                                 ; return

;;;============================================================================
;;; SPRITE INTERFACE //////////////////////////////////////////////////////////
;;;============================================================================

boardSetupSprites:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   <board data> -- sprite data prepared for operations
        ;;
        XOR     A                      ; reset sprite count
        LD      (boardSpriteCount), A  ;
        RET                            ; return

boardAddSprite:
        ;; INPUT:
        ;;   <board data> -- determines where to add sprite
        ;;
        ;; OUTPUT:
        ;;   ACC -- sprite ID of added sprite
        ;;
        LD      A, (boardSpriteCount)  ; ACC = sprite count++
        INC     A                      ;
        LD      (boardSpriteCount), A  ;
        DEC     A                      ;
        RET                            ; return

boardGetSpritePointer:
        ;; INPUT:
        ;;   ACC -- sprite ID
        ;;
        ;; OUTPUT:
        ;;   IX -- base of data for sprite
        ;;
        ;; ASSUMPTIONS:
        ;;   - Each sprite has four bytes of data.
        ;;
        PUSH    DE                ; STACK: [PC DE]
        ADD     A, A              ; DE = ID * 4 (size of sprite data)
        ADD     A, A              ;
        LD      E, A              ;
        LD      D, 0              ;
        LD      IX, boardSprites  ; IX = boardSprites + DE
        ADD     IX, DE            ;
        POP     DE                ; STACK: [PC]
        RET                       ; return

boardGetSpriteCell:
        ;; INPUT:
        ;;   IX -- sprite pointer
        ;;
        ;; OUTPUT:
        ;;   D -- cell-wise row of sprite
        ;;   E -- cell-wise column of sprite
        ;;
        PUSH    BC
        CALL    boardGetSpriteLocation
        CALL    boardExtractLocationData
        POP     BC
        RET

boardSetSpriteCell:
        ;; INPUT:
        ;;   IX -- sprite pointer
        ;;   D -- cell-wise row for sprite
        ;;   E -- cell-wise column for sprite
        ;;
        ;; OUTPUT:
        ;;   (IX) -- cell-wise row and column set for sprite
        ;;
        PUSH    BC
        PUSH    DE
        CALL    boardGetSpriteOffsets
        CALL    boardGetCellLocation
        EX      DE, HL
        ADD     HL, BC
        EX      DE, HL
        CALL    boardSetSpriteLocation
        POP     DE
        POP     BC
        RET

boardGetSpriteOffsets:
        ;; INPUT:
        ;;   IX -- sprite pointer
        ;;
        ;; OUTPUT:
        ;;   B -- pixel-wise row offset of sprite
        ;;   C -- pixel-wise column offset of sprite
        ;;
        PUSH    DE
        CALL    boardGetSpriteLocation
        CALL    boardExtractLocationData
        POP     DE
        RET

boardSetSpriteOffsets:
        ;; INPUT:
        ;;   IX -- sprite pointer
        ;;   B -- pixel-wise row offset for sprite
        ;;   C -- pixel-wise column offset for sprite
        ;;
        ;; OUTPUT:
        ;;   (IX) -- pixel-wise row and column offsets set for sprite
        ;;
        PUSH    DE
        CALL    boardGetSpriteCell
        CALL    boardGetCellLocation
        EX      DE, HL
        ADD     HL, BC
        EX      DE, HL
        CALL    boardSetSpriteLocation
        POP     DE
        RET

boardGetSpriteLocation:
        ;; INPUT:
        ;;   IX -- sprite pointer
        ;;
        ;; OUTPUT:
        ;;   D -- pixel-wise row of sprite
        ;;   E -- pixel-wise column of sprite
        ;;
        LD      E, (IX+BOARD_SPRITE_COLUMN)     ; E = column
        LD      D, (IX+BOARD_SPRITE_ROW)        ; D = row
        RET                                     ; return

boardSetSpriteLocation:
        ;; INPUT:
        ;;   IX -- sprite pointer
        ;;   D -- pixel-wise row for sprite
        ;;   E -- pixel-wise column for sprite
        ;;
        ;; OUTPUT:
        ;;   (IX) -- pixel-wise location of sprite set to (D, E)
        ;;
        LD      (IX+BOARD_SPRITE_COLUMN), E     ; set column
        LD      (IX+BOARD_SPRITE_ROW), D        ; set row
        RET                                     ; return

boardSetSpritePicture:
        ;; INPUT:
        ;;   IX -- sprite pointer
        ;;   HL -- base of picture for sprite
        ;;
        ;; OUTPUT:
        ;;   (IX) -- picture for sprite set to HL
        ;;
        LD      (IX+BOARD_SPRITE_PICTURE+0), L  ; set picture
        LD      (IX+BOARD_SPRITE_PICTURE+1), H  ;
        RET                                     ; return

boardDrawSprites:
        ;; INPUT:
        ;;   <board data> -- determines how/where to draw sprites
        ;;
        ;; OUTPUT:
        ;;   <screen buffer> -- sprites drawn on screen
        ;;
        PUSH    HL                    ; STACK: [PC HL]
        LD      HL, boardDrawSprite   ; draw all sprites
        CALL    boardSpriteIter       ;
        POP     HL                    ; STACK: [PC]
        RET                           ; return

;;;============================================================================
;;; LOCATION INTERFACE ////////////////////////////////////////////////////////
;;;============================================================================

boardMoveDirection:
        ;; INPUT:
        ;;   ACC -- direction
        ;;   D -- row
        ;;   E -- column
        ;;
        ;; OUTPUT:
        ;;   D -- new row
        ;;   E -- new column
        ;;
        PUSH    HL
        LD      HL, boardMoveDirection_dispatch
        ADD     A, A
        ADD     A, L
        LD      L, A
        LD      A, H
        ADC     A, 0
        LD      H, A
        CALL    boardMoveDirection_jumpHL
        POP     HL
        RET
        ;;
boardMoveDirection_jumpHL:
        JP      (HL)
        ;;
boardMoveDirection_dispatch:
        DEC     D
        RET
        INC     E
        RET
        INC     D
        RET
        DEC     E
        RET

boardCheckLocationSpritely:
        ;; INPUT:
        ;;   D -- pixel-wise row of sprite
        ;;   E -- pixel-wise column of sprite
        ;;   <board data> -- determines board layout
        ;;
        ;; OUTPUT:
        ;;   <carry flag> -- RESET if and only if location is valid
        ;;
        PUSH    DE                                   ; STACK: [PC DE]
        CALL    boardCheckWall                       ; FALSE if wall
        JR      C, boardCheckLocationSpritely_return ;
        LD      A, E                                 ; to top right 
        ADD     A, BOARD_CELL_SIDE - 1               ;
        LD      E, A                                 ;
        CALL    boardCheckWall                       ; FALSE if wall
        JR      C, boardCheckLocationSpritely_return ;
        LD      A, D                                 ; to bottom right
        ADD     A, BOARD_CELL_SIDE - 1               ;
        LD      D, A                                 ;
        CALL    boardCheckWall                       ; FALSE if wall
        JR      C, boardCheckLocationSpritely_return ;
        LD      A, E                                 ; to bottom left
        SUB     BOARD_CELL_SIDE - 1                  ;
        LD      E, A                                 ;
        CALL    boardCheckWall                       ; FALSE if wall
boardCheckLocationSpritely_return:                   ;
        POP     DE                                   ; STACK: [PC]
        RET                                          ; return

boardGetCellLocation:
        ;; INPUT:
        ;;   D -- cell-wise row
        ;;   E -- cell-wise column
        ;;
        ;; OUTPUT:
        ;;   D -- pixel-wise row
        ;;   E -- pixel-wise column
        ;;
        PUSH    HL                  ; STACK: [PC HL]
        LD      L, E                ; H, L = D, E
        LD      H, D                ;
        ADD     HL, HL              ; H, L = 6 * (D, E)
        ADD     HL, DE              ;
        ADD     HL, HL              ;
        LD      DE, BOARD_LOCATION  ; H, L += BOARD_ROW, BOARD_COLUMN
        ADD     HL, DE              ;
        EX      DE, HL              ; D, E = H, L and H, L = D, E
        POP     HL                  ; STACK: [PC]
        RET                         ; return

;;;============================================================================
;;; BOARD LAYOUT INTERFACE ////////////////////////////////////////////////////
;;;============================================================================

;;;============================================================================
;;; HIGH-LEVEL SPRITE INTERFACE ///////////////////////////////////////////////
;;;============================================================================

;;;============================================================================
;;; LOW-LEVEL SPRITE INTERFACE ////////////////////////////////////////////////
;;;============================================================================

;;; SPRITE GETTERS/SETTERS.....................................................

;;; LOCATION ROUTINES..........................................................

;;;============================================================================
;;; CELL INTERFACE ////////////////////////////////////////////////////////////
;;;============================================================================

;;; CELL VALUE ROUTINES........................................................

;;; CELL LOCATION ROUTINES.....................................................

;;; CELL TOUCH/UPDATE INTERFACE................................................

;;; ITEM COUNTING..............................................................

boardItemCountSetup:
        RET

boardItemCountDecrement:
        RET

boardItemCountRead:
        CALL    boardCountDots
        RET

;;;============================================================================
;;; HELPER ROUTINES ///////////////////////////////////////////////////////////
;;;============================================================================

boardDrawCellCustom:
        ;; INPUT:
        ;;   D -- cell-wise row
        ;;   E -- cell-wise column
        ;;
        ;; OUTPUT:
        ;;   <board data> -- possibly affected
        ;;   <screen data> -- image written
        ;;
        LD      A, (HL)         ; ACC = b[0][0]
        AND     B               ; ACC = b[0][0] AND m[0]
        OR      (IX+0)          ; ACC = (b[0][0] AND m[0]) OR p[0][0]
        LD      (HL), A         ; b[0][0] = (b[0][0] AND m[0]) OR p[0][0]
        INC     HL
        LD      A, (HL)
        AND     C
        OR      (IX+1)
        LD      (HL), A
        ADD     HL, DE
        RET

        ;; Suppose BC is mask, DE = buffer pointer, and HL = image pointer.
        ;;
        ;; (b AND m) OR p == (b OR p) AND (m or p)
        ;;
        LD      A, (DE)
        AND     B
        OR      (HL)
        LD      (DE), A
        INC     HL
        INC     DE
        LD      A, (DE)
        AND     C
        OR      (HL)
        LD      (DE), A
        INC     HL
        LD      A, L
        ADD     A, 11
        LD      L, A
        LD      A, H
        ADC     A, 0
        LD      H, A
        RET

boardDrawCell:
        ;; INPUT:
        ;;   D -- cell-wise row
        ;;   E -- cell-wise column
        ;;   <board data> -- determines image for cell
        ;;
        ;; OUTPUT:
        ;;   <board data> -- possibly affected
        ;;   <screen data> -- image written
        ;;
        PUSH    BC                    ; STACK: [PC BC]
        PUSH    DE                    ; STACK: [PC BC DE]
        PUSH    HL                    ; STACK: [PC BC DE HL]
        CALL    boardEraseCell        ; erase background
        CALL    boardGetCellPicture   ; HL = cell picture
        CALL    boardGetCellLocation  ; D, E = cell location
        LD      B, BOARD_CELL_HEIGHT  ; B = cell height
        CALL    drawPicture           ; draw the picture
        POP     HL                    ; STACK: [PC BC DE]
        POP     DE                    ; STACK: [PC BC]
        POP     BC                    ; STACK: [PC]
        RET                           ; return

boardEraseCell:
        ;; INPUT:
        ;;   D -- cell-wise row
        ;;   E -- cell-wise column
        ;;
        ;; OUTPUT:
        ;;   <screen data> -- cell footprint erased
        ;;
        PUSH    BC
        PUSH    DE
        LD      BC, BOARD_CELL_DIMENSIONS
        CALL    boardGetCellLocation
        CALL    drawClearRectangle
        POP     DE
        POP     BC
        RET
        ;;
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      HL, $FF << 1
        LD      A, E
        RRCA
        JR      C, $+2+1
        ADD     HL, HL
        RRCA
        JR      C, $+2+2
        ADD     HL, HL
        ADD     HL, HL
        RRCA
        JR      C, $+2+4
        ADD     HL, HL
        ADD     HL, HL
        ADD     HL, HL
        ADD     HL, HL
        LD      C, L
        LD      B, H
        LD      L, D
        LD      H, 0
        ADD     HL, HL
        ADD     HL, HL
        LD      E, L
        LD      D, H
        ADD     HL, HL
        ADD     HL, DE
        POP     HL
        POP     DE
        POP     BC
        RET

boardGetCellPicture:
        ;; INPUT:
        ;;   D -- cell-wise row of cell
        ;;   E -- cell-wise column of cell
        ;;
        ;; OUTPUT:
        ;;   HL -- base of picture for cell
        ;;
        PUSH    DE                     ; STACK: [PC DE]
        CALL    boardGetCellAddress    ; HL = address of cell
        LD      A, (HL)                ; ACC = cell * 6 (cell picture size)
        ADD     A, A                   ;
        ADD     A, (HL)                ;
        ADD     A, A                   ;
        LD      HL, boardCellPictures  ;
        LD      E, A                   ; HL += (DE = ACC)
        LD      D, 0                   ;
        ADD     HL, DE                 ;
        POP     DE                     ; STACK: [PC]
        RET                            ; return

boardDivideCellSide:
        ;; INPUT:
        ;;   ACC -- value to take mod cell side
        ;;
        ;; OUTPUT:
        ;;   ACC -- value mod cell side
        ;;   B -- value // cell side
        ;;
        LD      B, -1
boardDivideCellSide_loop:
        INC     B
        SUB     BOARD_CELL_SIDE
        JR      NC, boardDivideCellSide_loop
        ADD     A, BOARD_CELL_SIDE
        RET

boardCountDots:
        ;; INPUT:
        ;;   <board data> -- contains dots to be counted
        ;;
        ;; OUTPUT:
        ;;   ACC -- number of dots on board
        ;;
        PUSH    BC                         ; STACK: [PC BC]
        PUSH    HL                         ; STACK: [PC BC HL]
        LD      A, BOARD_CELL_DOT          ; ACC = DOT for comparison
        LD      BC, BOARD_ARRAY_SIZE << 8  ; B, C = size, 0
        LD      HL, boardArray             ; HL = base of board array
boardCountDots_loop:                       ;
        CP      (HL)                       ; set Z if cell is dot
        JR      NZ, boardCountDots_skip    ; skip if not
        INC     C                          ; increment C otherwise
boardCountDots_skip:                       ;
        INC     HL                         ; advance HL to next cell
        DJNZ    boardCountDots_loop        ; repeat for each cell
        LD      A, C                       ; ACC = C (count)
        POP     HL                         ; STACK: [PC BC]
        POP     BC                         ; STACK: [PC]
        RET                                ; return

boardSpriteIter:
        ;; INPUT:
        ;;   HL -- address of callback routine to apply to each sprite
        ;;
        ;; OUTPUT:
        ;;   <callback applied to each sprite>
        ;;
        LD      A, (boardSpriteCount)   ; ACC = sprite count
        OR      A                       ; return if sprite count == 0
        RET     Z                       ;
        PUSH    BC                      ; STACK: [PC BC]
        PUSH    DE                      ; STACK: [PC BC DE]
        PUSH    IX                      ; STACK: [PC BC DE IX]
        LD      B, A                    ; B (counter) = sprite count
        LD      C, 0                    ; C (sprite index) = 0
        LD      DE, BOARD_SPRITE_SIZE   ;
        LD      IX, boardSprites        ;
boardSpriteIter_loop:                   ;
        LD      A, C                    ; ACC = sprite index
        CALL    boardSpriteIter_jumpHL  ; call the callback routine
        INC     C                       ; advance sprite index
        ADD     IX, DE                  ; advance sprite pointer
        DJNZ    boardSpriteIter_loop    ; repeat for each sprite index
        POP     IX                      ; STACK: [PC BC DE]
        POP     DE                      ; STACK: [PC BC]
        POP     BC                      ; STACK: [PC]
        RET                             ; return
        ;;
boardSpriteIter_jumpHL:
        JP      (HL)

boardDrawSprite:
        ;; INPUT:
        ;;   ACC -- index of sprite to draw
        ;;   <board data> -- used to determine location and picture
        ;;
        ;; OUTPUT:
        ;;   <screen buffer> -- sprite drawn in buffer
        ;;
        PUSH    BC                              ; STACK: [PC BC]
        PUSH    DE                              ; STACK: [PC BC DE]
        PUSH    HL                              ; STACK: [PC BC DE HL]
        LD      B, BOARD_SPRITE_HEIGHT          ; B = sprite height
        LD      E, (IX+BOARD_SPRITE_COLUMN)     ; E = column
        LD      D, (IX+BOARD_SPRITE_ROW)        ; D = row
        LD      L, (IX+BOARD_SPRITE_PICTURE+0)  ; HL = picture
        LD      H, (IX+BOARD_SPRITE_PICTURE+1)  ;
        CALL    drawPicture                     ; draw the picture
        POP     HL                              ; STACK: [PC BC DE]
        POP     DE                              ; STACK: [PC BC]
        POP     BC                              ; STACK: [PC]
        RET                                     ; return

boardExtractLocationData:
        ;; INPUT:
        ;;   D -- pixel-wise row
        ;;   E -- pixel-wise column
        ;;
        ;; OUTPUT:
        ;;   B -- pixel-wise row OFFSET within cell
        ;;   C -- pixel-wise column OFFSET within cell
        ;;   D -- cell-wise row
        ;;   E -- cell-wise column
        ;; 
        LD      A, E
        SUB     BOARD_COLUMN
        CALL    boardDivideCellSide
        LD      E, B
        LD      C, A
        LD      A, D
        SUB     BOARD_ROW
        CALL    boardDivideCellSide
        LD      D, B
        LD      B, A
        RET

boardCheckWall:
        ;; INPUT:
        ;;   D -- pixel-wise row
        ;;   E -- pixel-wise column
        ;;   <board data> -- determines wall layout
        ;;
        ;; OUTPUT:
        ;;   <carry flag> -- set iff cell at location is wall
        ;;
        PUSH    BC                        ; STACK: [PC BC]
        PUSH    DE                        ; STACK: [PC BC DE]
        PUSH    HL                        ; STACK: [PC BC DE HL]
        CALL    boardExtractLocationData  ; get cell and offsets
        CALL    boardGetCellAddress       ; HL = cell address
        LD      A, (HL)                   ; set carry iff cell is wall
        SUB     BOARD_CELL_WALL           ;
        SUB     1                         ;
        POP     HL                        ; STACK: [PC BC DE]
        POP     DE                        ; STACK: [PC BC]
        POP     BC                        ; STACK: [PC]
        RET                               ; return

;;;============================================================================
;;; CELL HELPER ROUTINES //////////////////////////////////////////////////////
;;;============================================================================

boardUpdateSpriteCells:
        ;; INPUT:
        ;;   ACC -- sprite ID
        ;;
        ;; OUTPUT:
        ;;   <screen buffer> -- cells updated around sprite
        ;;
        ;; Simple but inefficient implementation: draw all nine cells
        ;; in square centered on cell containing sprite's upper left corner.
        ;;
        PUSH    BC                                ; STACK: [PC BC]
        PUSH    DE                                ; STACK: [PC BC DE]
        PUSH    HL                                ; STACK: [PC BC DE HL]
        PUSH    IX                                ; STACK: [PC BC DE HL IX]
        CALL    boardGetSpritePointer             ; IX = sprite pointer
        LD      E, (IX+BOARD_SPRITE_COLUMN)       ; E, D = column, row
        LD      D, (IX+BOARD_SPRITE_ROW)          ;
        CALL    boardExtractLocationData          ; E, D = cell-wise location
        DEC     E                                 ; E, D = upper left of square
        DEC     D                                 ;
        PUSH    DE                                ; STACK: [PC BC DE HL IX DE]
        CALL    boardGetCellLocation              ; D, E = pixel-wise location
        LD      BC, BOARD_CELL_SIDE * 00303h      ; B, C = pixel-wise size
        CALL    drawClearRectangle                ; clear rectangle under cells
        POP     DE                                ; STACK: [PC BC DE HL IX]
        LD      H, D                              ; (save initial row in H)
        LD      C, 3                              ; C (outer counter) = 3
boardUpdateSpriteCells_outer:                     ;
        LD      B, 3                              ; B (inner counter) = 3
boardUpdateSpriteCells_inner:                     ;
        CALL    boardDrawCell                     ; draw current cell
        INC     D                                 ; advance to next row
        DJNZ    boardUpdateSpriteCells_inner      ; repeat for each row
        LD      D, H                              ; reset D (row)
        INC     E                                 ; advance to next column
        DEC     C                                 ; repeat for each column
        JR      NZ, boardUpdateSpriteCells_outer  ;
        POP     IX                                ; STACK: [PC BC DE HL]
        POP     HL                                ; STACK: [PC BC DE
        POP     DE                                ; STACK: [PC BC]
        POP     BC                                ; STACK: [PC]
        RET                                       ; return

boardIter:
        ;; INPUT:
        ;;   HL -- start of callback to apply to each cell
        ;;
        ;; OUTPUT:
        ;;   <board data> -- callback applied to each cell
        ;;
        PUSH    BC                     ; STACK: [PC BC]
        PUSH    DE                     ; STACK: [PC BC DE]
        LD      C, BOARD_NUM_ROWS      ; C = row counter
        LD      D, 0                   ; D = top row
boardIter_rowLoop:                     ;
        LD      B, BOARD_NUM_COLUMNS   ; B = column counter
        LD      E, 0                   ; E = left column
boardIter_columnLoop:                  ;
        CALL    boardIter_jumpHL       ; call callback routine
        INC     E                      ; advance to next column
        DJNZ    boardIter_columnLoop   ; repeat columnLoop for each column
        INC     D                      ; advance to next row
        DEC     C                      ; repeat rowLoop for each row
        JR      NZ, boardIter_rowLoop  ;
        POP     DE                     ; STACK: [PC BC]
        POP     BC                     ; STACK: [PC]
        RET                            ; return
        ;;
boardIter_jumpHL:                      ; subroutine to implement `CALL (HL)`
        JP      (HL)                   ;

;;;============================================================================
;;; SPRITE HELPER ROUTINES ////////////////////////////////////////////////////
;;;============================================================================

boardGetSpriteLocationData:
        ;; INPUT:
        ;;   ACC -- sprite ID
        ;;
        ;; OUTPUT:
        ;;   B -- pixel-wise row OFFSET of sprite within cell
        ;;   C -- pixel-wise column OFFSET of sprite within cell
        ;;   D -- cell-wise row of sprite's cell
        ;;   E -- cell-wise column of sprite's cell
        ;;
        PUSH    IX
        CALL    boardGetSpritePointer
        LD      A, (IX+BOARD_SPRITE_COLUMN)
        SUB     BOARD_COLUMN
        CALL    boardDivideCellSide
        LD      E, B
        LD      C, A
        LD      A, (IX+BOARD_SPRITE_ROW)
        SUB     BOARD_ROW
        CALL    boardDivideCellSide
        LD      D, B
        LD      B, A
        POP     IX
        RET

;;;============================================================================
;;; CONSTANTS /////////////////////////////////////////////////////////////////
;;;============================================================================

#define BOARD_DIRECTION_UP      0
#define BOARD_DIRECTION_RIGHT   1
#define BOARD_DIRECTION_DOWN    2
#define BOARD_DIRECTION_LEFT    3

#define BOARD_CELL_EMPTY        0
#define BOARD_CELL_WALL         1
#define BOARD_CELL_DOT          2
#define BOARD_CELL_BIG_DOT      3
#define BOARD_CELL_CHERRY       4
#define BOARD_CELL_HEART        5

#define BOARD_CELL_SIDE         6
#define BOARD_CELL_HEIGHT       BOARD_CELL_SIDE
#define BOARD_CELL_WIDTH        BOARD_CELL_SIDE
#define BOARD_CELL_DIMENSIONS   BOARD_CELL_HEIGHT*256+BOARD_CELL_WIDTH

#define BOARD_NUM_ROWS          9
#define BOARD_NUM_COLUMNS       16

#define BOARD_HEIGHT            BOARD_CELL_HEIGHT * BOARD_NUM_ROWS
#define BOARD_WIDTH             BOARD_CELL_WIDTH * BOARD_NUM_COLUMNS
#define BOARD_DIMENSIONS        BOARD_HEIGHT * 256 + BOARD_WIDTH

#define BOARD_ROW               2
#define BOARD_COLUMN            0
#define BOARD_LOCATION          BOARD_ROW * 256 + BOARD_COLUMN

#define BOARD_MAP_SIZE          9 * 2

#define BOARD_CELL_PICTURE_SIZE BOARD_CELL_HEIGHT
#define BOARD_SPRITE_HEIGHT     5

;;;============================================================================
;;; VARIABLE DATA /////////////////////////////////////////////////////////////
;;;============================================================================

#define BOARD_ARRAY_SIZE        BOARD_NUM_ROWS * BOARD_NUM_COLUMNS
#define BOARD_SPRITE_COUNT_SIZE 1
#define BOARD_SPRITE_SIZE       1 + 1 + 2
#define BOARD_SPRITES_SIZE      5 * BOARD_SPRITE_SIZE

#define BOARD_SPRITE_COLUMN     0
#define BOARD_SPRITE_ROW        1
#define BOARD_SPRITE_PICTURE    2

#define boardArray              boardData
#define boardSpriteCount        boardArray + BOARD_ARRAY_SIZE
#define boardSprites            boardSpriteCount + BOARD_SPRITE_COUNT_SIZE
#define boardTouchedCellCount   boardSprites + BOARD_SPRITES_SIZE
#define boardTouchedCells       boardTouchedCellCount + 1

#define boardDataEnd            boardTouchedCells + (2 * 20)
#define BOARD_DATA_SIZE         boardDataEnd - boardData

;;;============================================================================
;;; IMAGE DATA ////////////////////////////////////////////////////////////////
;;;============================================================================

boardCellPictures:
        ;;
boardCellPictureEmpty:
        .db     00000000b
        .db     00000000b
        .db     00000000b
        .db     00000000b
        .db     00000000b
        .db     00000000b
        ;;
boardCellPictureWallCenter:
        .db     11111000b
        .db     11111000b
        .db     11111000b
        .db     11111000b
        .db     11111000b
        .db     00000000b
        ;;
boardCellPictureDot:
        .db     00000000b
        .db     01110000b
        .db     01010000b
        .db     01110000b
        .db     00000000b
        .db     00000000b
