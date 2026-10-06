      *----------------------------------------------------------------
      * ORDREC   - ORDER INPUT RECORD                     LRECL=080
      *            SHARED BY MATCHENG, ORDLOAD, EODRPT (DO NOT CHANGE
      *            WITHOUT CHECKING ALL PROGRAMS - SEE CR-0388)
      *----------------------------------------------------------------
       01  ORD-REC.
           05  ORD-ACTION              PIC X(01).
               88  ORD-IS-NEW                  VALUE 'N'.
               88  ORD-IS-CANCEL               VALUE 'C'.
           05  ORD-ID                  PIC X(12).
           05  ORD-PART-ID             PIC X(08).
           05  ORD-INSTR               PIC X(08).
           05  ORD-SIDE                PIC X(01).
               88  ORD-BUY                     VALUE 'B'.
               88  ORD-SELL                    VALUE 'S'.
           05  ORD-TYPE                PIC X(01).
               88  ORD-LIMIT                   VALUE 'L'.
               88  ORD-MARKET                  VALUE 'M'.
           05  ORD-PRICE               PIC 9(07)V99.
           05  ORD-QTY                 PIC 9(09).
           05  ORD-TS                  PIC X(26).
           05  FILLER                  PIC X(05).
