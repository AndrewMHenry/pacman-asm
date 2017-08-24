;;; iboard.asm --

;;;============================================================================
;;; SETUP AND TEARDOWN ////////////////////////////////////////////////////////
;;;============================================================================
        
iboardInit:
        RET

iboardExit:
        RET

;;;============================================================================
;;; EXTERNAL INTERFACE HOOKS //////////////////////////////////////////////////
;;;============================================================================

;;; In order to increase flexibility, we supply internal hooks for each of the
;;; three "event" categories in the external interface: initializing,
;;; deploying, and updating.  Each hook must be called at the BEGINNING of the
;;; corresponding external interface routine to ensure correct operation.

;;; As an example, this scheme allows initialization of the proposed item
;;; counter to be done either when the iboard is initialized or when it is
;;; deployed, depending on efficiency and ease-of-implementation
;;; considerations.

iboardInitializeHook:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   <iboard data> -- prepared for staging
        ;;
        XOR     A                           ; reset sprite, touched cell counts
        LD      (iboardSpriteCount), A       ;
        LD      (iboardTouchedCellCount), A  ;
        RET                                 ; return

iboardDeployHook:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   <iboard data> -- prepared for deploying
        ;;
        CALL    iboardItemCountSetup
        RET

iboardUpdateHook:
        ;; INPUT:
        ;;   <none>
        ;;
        ;; OUTPUT:
        ;;   <iboard data> -- prepared for deploying
        ;;
        RET

;;;============================================================================
;;; IBOARD LAYOUT INTERFACE ////////////////////////////////////////////////////
;;;============================================================================

iboardFill:
        ;; INPUT:
        ;;   ACC -- cell value to load in all cells
        ;;
        ;; OUTPUT:
        ;;   <iboard data> -- all iboard cells given value in ACC
        ;;
        ;; NOTE: The cell value is not necessarily the actual content
        ;; of the memory cell, but rather indicates the kind of thing
        ;; to be loaded into the cells.
        ;;
        PUSH    BC                        ; STACK: [PC BC]
        PUSH    DE                        ; STACK: [PC BC DE]
        PUSH    HL                        ; STACK: [PC BC DE HL]
        LD      BC, IBOARD_ARRAY_SIZE - 1  ; BC = iboard size - 1
        LD      DE, iboardArray + 1        ; DE = iboard base + 1
        LD      HL, iboardArray + 0        ; HL = iboard base
        LD      (HL), A                   ; seed initial value
        LDIR                              ; propagate
        POP     HL                        ; STACK: [PC BC DE]
        POP     DE                        ; STACK: [PC BC]
        POP     BC                        ; STACK: [PC]
        RET                               ; return

iboardApplyMap:
        ;; INPUT:
        ;;   ACC -- cell value to load in specified cells
        ;;   HL -- base of cell bitmap
        ;;
        ;; OUTPUT:
        ;;   (iboardArray) -- cells specified by bitmap given input value
        ;;
        PUSH    BC                          ; STACK: [PC BC]
        PUSH    DE                          ; STACK: [PC BC DE]
        PUSH    HL                          ; STACK: [PC BC DE HL]
        LD      B, IBOARD_MAP_SIZE           ; B = iboard map counter
        LD      C, A                        ; C = cell value
        LD      DE, iboardArray              ; DE = base of iboard array
iboardApplyMap_outer:                        ;
        PUSH    BC                          ; STACK: [PC BC DE HL BC]
        PUSH    HL                          ; STACK: [PC BC DE HL BC HL]
        LD      B, 8                        ; B = bit counter
        LD      L, (HL)                     ; L = map byte
