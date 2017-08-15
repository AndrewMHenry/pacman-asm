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
        PUSH    BC                       ; STACK: [PC BC]
        PUSH    DE                       ; STACK: [PC BC DE]
        PUSH    HL                       ; STACK: [PC BC DE HL]
        LD      BC, BOARD_ARRAY_SIZE - 1 ; BC = array size - 1
        LD      DE, boardArray + 1       ; DE = array base + 1
        LD      HL, boardArray + 0       ; HL = array base
        LD      (HL), BOARD_CELL_DOT     ; seed dot as initial value
        LDIR                             ; propagate
        XOR     A                        ; sprite count = 0
        LD      (boardSpriteCount), A    ;
        POP     HL                       ; STACK: [PC BC DE]
        POP     DE                       ; STACK: [PC BC]
        POP     BC                       ; STACK: [PC]
        RET                              ; return

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
        PUSH    BC                          ; STACK: [PC BC]
        PUSH    DE                          ; STACK: [PC BC DE]
        PUSH    HL                          ; STACK: [PC BC DE HL]
        LD      C, BOARD_MAP_SIZE           ; C = board map counter
        LD      DE, boardArray              ; DE = base of board array
boardStageWallMap_outer:                    ;
        PUSH    HL                          ; STACK: [PC BC DE HL HL]
        LD      B, 8                        ; B = bit counter
        LD      L, (HL)                     ; L = map byte
        LD      A, BOARD_CELL_WALL          ; ACC = wall
boardStageWallMap_inner:                    ;
        RLC     L                           ; rotate bit into carry
        JR      NC, boardStageWallMap_skip  ; skip if bit reset (no wall)
        LD      (DE), A                     ; load wall otherwise
boardStageWallMap_skip:                     ;
        INC     DE                          ; advance to next board array byte
        DJNZ    boardStageWallMap_inner     ; repeat inner loop until byte done
        POP     HL                          ; STACK: [PC BC DE HL]
        INC     HL                          ; advance to next map byte
        DEC     C                           ; repeat outer loop until map done
        JR      NZ, boardStageWallMap_outer ;
        POP     HL                          ; STACK: [PC BC DE]
        POP     DE                          ; STACK: [PC BC]
        POP     BC                          ; STACK: [PC]
        RET                                 ; return

boardStageEmptyCell:
        ;; INPUT:
        ;;   D -- cell-wise row of empty cell
        ;;   E -- cell-wise column of empty cell
        ;;
        ;; OUTPUT:
        ;;   <board data> -- empty cell staged at (D, E)
        ;;
        PUSH    HL
        CALL    boardGetCellAddress
        LD      (HL), BOARD_CELL_EMPTY
        POP     HL
        RET

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
        PUSH    DE                                     ; STACK: [PC DE]
        PUSH    IX                                     ; STACK: [PC DE IX]
        LD      A, (boardSpriteCount)                  ; ACC = sprite count++
        INC     A                                      ;
        LD      (boardSpriteCount), A                  ;
        DEC     A                                      ;
        CALL    boardGetSpritePointer                  ;
        CALL    boardGetCellLocation                   ; D, E = location
        LD      (IX+BOARD_SPRITE_COLUMN), E     ; set column
        LD      (IX+BOARD_SPRITE_ROW), D        ; set row
        LD      (IX+BOARD_SPRITE_PICTURE+0), L  ; set picture
        LD      (IX+BOARD_SPRITE_PICTURE+1), H  ;
        POP     IX                                     ; STACK: [PC DE]
        POP     DE                                     ; STACK: [PC]
        RET                                            ; return

        PUSH    BC                    ; STACK: [PC BC]
        PUSH    DE                    ; STACK: [PC BC DE]
        LD      C, L                  ; BC = HL (image base)
        LD      B, H                  ;
        LD      A, (boardSpriteCount) ; ACC = (sprite count += 1) * 4
        INC     A                     ;
        LD      (boardSpriteCount), A ;
        ADD     A, A                  ;
        ADD     A, A                  ;
        LD      HL, boardSprites - 4  ; HL = board sprites base - 4 + ACC
        ADD     A, L                  ;
        LD      L, A                  ;
        LD      A, H                  ;
        ADC     A, 0                  ;
        LD      H, A                  ;
        CALL    boardGetCellLocation  ; D, E = pixel-wise initial cell location
        LD      (HL), E               ; load location into sprite data
        INC     HL                    ;
        LD      (HL), D               ;
        INC     HL                    ;
        LD      (HL), C               ; load image base into sprite data
        INC     HL                    ;
        LD      (HL), B               ;
        LD      L, C                  ; HL = original value
        LD      H, B                  ;
        POP     DE                    ; STACK: [PC BC]
        POP     BC                    ; STACK: [PC]
        RET                           ; return

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
;;; allowed.  To this end, for each direction (up, down, left, or right) in
;;; which a sprite may move, we supply two routines, which both expect ACC to
;;; contain the index of the sprite in question:
;;;
;;;     (1) boardCheckMoveSprite<Direction>: This routine returns
;;;         with the carry flag RESET if and only if the movement is allowed.
;;;
;;;     (2) boardMoveSprite<Direction>: This routine ASSUMES that the requested
;;;         movement is allowed and carries it out.
;;;
;;; It is important to note that the only way guaranteed by the interface of
;;; ensuring that a given movement is allowed is to use the corresponding
;;; boardCheckMoveSprite<Direction> routine.  For example, if C contains the
;;; index of a sprite to be moved to the right, the following sequence of
;;; instructions safely carries out the movement only if it is allowed:
;;;
;;;     LD      A, C                       ; ACC = sprite index
;;;     CALL    boardCheckMoveSpriteRight  ; RESET carry iff movement allowed
;;;     LD      A, C                       ; ACC = sprite index (again)
;;;     CALL    NC, boardMoveSpriteRight   ; move ONLY IF ALLOWED
;;;

