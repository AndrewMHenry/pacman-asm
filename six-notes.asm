;;; IDEAS

;;; In the future, to maximize game speed, we will probably want to write
;;; some custom LCD code that circumvents the screen buffer.  This is
;;; helpful mostly because so many things on the game screen fit within the
;;; six-pixel-wide partitions corresponding to the 6-bit mode on the LCD.

;;; If cells alone needed updating on the board, this could be a simple matter
;;; of re-implementing boardDrawCell using a very simple routine that writes
;;; the cell picture data directly to the LCD.  However, sprites complicate
;;; the situation, because
;;;
;;;     (1) Any combination of sprites (including no sprites) may intersect
;;;         with a cell that needs to be drawn, so the code that draws a
;;;         cell needs some way of knowing which (if any) sprites touch it,
;;;         and in what way, and
;;;
;;;     (2) The sprites themselves may share footprint cells or even intersect
;;;         pixel-wise, so that sprites cannot simply be drawn in sequence
;;;         (that is, some kind of buffering is still required).
;;;
;;; So far, my best plan treats each cell as a composite of two pictures:
;;; a background (which includes the cell's contents) and a foreground
;;; (which includes contributions from any sprites).  Given the background
;;; and foreground pictures, the gist of the actual cell-drawing logic
;;; is conveyed by sixBlit below.  The more complicated part is determining
;;; the background and foreground pictures.
;;;
;;; Determining the background picture can still be done in largely the same
;;; way.  However, determining the foreground picture is more complicated
;;; because there are so many more possibilities (due to the arbitrary
;;; positions of and intersections between the sprites).  This makes storing
;;; an index into an array of possible foreground images impractical.
;;; Therefore, we need to construct the foreground in some way.

;;; One way to arrange the cell is
;;;
;;;     fffffvvv
;;;
;;; where the f bits specify an index into an array of dynamically-constructed
;;; foreground images, and the v bits specify the cell contents as before.


;;;     for sprite in sprites:
;;;         move sprite; determine affected cells
;;;         for cell in affected cells:
;;;             get cell address
;;;             if cell does NOT have foreground
;;;                 assign it a blank new foreground
;;;             determine foreground contribution to cell of sprite
;;;             apply foreground contribution to cell's foreground
;;;             touch the cell

;;;     for cell in touched cells:
;;;         get cell address
;;;         get background from v bits
;;;         get foreground index from f bits
;;;         get foreground picture from foreground index
sixBlit:
        ;; <set LCD row and column>
sixBlit_loop:
        LD      A, (DE)
        AND     (HL)
        INC     DE
        INC     HL
        ;; <wait for LCD>
        OUT     (011h), A
        DJNZ    sixBlit_loop
        RET
