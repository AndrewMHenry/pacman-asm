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
        PUSH    HL                      ; STACK: [PC HL]
        CALL    boardGetCellAddress     ; cell = empty
        LD      (HL), BOARD_CELL_EMPTY  ;
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
        PUSH    DE                              ; STACK: [PC DE]
        PUSH    IX                              ; STACK: [PC DE IX]
        LD      A, (boardSpriteCount)           ; ACC = sprite count++
        INC     A                               ;
        LD      (boardSpriteCount), A           ;
        DEC     A                               ;
        CALL    boardGetSpritePointer           ;
        CALL    boardGetCellLocation            ; D, E = location
        LD      (IX+BOARD_SPRITE_COLUMN), E     ; set column
        LD      (IX+BOARD_SPRITE_ROW), D        ; set row
        LD      (IX+BOARD_SPRITE_PICTURE+0), L  ; set picture
        LD      (IX+BOARD_SPRITE_PICTURE+1), H  ;
        POP     IX                              ; STACK: [PC DE]
        POP     DE                              ; STACK: [PC]
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
        PUSH    DE
        PUSH    IX
        CALL    boardGetSpritePointer
        LD      A, D
        LD      E, (IX+BOARD_SPRITE_COLUMN)
        LD      D, (IX+BOARD_SPRITE_ROW)
        CALL    boardMoveDirection
        CALL    boardCheckLocationSpritely
        POP     IX
        POP     DE
        RET

boardMoveSprite:
        ;; INPUT:
        ;;   ACC -- sprite ID
        ;;   D -- direction in which to move sprite
        ;;
        ;; OUTPUT:
        ;;   <board data> -- sprite moved
        ;;
        PUSH    DE
        PUSH    IX
        CALL    boardGetSpritePointer
        LD      A, D
        LD      E, (IX+BOARD_SPRITE_COLUMN)
        LD      D, (IX+BOARD_SPRITE_ROW)
        CALL    boardMoveDirection
        LD      (IX+BOARD_SPRITE_COLUMN), E
        LD      (IX+BOARD_SPRITE_ROW), D
        POP     IX
        POP     DE
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
        CALL    boardGetSpritePointer               ; get pixel-wise location
        LD      E, (IX+BOARD_SPRITE_COLUMN)         ;
        LD      D, (IX+BOARD_SPRITE_ROW)            ;
        CALL    boardExtractLocationData            ; get offsets, cell
        LD      A, C                                ; no dice if misaligned
        OR      B                                   ;
        JR      NZ, boardSpriteCollectItems_return  ;
        CALL    boardGetCellAddress                 ; set cell empty
        LD      (HL), BOARD_CELL_EMPTY              ;
boardSpriteCollectItems_return:                     ;
        POP     IX                                  ; STACK: [PC BC DE HL]
        POP     HL                                  ; STACK: [PC BC DE]
        POP     DE                                  ; STACK: [PC BC]
        POP     BC                                  ; STACK: [PC]
        RET                                         ; return

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
        PUSH    BC                    ; STACK: [PC BC]
        PUSH    DE                    ; STACK: [PC BC DE]
        PUSH    HL                    ; STACK: [PC BC DE HL]
        LD      BC, BOARD_DIMENSIONS  ; clear board footprint
        LD      DE, BOARD_LOCATION    ;
        CALL    drawClearRectangle    ;
        LD      HL, boardDrawCell     ; draw all board cells
        CALL    boardIter             ;
        LD      HL, boardDrawSprite   ; draw all sprites
        CALL    boardSpriteIter       ;
        CALL    screenUpdate          ; flush buffer to LCD
        POP     HL                    ; STACK: [PC BC DE]
        POP     DE                    ; STACK: [PC BC]
        POP     BC                    ; STACK: [PC]
        RET                           ; return

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
        LD      B, BOARD_CELL_HEIGHT  ; B = cell height
        CALL    boardGetCellPicture   ; HL = cell picture
        CALL    boardGetCellLocation  ; D, E = cell location
        CALL    drawPicture           ; draw the picture
        POP     HL                    ; STACK: [PC BC DE]
        POP     DE                    ; STACK: [PC BC]
        POP     BC                    ; STACK: [PC]
        RET                           ; return

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