boardCheckMoveSpriteUp:
        PUSH    BC                                ; STACK: [PC BC]
        PUSH    DE                                ; STACK: [PC BC DE]
        PUSH    HL                                ; STACK: [PC BC DE HL]
        CALL    boardGetSpriteLocationData        ; get cell and offsets
        LD      A, C                              ; if misaligned column:
        OR      A                                 ;
        SCF                                       ;     return FALSE
        JR      NZ, boardCheckMoveSpriteUp_return ;
        LD      A, B                              ; if misaligned row:
        OR      A                                 ;
        JR      NZ, boardCheckMoveSpriteUp_return ;     return TRUE
        DEC     D                                 ; if cell above wall:
        CALL    boardGetCellAddress               ;
        LD      A, BOARD_CELL_WALL - 1            ;     return FALSE
        SUB     (HL)                              ;
        ADD     A, 1                              ;
boardCheckMoveSpriteUp_return:                    ;
        POP     HL                                ; STACK: [PC BC DE]
        POP     DE                                ; STACK: [PC BC]
        POP     BC                                ; STACK: [PC]
        RET                                       ; return

boardCheckMoveSpriteRight:
        PUSH    BC                                   ; STACK: [PC BC]
        PUSH    DE                                   ; STACK: [PC BC DE]
        PUSH    HL                                   ; STACK: [PC BC DE HL]
        CALL    boardGetSpriteLocationData           ; get cell and offsets
        LD      A, B                                 ; if misaligned row:
        OR      A                                    ;
        SCF                                          ;     return FALSE
        JR      NZ, boardCheckMoveSpriteRight_return ;
        LD      A, C                                 ; if misaligned column:
        OR      A                                    ;
        JR      NZ, boardCheckMoveSpriteRight_return ;     return TRUE
        INC     E                                    ; if cell to right wall:
        CALL    boardGetCellAddress                  ;
        LD      A, (HL)                              ;
        CP      BOARD_CELL_WALL                      ;
        SCF                                          ;     return FALSE
        JR      Z, boardCheckMoveSpriteRight_return  ;
        XOR     A                                    ; return TRUE otherwise
boardCheckMoveSpriteRight_return:                    ;
        POP     HL                                   ; STACK: [PC BC DE]
        POP     DE                                   ; STACK: [PC BC]
        POP     BC                                   ; STACK: [PC]
        RET                                          ; return

