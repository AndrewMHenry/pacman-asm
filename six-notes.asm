sixBlit:
        ;; <set LCD row and column>
sixBlit_loop:
        LD      A, (DE)
        AND     (HL)
        OR      (IX)
        INC     DE
        INC     HL
        INC     IX
        DJNZ    sixBlit_loop
        RET
