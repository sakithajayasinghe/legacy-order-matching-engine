#!/bin/sh
# runbatch.cgi - submit a new batch run from the intranet page.
# Only POST is accepted. Takes no input from the request.

if [ "$REQUEST_METHOD" != "POST" ]; then
    printf 'Status: 405 Method Not Allowed\r\nContent-Type: text/plain\r\n\r\nPOST only\n'
    exit 0
fi

RUN=$(flock -n /tmp/matchjob.lock /opt/matcheng/run/NEWDAY.sh 2>/dev/null)
RC=$?

if [ "$RC" -eq 1 ] && [ -z "$RUN" ]; then
    LOC="/cgi-bin/matcheng.cgi?msg=busy"
elif [ "$RC" -ne 0 ]; then
    LOC="/cgi-bin/matcheng.cgi?view=runs&msg=fail"
else
    LOC="/cgi-bin/matcheng.cgi?view=summary&run=$RUN&msg=done"
fi

printf 'Status: 303 See Other\r\nLocation: %s\r\n\r\n' "$LOC"