iboardApplyMap_inner:                        ;
        RLC     L                           ; rotate bit into carry
        EX      DE, HL                      ; set wall if carry (bit set)
        LD      A, C                        ; set cell value to C
        CALL    C, iboardSetCellValue        ;
        EX      DE, HL                      ;
        INC     DE                          ; advance to next iboard array byte
        DJNZ    iboardApplyMap_inner         ; repeat inner loop until byte done
        POP     HL                          ; STACK: [PC BC DE HL BC]
        POP     BC                          ; STACK: [PC BC DE HL]
        INC     HL                          ; advance to next map byte
        DJNZ    iboardApplyMap_outer         ; repeat outer loop until map done
        POP     HL                          ; STACK: [PC BC DE]
        POP     DE                          ; STACK: [PC BC]
        POP     BC                          ; STACK: [PC]
        RET                                 ; return

;;;============================================================================
;;; HIGH-LEVEL SPRITE INTERFACE ///////////////////////////////////////////////
;;;============================================================================

iboardAddSprite:
        ;; INPUT:
        ;;   <iboard data> -- determines where to add sprite
        ;;
        ;; OUTPUT:
        ;;   ACC -- sprite ID of added sprite
        ;;
        LD      A, (iboardSpriteCount)  ; ACC = sprite count++
        INC     A                      ;
        LD      (iboardSpriteCount), A  ;
        DEC     A                      ;
        RET                            ; return

iboardGetSpritePointer:
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
        LD      IX, iboardSprites  ; IX = iboardSprites + DE
        ADD     IX, DE            ;
        POP     DE                ; STACK: [PC]
        RET                       ; return

iboardDrawSprites:
        ;; INPUT:
        ;;   <iboard data> -- determines how/where to draw sprites
        ;;
        ;; OUTPUT:
        ;;   <screen buffer> -- sprites drawn on screen
        ;;
        PUSH    HL                    ; STACK: [PC HL]
        LD      HL, iboardDrawSprite   ; draw all sprites
        CALL    iboardSpriteIter       ;
        POP     HL                    ; STACK: [PC]
        RET                           ; return

;;;============================================================================
;;; LOW-LEVEL SPRITE INTERFACE ////////////////////////////////////////////////
;;;============================================================================

;;; SPRITE GETTERS/SETTERS.....................................................

iboardGetSpriteCell:
        ;; INPUT:
        ;;   IX -- sprite pointer
        ;;
        ;; OUTPUT:
        ;;   D -- cell-wise row of sprite
        ;;   E -- cell-wise column of sprite
        ;;
        PUSH    BC
        CALL    iboardGetSpriteLocation
        CALL    iboardExtractLocationData
        POP     BC
        RET

iboardSetSpriteCell:
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
        CALL    iboardGetSpriteOffsets
        CALL    iboardGetCellLocation
        EX      DE, HL
        ADD     HL, BC
        EX      DE, HL
        CALL    iboardSetSpriteLocation
        POP     DE
        POP     BC
        RET

iboardGetSpriteOffsets:
        ;; INPUT:
        ;;   IX -- sprite pointer
        ;;
        ;; OUTPUT:
        ;;   B -- pixel-wise row offset of sprite
        ;;   C -- pixel-wise column offset of sprite
        ;;
        PUSH    DE
        CALL    iboardGetSpriteLocation
        CALL    iboardExtractLocationData
        POP     DE
        RET

iboardSetSpriteOffsets:
        ;; INPUT:
        ;;   IX -- sprite pointer
        ;;   B -- pixel-wise row offset for sprite
        ;;   C -- pixel-wise column offset for sprite
        ;;
        ;; OUTPUT:
        ;;   (IX) -- pixel-wise row and column offsets set for sprite
        ;;
        PUSH    DE
        CALL    iboardGetSpriteCell
        CALL    iboardGetCellLocation
        EX      DE, HL
        ADD     HL, BC
        EX      DE, HL
        CALL    iboardSetSpriteLocation
        POP     DE
        RET

iboardGetSpriteLocation:
        ;; INPUT:
        ;;   IX -- sprite pointer
        ;;
        ;; OUTPUT:
        ;;   D -- pixel-wise row of sprite
        ;;   E -- pixel-wise column of sprite
        ;;
        LD      E, (IX+IBOARD_SPRITE_COLUMN)     ; E = column
        LD      D, (IX+IBOARD_SPRITE_ROW)        ; D = row
        RET                                     ; return

