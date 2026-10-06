#!/usr/bin/env python3
"""Generate a synthetic order file for MATCHENG.

Writes the fixed-width ORDERS.DAT the COBOL batch reads, and optionally a
CSV copy using the TransitionX dataset field names.

usage: gen_orders.py [--count N] [--seed S] [--out data/ORDERS.DAT] [--csv data/orders.csv]
"""
import argparse
import csv
import random
from datetime import datetime, timedelta

# Must match copybooks/WSCONST.cpy
INSTRUMENTS = {"ACME": 4520, "BOLT": 12850, "CRWN": 985, "DYNX": 31000, "EVRG": 7240}


def tick_for(cents):
    return 5 if cents >= 10000 else 1


def round_to_tick(cents):
    t = tick_for(cents)
    return max(t, int(round(cents / t)) * t)


def fixed(action, oid, part, instr, side, otype, price_cents, qty, ts):
    rec = (
        f"{action:1.1}{oid:<12.12}{part:<8.8}{instr:<8.8}{side:1.1}{otype:1.1}"
        f"{price_cents:09d}{qty:09d}{ts:<26.26}"
    )
    return rec.ljust(80)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=10000)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", default="data/ORDERS.DAT")
    ap.add_argument("--csv", default=None)
    args = ap.parse_args()

    rnd = random.Random(args.seed)
    mids = dict(INSTRUMENTS)
    issued = {k: [] for k in INSTRUMENTS}
    ts = datetime(2026, 3, 2, 9, 30, 0)
    rows = []

    for n in range(1, args.count + 1):
        ts += timedelta(microseconds=rnd.randint(200, 40000))
        tstr = ts.strftime("%Y-%m-%dT%H:%M:%S.%f")
        instr = rnd.choice(list(INSTRUMENTS))
        mids[instr] = max(100, round(mids[instr] * (1 + rnd.gauss(0, 0.0004))))
        mid = mids[instr]
        oid = f"ORD{n:09d}"
        part = f"P{rnd.randint(1, 50):04d}"
        side = rnd.choice("BS")
        qty = rnd.randint(1, 500) * 10
        r = rnd.random()

        if r < 0.10 and issued[instr]:
            # cancels mostly target recent orders, sometimes stale ones
            target = rnd.choice(issued[instr][-40:])
            rows.append(("C", target, part, instr, " ", " ", 0, 0, tstr))
            continue
        if r < 0.17:
            rows.append(("N", oid, part, instr, side, "M", 0, qty, tstr))
            issued[instr].append(oid)
            continue
        if r < 0.20:
            # deliberately bad records, like a real upstream feed
            bad = rnd.choice(["instr", "qty", "tick", "band", "side", "action"])
            px = round_to_tick(mid)
            if bad == "instr":
                rows.append(("N", oid, part, "ZZZZ", side, "L", px, qty, tstr))
            elif bad == "qty":
                rows.append(("N", oid, part, instr, side, "L", px, 0, tstr))
            elif bad == "tick":
                rows.append(("N", oid, part, "DYNX", side, "L", mids["DYNX"] // 5 * 5 + 2, qty, tstr))
            elif bad == "band":
                rows.append(("N", oid, part, instr, side, "L", round_to_tick(round(mid * 1.3)), qty, tstr))
            elif bad == "side":
                rows.append(("N", oid, part, instr, "X", "L", px, qty, tstr))
            else:
                rows.append(("A", oid, part, instr, side, "L", px, qty, tstr))
            continue

        # limit order around the mid; buys skew up, sells skew down so some cross
        offset = rnd.gauss(0.0005 if side == "B" else -0.0005, 0.004)
        px = round_to_tick(round(mid * (1 + offset)))
        rows.append(("N", oid, part, instr, side, "L", px, qty, tstr))
        issued[instr].append(oid)

    with open(args.out, "w", newline="\n") as f:
        for row in rows:
            f.write(fixed(*row) + "\n")

    if args.csv:
        with open(args.csv, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["action", "order_id", "participant_id", "instrument", "side",
                        "order_type", "price", "quantity", "timestamp"])
            for a, oid, part, instr, side, otype, px, qty, t in rows:
                w.writerow([a, oid, part, instr, side.strip(), otype.strip(),
                            f"{px / 100:.2f}", qty, t])

    print(f"wrote {len(rows)} records to {args.out}")


if __name__ == "__main__":
    main()
