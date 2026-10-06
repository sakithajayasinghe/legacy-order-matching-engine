#!/bin/sh
# matcheng.cgi - MATCHENG intranet report viewer
# Reads the batch output files directly and renders HTML.
# 2002-05 SLW  first version
# 2004-11 SLW  added order book page

BASE=/opt/matcheng
OUTROOT=$BASE/output
PAGE_SIZE=50

param() {
    printf '%s' "$QUERY_STRING" | tr '&' '\n' | sed -n "s/^$1=//p" | head -1
}

VIEW=$(param view)
RUN=$(param run)
PG=$(param page)
INSTR=$(param instr)
MSG=$(param msg)

case "$VIEW" in summary|trades|rejects|book|runs) ;; *) VIEW=summary ;; esac
case "$PG" in ''|*[!0-9]*) PG=1 ;; esac
case "$INSTR" in *[!A-Z]*) INSTR= ;; esac
LATEST=$(ls -1 "$OUTROOT" 2>/dev/null | grep -E '^[0-9_]+$' | sort | tail -1)
case "$RUN" in ''|*[!0-9_]*) RUN=$LATEST ;; esac
[ -d "$OUTROOT/$RUN" ] || RUN=$LATEST
DIR=$OUTROOT/$RUN

run_label() {
    printf '%s' "$1" | sed 's/^\(....\)\(..\)\(..\)_\(..\)\(..\)\(..\)$/\1-\2-\3 \4:\5:\6/'
}

link() {
    printf '/cgi-bin/matcheng.cgi?view=%s&run=%s' "$1" "$RUN"
}

printf 'Content-Type: text/html\r\n\r\n'