iboardSetSpriteLocation:
        ;; INPUT:
        ;;   IX -- sprite pointer
        ;;   D -- pixel-wise row for sprite
        ;;   E -- pixel-wise column for sprite
        ;;
        ;; OUTPUT:
        ;;   (IX) -- pixel-wise location of sprite set to (D, E)
        ;;
        LD      (IX+IBOARD_SPRITE_COLUMN), E     ; set column
        LD      (IX+IBOARD_SPRITE_ROW), D        ; set row
        RET                                     ; return

iboardSetSpritePicture:
        ;; INPUT:
        ;;   IX -- sprite pointer
        ;;   HL -- base of picture for sprite
        ;;
        ;; OUTPUT:
        ;;   (IX) -- picture for sprite set to HL
        ;;
        LD      (IX+IBOARD_SPRITE_PICTURE+0), L  ; set picture
        LD      (IX+IBOARD_SPRITE_PICTURE+1), H  ;
        RET                                     ; return

;;; LOCATION ROUTINES..........................................................

iboardMoveDirection:
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
        LD      HL, iboardMoveDirection_dispatch
        ADD     A, A
        ADD     A, L
        LD      L, A
        LD      A, H
        ADC     A, 0
        LD      H, A
        CALL    iboardMoveDirection_jumpHL
        POP     HL
        RET
        ;;
iboardMoveDirection_jumpHL:
        JP      (HL)
        ;;
iboardMoveDirection_dispatch:
        DEC     D
        RET
        INC     E
        RET
        INC     D
        RET
        DEC     E
        RET

iboardCheckLocationSpritely:
        ;; INPUT:
        ;;   D -- pixel-wise row of sprite
        ;;   E -- pixel-wise column of sprite
        ;;   <iboard data> -- determines iboard layout
        ;;
        ;; OUTPUT:
        ;;   <carry flag> -- RESET if and only if location is valid
        ;;
        PUSH    DE                                   ; STACK: [PC DE]
        CALL    iboardCheckWall                       ; FALSE if wall
        JR      C, iboardCheckLocationSpritely_return ;
        LD      A, E                                 ; to top right 
        ADD     A, IBOARD_CELL_SIDE - 1               ;
        LD      E, A                                 ;
        CALL    iboardCheckWall                       ; FALSE if wall
        JR      C, iboardCheckLocationSpritely_return ;
        LD      A, D                                 ; to bottom right
        ADD     A, IBOARD_CELL_SIDE - 1               ;
        LD      D, A                                 ;
        CALL    iboardCheckWall                       ; FALSE if wall
        JR      C, iboardCheckLocationSpritely_return ;
        LD      A, E                                 ; to bottom left
        SUB     IBOARD_CELL_SIDE - 1                  ;
        LD      E, A                                 ;
        CALL    iboardCheckWall                       ; FALSE if wall
iboardCheckLocationSpritely_return:                   ;
        POP     DE                                   ; STACK: [PC]
        RET                                          ; return

;;;============================================================================
;;; CELL INTERFACE ////////////////////////////////////////////////////////////
;;;============================================================================

;;; CELL VALUE ROUTINES........................................................

iboardSetCellEmpty:
        ;; INPUT:
        ;;   HL -- cell pointer
        ;;
        ;; OUTPUT:
        ;;   (HL) -- cell set to empty
        ;;
        LD      (HL), IBOARD_CELL_EMPTY
        RET

iboardSetCellWall:
        ;; INPUT:
        ;;   HL -- cell pointer
        ;;
        ;; OUTPUT:
        ;;   (HL) -- cell set to wall
        ;;
        LD      (HL), IBOARD_CELL_WALL
        RET