boardCheckMoveSpriteDown:
        PUSH    BC                                  ; STACK: [PC BC]
        PUSH    DE                                  ; STACK: [PC BC DE]
        PUSH    HL                                  ; STACK: [PC BC DE HL]
        CALL    boardGetSpriteLocationData          ; get cell and offsets
        LD      A, C                                ; if misaligned column:
        OR      A                                   ;
        SCF                                         ;     return FALSE
        JR      NZ, boardCheckMoveSpriteDown_return ;
        LD      A, B                                ; if misaligned row:
        OR      A                                   ;
        JR      NZ, boardCheckMoveSpriteDown_return ;     return TRUE
        INC     D                                   ; if cell below wall:
        CALL    boardGetCellAddress                 ;
        LD      A, BOARD_CELL_WALL - 1              ;     return FALSE
        SUB     (HL)                                ;
        ADD     A, 1                                ;
boardCheckMoveSpriteDown_return:                    ;
        POP     HL                                  ; STACK: [PC BC DE]
        POP     DE                                  ; STACK: [PC BC]
        POP     BC                                  ; STACK: [PC]
        RET                                         ; return

boardCheckMoveSpriteLeft:
        PUSH    BC                                   ; STACK: [PC BC]
        PUSH    DE                                   ; STACK: [PC BC DE]
        PUSH    HL                                   ; STACK: [PC BC DE HL]
        CALL    boardGetSpriteLocationData           ; get cell and offsets
        LD      A, B                                 ; if misaligned row:
        OR      A                                    ;
        SCF                                          ;     return FALSE
        JR      NZ, boardCheckMoveSpriteLeft_return  ;
        LD      A, C                                 ; if misaligned column:
        OR      A                                    ;
        JR      NZ, boardCheckMoveSpriteLeft_return  ;     return TRUE
        DEC     E                                    ; if cell to right wall:
        CALL    boardGetCellAddress                  ;
        LD      A, (HL)                              ;
        CP      BOARD_CELL_WALL                      ;
        SCF                                          ;     return FALSE
        JR      Z, boardCheckMoveSpriteLeft_return   ;
        XOR     A                                    ; return TRUE otherwise
boardCheckMoveSpriteLeft_return:                     ;
        POP     HL                                   ; STACK: [PC BC DE]
        POP     DE                                   ; STACK: [PC BC]
        POP     BC                                   ; STACK: [PC]
        RET                                          ; return

boardMoveSpriteUp:
        PUSH    IX
        CALL    boardGetSpritePointer
        DEC     (IX+BOARD_SPRITE_ROW)
        POP     IX
        RET

boardMoveSpriteRight:
        PUSH    IX
        CALL    boardGetSpritePointer
        INC     (IX+BOARD_SPRITE_COLUMN)
        POP     IX
        RET

boardMoveSpriteDown:
        PUSH    IX
        CALL    boardGetSpritePointer
        INC     (IX+BOARD_SPRITE_ROW)
        POP     IX
        RET

boardMoveSpriteLeft:
        PUSH    IX
        CALL    boardGetSpritePointer
        DEC     (IX+BOARD_SPRITE_COLUMN)
        POP     IX
        RET

;;; SPRITE INTERACTION.........................................................

boardSpriteCollectItems:
        RET

;;;============================================================================
;;; UPDATING INTERFACE ////////////////////////////////////////////////////////
;;;============================================================================

boardUpdate:
        ;; INPUTS:
        ;;   <board data> -- current state of board
        ;;
        ;; OUTPUTS:
        ;;   <screen buffer> -- updated to reflect board contents
        ;;
        PUSH    BC                   ; STACK: [PC BC]
        PUSH    DE                   ; STACK: [PC BC DE]
        PUSH    HL                   ; STACK: [PC BC DE HL]
        LD      BC, BOARD_DIMENSIONS ; clear board footprint
        LD      DE, BOARD_LOCATION   ;
        CALL    drawClearRectangle   ;
        LD      HL, boardDrawCell    ; draw all board cells
        CALL    boardIter            ;
        LD      HL, boardDrawSprite  ; draw all sprites
        CALL    boardSpriteIter      ;
        CALL    screenUpdate         ; flush buffer to LCD
        POP     HL                   ; STACK: [PC BC DE]
        POP     DE                   ; STACK: [PC BC]
        POP     BC                   ; STACK: [PC]
        RET                          ; return

;;;============================================================================
;;; CELL HELPER ROUTINES //////////////////////////////////////////////////////
;;;============================================================================

