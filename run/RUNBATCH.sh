#!/bin/sh
# RUNBATCH - nightly matching batch.
# Replaces the MVS job MATCHJOB.  Each DD_ variable maps a COBOL
# file name (ASSIGN TO 'ORDIN' etc.) to a real path, like a JCL DD card.
#
# usage: run/RUNBATCH.sh [orders-file] [output-dir]

BASE=$(cd "$(dirname "$0")/.." && pwd)
IN=${1:-$BASE/data/ORDERS.DAT}
OUT=${2:-$BASE/output/$(date +%Y%m%d_%H%M%S)}

if [ ! -f "$IN" ]; then
    echo "MATCHJOB - INPUT NOT FOUND: $IN"
    exit 16
fi
mkdir -p "$OUT"

export DD_ORDIN="$IN"
export DD_TRDOUT="$OUT/TRADES.DAT"
export DD_REJOUT="$OUT/REJECTS.DAT"
export DD_BOOKOUT="$OUT/BOOK.DAT"
export DD_RPTOUT="$OUT/REPORT.TXT"
export DD_AUDOUT="$OUT/AUDIT.LOG"

echo "MATCHJOB - STARTED  $(date '+%Y-%m-%d %H:%M:%S')  INPUT=$IN"
"$BASE/bin/MATCHENG"
RC=$?
echo "MATCHJOB - ENDED    $(date '+%Y-%m-%d %H:%M:%S')  RC=$RC  OUTPUT=$OUT"

# RC 0 = clean, RC 4 = completed with rejects, anything else = abend
if [ "$RC" -gt 4 ]; then
    exit "$RC"
fi
exit 0
