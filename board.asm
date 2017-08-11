;;;============================================================================
;;; HIGH-LEVEL INTERFACE DESCRIPTION //////////////////////////////////////////
;;;============================================================================

;;; This library's interface exposes four categories of routines for
;;; interacting with the game board:
;;;
;;;     (1) STAGING.  These routines specify various attributes of
;;;         the board to be used.  For example, a staging routine might
;;;         specify the maze layout of the board.
;;;
;;;     (2) DEPLOYING.  This routine signals to the library that
;;;         all attributes have been staged for the current board and
;;;         prepares the board for gameplay accordingly.
;;;
;;;     (3) MANIPULATING.  These routines effect changes to the board
;;;         corresponding to events that occur during gameplay.  For example,
;;;         a manipulation routine might signal that an item should be
;;;         collected or a portion of the board should be redrawn.
;;;
;;;     (4) UPDATING.  This routine applies any changes effected by the
;;;         manipulation routines and ensures they are reflected by the
;;;         image of the board shown on the LCD.

;;;============================================================================
;;; STAGING INTERFACE /////////////////////////////////////////////////////////
;;;============================================================================

boardStageWallMap:
        ;; INPUT:
        ;;   HL -- base of bitmap specifying board wall cells
        ;;
        ;; OUTPUT:
        ;;   <board data> -- bitmap staged as maze map
        ;;
        LD      (boardMapBase), HL
        RET

;;;============================================================================
;;; DEPLOYING INTERFACE ///////////////////////////////////////////////////////
;;;============================================================================

boardDeploy:
        CALL    boardApplyWallMap
        CALL    boardFillDots
        RET

;;;============================================================================
;;; MANIPULATION INTERFACE ////////////////////////////////////////////////////
;;;============================================================================

boardTouchRectangle:
        RET

;;;============================================================================
;;; UPDATING INTERFACE ////////////////////////////////////////////////////////
;;;============================================================================

boardUpdate:
        ;; INPUTS:
        ;;   <board data> -- current state of board
        ;;
        ;; OUTPUTS:
        ;;   <screen buffer and LCD> -- updated to reflect board contents
        ;;
        PUSH    HL                 ; STACK: [PC HL]
        LD      HL, boardWriteCell ; draw all board cells
        CALL    boardIter          ;
        CALL    screenUpdate       ; flush the cells
        POP     HL                 ; STACK: [PC]
        RET                        ; return

;;;============================================================================
;;; BOARD SETUP INTERFACE /////////////////////////////////////////////////////
;;;============================================================================

;;; Rather than specifying *a priori* a format specifying the various
;;; attributes of the board for a given level, we adopt a two-stage process
;;; for setting up the board:
;;;
;;;     (1) Use the ``boardSet<attribute>`` routines to "stage" various
;;; 	    attributes of the board to be loaded, and then
;;;
;;;     (2) Call the ``boardSetup`` routine to prepare the board for play
;;;         based on the staged attributes.

;;; ATTRIBUTE SETTERS..........................................................

boardSetWallMap:
        ;; INPUT:
        ;;   HL -- base of bitmap specifying board wall cells
        ;;
        ;; OUTPUT:
        ;;   <board data> -- board wall bitmap set to input
        ;;
        LD      (boardMapBase), HL
        RET

boardSetPacmanStartCell:
        ;; INPUT:
        ;;   D -- cell-wise row of start cell
        ;;   E -- cell-wise column of start cell
        ;;
        ;; OUTPUT:
        ;;   <board data> -- Pacman's starting location set to input
        ;;
        LD      (boardPacmanStartCell), DE
        RET

;;; SETUP ROUTINES.............................................................

boardSetup:
        ;; INPUT:
        ;;   <board data> -- staged board attributes
        ;;
        ;; OUTPUT:
        ;;   <board data> -- prepared for play
        ;;
        CALL    boardApplyWallMap
        CALL    boardFillDots
        CALL    boardSetupPacman
        RET