iboardSetCellValue:
        ;; INPUT:
        ;;   ACC -- cell value
        ;;   HL -- cell pointer
        ;;
        ;; OUTPUT:
        ;;   (HL) -- cell value set
        ;;
        LD      (HL), A
        RET

iboardCollectCellItem:
        ;; INPUT:
        ;;   HL -- cell pointer
        ;;
        ;; OUTPUT:
        ;;   (HL) -- cell emptied (if not already)
        ;;   <iboard data> -- item (if present) collected
        ;;
        CALL    iboardSetCellEmpty
        RET

;;; CELL LOCATION ROUTINES.....................................................

iboardGetCellLocation:
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
        LD      DE, IBOARD_LOCATION  ; H, L += IBOARD_ROW, IBOARD_COLUMN
        ADD     HL, DE              ;
        EX      DE, HL              ; D, E = H, L and H, L = D, E
        POP     HL                  ; STACK: [PC]
        RET                         ; return

iboardGetCellAddress:
        ;; INPUT:
        ;;   D -- cell-wise row of cell
        ;;   E -- cell-wise column of cell
        ;;
        ;; OUTPUT:
        ;;   HL -- address of cell in iboardArray
        ;;
        PUSH    DE              ; STACK: [PC DE]
        LD      HL, iboardArray  ; HL = iboard array start
        LD      A, D            ; ACC = cell-wise row
        LD      D, 0            ; DE = E (cell-wise column)
        ADD     HL, DE          ; HL += E
        ADD     A, A            ; ACC = cell-wise row * 16 (IBOARD_NUM_COLUMNS)
        ADD     A, A            ;
        ADD     A, A            ;
        ADD     A, A            ;
        LD      E, A            ; DE = ACC
        ADD     HL, DE          ; HL += DE
        POP     DE              ; STACK: [PC]
        RET                     ; return

;;; CELL TOUCH/UPDATE INTERFACE................................................

iboardTouchCell:
        ;; INPUT:
        ;;   D -- cell-wise row
        ;;   E -- cell-wise column
        ;;
        ;; OUTPUT:
        ;;   <iboard data> -- specified cell touched
        ;;
        PUSH    BC
        PUSH    HL
        LD      A, (iboardTouchedCellCount)
        LD      C, A
        LD      B, 0
        INC     A
        LD      (iboardTouchedCellCount), A
        LD      HL, iboardTouchedCells
        ADD     HL, BC
        ADD     HL, BC
        LD      (HL), E
        INC     HL
        LD      (HL), D
        POP     HL
        POP     BC
        RET

iboardUpdateCells:
        ;; INPUT:
        ;;   <iboard data> -- determines cells to update, and how
        ;;
        ;; OUTPUT:
        ;;   <screen buffer> -- updated pictures drawn
        ;;
        LD      A, (iboardTouchedCellCount)  ; ACC = touched cell count
        OR      A                           ;
        RET     Z                           ; return if no touched cells
        PUSH    BC                          ; STACK: [PC BC]
        PUSH    DE                          ; STACK: [PC BC DE]
        PUSH    HL                          ; STACK: [PC BC DE HL]
        LD      B, A                        ; B = touched cell count
        LD      HL, iboardTouchedCells       ; HL = base of touched cells
iboardUpdateCells_loop:                      ;
        LD      E, (HL)                     ; get row and column
        INC     HL                          ;
        LD      D, (HL)                     ;
        INC     HL                          ;
        CALL    iboardDrawCell               ; draw the cell
        DJNZ    iboardUpdateCells_loop       ; repeat for each touched cell
        XOR     A                           ; reset touched cell count
        LD      (iboardTouchedCellCount), A  ;
        POP     HL                          ; STACK: [PC BC DE]
        POP     DE                          ; STACK: [PC BC]
        POP     BC                          ; STACK: [PC]
        RET                                 ; return

;;; ITEM COUNTING..............................................................

iboardItemCountSetup:
        RET

iboardItemCountDecrement:
        RET

iboardItemCountRead:
        CALL    iboardCountDots
        RET

