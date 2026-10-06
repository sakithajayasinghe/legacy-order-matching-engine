#!/bin/sh
# Container start: make sure there is at least one batch run to show,
# then start the intranet web server in the foreground.

chown -R www-data:www-data /opt/matcheng/output

if [ -z "$(ls -1 /opt/matcheng/output | grep -E '^[0-9_]+$')" ]; then
    su -s /bin/sh www-data -c "/opt/matcheng/run/NEWDAY.sh /opt/matcheng/data/ORDERS.DAT" > /dev/null
fi

exec lighttpd -D -f /opt/matcheng/web/lighttpd.conf
