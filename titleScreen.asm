;;;============================================================================
;;; INTERFACE /////////////////////////////////////////////////////////////////
;;;============================================================================

#define TITLE_SCREEN_SELECTION_PLAY             0
#define TITLE_SCREEN_SELECTION_SCORE_BOARD      1
#define TITLE_SCREEN_SELECTION_QUIT             2

titleScreenRun:
        ;; INPUT:
        ;;   <keyboard> -- receives user's selection
        ;;
        ;; OUTPUT;
        ;;   <screen> -- shows menu to user
        ;;   ACC -- user's selection
        ;;
        PUSH    BC                              ; STACK: [PC BC]
        PUSH    DE                              ; STACK: [PC BC DE]
        PUSH    HL                              ; STACK: [PC BC DE HL]
        CALL    drawClearScreen                 ; clear the screen buffer
        LD      DE, TITLE_SCREEN_TITLE_LOCATION ; write the title string
        LD      HL, titleScreen_titleString     ;
        CALL    writeString                     ;
        LD      DE, TITLE_SCREEN_NAME_LOCATION  ; write the name string
        LD      HL, titleScreen_nameString      ;
        CALL    writeString                     ;
        LD      DE, TITLE_SCREEN_YEAR_LOCATION  ; write the year string
        LD      HL, titleScreen_yearString      ;
        CALL    writeString                     ;
        LD      BC, TITLE_SCREEN_OUTER_SIZE     ; draw the outer menu border
        LD      DE, TITLE_SCREEN_OUTER_LOCATION ;
        CALL    drawRectangle                   ;
        LD      BC, TITLE_SCREEN_INNER_SIZE     ; draw the inner menu border
        LD      DE, TITLE_SCREEN_INNER_LOCATION ;
        CALL    drawRectangle                   ;
        LD      DE, TITLE_SCREEN_PLAY_LOCATION  ; write the play string
        LD      HL, titleScreen_playString      ;
        CALL    writeString                     ;
        LD      DE, TITLE_SCREEN_SCORE_LOCATION ; write the score string
        LD      HL, titleScreen_scoreString     ;
        CALL    writeString                     ;
        LD      DE, TITLE_SCREEN_QUIT_LOCATION  ; write the quit string
        LD      HL, titleScreen_quitString      ;
        CALL    writeString                     ;
        CALL    titleScreen_menuRun             ; get user selection from menu
        LD      A, TITLE_SCREEN_SELECTION_PLAY  ; default to PLAY selection
        POP     HL                              ; STACK: [PC BC DE]
        POP     DE                              ; STACK: [PC BC]
        POP     BC                              ; STACK: [PC]
        RET                                     ; return

;;;============================================================================
;;; SETUP AND TEARDOWN ////////////////////////////////////////////////////////
;;;============================================================================

titleScreenInit:
        RET

titleScreenExit:
        RET

;;;============================================================================
;;; CONSTANTS /////////////////////////////////////////////////////////////////
;;;============================================================================

#define TITLE_SCREEN_TITLE_LOCATION     5 * 256 + (5 * 6)
#define TITLE_SCREEN_NAME_LOCATION      47 * 256 + (2 * 6)
#define TITLE_SCREEN_YEAR_LOCATION      54 * 256 + (5 * 6)
#define TITLE_SCREEN_PLAY_LOCATION      19 * 256 + 18
#define TITLE_SCREEN_SCORE_LOCATION     26 * 256 + 18
#define TITLE_SCREEN_QUIT_LOCATION      33 * 256 + 18

#define TITLE_SCREEN_OUTER_SIZE         29 * 256 + 81
#define TITLE_SCREEN_OUTER_LOCATION     14 * 256 + 7
#define TITLE_SCREEN_INNER_SIZE         TITLE_SCREEN_OUTER_SIZE - $0404
#define TITLE_SCREEN_INNER_LOCATION     TITLE_SCREEN_OUTER_LOCATION + $0202

titleScreen_titleString:
        .db     "PACMAN", 0