boardApplyWallMap:
        ;; INPUT:
        ;;   (boardMapBase) -- base of wall bitmap
        ;;
        ;; OUTPUT:
        ;;   (boardArray) -- cells specified by bitmap made walls
        ;;
        PUSH    BC                       ; STACK: [PC BC]
        PUSH    DE                       ; STACK: [PC BC DE]
        PUSH    HL                       ; STACK: [PC BC DE HL]
        LD      C, BOARD_MAP_SIZE        ; C = board map counter
        LD      DE, boardArray           ; DE = base of board array
        LD      HL, (boardMapBase)       ; HL = base of wall map
boardSetup_outerLoop:                    ;
        PUSH    HL                       ; STACK: [PC BC DE HL HL]
        LD      B, 8                     ; B = bit counter
        LD      L, (HL)                  ; L = map byte
boardSetup_innerLoop:                    ;
        XOR     A                        ; assume empty
        RLC     L                        ; rotate bit into carry
        ADC     A, 0                     ; make wall if bit was set
        LD      (DE), A                  ; load new cell value
        INC     DE                       ; advance to next board array byte
        DJNZ    boardSetup_innerLoop     ; repeat inner loop until byte done
        POP     HL                       ; STACK: [PC BC DE HL]
        INC     HL                       ; advance to next map byte
        DEC     C                        ; repeat outer loop until map done
        JR      NZ, boardSetup_outerLoop ;
        POP     HL                       ; STACK: [PC BC DE]
        POP     DE                       ; STACK: [PC BC]
        POP     BC                       ; STACK: [PC]
        RET                              ; return

boardFillDots:
        ;; INPUTS:
        ;;   <board data> -- determines where to place dots
        ;;
        ;; OUTPUTS:
        ;;   (boardArray) -- dots placed in eligible positions
        ;;
        PUSH    BC                     ; STACK: [PC BC]
        PUSH    HL                     ; STACK: [PC BC HL]
        LD      B, BOARD_ARRAY_SIZE    ; B = cell counter
        LD      HL, boardArray         ; HL = base of board array
boardFillDots_loop:                    ;
        LD      A, (HL)                ; ACC = cell value
        CP      BOARD_CELL_EMPTY       ; skip if cell non-empty
        JR      NZ, boardFillDots_skip ;
        LD      A, BOARD_CELL_DOT      ; set cell to dot otherwise
        LD      (HL), A                ;
boardFillDots_skip:                    ;
        INC     HL                     ; advance to next cell
        DJNZ    boardFillDots_loop     ; repeat for each cell
        POP     HL                     ; STACK: [PC BC]
        POP     BC                     ; STACK: [PC]
        RET                            ; return

boardSetupPacman:
        ;; INPUT:
        ;;   (boardPacmanStartCell) -- cell-wise location of Pacman's
        ;;       starting location
        ;;
        ;; OUTPUT:
        ;;   (boardPacmanLocation) -- initial pixel-wise location of Pacman
        ;;   (boardArray) -- dot removed from starting cell
        ;;
        PUSH    DE                         ; STACK: [PC DE]
        PUSH    HL                         ; STACK: [PC DE HL]
        LD      DE, (boardPacmanStartCell) ; D, E = Pacman start cell location
        CALL    boardGetCellAddress        ; HL = Pacman start cell address
        LD      (HL), BOARD_CELL_EMPTY     ; empty this cell
        CALL    boardGetCellLocation       ; set Pacman start location
        LD      (boardPacmanLocation), DE  ;
        POP     HL                         ; STACK: [PC DE]
        POP     DE                         ; STACK: [PC]
        RET                                ; return


;; ;;;============================================================================
;; ;;; PACMAN MANIPULATION INTERFACE /////////////////////////////////////////////
;; ;;;============================================================================

;; boardPacmanSetDirection:
;;         ;; INPUT:
;;         ;;   ACC -- new direction for Pacman to begin moving
;;         ;;
;;         ;; OUTPUT:
;;         ;;   (boardPacmanDirection) -- direction stored
;;         ;;
;;         LD      (boardPacmanDirection), A
;;         RET