;;;============================================================================
;;; HELPER ROUTINES ///////////////////////////////////////////////////////////
;;;============================================================================

iboardDrawCellCustom:
        ;; INPUT:
        ;;   D -- cell-wise row
        ;;   E -- cell-wise column
        ;;
        ;; OUTPUT:
        ;;   <iboard data> -- possibly affected
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

iboardDrawCell:
        ;; INPUT:
        ;;   D -- cell-wise row
        ;;   E -- cell-wise column
        ;;   <iboard data> -- determines image for cell
        ;;
        ;; OUTPUT:
        ;;   <iboard data> -- possibly affected
        ;;   <screen data> -- image written
        ;;
        PUSH    BC                    ; STACK: [PC BC]
        PUSH    DE                    ; STACK: [PC BC DE]
        PUSH    HL                    ; STACK: [PC BC DE HL]
        CALL    iboardGetCellPicture   ; HL = cell picture
        CALL    iboardGetCellLocation  ; D, E = cell location
        CALL    iboardEraseCell        ; erase background
        LD      B, IBOARD_CELL_HEIGHT  ; B = cell height
        CALL    drawPicture           ; draw the picture
        POP     HL                    ; STACK: [PC BC DE]
        POP     DE                    ; STACK: [PC BC]
        POP     BC                    ; STACK: [PC]
        RET                           ; return

iboardEraseCell:
        ;; INPUT:
        ;;   D -- pixel-wise row
        ;;   E -- pixel-wise column
        ;;
        ;; OUTPUT:
        ;;   <screen data> -- cell footprint erased
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
        LD      BC, IBOARD_CELL_DIMENSIONS
        CALL    drawClearRectangle
        POP     HL
        POP     DE
        POP     BC
        RET

iboardGetCellPicture:
        ;; INPUT:
        ;;   D -- cell-wise row of cell
        ;;   E -- cell-wise column of cell
        ;;
        ;; OUTPUT:
        ;;   HL -- base of picture for cell
        ;;
        PUSH    DE                     ; STACK: [PC DE]
        CALL    iboardGetCellAddress    ; HL = address of cell
        LD      A, (HL)                ; ACC = cell * 6 (cell picture size)
        ADD     A, A                   ;
        ADD     A, (HL)                ;
        ADD     A, A                   ;
        LD      HL, iboardCellPictures  ;
        LD      E, A                   ; HL += (DE = ACC)
        LD      D, 0                   ;
        ADD     HL, DE                 ;
        POP     DE                     ; STACK: [PC]
        RET                            ; return

iboardDivideCellSide:
        ;; INPUT:
        ;;   ACC -- value to take mod cell side
        ;;
        ;; OUTPUT:
        ;;   ACC -- value mod cell side
        ;;   B -- value // cell side
        ;;
        LD      B, -1
iboardDivideCellSide_loop:
        INC     B
        SUB     IBOARD_CELL_SIDE
        JR      NC, iboardDivideCellSide_loop
        ADD     A, IBOARD_CELL_SIDE
        RET

iboardCountDots:
        ;; INPUT:
        ;;   <iboard data> -- contains dots to be counted
        ;;
        ;; OUTPUT:
        ;;   ACC -- number of dots on iboard
        ;;
        PUSH    BC                         ; STACK: [PC BC]
        PUSH    HL                         ; STACK: [PC BC HL]
        LD      A, IBOARD_CELL_DOT          ; ACC = DOT for comparison
        LD      BC, IBOARD_ARRAY_SIZE << 8  ; B, C = size, 0
        LD      HL, iboardArray             ; HL = base of iboard array
iboardCountDots_loop:                       ;
        CP      (HL)                       ; set Z if cell is dot
        JR      NZ, iboardCountDots_skip    ; skip if not
        INC     C                          ; increment C otherwise