boardIter:
        ;; INPUT:
        ;;   HL -- start of callback to apply to each cell
        ;;
        ;; OUTPUT:
        ;;   <board data> -- callback applied to each cell
        ;;
        PUSH    BC                    ; STACK: [PC BC]
        PUSH    DE                    ; STACK: [PC BC DE]
        LD      C, BOARD_NUM_ROWS     ; C = row counter
        LD      D, 0                  ; D = top row
boardIter_rowLoop:                    ;
        LD      B, BOARD_NUM_COLUMNS  ; B = column counter
        LD      E, 0                  ; E = left column
boardIter_columnLoop:                 ;
        CALL    boardIter_jumpHL      ; call callback routine
        INC     E                     ; advance to next column
        DJNZ    boardIter_columnLoop  ; repeat columnLoop for each column
        INC     D                     ; advance to next row
        DEC     C                     ; repeat rowLoop for each row
        JR      NZ, boardIter_rowLoop ;
        POP     DE                    ; STACK: [PC BC]
        POP     BC                    ; STACK: [PC]
        RET                           ; return
        ;;
boardIter_jumpHL:                     ; subroutine to implement `CALL (HL)`
        JP      (HL)                  ;

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
        PUSH    BC                   ; STACK: [PC BC]
        PUSH    DE                   ; STACK: [PC BC DE]
        PUSH    HL                   ; STACK: [PC BC DE HL]
        LD      B, BOARD_CELL_HEIGHT ; B = cell height
        CALL    boardGetCellPicture  ; HL = cell picture
        CALL    boardGetCellLocation ; D, E = cell location
        CALL    drawPicture          ; draw the picture
        POP     HL                   ; STACK: [PC BC DE]
        POP     DE                   ; STACK: [PC BC]
        POP     BC                   ; STACK: [PC]
        RET                          ; return

boardGetCellLocation:
        ;; INPUT:
        ;;   D -- cell-wise row
        ;;   E -- cell-wise column
        ;;
        ;; OUTPUT:
        ;;   D -- pixel-wise row
        ;;   E -- pixel-wise column
        ;;
        PUSH    HL
        LD      L, E
        LD      H, D
        ADD     HL, HL
        ADD     HL, DE
        ADD     HL, HL
        LD      DE, BOARD_LOCATION
        ADD     HL, DE
        EX      DE, HL
        POP     HL
        RET

boardGetCellAddress:
        ;; INPUT:
        ;;   D -- cell-wise row of cell
        ;;   E -- cell-wise column of cell
        ;;
        ;; OUTPUT:
        ;;   HL -- address of cell in boardArray
        ;;
        PUSH    DE
        LD      HL, boardArray
        LD      A, D
        LD      D, 0
        ADD     HL, DE
        ADD     A, A
        ADD     A, A
        ADD     A, A
        ADD     A, A
        LD      E, A
        ADD     HL, DE
        POP     DE
        RET

boardGetCellPicture:
        ;; INPUT:
        ;;   D -- cell-wise row of cell
        ;;   E -- cell-wise column of cell
        ;;
        ;; OUTPUT:
        ;;   HL -- base of picture for cell
        ;;
        PUSH    DE
        CALL    boardGetCellAddress
        LD      A, (HL)
        ADD     A, A
        ADD     A, (HL)
        ADD     A, A
        LD      HL, boardCellPictures
        LD      E, A
        LD      D, 0
        ADD     HL, DE
        POP     DE
        RET

;;;============================================================================
;;; SPRITE HELPER ROUTINES ////////////////////////////////////////////////////
;;;============================================================================

boardSpriteIter:
        ;; INPUT:
        ;;   HL -- address of callback routine to apply to each sprite
        ;;
        ;; OUTPUT:
        ;;   <callback applied to each sprite>
        ;;
        LD      A, (boardSpriteCount)  ; ACC = sprite count
        OR      A                      ; return if sprite count == 0
        RET     Z                      ;
        PUSH    BC                     ; STACK: [PC BC]
        LD      B, A                   ; B (counter) = sprite count
        LD      C, 0                   ; C (sprite index) = 0
boardSpriteIter_loop:                  ;
        LD      A, C                   ; ACC = sprite index
        CALL    boardSpriteIter_jumpHL ; call the callback routine
        INC     C                      ; advance sprite index
        DJNZ    boardSpriteIter_loop   ; repeat for each sprite index
        POP     BC                     ; STACK: [PC]
        RET                            ; return
        ;;
