      *----------------------------------------------------------------
      * TRDREC   - TRADE OUTPUT RECORD                    LRECL=110
      *            READ DOWNSTREAM BY SETTLEMENT (STLBATCH) AND
      *            REGULATORY REPORTING (REGRPT01)
      *----------------------------------------------------------------
       01  TRD-REC.
           05  TRD-ID                  PIC 9(10).
           05  TRD-INSTR               PIC X(08).
           05  TRD-PRICE               PIC 9(07)V99.
           05  TRD-QTY                 PIC 9(09).
           05  TRD-BUY-ID              PIC X(12).
           05  TRD-SELL-ID             PIC X(12).
           05  TRD-BUY-PART            PIC X(08).
           05  TRD-SELL-PART           PIC X(08).
           05  TRD-AGGR-SIDE           PIC X(01).
           05  TRD-TS                  PIC X(26).
           05  FILLER                  PIC X(07).