iboardCountDots_skip:                       ;
        INC     HL                         ; advance HL to next cell
        DJNZ    iboardCountDots_loop        ; repeat for each cell
        LD      A, C                       ; ACC = C (count)
        POP     HL                         ; STACK: [PC BC]
        POP     BC                         ; STACK: [PC]
        RET                                ; return

iboardSpriteIter:
        ;; INPUT:
        ;;   HL -- address of callback routine to apply to each sprite
        ;;
        ;; OUTPUT:
        ;;   <callback applied to each sprite>
        ;;
        LD      A, (iboardSpriteCount)   ; ACC = sprite count
        OR      A                       ; return if sprite count == 0
        RET     Z                       ;
        PUSH    BC                      ; STACK: [PC BC]
        PUSH    DE                      ; STACK: [PC BC DE]
        PUSH    IX                      ; STACK: [PC BC DE IX]
        LD      B, A                    ; B (counter) = sprite count
        LD      C, 0                    ; C (sprite index) = 0
        LD      DE, IBOARD_SPRITE_SIZE   ;
        LD      IX, iboardSprites        ;
iboardSpriteIter_loop:                   ;
        LD      A, C                    ; ACC = sprite index
        CALL    iboardSpriteIter_jumpHL  ; call the callback routine
        INC     C                       ; advance sprite index
        ADD     IX, DE                  ; advance sprite pointer
        DJNZ    iboardSpriteIter_loop    ; repeat for each sprite index
        POP     IX                      ; STACK: [PC BC DE]
        POP     DE                      ; STACK: [PC BC]
        POP     BC                      ; STACK: [PC]
        RET                             ; return
        ;;
iboardSpriteIter_jumpHL:
        JP      (HL)

iboardDrawSprite:
        ;; INPUT:
        ;;   ACC -- index of sprite to draw
        ;;   <iboard data> -- used to determine location and picture
        ;;
        ;; OUTPUT:
        ;;   <screen buffer> -- sprite drawn in buffer
        ;;
        PUSH    BC                              ; STACK: [PC BC]
        PUSH    DE                              ; STACK: [PC BC DE]
        PUSH    HL                              ; STACK: [PC BC DE HL]
        LD      B, IBOARD_SPRITE_HEIGHT          ; B = sprite height
        LD      E, (IX+IBOARD_SPRITE_COLUMN)     ; E = column
        LD      D, (IX+IBOARD_SPRITE_ROW)        ; D = row
        LD      L, (IX+IBOARD_SPRITE_PICTURE+0)  ; HL = picture
        LD      H, (IX+IBOARD_SPRITE_PICTURE+1)  ;
        CALL    drawPicture                     ; draw the picture
        POP     HL                              ; STACK: [PC BC DE]
        POP     DE                              ; STACK: [PC BC]
        POP     BC                              ; STACK: [PC]
        RET                                     ; return

iboardExtractLocationData:
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
        SUB     IBOARD_COLUMN
        CALL    iboardDivideCellSide
        LD      E, B
        LD      C, A
        LD      A, D
        SUB     IBOARD_ROW
        CALL    iboardDivideCellSide
        LD      D, B
        LD      B, A
        RET

iboardCheckWall:
        ;; INPUT:
        ;;   D -- pixel-wise row
        ;;   E -- pixel-wise column
        ;;   <iboard data> -- determines wall layout
        ;;
        ;; OUTPUT:
        ;;   <carry flag> -- set iff cell at location is wall
        ;;
        PUSH    BC                        ; STACK: [PC BC]
        PUSH    DE                        ; STACK: [PC BC DE]
        PUSH    HL                        ; STACK: [PC BC DE HL]
        CALL    iboardExtractLocationData  ; get cell and offsets
        CALL    iboardGetCellAddress       ; HL = cell address
        LD      A, (HL)                   ; set carry iff cell is wall
        SUB     IBOARD_CELL_WALL           ;
        SUB     1                         ;
        POP     HL                        ; STACK: [PC BC DE]
        POP     DE                        ; STACK: [PC BC]
        POP     BC                        ; STACK: [PC]
        RET                               ; return

