# MATCHENG: legacy order-matching batch (COBOL)

The **"before"** system for TransitionX 2026, Challenge 1.1: a monolithic COBOL batch program that matches buy and sell orders for an exchange.

> **This is a synthetic legacy system.** No open-source COBOL matching engine exists, so we wrote one in the style of a 1990s exchange back office. Its problems are deliberate: one large program, `GO TO` control flow, shared global working storage, hard-coded business rules, copybooks shared across programs, fixed-width files, no API, no tests, and no documentation of the rules. These are the problems the modernization project fixes.

## What it does

```
ORDERS.DAT ──► MATCHENG (one COBOL program) ──► TRADES.DAT   trades
 fixed-width     read · validate · match         REJECTS.DAT  rejected records
 80-byte recs    rest · cancel · report · audit   BOOK.DAT     resting orders at end of run
                                                  REPORT.TXT   daily summary
                                                  AUDIT.LOG    event log
```

## Layout

| Path | Contents |
|---|---|
| `src/MATCHENG.cbl` | The whole engine, in fixed-format COBOL |
| `copybooks/` | Record layouts and the hard-coded instrument master |
| `run/RUNBATCH.sh` | Job script. Plays the role of the old MVS JCL and maps COBOL file names to paths through `DD_` variables |
| `tools/gen_orders.py` | Generates synthetic order files |
| `data/ORDERS.DAT` | Sample input: 10,000 orders |
| `web/` | Intranet report viewer: lighttpd with shell/awk CGI scripts that read the batch files directly |
| `deploy/` | Caddy (HTTPS) config and VM setup script |

## Run it

With Docker (any OS):

```sh
make docker-build
make docker-run          # output appears in ./output/<timestamp>/
```

With GnuCOBOL installed locally (`sudo apt install gnucobol`):

```sh
make build
make run
```

Generate a different input file:

```sh
python3 tools/gen_orders.py --count 100000 --seed 7 --out data/ORDERS_100K.DAT
./run/RUNBATCH.sh data/ORDERS_100K.DAT
```

## Report viewer (legacy UI)

A 2002-style intranet page that shows the batch output: summary report, trades, rejects, order book and run history. **Submit New Batch Run** generates a new business day of orders and runs the batch.

```sh
docker build -t matcheng-legacy .
docker run --rm -p 8080:8080 matcheng-legacy   # open http://localhost:8080
```

Deployed with `docker compose up -d`, which also starts Caddy for HTTPS on `$SITE_DOMAIN` (default `legacy.calit.online`).

Return codes: `0` clean run, `4` completed with rejected records, `16` file error.
