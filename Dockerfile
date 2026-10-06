FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends gnucobol python3 lighttpd util-linux \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/matcheng
COPY src/ src/
COPY copybooks/ copybooks/
COPY run/ run/
COPY tools/ tools/
COPY data/ data/
COPY web/ web/

RUN mkdir -p bin output web/htdocs \
 && cobc -x -I copybooks -o bin/MATCHENG src/MATCHENG.cbl \
 && chmod +x run/*.sh web/cgi-bin/*.cgi \
 && chown -R www-data:www-data output

EXPOSE 8080
CMD ["./run/ENTRYPOINT.sh"]
