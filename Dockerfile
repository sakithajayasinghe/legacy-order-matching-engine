FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends gnucobol python3 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/matcheng
COPY src/ src/
COPY copybooks/ copybooks/
COPY run/ run/
COPY tools/ tools/
COPY data/ data/

RUN mkdir -p bin output \
 && cobc -x -I copybooks -o bin/MATCHENG src/MATCHENG.cbl \
 && chmod +x run/*.sh

CMD ["./run/RUNBATCH.sh"]