titleScreen_nameString:
        .db     "ANDREW HENRY", 0

titleScreen_yearString:
        .db     "-2017-", 0

titleScreen_playString:
        .db     "PLAY GAME", 0

titleScreen_scoreString:
        .db     "SCORE BOARD", 0

titleScreen_quitString:
        .db     "QUIT", 0


;;;============================================================================
;;; VARIABLE DATA /////////////////////////////////////////////////////////////
;;;============================================================================

#define TITLESCREEN_DATA_SIZE   0


;;;============================================================================
;;; HELPER ROUTINES ///////////////////////////////////////////////////////////
;;;============================================================================


#define TITLE_SCREEN_CURSOR_SIZE        PACMAN_IMAGE_SIZE
#define TITLE_SCREEN_CURSOR_IMAGE       pacmanImageCherry
#define TITLE_SCREEN_CURSOR_LOCATION    19 * 256 + 12
#define TITLE_SCREEN_CURSOR_STEP        7
#define TITLE_SCREEN_NUM_SELECTIONS     3

titleScreen_menuRun:
        ;; INPUT:
        ;;   <keyboard> -- receives user input
        ;;
        ;; OUTPUT:
        ;;   <screen> -- displays and moves cursor
        ;;
        PUSH    BC
        LD      C, 0
titleScreen_menuRun_keyLoop:
        CALL    titleScreen_menuRun_drawCursor
        CALL    screenUpdate
        CALL    titleScreen_menuRun_eraseCursor
        CALL    keyboardRead
titleScreen_menuRun_keyUp:
        CP      skUp
        JR      NZ, titleScreen_menuRun_keyDown
        LD      A, C
        DEC     C
        OR      A
        JR      NZ, titleScreen_menuRun_keyLoop
        LD      C, TITLE_SCREEN_NUM_SELECTIONS - 1
        JR      titleScreen_menuRun_keyLoop
titleScreen_menuRun_keyDown:
        CP      skDown
        JR      NZ, titleScreen_menuRun_keyEnter
        INC     C
        LD      A, C
        SUB     TITLE_SCREEN_NUM_SELECTIONS
        JR      C, titleScreen_menuRun_keyLoop
        LD      C, A
        JR      titleScreen_menuRun_keyLoop
titleScreen_menuRun_keyEnter:
        CP      skEnter
        JR      NZ, titleScreen_menuRun_keyLoop
        LD      A, C
        POP     BC
        RET
        ;;
titleScreen_menuRun_eraseCursor:
        ;; INPUT:
        ;;   C -- current cursor position (as a menu index)
        ;;
        ;; OUTPUT:
        ;;   <screen buffer> -- cursor image at current position erased
        ;;
        PUSH    BC
        PUSH    DE
        CALL    titleScreen_menuRun_getCursorLocation
        LD      BC, TITLE_SCREEN_CURSOR_SIZE
        CALL    drawClearRectangle
        POP     DE
        POP     BC
        RET
        ;;
titleScreen_menuRun_drawCursor:
        ;; INPUT:
        ;;   C -- current cursor position (as a menu index)
        ;;
        ;; OUTPUT:
        ;;   <screen buffer> -- cursor image drawn at current position
        ;;
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      B, TITLE_SCREEN_CURSOR_SIZE >> 8
        CALL    titleScreen_menuRun_getCursorLocation
        LD      HL, TITLE_SCREEN_CURSOR_IMAGE
        CALL    drawPicture
        POP     HL
        POP     DE
        POP     BC
        RET
        ;;
titleScreen_menuRun_getCursorLocation:
        ;; INPUT:
        ;;   C -- current cursor position (as a menu index)
        ;;
        ;; OUTPUT:
        ;;   D -- pixelwise row of current cursor position
        ;;   E -- pixelwise column of current cursor position
        ;;
        LD      DE, TITLE_SCREEN_CURSOR_LOCATION
        LD      A, C
        ADD     A, A
        ADD     A, A
        ADD     A, A
        SUB     C
        ADD     A, D
        LD      D, A
        RET