boardSpriteIter_jumpHL:
        JP      (HL)

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
        PUSH    DE
        ADD     A, A
        ADD     A, A
        LD      E, A
        LD      D, 0
        LD      IX, boardSprites
        ADD     IX, DE
        POP     DE
        RET

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
        PUSH    IX                              ; STACK: [PC BC DE HL IX]
        CALL    boardGetSpritePointer           ;
        LD      B, BOARD_SPRITE_HEIGHT          ; B = sprite height
        LD      E, (IX+BOARD_SPRITE_COLUMN)     ; E = column
        LD      D, (IX+BOARD_SPRITE_ROW)        ; D = row
        LD      L, (IX+BOARD_SPRITE_PICTURE+0)  ; HL = picture
        LD      H, (IX+BOARD_SPRITE_PICTURE+1)  ;
        CALL    drawPicture                     ; draw the picture
        POP     IX                              ; STACK: [PC BC DE HL]
        POP     HL                              ; STACK: [PC BC DE]
        POP     DE                              ; STACK: [PC BC]
        POP     BC                              ; STACK: [PC]
        RET                                     ; return

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

boardDivideCellSide:
        ;; INPUT:
        ;;   ACC -- value to take mod cell side
        ;;
        ;; OUTPUT:
        ;;   ACC -- value mod cell side
        ;;   B -- value // cell side
        ;;
        LD      B, -1
boardModCellSide_loop:
        INC     B
        SUB     BOARD_CELL_SIDE
        JR      NC, boardModCellSide_loop
        ADD     A, BOARD_CELL_SIDE
        RET

;;;============================================================================
;;; CONSTANTS /////////////////////////////////////////////////////////////////
;;;============================================================================

#define BOARD_CELL_EMPTY                0
#define BOARD_CELL_WALL                 1
#define BOARD_CELL_DOT                  2
#define BOARD_CELL_BIG_DOT              3
#define BOARD_CELL_CHERRY               4
#define BOARD_CELL_HEART                5

#define BOARD_CELL_SIDE                 6
#define BOARD_CELL_HEIGHT               BOARD_CELL_SIDE
#define BOARD_CELL_WIDTH                BOARD_CELL_SIDE
#define BOARD_CELL_DIMENSIONS           BOARD_CELL_HEIGHT*256+BOARD_CELL_WIDTH

#define BOARD_NUM_ROWS                  9
#define BOARD_NUM_COLUMNS               16

#define BOARD_HEIGHT                    BOARD_CELL_HEIGHT * BOARD_NUM_ROWS
#define BOARD_WIDTH                     BOARD_CELL_WIDTH * BOARD_NUM_COLUMNS
#define BOARD_DIMENSIONS                BOARD_HEIGHT * 256 + BOARD_WIDTH

#define BOARD_ROW                       2
#define BOARD_COLUMN                    0
#define BOARD_LOCATION                  BOARD_ROW * 256 + BOARD_COLUMN

#define BOARD_MAP_SIZE                  9 * 2

#define BOARD_CELL_PICTURE_SIZE         BOARD_CELL_HEIGHT
#define BOARD_SPRITE_HEIGHT             5

;;;============================================================================
;;; VARIABLE DATA /////////////////////////////////////////////////////////////
;;;============================================================================

#define BOARD_ARRAY_SIZE                BOARD_NUM_ROWS * BOARD_NUM_COLUMNS
#define BOARD_SPRITE_COUNT_SIZE         1
#define BOARD_SPRITES_SIZE              5 * (1 + 1 + 2)

#define BOARD_SPRITE_COLUMN             0
#define BOARD_SPRITE_ROW                1
#define BOARD_SPRITE_PICTURE            2

#define boardArray              boardData
#define boardSpriteCount        boardArray + BOARD_ARRAY_SIZE
#define boardSprites            boardSpriteCount + BOARD_SPRITE_COUNT_SIZE

#define boardDataEnd            boardSprites + BOARD_SPRITES_SIZE
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

;;;============================================================================
;;; SETUP AND TEARDOWN ////////////////////////////////////////////////////////
;;;============================================================================
        
boardInit:
        RET

boardExit:
        RET