cat <<EOF
<html>
<head>
<title>MATCHENG Report Viewer</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style type="text/css">
body { margin: 0; background: #ece9d8; font-family: Verdana, Tahoma, Arial, sans-serif; font-size: 12px; color: #000; }
a { color: #0033cc; }
a:visited { color: #551a8b; }
.title { background: #003366; color: #fff; padding: 6px 10px; border-bottom: 3px solid #ff9900; }
.title b { font-size: 16px; letter-spacing: 1px; }
.title span { font-size: 11px; color: #c8d8e8; }
.wrap { padding: 10px; }
.tabs { border-collapse: collapse; margin-bottom: 0; }
.tabs td { border: 1px solid #808080; border-bottom: none; background: #d4d0c8; padding: 4px 12px; }
.tabs td.on { background: #fff; font-weight: bold; }
.tabs a { text-decoration: none; color: #000; }
.panel { background: #fff; border: 1px solid #808080; padding: 10px; overflow-x: auto; }
.bar { background: #d4d0c8; border: 1px solid #808080; padding: 5px 8px; margin-bottom: 8px; }
table.grid { border-collapse: collapse; font-size: 11px; }
table.grid th { background: #c0c0c0; border: 1px solid #808080; padding: 2px 6px; text-align: left; white-space: nowrap; }
table.grid td { border: 1px solid #c0c0c0; padding: 2px 6px; white-space: nowrap; }
table.grid tr.alt td { background: #f0f0f0; }
td.n { text-align: right; font-family: "Courier New", Courier, monospace; }
td.m { font-family: "Courier New", Courier, monospace; }
pre.rpt { font-family: "Courier New", Courier, monospace; font-size: 12px; background: #fffff0; border: 1px dashed #999; padding: 8px; margin: 0; }
input.btn { font-family: Tahoma, Verdana, sans-serif; font-size: 11px; background: #d4d0c8; border: 2px outset #fff; padding: 2px 10px; cursor: pointer; }
input.btn:active { border-style: inset; }
.warn { background: #ffffcc; border: 1px solid #cc9900; padding: 4px 8px; margin-bottom: 8px; }
.foot { color: #666; font-size: 10px; padding: 8px 10px; }
h3 { font-size: 13px; margin: 12px 0 6px 0; }
</style>
</head>
<body>
<div class="title"><b>MATCHENG</b> &nbsp;<span>Exchange Matching System &middot; Batch Report Viewer &middot; INTRANET USE ONLY</span></div>
<div class="wrap">
EOF

if [ -z "$RUN" ]; then
    echo '<div class="warn">No batch output found. Submit a batch run to begin.</div>'
fi

case "$MSG" in
    busy) echo '<div class="warn">A batch is already running. Please wait and refresh.</div>' ;;
    done) echo '<div class="warn">Batch run complete. Showing the new output.</div>' ;;
    fail) echo '<div class="warn">Batch run ended abnormally. Check the job log on the Run History page.</div>' ;;
esac

cat <<EOF
<div class="bar">
<form method="post" action="/cgi-bin/runbatch.cgi" style="margin:0">
Business day: <b>$(run_label "$RUN")</b> &nbsp;|&nbsp;
<a href="/cgi-bin/matcheng.cgi?view=runs&run=$RUN">change</a> &nbsp;|&nbsp;
<input class="btn" type="submit" value="Submit New Batch Run">
</form>
</div>
<table class="tabs"><tr>
EOF
for v in summary trades rejects book runs; do
    case $v in
        summary) l="Summary Report" ;; trades) l="Trades" ;; rejects) l="Rejects" ;;
        book) l="Order Book" ;; runs) l="Run History" ;;
    esac
    if [ "$v" = "$VIEW" ]; then
        echo "<td class=\"on\">$l</td>"
    else
        echo "<td><a href=\"$(link $v)\">$l</a></td>"
    fi
done
echo '</tr></table><div class="panel">'

instr_filter() {
    echo "<form method=\"get\" action=\"/cgi-bin/matcheng.cgi\" style=\"margin:0 0 8px 0\">"
    echo "<input type=\"hidden\" name=\"view\" value=\"$VIEW\"><input type=\"hidden\" name=\"run\" value=\"$RUN\">"
    echo "Instrument: <select name=\"instr\"><option value=\"\">(all)</option>"
    for i in ACME BOLT CRWN DYNX EVRG; do
        if [ "$i" = "$INSTR" ]; then s=' selected'; else s=''; fi
        echo "<option$s>$i</option>"
    done
    echo "</select> <input class=\"btn\" type=\"submit\" value=\"Go\"></form>"
}

pager() {
    total=$1
    pages=$(( (total + PAGE_SIZE - 1) / PAGE_SIZE ))
    [ "$pages" -lt 1 ] && pages=1
    base="$(link "$VIEW")&instr=$INSTR"
    printf '<p>Records: <b>%s</b> &nbsp; Page %s of %s &nbsp; ' "$total" "$PG" "$pages"
    [ "$PG" -gt 1 ] && printf '<a href="%s&page=1">&lt;&lt; First</a> <a href="%s&page=%s">&lt; Prev</a> ' "$base" "$base" $((PG - 1))
    [ "$PG" -lt "$pages" ] && printf '<a href="%s&page=%s">Next &gt;</a> <a href="%s&page=%s">Last &gt;&gt;</a>' "$base" $((PG + 1)) "$base" "$pages"
    echo '</p>'
}

if [ -n "$RUN" ]; then
case "$VIEW" in

summary)
    echo '<pre class="rpt">'
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' "$DIR/REPORT.TXT"
    echo '</pre>'
    ;;

trades)
    instr_filter
    total=$(awk -v f="$INSTR" 'f=="" || substr($0,11,4)==f' "$DIR/TRADES.DAT" | wc -l)
    pager "$total"
    echo '<table class="grid"><tr><th>Trade #</th><th>Instr</th><th>Price</th><th>Quantity</th><th>Buy Order</th><th>Buyer</th><th>Sell Order</th><th>Seller</th><th>Aggr</th><th>Time</th></tr>'
    awk -v f="$INSTR" -v pg="$PG" -v ps="$PAGE_SIZE" '
        function px(s) { return (substr(s,1,7)+0) "." substr(s,8,2) }
        f=="" || substr($0,11,4)==f {
            n++; if (n <= (pg-1)*ps || n > pg*ps) next
            cls = (n % 2 == 0) ? " class=\"alt\"" : ""
            printf "<tr%s><td class=\"n\">%d</td><td>%s</td><td class=\"n\">%s</td><td class=\"n\">%d</td><td class=\"m\">%s</td><td>%s</td><td class=\"m\">%s</td><td>%s</td><td>%s</td><td class=\"m\">%s</td></tr>\n",
                cls, substr($0,1,10)+0, substr($0,11,8), px(substr($0,19,9)), substr($0,28,9)+0,
                substr($0,37,12), substr($0,61,8), substr($0,49,12), substr($0,69,8),
                substr($0,77,1), substr($0,89,15)
        }' "$DIR/TRADES.DAT"
    echo '</table>'
    ;;

rejects)
    echo '<h3>Rejects by reason</h3><table class="grid"><tr><th>Code</th><th>Reason</th><th>Count</th></tr>'
    awk '{ c=substr($0,22,3); t[c]=substr($0,25,40); n[c]++ }
         END { for (c in n) printf "%s|%s|%d\n", c, t[c], n[c] }' "$DIR/REJECTS.DAT" | sort |
    awk -F'|' '{ printf "<tr><td class=\"m\">%s</td><td>%s</td><td class=\"n\">%d</td></tr>\n", $1, $2, $3 }'
    echo '</table><h3>Reject detail</h3>'
    total=$(wc -l < "$DIR/REJECTS.DAT")
    pager "$total"
    echo '<table class="grid"><tr><th>Input Rec #</th><th>Order ID</th><th>Code</th><th>Reason</th><th>Time</th></tr>'
    awk -v pg="$PG" -v ps="$PAGE_SIZE" '
        { n++; if (n <= (pg-1)*ps || n > pg*ps) next
          cls = (n % 2 == 0) ? " class=\"alt\"" : ""
          printf "<tr%s><td class=\"n\">%d</td><td class=\"m\">%s</td><td class=\"m\">%s</td><td>%s</td><td class=\"m\">%s</td></tr>\n",
              cls, substr($0,1,9)+0, substr($0,10,12), substr($0,22,3), substr($0,25,40), substr($0,76,15) }' "$DIR/REJECTS.DAT"
    echo '</table>'
    ;;

book)
    instr_filter
    for i in ACME BOLT CRWN DYNX EVRG; do
        [ -n "$INSTR" ] && [ "$INSTR" != "$i" ] && continue
        echo "<h3>$i &nbsp;<span style=\"font-weight:normal\">(top 15 levels each side)</span></h3>"
        echo '<table class="grid"><tr><th colspan="4">BIDS (BUY)</th><th colspan="4">ASKS (SELL)</th></tr>'
        echo '<tr><th>Order</th><th>Part</th><th>Qty</th><th>Price</th><th>Price</th><th>Qty</th><th>Part</th><th>Order</th></tr>'
        awk -v f="$i" '
            function px(s) { return (substr(s,1,7)+0) "." substr(s,8,2) }
            substr($0,1,4)==f && substr($0,9,1)=="B" && nb < 15 { nb++; b[nb] = sprintf("<td class=\"m\">%s</td><td>%s</td><td class=\"n\">%d</td><td class=\"n\">%s</td>", substr($0,28,12), substr($0,40,8), substr($0,19,9)+0, px(substr($0,10,9))) }
            substr($0,1,4)==f && substr($0,9,1)=="S" && na < 15 { na++; a[na] = sprintf("<td class=\"n\">%s</td><td class=\"n\">%d</td><td>%s</td><td class=\"m\">%s</td>", px(substr($0,10,9)), substr($0,19,9)+0, substr($0,40,8), substr($0,28,12)) }
            END {
                m = (nb > na) ? nb : na
                if (m == 0) print "<tr><td colspan=\"8\">Book empty</td></tr>"
                for (k = 1; k <= m; k++) {
                    l = (k in b) ? b[k] : "<td></td><td></td><td></td><td></td>"
                    r = (k in a) ? a[k] : "<td></td><td></td><td></td><td></td>"
                    printf "<tr%s>%s%s</tr>\n", (k % 2 == 0) ? " class=\"alt\"" : "", l, r
                }
            }' "$DIR/BOOK.DAT"
        echo '</table>'
    done
    ;;

runs)
    echo '<table class="grid"><tr><th>Business Day (Run)</th><th>Orders</th><th>Trades</th><th>Rejects</th><th>Return Code</th><th>Job Log</th></tr>'
    n=0
    for r in $(ls -1 "$OUTROOT" | grep -E '^[0-9_]+$' | sort -r); do
        d=$OUTROOT/$r
        n=$((n + 1))
        o=$( [ -f "$d/ORDERS.DAT" ] && wc -l < "$d/ORDERS.DAT" || echo "-")
        t=$(wc -l < "$d/TRADES.DAT" 2>/dev/null || echo "-")
        j=$(wc -l < "$d/REJECTS.DAT" 2>/dev/null || echo "-")
        rc=$(sed -n 's/.*RC=\([0-9]*\).*/\1/p' "$d/JOBLOG.TXT" 2>/dev/null | tail -1)
        cls=''; [ $((n % 2)) -eq 0 ] && cls=' class="alt"'
        mark=''; [ "$r" = "$RUN" ] && mark=' <b>&laquo; viewing</b>'
        echo "<tr$cls><td><a href=\"/cgi-bin/matcheng.cgi?view=summary&run=$r\">$(run_label "$r")</a>$mark</td><td class=\"n\">$o</td><td class=\"n\">$t</td><td class=\"n\">$j</td><td class=\"n\">${rc:--}</td><td>"
        if [ -f "$d/JOBLOG.TXT" ]; then
            echo "<pre class=\"rpt\" style=\"font-size:10px;border:none;padding:0;background:none\">$(sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' "$d/JOBLOG.TXT")</pre>"
        fi
        echo '</td></tr>'
    done
    echo '</table>'
    ;;
esac
fi

cat <<EOF
</div>
</div>
<div class="foot">MATCHENG Report Viewer v2.3 &middot; Data is refreshed by the nightly batch (MATCHJOB) &middot; Best viewed in Internet Explorer 6.0 at 1024x768<br>
Synthetic legacy system for TransitionX 2026, Challenge 1.1. All orders and participants are generated test data.</div>
</body>
</html>
EOF
