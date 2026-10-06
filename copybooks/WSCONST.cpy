      *----------------------------------------------------------------
      * WSCONST  - INSTRUMENT MASTER (HARD CODED)
      *            CODE(8) + REFERENCE PRICE 9(7)V99
      *            TO ADD AN INSTRUMENT: ADD A LINE HERE, CHANGE THE
      *            OCCURS BELOW, CHANGE WS-MAX-INSTR, RECOMPILE ALL.
      * 1997-03 JKT ADDED DYNX/EVRG
      *----------------------------------------------------------------
       01  WS-INSTR-VALUES.
           05  FILLER  PIC X(17) VALUE 'ACME    000004520'.
           05  FILLER  PIC X(17) VALUE 'BOLT    000012850'.
           05  FILLER  PIC X(17) VALUE 'CRWN    000000985'.
           05  FILLER  PIC X(17) VALUE 'DYNX    000031000'.
           05  FILLER  PIC X(17) VALUE 'EVRG    000007240'.
       01  WS-INSTR-TABLE REDEFINES WS-INSTR-VALUES.
           05  WS-INSTR-ENTRY OCCURS 5 TIMES.
               10  WS-INSTR-CODE       PIC X(08).
               10  WS-INSTR-REFPX      PIC 9(07)V99.
       77  WS-MAX-INSTR                PIC 9(02) VALUE 5.