;; ;;;============================================================================
;; ;;; INTERFACE /////////////////////////////////////////////////////////////////
;; ;;;============================================================================

;; ;;; UPDATE ROUTINE(S)..........................................................

;; boardUpdate:
;;         ;; INPUTS:
;;         ;;   <board data> -- current state of board
;;         ;;
;;         ;; OUTPUTS:
;;         ;;   <screen buffer and LCD> -- updated to reflect board contents
;;         ;;
;;         PUSH    HL                 ; STACK: [PC HL]
;;         LD      HL, boardWriteCell ; draw all board cells
;;         CALL    boardIter          ;
;;         CALL    boardDrawPacman    ; draw Pacman on board
;;         CALL    screenUpdate       ; flush the cells
;;         POP     HL                 ; STACK: [PC]
;;         RET                        ; return

;;;============================================================================
;;; HELPER ROUTINES ///////////////////////////////////////////////////////////
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

boardWriteCell:
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

boardDrawPacman:
        ;; INPUT:
        ;;   (boardPacmanLocation) -- current pixel-wise location of Pacman
        ;;
        ;; OUTPUT:
        ;;   <screen buffer> -- picture of Pacman written
        ;;
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      B, BOARD_PACMAN_PICTURE_HEIGHT
        LD      DE, (boardPacmanLocation)
        CALL    boardGetPacmanPicture
        CALL    drawPicture
        POP     HL
        POP     DE
        POP     BC
        RET

boardGetPacmanPicture:
        LD      HL, boardPacmanPicture
        RET

boardLoad:
        ;; INPUT:
        ;;   HL -- base of array of board cells
        ;;
        ;; OUTPUT:
        ;;   <board data> -- board array populated with cells
        ;;
        PUSH    BC                   ; STACK: [PC BC]
        PUSH    DE                   ; STACK: [PC BC DE]
        PUSH    HL                   ; STACK: [PC BC DE HL]
        LD      BC, BOARD_ARRAY_SIZE ; BC = length of array
        LD      DE, boardArray       ; DE = boardArray location
        LDIR                         ; copy the bytes
        POP     HL                   ; STACK: [PC BC DE]
        POP     DE                   ; STACK: [PC BC]
        POP     BC                   ; STACK: [PC]
        RET                          ; return

;;;============================================================================
;;; CONSTANTS /////////////////////////////////////////////////////////////////
;;;============================================================================

#define BOARD_CELL_EMPTY                0
#define BOARD_CELL_WALL                 1
#define BOARD_CELL_DOT                  2
#define BOARD_CELL_BIG_DOT              3
#define BOARD_CELL_CHERRY               4
#define BOARD_CELL_HEART                5

#define BOARD_CELL_HEIGHT               6
#define BOARD_CELL_WIDTH                6

#define BOARD_NUM_ROWS                  9
#define BOARD_NUM_COLUMNS               16

#define BOARD_ARRAY_SIZE                BOARD_NUM_ROWS * BOARD_NUM_COLUMNS
#define BOARD_MAP_SIZE                  9 * 2

#define BOARD_PACMAN_PICTURE_HEIGHT     5

#define BOARD_CELL_PICTURE_SIZE         BOARD_CELL_HEIGHT

;;;============================================================================
;;; VARIABLE DATA /////////////////////////////////////////////////////////////
;;;============================================================================

#define boardArray              boardData
#define boardMapBase            boardArray + BOARD_ARRAY_SIZE
#define boardPacmanStartCell    boardMapBase + 2
#define boardPacmanLocation     boardPacmanStartCell + 2
#define boardPacmanDirection    boardPacmanLocation + 2

#define boardDataEnd            boardPacmanDirection + 1
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

boardPacmanPicture:
        .db     01111000b
        .db     11010000b
        .db     11100000b
        .db     11110000b
        .db     01111000b
        .db     00000000b

;;;============================================================================
;;; SETUP AND TEARDOWN ////////////////////////////////////////////////////////
;;;============================================================================
        
boardInit:
        RET

boardExit:
        RET
