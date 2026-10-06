#!/bin/sh
# NEWDAY - generate a new business day of orders and run MATCHJOB on it.
# Prints the run id on success. Keeps the most recent KEEP_RUNS runs.
#
# usage: run/NEWDAY.sh [orders-file]   (default: generate a new file)

BASE=$(cd "$(dirname "$0")/.." && pwd)
OUTROOT=$BASE/output
KEEP_RUNS=${KEEP_RUNS:-30}
COUNT=${COUNT:-10000}

RUNID=$(date +%Y%m%d_%H%M%S)
while [ -e "$OUTROOT/$RUNID" ]; do
    sleep 1
    RUNID=$(date +%Y%m%d_%H%M%S)
done
OUT=$OUTROOT/$RUNID
mkdir -p "$OUT"

if [ -n "$1" ]; then
    cp "$1" "$OUT/ORDERS.DAT"
else
    python3 "$BASE/tools/gen_orders.py" --count "$COUNT" --seed "$(date +%s)" \
        --out "$OUT/ORDERS.DAT" > /dev/null || exit 16
fi

"$BASE/run/RUNBATCH.sh" "$OUT/ORDERS.DAT" "$OUT" > "$OUT/JOBLOG.TXT" 2>&1
RC=$?

ls -1 "$OUTROOT" | grep -E '^[0-9_]+$' | sort -r | tail -n +$((KEEP_RUNS + 1)) |
    while read -r old; do rm -rf "${OUTROOT:?}/$old"; done

echo "$RUNID"
exit $RC