;;;============================================================================
;;; CELL HELPER ROUTINES //////////////////////////////////////////////////////
;;;============================================================================

iboardCountCellValue:
        ;; INPUT:
        ;;   ACC -- cell value to count
        ;;
        ;; OUTPUT:
        ;;   ACC -- number of cells with given value
        ;;
        RET

iboardUpdateSpriteCells:
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
        CALL    iboardGetSpritePointer             ; IX = sprite pointer
        LD      E, (IX+IBOARD_SPRITE_COLUMN)       ; E, D = column, row
        LD      D, (IX+IBOARD_SPRITE_ROW)          ;
        CALL    iboardExtractLocationData          ; E, D = cell-wise location
        DEC     E                                 ; E, D = upper left of square
        DEC     D                                 ;
        PUSH    DE                                ; STACK: [PC BC DE HL IX DE]
        CALL    iboardGetCellLocation              ; D, E = pixel-wise location
        LD      BC, IBOARD_CELL_SIDE * 00303h      ; B, C = pixel-wise size
        CALL    drawClearRectangle                ; clear rectangle under cells
        POP     DE                                ; STACK: [PC BC DE HL IX]
        LD      H, D                              ; (save initial row in H)
        LD      C, 3                              ; C (outer counter) = 3
iboardUpdateSpriteCells_outer:                     ;
        LD      B, 3                              ; B (inner counter) = 3
