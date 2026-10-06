      *================================================================
      * PROGRAM-ID : MATCHENG
      * SYSTEM     : EXCHANGE ORDER MATCHING - NIGHTLY BATCH
      * FUNCTION   : READS ORDER FILE, VALIDATES, MATCHES AGAINST THE
      *              ORDER BOOK, WRITES TRADES / REJECTS / BOOK / RPT
      *
      * CHANGE LOG
      * DATE     BY   CR       DESCRIPTION
      * -------- ---- -------- ------------------------------------
      * 94-02-11 RH   INITIAL  ORIGINAL VERSION
      * 95-08-30 RH   CR-0211  ADDED MARKET ORDERS
      * 97-03-14 JKT  CR-0305  ADDED DYNX, EVRG TO INSTR MASTER
      * 98-11-02 JKT  CR-0388  PRICE BAND CHECK +/- 10 PCT
      * 99-06-21 MPD  CR-0412  PRO-RATA ALLOC DISABLED (SEE 6000)
      * 99-12-08 MPD  Y2K-017  TIMESTAMP FIELD EXPANDED TO X(26)
      * 01-04-17 SLW  CR-0533  TICK SIZE .05 FOR PRICES >= 100
      * 03-09-05 SLW  CR-0601  BOOK SIZE RAISED 2000 -> 5000
      * 03-09-05 SLW  CR-0601  CANCEL BY ORDER ID
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MATCHENG.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ORDERS-FILE ASSIGN TO 'ORDIN'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-ORD.
           SELECT TRADES-FILE ASSIGN TO 'TRDOUT'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-TRD.
           SELECT REJECT-FILE ASSIGN TO 'REJOUT'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-REJ.
           SELECT BOOK-FILE ASSIGN TO 'BOOKOUT'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-BOOK.
           SELECT REPORT-FILE ASSIGN TO 'RPTOUT'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-RPT.
           SELECT AUDIT-FILE ASSIGN TO 'AUDOUT'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-AUD.

       DATA DIVISION.
       FILE SECTION.
       FD  ORDERS-FILE.
           COPY ORDREC.

       FD  TRADES-FILE.
           COPY TRDREC.

       FD  REJECT-FILE.
       01  REJ-REC.
           05  REJ-SEQ                 PIC 9(09).
           05  REJ-ORD-ID              PIC X(12).
           05  REJ-CODE                PIC X(03).
           05  REJ-TEXT                PIC X(40).
           05  REJ-TS                  PIC X(26).

       FD  BOOK-FILE.
       01  BK-REC.
           05  BK-INSTR                PIC X(08).
           05  BK-SIDE                 PIC X(01).
           05  BK-PRICE                PIC 9(07)V99.
           05  BK-QTY                  PIC 9(09).
           05  BK-ORD-ID               PIC X(12).
           05  BK-PART                 PIC X(08).
           05  BK-SEQ                  PIC 9(09).

       FD  REPORT-FILE.
       01  RPT-LINE                    PIC X(100).

       FD  AUDIT-FILE.
       01  AUD-LINE                    PIC X(132).

       WORKING-STORAGE SECTION.
           COPY WSCONST.

       01  WS-FILE-STATUS.
           05  WS-FS-ORD               PIC X(02).
           05  WS-FS-TRD               PIC X(02).
           05  WS-FS-REJ               PIC X(02).
           05  WS-FS-BOOK              PIC X(02).
           05  WS-FS-RPT               PIC X(02).
           05  WS-FS-AUD               PIC X(02).

       01  WS-SWITCHES.
           05  WS-REJ-SW               PIC X(01) VALUE 'N'.
           05  WS-FLAG-OLD-RULE        PIC X(01) VALUE 'N'.

       01  WS-COUNTERS.
           05  WS-CNT-READ             PIC 9(09) VALUE 0.
           05  WS-CNT-ACCEPT           PIC 9(09) VALUE 0.
           05  WS-CNT-CANCEL           PIC 9(09) VALUE 0.
           05  WS-CNT-REJECT           PIC 9(09) VALUE 0.
           05  WS-CNT-RESTED           PIC 9(09) VALUE 0.
           05  WS-CNT-MKTCXL           PIC 9(09) VALUE 0.
           05  WS-SEQ                  PIC 9(09) VALUE 0.
           05  WS-TRD-ID               PIC 9(10) VALUE 0.

      * GENERAL WORK FIELDS - USED BY ALL PARAGRAPHS
       01  WS-WORK.
           05  WS-I                    PIC S9(05) COMP VALUE 0.
           05  WS-J                    PIC S9(05) COMP VALUE 0.
           05  WS-N                    PIC S9(05) COMP VALUE 0.
           05  WS-POS                  PIC S9(05) COMP VALUE 0.
           05  WS-IX                   PIC S9(05) COMP VALUE 0.
           05  WS-OWN                  PIC S9(05) COMP VALUE 0.
           05  WS-OPP                  PIC S9(05) COMP VALUE 0.
           05  WS-SD                   PIC S9(05) COMP VALUE 0.
           05  WS-REM-QTY              PIC 9(09) VALUE 0.
           05  WS-FILL-QTY             PIC 9(09) VALUE 0.
           05  WS-FILL-PX              PIC 9(07)V99 VALUE 0.
           05  WS-BAND-LO              PIC 9(07)V99 VALUE 0.
           05  WS-BAND-HI              PIC 9(07)V99 VALUE 0.
           05  WS-PX-CENTS             PIC 9(09) VALUE 0.
           05  WS-TICK-Q               PIC 9(09) VALUE 0.
           05  WS-TICK-R               PIC 9(09) VALUE 0.
           05  WS-NOTIONAL             PIC 9(13)V99 VALUE 0.
           05  WS-REJ-CODE             PIC X(03) VALUE SPACES.
           05  WS-REJ-TEXT             PIC X(40) VALUE SPACES.
           05  WS-RUN-DATE             PIC 9(08) VALUE 0.

       01  WS-LAST-PX-TABLE.
           05  WS-LAST-PX              PIC 9(07)V99 OCCURS 5 TIMES.

       01  WS-STATS.
           05  WS-ST-ENTRY OCCURS 5 TIMES.
               10  WS-ST-TRADES        PIC 9(09).
               10  WS-ST-VOLUME        PIC 9(12).
               10  WS-ST-NOTIONAL      PIC 9(15)V99.

      * ORDER BOOK - SIDE 1 = BUY (BIDS)  SIDE 2 = SELL (ASKS)
      * ENTRIES KEPT SORTED: BEST PRICE FIRST, THEN ARRIVAL SEQUENCE
       01  WS-BOOK.
           05  WS-BK-INSTR OCCURS 5 TIMES.
               10  WS-BK-SIDE OCCURS 2 TIMES.
                   15  WS-BK-COUNT     PIC S9(05) COMP.
                   15  WS-BK-ENTRY OCCURS 5000 TIMES.
                       20  WS-BK-ORD-ID    PIC X(12).
                       20  WS-BK-PART      PIC X(08).
                       20  WS-BK-PRICE     PIC 9(07)V99.
                       20  WS-BK-QTY       PIC 9(09).
                       20  WS-BK-SEQ       PIC 9(09).

       01  WS-AUD-REC.
           05  WS-AUD-SEQ              PIC 9(09).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-AUD-EVENT            PIC X(08).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-AUD-ORD-ID           PIC X(12).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-AUD-INSTR            PIC X(08).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-AUD-SIDE             PIC X(01).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-AUD-PX               PIC Z(06)9.99.
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-AUD-QTY              PIC Z(08)9.
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-AUD-REF              PIC X(12).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-AUD-TEXT             PIC X(40).

       01  WS-RPT-HDR1.
           05  FILLER                  PIC X(40)
               VALUE 'MATCHENG - DAILY MATCHING SUMMARY REPORT'.
           05  FILLER                  PIC X(20) VALUE SPACES.
           05  FILLER                  PIC X(10) VALUE 'RUN DATE: '.
           05  WS-RH-DATE              PIC 9999/99/99.
       01  WS-RPT-RULE.
           05  FILLER                  PIC X(80) VALUE ALL '-'.
       01  WS-RPT-HDR2.
           05  FILLER                  PIC X(40)
               VALUE 'INSTR     TRADES          VOLUME        '.
           05  FILLER                  PIC X(40)
               VALUE '   NOTIONAL      LAST PX  BIDS  ASKS    '.
       01  WS-RPT-DTL.
           05  WS-RD-INSTR             PIC X(08).
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-RD-TRADES            PIC ZZZ,ZZ9.
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-RD-VOLUME            PIC ZZZ,ZZZ,ZZZ,ZZ9.
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-RD-NOTIONAL          PIC ZZZ,ZZZ,ZZZ,ZZ9.99.
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-RD-LASTPX            PIC Z,ZZZ,ZZ9.99.
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-RD-BIDS              PIC ZZZZ9.
           05  FILLER                  PIC X(01) VALUE SPACE.
           05  WS-RD-ASKS              PIC ZZZZ9.
       01  WS-RPT-TOT.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  WS-RT-LABEL             PIC X(24).
           05  WS-RT-VALUE             PIC ZZZ,ZZZ,ZZ9.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT THRU 1000-EXIT.

       0100-READ-LOOP.
           READ ORDERS-FILE
               AT END GO TO 0900-EOJ.
           ADD 1 TO WS-CNT-READ.
           ADD 1 TO WS-SEQ.
           MOVE 'N' TO WS-REJ-SW.
           PERFORM 2000-VALIDATE THRU 2000-EXIT.
           IF WS-REJ-SW = 'Y'
               PERFORM 8000-WRITE-REJECT THRU 8000-EXIT
               GO TO 0100-READ-LOOP.
           IF ORD-IS-CANCEL
               PERFORM 4000-CANCEL THRU 4000-EXIT
               GO TO 0100-READ-LOOP.
           ADD 1 TO WS-CNT-ACCEPT.
           PERFORM 3000-MATCH THRU 3000-EXIT.
           GO TO 0100-READ-LOOP.

       0900-EOJ.
           PERFORM 9000-EOJ THRU 9000-EXIT.
           STOP RUN.

      *----------------------------------------------------------------
      * 1000 - OPEN FILES, LOAD REFERENCE PRICES, CLEAR BOOK
      *----------------------------------------------------------------
       1000-INIT.
           OPEN INPUT ORDERS-FILE.
           IF WS-FS-ORD NOT = '00'
               DISPLAY 'MATCHENG - OPEN FAILED ORDIN  FS=' WS-FS-ORD
               MOVE 16 TO RETURN-CODE
               STOP RUN.
           OPEN OUTPUT TRADES-FILE REJECT-FILE BOOK-FILE
                       REPORT-FILE AUDIT-FILE.
           IF WS-FS-TRD NOT = '00' OR WS-FS-REJ NOT = '00'
              OR WS-FS-BOOK NOT = '00' OR WS-FS-RPT NOT = '00'
              OR WS-FS-AUD NOT = '00'
               DISPLAY 'MATCHENG - OPEN FAILED ON OUTPUT FILES'
               MOVE 16 TO RETURN-CODE
               STOP RUN.
           ACCEPT WS-RUN-DATE FROM DATE YYYYMMDD.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-MAX-INSTR
               MOVE WS-INSTR-REFPX (WS-I) TO WS-LAST-PX (WS-I)
               MOVE 0 TO WS-ST-TRADES (WS-I)
               MOVE 0 TO WS-ST-VOLUME (WS-I)
               MOVE 0 TO WS-ST-NOTIONAL (WS-I)
               MOVE 0 TO WS-BK-COUNT (WS-I, 1)
               MOVE 0 TO WS-BK-COUNT (WS-I, 2)
           END-PERFORM.
       1000-EXIT.
           EXIT.

      *----------------------------------------------------------------
      * 2000 - VALIDATE INPUT RECORD.  FIRST FAILING CHECK WINS.
      *----------------------------------------------------------------
       2000-VALIDATE.
           IF NOT ORD-IS-NEW AND NOT ORD-IS-CANCEL
               MOVE 'R01' TO WS-REJ-CODE
               MOVE 'INVALID ACTION CODE' TO WS-REJ-TEXT
               GO TO 2000-REJECT.
           IF ORD-ID = SPACES
               MOVE 'R02' TO WS-REJ-CODE
               MOVE 'MISSING ORDER ID' TO WS-REJ-TEXT
               GO TO 2000-REJECT.
           MOVE 0 TO WS-IX.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-MAX-INSTR
               IF WS-INSTR-CODE (WS-I) = ORD-INSTR
                   MOVE WS-I TO WS-IX
               END-IF
           END-PERFORM.
           IF WS-IX = 0
               MOVE 'R03' TO WS-REJ-CODE
               MOVE 'UNKNOWN INSTRUMENT' TO WS-REJ-TEXT
               GO TO 2000-REJECT.
           IF ORD-IS-CANCEL
               GO TO 2000-EXIT.
           IF NOT ORD-BUY AND NOT ORD-SELL
               MOVE 'R04' TO WS-REJ-CODE
               MOVE 'INVALID SIDE' TO WS-REJ-TEXT
               GO TO 2000-REJECT.
           IF NOT ORD-LIMIT AND NOT ORD-MARKET
               MOVE 'R05' TO WS-REJ-CODE
               MOVE 'INVALID ORDER TYPE' TO WS-REJ-TEXT
               GO TO 2000-REJECT.
           IF ORD-QTY IS NOT NUMERIC
               MOVE 'R06' TO WS-REJ-CODE
               MOVE 'INVALID QUANTITY' TO WS-REJ-TEXT
               GO TO 2000-REJECT.
           IF ORD-QTY = 0
               MOVE 'R06' TO WS-REJ-CODE
               MOVE 'INVALID QUANTITY' TO WS-REJ-TEXT
               GO TO 2000-REJECT.
           IF ORD-QTY > 1000000
               MOVE 'R07' TO WS-REJ-CODE
               MOVE 'QUANTITY EXCEEDS MAXIMUM' TO WS-REJ-TEXT
               GO TO 2000-REJECT.
           IF ORD-MARKET
               GO TO 2000-EXIT.
           IF ORD-PRICE IS NOT NUMERIC
               MOVE 'R08' TO WS-REJ-CODE
               MOVE 'INVALID PRICE' TO WS-REJ-TEXT
               GO TO 2000-REJECT.
           IF ORD-PRICE = 0
               MOVE 'R08' TO WS-REJ-CODE
               MOVE 'INVALID PRICE' TO WS-REJ-TEXT
               GO TO 2000-REJECT.
      * CR-0533 TICK .05 AT OR ABOVE 100.00
           IF ORD-PRICE NOT < 100.00
               COMPUTE WS-PX-CENTS = ORD-PRICE * 100
               DIVIDE WS-PX-CENTS BY 5 GIVING WS-TICK-Q
                   REMAINDER WS-TICK-R
               IF WS-TICK-R NOT = 0
                   MOVE 'R09' TO WS-REJ-CODE
                   MOVE 'PRICE NOT ON TICK' TO WS-REJ-TEXT
                   GO TO 2000-REJECT
               END-IF
           END-IF.
      * CR-0388 PRICE BAND +/- 10 PCT OF LAST TRADE
           COMPUTE WS-BAND-LO = WS-LAST-PX (WS-IX) * 0.90.
           COMPUTE WS-BAND-HI = WS-LAST-PX (WS-IX) * 1.10.
           IF ORD-PRICE < WS-BAND-LO OR ORD-PRICE > WS-BAND-HI
               MOVE 'R10' TO WS-REJ-CODE
               MOVE 'PRICE OUTSIDE BAND' TO WS-REJ-TEXT
               GO TO 2000-REJECT.
           GO TO 2000-EXIT.
       2000-REJECT.
           MOVE 'Y' TO WS-REJ-SW.
       2000-EXIT.
           EXIT.

      *----------------------------------------------------------------
      * 3000 - MATCH INCOMING ORDER AGAINST OPPOSITE SIDE
      *----------------------------------------------------------------
       3000-MATCH.
           MOVE ORD-QTY TO WS-REM-QTY.
           IF ORD-BUY
               MOVE 1 TO WS-OWN
               MOVE 2 TO WS-OPP
           ELSE
               MOVE 2 TO WS-OWN
               MOVE 1 TO WS-OPP
           END-IF.
       3100-MATCH-LOOP.
           IF WS-REM-QTY = 0
               GO TO 3800-DONE.
           IF WS-BK-COUNT (WS-IX, WS-OPP) = 0
               GO TO 3700-NO-MORE.
           IF ORD-LIMIT
               IF ORD-BUY
                  AND WS-BK-PRICE (WS-IX, WS-OPP, 1) > ORD-PRICE
                   GO TO 3700-NO-MORE
               END-IF
               IF ORD-SELL
                  AND WS-BK-PRICE (WS-IX, WS-OPP, 1) < ORD-PRICE
                   GO TO 3700-NO-MORE
               END-IF
           END-IF.
           IF WS-BK-QTY (WS-IX, WS-OPP, 1) < WS-REM-QTY
               MOVE WS-BK-QTY (WS-IX, WS-OPP, 1) TO WS-FILL-QTY
           ELSE
               MOVE WS-REM-QTY TO WS-FILL-QTY
           END-IF.
           MOVE WS-BK-PRICE (WS-IX, WS-OPP, 1) TO WS-FILL-PX.
           PERFORM 7000-WRITE-TRADE THRU 7000-EXIT.
           SUBTRACT WS-FILL-QTY FROM WS-REM-QTY.
           SUBTRACT WS-FILL-QTY FROM WS-BK-QTY (WS-IX, WS-OPP, 1).
           MOVE WS-FILL-PX TO WS-LAST-PX (WS-IX).
           IF WS-BK-QTY (WS-IX, WS-OPP, 1) = 0
               MOVE WS-OPP TO WS-SD
               MOVE 1 TO WS-POS
               PERFORM 5500-REMOVE-ENTRY THRU 5500-EXIT
           END-IF.
           GO TO 3100-MATCH-LOOP.
       3700-NO-MORE.
           IF ORD-MARKET
               ADD 1 TO WS-CNT-MKTCXL
               MOVE SPACES TO WS-AUD-REC
               MOVE 'MKTCXL' TO WS-AUD-EVENT
               MOVE WS-REM-QTY TO WS-AUD-QTY
               MOVE 'MARKET REMAINDER CANCELLED' TO WS-AUD-TEXT
               PERFORM 8500-WRITE-AUDIT THRU 8500-EXIT
               GO TO 3800-DONE.
           PERFORM 5000-INSERT-ENTRY THRU 5000-EXIT.
       3800-DONE.
       3000-EXIT.
           EXIT.

      *----------------------------------------------------------------
      * 4000 - CANCEL A RESTING ORDER BY ORDER ID
      *----------------------------------------------------------------
       4000-CANCEL.
           MOVE 1 TO WS-SD.
       4010-SCAN-SIDE.
           MOVE 1 TO WS-I.
       4020-SCAN-ENTRY.
           IF WS-I > WS-BK-COUNT (WS-IX, WS-SD)
               GO TO 4030-NEXT-SIDE.
           IF WS-BK-ORD-ID (WS-IX, WS-SD, WS-I) = ORD-ID
               GO TO 4050-FOUND.
           ADD 1 TO WS-I.
           GO TO 4020-SCAN-ENTRY.
       4030-NEXT-SIDE.
           ADD 1 TO WS-SD.
           IF WS-SD NOT > 2
               GO TO 4010-SCAN-SIDE.
           MOVE 'R11' TO WS-REJ-CODE.
           MOVE 'CANCEL - ORDER NOT IN BOOK' TO WS-REJ-TEXT.
           PERFORM 8000-WRITE-REJECT THRU 8000-EXIT.
           GO TO 4000-EXIT.
       4050-FOUND.
           MOVE SPACES TO WS-AUD-REC.
           MOVE 'CANCEL' TO WS-AUD-EVENT.
           MOVE WS-BK-PRICE (WS-IX, WS-SD, WS-I) TO WS-AUD-PX.
           MOVE WS-BK-QTY (WS-IX, WS-SD, WS-I) TO WS-AUD-QTY.
           PERFORM 8500-WRITE-AUDIT THRU 8500-EXIT.
           MOVE WS-I TO WS-POS.
           PERFORM 5500-REMOVE-ENTRY THRU 5500-EXIT.
           ADD 1 TO WS-CNT-CANCEL.
       4000-EXIT.
           EXIT.

      *----------------------------------------------------------------
      * 5000 - INSERT REMAINDER INTO OWN SIDE OF BOOK (SORTED)
      *----------------------------------------------------------------
       5000-INSERT-ENTRY.
           IF WS-BK-COUNT (WS-IX, WS-OWN) NOT < 5000
               MOVE 'R12' TO WS-REJ-CODE
               MOVE 'BOOK FULL - REMAINDER CANCELLED' TO WS-REJ-TEXT
               PERFORM 8000-WRITE-REJECT THRU 8000-EXIT
               GO TO 5000-EXIT.
           MOVE WS-BK-COUNT (WS-IX, WS-OWN) TO WS-N.
           COMPUTE WS-POS = WS-N + 1.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
               IF WS-OWN = 1
                   IF WS-BK-PRICE (WS-IX, 1, WS-I) < ORD-PRICE
                       MOVE WS-I TO WS-POS
                       MOVE WS-N TO WS-I
                   END-IF
               ELSE
                   IF WS-BK-PRICE (WS-IX, 2, WS-I) > ORD-PRICE
                       MOVE WS-I TO WS-POS
                       MOVE WS-N TO WS-I
                   END-IF
               END-IF
           END-PERFORM.
           PERFORM VARYING WS-J FROM WS-N BY -1 UNTIL WS-J < WS-POS
               MOVE WS-BK-ENTRY (WS-IX, WS-OWN, WS-J)
                 TO WS-BK-ENTRY (WS-IX, WS-OWN, WS-J + 1)
           END-PERFORM.
           MOVE ORD-ID      TO WS-BK-ORD-ID (WS-IX, WS-OWN, WS-POS).
           MOVE ORD-PART-ID TO WS-BK-PART   (WS-IX, WS-OWN, WS-POS).
           MOVE ORD-PRICE   TO WS-BK-PRICE  (WS-IX, WS-OWN, WS-POS).
           MOVE WS-REM-QTY  TO WS-BK-QTY    (WS-IX, WS-OWN, WS-POS).
           MOVE WS-SEQ      TO WS-BK-SEQ    (WS-IX, WS-OWN, WS-POS).
           ADD 1 TO WS-BK-COUNT (WS-IX, WS-OWN).
           ADD 1 TO WS-CNT-RESTED.
           MOVE SPACES TO WS-AUD-REC.
           MOVE 'REST' TO WS-AUD-EVENT.
           MOVE ORD-PRICE TO WS-AUD-PX.
           MOVE WS-REM-QTY TO WS-AUD-QTY.
           PERFORM 8500-WRITE-AUDIT THRU 8500-EXIT.
       5000-EXIT.
           EXIT.

      *----------------------------------------------------------------
      * 5500 - REMOVE ENTRY WS-POS FROM SIDE WS-SD (SHIFT UP)
      *----------------------------------------------------------------
       5500-REMOVE-ENTRY.
           MOVE WS-BK-COUNT (WS-IX, WS-SD) TO WS-N.
           PERFORM VARYING WS-J FROM WS-POS BY 1 UNTIL WS-J >= WS-N
               MOVE WS-BK-ENTRY (WS-IX, WS-SD, WS-J + 1)
                 TO WS-BK-ENTRY (WS-IX, WS-SD, WS-J)
           END-PERFORM.
           SUBTRACT 1 FROM WS-BK-COUNT (WS-IX, WS-SD).
       5500-EXIT.
           EXIT.

      *----------------------------------------------------------------
      * 6000 - PRO-RATA ALLOCATION.  DISABLED 99-06 BY CR-0412.
      *        DO NOT REMOVE - AUDIT MAY ASK FOR IT BACK.  -MPD
      *----------------------------------------------------------------
       6000-OLD-ALLOC-RULE.
           IF WS-FLAG-OLD-RULE = 'Y'
               COMPUTE WS-FILL-QTY = WS-REM-QTY / 2
               IF WS-FILL-QTY < 100
                   MOVE WS-REM-QTY TO WS-FILL-QTY
               END-IF
           END-IF.
       6000-EXIT.
           EXIT.

      *----------------------------------------------------------------
      * 7000 - WRITE TRADE RECORD AND UPDATE STATISTICS
      *----------------------------------------------------------------
       7000-WRITE-TRADE.
           ADD 1 TO WS-TRD-ID.
           MOVE SPACES TO TRD-REC.
           MOVE WS-TRD-ID   TO TRD-ID.
           MOVE ORD-INSTR   TO TRD-INSTR.
           MOVE WS-FILL-PX  TO TRD-PRICE.
           MOVE WS-FILL-QTY TO TRD-QTY.
           MOVE ORD-SIDE    TO TRD-AGGR-SIDE.
           MOVE ORD-TS      TO TRD-TS.
           IF ORD-BUY
               MOVE ORD-ID      TO TRD-BUY-ID
               MOVE ORD-PART-ID TO TRD-BUY-PART
               MOVE WS-BK-ORD-ID (WS-IX, WS-OPP, 1) TO TRD-SELL-ID
               MOVE WS-BK-PART (WS-IX, WS-OPP, 1)   TO TRD-SELL-PART
           ELSE
               MOVE ORD-ID      TO TRD-SELL-ID
               MOVE ORD-PART-ID TO TRD-SELL-PART
               MOVE WS-BK-ORD-ID (WS-IX, WS-OPP, 1) TO TRD-BUY-ID
               MOVE WS-BK-PART (WS-IX, WS-OPP, 1)   TO TRD-BUY-PART
           END-IF.
           WRITE TRD-REC.
           COMPUTE WS-NOTIONAL = WS-FILL-PX * WS-FILL-QTY.
           ADD 1 TO WS-ST-TRADES (WS-IX).
           ADD WS-FILL-QTY TO WS-ST-VOLUME (WS-IX).
           ADD WS-NOTIONAL TO WS-ST-NOTIONAL (WS-IX).
           MOVE SPACES TO WS-AUD-REC.
           MOVE 'TRADE' TO WS-AUD-EVENT.
           MOVE WS-FILL-PX TO WS-AUD-PX.
           MOVE WS-FILL-QTY TO WS-AUD-QTY.
           MOVE WS-BK-ORD-ID (WS-IX, WS-OPP, 1) TO WS-AUD-REF.
           PERFORM 8500-WRITE-AUDIT THRU 8500-EXIT.
       7000-EXIT.
           EXIT.

      *----------------------------------------------------------------
      * 8000 - WRITE REJECT RECORD
      *----------------------------------------------------------------
       8000-WRITE-REJECT.
           MOVE SPACES TO REJ-REC.
           MOVE WS-SEQ      TO REJ-SEQ.
           MOVE ORD-ID      TO REJ-ORD-ID.
           MOVE WS-REJ-CODE TO REJ-CODE.
           MOVE WS-REJ-TEXT TO REJ-TEXT.
           MOVE ORD-TS      TO REJ-TS.
           WRITE REJ-REC.
           ADD 1 TO WS-CNT-REJECT.
           MOVE SPACES TO WS-AUD-REC.
           MOVE 'REJECT' TO WS-AUD-EVENT.
           MOVE WS-REJ-CODE TO WS-AUD-REF.
           MOVE WS-REJ-TEXT TO WS-AUD-TEXT.
           PERFORM 8500-WRITE-AUDIT THRU 8500-EXIT.
       8000-EXIT.
           EXIT.

      *----------------------------------------------------------------
      * 8500 - WRITE AUDIT LINE (CALLER FILLS EVENT FIELDS)
      *----------------------------------------------------------------
       8500-WRITE-AUDIT.
           MOVE WS-SEQ    TO WS-AUD-SEQ.
           MOVE ORD-ID    TO WS-AUD-ORD-ID.
           MOVE ORD-INSTR TO WS-AUD-INSTR.
           MOVE ORD-SIDE  TO WS-AUD-SIDE.
           WRITE AUD-LINE FROM WS-AUD-REC.
       8500-EXIT.
           EXIT.

      *----------------------------------------------------------------
      * 9000 - END OF JOB: BOOK DUMP, REPORT, CLOSE
      *----------------------------------------------------------------
       9000-EOJ.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-MAX-INSTR
             PERFORM VARYING WS-SD FROM 1 BY 1 UNTIL WS-SD > 2
               PERFORM VARYING WS-J FROM 1 BY 1
                   UNTIL WS-J > WS-BK-COUNT (WS-I, WS-SD)
                   MOVE WS-INSTR-CODE (WS-I) TO BK-INSTR
                   IF WS-SD = 1
                       MOVE 'B' TO BK-SIDE
                   ELSE
                       MOVE 'S' TO BK-SIDE
                   END-IF
                   MOVE WS-BK-PRICE (WS-I, WS-SD, WS-J)  TO BK-PRICE
                   MOVE WS-BK-QTY (WS-I, WS-SD, WS-J)    TO BK-QTY
                   MOVE WS-BK-ORD-ID (WS-I, WS-SD, WS-J) TO BK-ORD-ID
                   MOVE WS-BK-PART (WS-I, WS-SD, WS-J)   TO BK-PART
                   MOVE WS-BK-SEQ (WS-I, WS-SD, WS-J)    TO BK-SEQ
                   WRITE BK-REC
               END-PERFORM
             END-PERFORM
           END-PERFORM.

           MOVE WS-RUN-DATE TO WS-RH-DATE.
           WRITE RPT-LINE FROM WS-RPT-HDR1.
           WRITE RPT-LINE FROM WS-RPT-RULE.
           WRITE RPT-LINE FROM WS-RPT-HDR2.
           WRITE RPT-LINE FROM WS-RPT-RULE.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-MAX-INSTR
               MOVE WS-INSTR-CODE (WS-I)  TO WS-RD-INSTR
               MOVE WS-ST-TRADES (WS-I)   TO WS-RD-TRADES
               MOVE WS-ST-VOLUME (WS-I)   TO WS-RD-VOLUME
               MOVE WS-ST-NOTIONAL (WS-I) TO WS-RD-NOTIONAL
               MOVE WS-LAST-PX (WS-I)     TO WS-RD-LASTPX
               MOVE WS-BK-COUNT (WS-I, 1) TO WS-RD-BIDS
               MOVE WS-BK-COUNT (WS-I, 2) TO WS-RD-ASKS
               WRITE RPT-LINE FROM WS-RPT-DTL
           END-PERFORM.
           WRITE RPT-LINE FROM WS-RPT-RULE.
           MOVE 'CONTROL TOTALS' TO RPT-LINE.
           WRITE RPT-LINE.
           MOVE 'RECORDS READ ..........' TO WS-RT-LABEL.
           MOVE WS-CNT-READ TO WS-RT-VALUE.
           WRITE RPT-LINE FROM WS-RPT-TOT.
           MOVE 'ORDERS ACCEPTED .......' TO WS-RT-LABEL.
           MOVE WS-CNT-ACCEPT TO WS-RT-VALUE.
           WRITE RPT-LINE FROM WS-RPT-TOT.
           MOVE 'CANCELS PROCESSED .....' TO WS-RT-LABEL.
           MOVE WS-CNT-CANCEL TO WS-RT-VALUE.
           WRITE RPT-LINE FROM WS-RPT-TOT.
           MOVE 'RECORDS REJECTED ......' TO WS-RT-LABEL.
           MOVE WS-CNT-REJECT TO WS-RT-VALUE.
           WRITE RPT-LINE FROM WS-RPT-TOT.
           MOVE 'ORDERS RESTED .........' TO WS-RT-LABEL.
           MOVE WS-CNT-RESTED TO WS-RT-VALUE.
           WRITE RPT-LINE FROM WS-RPT-TOT.
           MOVE 'MKT REMAINDERS CXL ....' TO WS-RT-LABEL.
           MOVE WS-CNT-MKTCXL TO WS-RT-VALUE.
           WRITE RPT-LINE FROM WS-RPT-TOT.
           MOVE 'TRADES WRITTEN ........' TO WS-RT-LABEL.
           MOVE WS-TRD-ID TO WS-RT-VALUE.
           WRITE RPT-LINE FROM WS-RPT-TOT.

           CLOSE ORDERS-FILE TRADES-FILE REJECT-FILE BOOK-FILE
                 REPORT-FILE AUDIT-FILE.

           DISPLAY 'MATCHENG - RECORDS READ     ' WS-CNT-READ.
           DISPLAY 'MATCHENG - RECORDS REJECTED ' WS-CNT-REJECT.
           DISPLAY 'MATCHENG - TRADES WRITTEN   ' WS-TRD-ID.
           IF WS-CNT-REJECT > 0
               MOVE 4 TO RETURN-CODE
           ELSE
               MOVE 0 TO RETURN-CODE
           END-IF.
       9000-EXIT.
           EXIT.
