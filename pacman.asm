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

;;; #define BOARD_PACMAN_PICTURE_HEIGHT     5

#define boardPacmanStartCell    boardMapBase + 2
#define boardPacmanLocation     boardPacmanStartCell + 2
#define boardPacmanDirection    boardPacmanLocation + 2

boardPacmanPicture:
        .db     01111000b
        .db     11010000b
        .db     11100000b
        .db     11110000b
        .db     01111000b
        .db     00000000b



        ;; boardSetupPacman:
;;         ;; INPUT:
;;         ;;   (boardPacmanStartCell) -- cell-wise location of Pacman's
;;         ;;       starting location
;;         ;;
;;         ;; OUTPUT:
;;         ;;   (boardPacmanLocation) -- initial pixel-wise location of Pacman
;;         ;;   (boardArray) -- dot removed from starting cell
;;         ;;
;;         PUSH    DE                         ; STACK: [PC DE]
;;         PUSH    HL                         ; STACK: [PC DE HL]
;;         LD      DE, (boardPacmanStartCell) ; D, E = Pacman start cell location
;;         CALL    boardGetCellAddress        ; HL = Pacman start cell address
;;         LD      (HL), BOARD_CELL_EMPTY     ; empty this cell
;;         CALL    boardGetCellLocation       ; set Pacman start location
;;         LD      (boardPacmanLocation), DE  ;
;;         POP     HL                         ; STACK: [PC DE]
;;         POP     DE                         ; STACK: [PC]
;;         RET                                ; return


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