iboardUpdateSpriteCells_inner:                     ;
        CALL    iboardDrawCell                     ; draw current cell
        INC     D                                 ; advance to next row
        DJNZ    iboardUpdateSpriteCells_inner      ; repeat for each row
        LD      D, H                              ; reset D (row)
        INC     E                                 ; advance to next column
        DEC     C                                 ; repeat for each column
        JR      NZ, iboardUpdateSpriteCells_outer  ;
        POP     IX                                ; STACK: [PC BC DE HL]
        POP     HL                                ; STACK: [PC BC DE
        POP     DE                                ; STACK: [PC BC]
        POP     BC                                ; STACK: [PC]
        RET                                       ; return

iboardIter:
        ;; INPUT:
        ;;   HL -- start of callback to apply to each cell
        ;;
        ;; OUTPUT:
        ;;   <iboard data> -- callback applied to each cell
        ;;
        PUSH    BC                     ; STACK: [PC BC]
        PUSH    DE                     ; STACK: [PC BC DE]
        LD      C, IBOARD_NUM_ROWS      ; C = row counter
        LD      D, 0                   ; D = top row
iboardIter_rowLoop:                     ;
        LD      B, IBOARD_NUM_COLUMNS   ; B = column counter
        LD      E, 0                   ; E = left column
iboardIter_columnLoop:                  ;
        CALL    iboardIter_jumpHL       ; call callback routine
        INC     E                      ; advance to next column
        DJNZ    iboardIter_columnLoop   ; repeat columnLoop for each column
        INC     D                      ; advance to next row
        DEC     C                      ; repeat rowLoop for each row
        JR      NZ, iboardIter_rowLoop  ;
        POP     DE                     ; STACK: [PC BC]
        POP     BC                     ; STACK: [PC]
        RET                            ; return
        ;;
iboardIter_jumpHL:                      ; subroutine to implement `CALL (HL)`
        JP      (HL)                   ;

;;;============================================================================
;;; SPRITE HELPER ROUTINES ////////////////////////////////////////////////////
;;;============================================================================

iboardGetSpriteLocationData:
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
        CALL    iboardGetSpritePointer
        LD      A, (IX+IBOARD_SPRITE_COLUMN)
        SUB     IBOARD_COLUMN
        CALL    iboardDivideCellSide
        LD      E, B
        LD      C, A
        LD      A, (IX+IBOARD_SPRITE_ROW)
        SUB     IBOARD_ROW
        CALL    iboardDivideCellSide
        LD      D, B
        LD      B, A
        POP     IX
        RET

;;;============================================================================
;;; CONSTANTS /////////////////////////////////////////////////////////////////
;;;============================================================================

#define IBOARD_DIRECTION_UP      0
#define IBOARD_DIRECTION_RIGHT   1
#define IBOARD_DIRECTION_DOWN    2
#define IBOARD_DIRECTION_LEFT    3

#define IBOARD_CELL_EMPTY        0
#define IBOARD_CELL_WALL         1
#define IBOARD_CELL_DOT          2
#define IBOARD_CELL_BIG_DOT      3
#define IBOARD_CELL_CHERRY       4
#define IBOARD_CELL_HEART        5

#define IBOARD_CELL_SIDE         6
#define IBOARD_CELL_HEIGHT       IBOARD_CELL_SIDE
#define IBOARD_CELL_WIDTH        IBOARD_CELL_SIDE
#define IBOARD_CELL_DIMENSIONS   IBOARD_CELL_HEIGHT*256+IBOARD_CELL_WIDTH

#define IBOARD_NUM_ROWS          9
#define IBOARD_NUM_COLUMNS       16

#define IBOARD_HEIGHT            IBOARD_CELL_HEIGHT * IBOARD_NUM_ROWS
#define IBOARD_WIDTH             IBOARD_CELL_WIDTH * IBOARD_NUM_COLUMNS
#define IBOARD_DIMENSIONS        IBOARD_HEIGHT * 256 + IBOARD_WIDTH

#define IBOARD_ROW               2
#define IBOARD_COLUMN            0
#define IBOARD_LOCATION          IBOARD_ROW * 256 + IBOARD_COLUMN

#define IBOARD_MAP_SIZE          9 * 2

#define IBOARD_CELL_PICTURE_SIZE IBOARD_CELL_HEIGHT
#define IBOARD_SPRITE_HEIGHT     5

;;;============================================================================
;;; VARIABLE DATA /////////////////////////////////////////////////////////////
;;;============================================================================

#define IBOARD_ARRAY_SIZE        IBOARD_NUM_ROWS * IBOARD_NUM_COLUMNS
#define IBOARD_SPRITE_COUNT_SIZE 1
#define IBOARD_SPRITE_SIZE       1 + 1 + 2
#define IBOARD_SPRITES_SIZE      5 * IBOARD_SPRITE_SIZE

#define IBOARD_SPRITE_COLUMN     0
#define IBOARD_SPRITE_ROW        1
#define IBOARD_SPRITE_PICTURE    2

#define iboardArray              iboardData
#define iboardSpriteCount        iboardData+IBOARD_ARRAY_SIZE
#define iboardSprites            iboardData+IBOARD_ARRAY_SIZE+IBOARD_SPRITE_COUNT_SIZE
#define iboardTouchedCellCount   iboardData+IBOARD_ARRAY_SIZE+IBOARD_SPRITE_COUNT_SIZE+IBOARD_SPRITES_SIZE
#define iboardTouchedCells       iboardData+IBOARD_ARRAY_SIZE+IBOARD_SPRITE_COUNT_SIZE+IBOARD_SPRITES_SIZE+1

#define iboardDataEnd            iboardTouchedCells + (2 * 20)
#define IBOARD_DATA_SIZE         iboardDataEnd - iboardData

;;;============================================================================
;;; IMAGE DATA ////////////////////////////////////////////////////////////////
;;;============================================================================

iboardCellPictures:
        ;;
iboardCellPictureEmpty:
        .db     00000000b
        .db     00000000b
        .db     00000000b
        .db     00000000b
        .db     00000000b
        .db     00000000b
        ;;
iboardCellPictureWallCenter:
        .db     11111000b
        .db     11111000b
        .db     11111000b
        .db     11111000b
        .db     11111000b
        .db     00000000b
        ;;
iboardCellPictureDot:
        .db     00000000b
        .db     01110000b
        .db     01010000b
        .db     01110000b
        .db     00000000b
        .db     00000000b
