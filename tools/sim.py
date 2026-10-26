"""Passability check for Moonpull levels (port of scripts/level_gen.gd).
Runs a simulated player with a human-ish decision interval on many seeds."""
import math, random, sys
WMIN, WMAX, REST, DRAFT, TOP, HL, GRACE = .4, 5.6, 1.2, .3, 1.5, .9, .15
NL, NH, PO, BOOST_MULT, BOOST_TIME, SLOW_MULT, SLOW_TIME = -99, 99, .6, 1.45, 2.6, .62, 3.0
ACC = 16
speed_for = lambda l: min(7 + (l - 1) * .3, 12.5)
rise_for = lambda l: 2.6 + .8 * min((l - 1) / 12, 1)
fall_for = lambda l: 2.2 + .6 * min((l - 1) / 12, 1)
OBS = {"reef", "bridge", "gate", "drawbridge", "breather"}

def wave(e, t): return .5 + .5 * math.sin(math.tau * t / e["period"] + e["phase"])
def h_at(e, t): return e["h"] + e["amp"] * wave(e, t) if e["kind"] == "breather" else e["h"]
def b_at(e, t): return e["b"] - e["amp"] * wave(e, t) if e["kind"] == "drawbridge" else e["b"]

def item(k): return dict(kind=k, z=0, depth=1.4, h=NL, b=NH, amp=0, period=1, phase=0, y=0, nat=REST)
def reef(h): e = item("reef"); e["h"] = h; e["nat"] = min(h + DRAFT + .45, WMAX - .1); return e
def bridge(b): e = item("bridge"); e["b"] = b; e["nat"] = max(b - TOP - .45, WMIN + .1); return e
def gate(c, w): e = item("gate"); e["h"] = c - w / 2 - DRAFT; e["b"] = c + w / 2 + TOP; e["nat"] = c; return e
def pick(k, y): e = item(k); e["y"] = y; e["depth"] = 1; e["nat"] = min(max(y - PO, WMIN + .1), WMAX - .1); return e

def patterns(l):
    p = {"reef": 3, "bridge": 3}
    if l >= 2: p["gate"] = 2
    if l >= 3: p.update(stairs_up=1.2, stairs_down=1.2, boost=1)
    if l >= 4: p.update(drawbridge=1.4, zigzag=1.2)
    if l >= 5: p.update(breather=1.4, slow_gate=.8)
    if l >= 6: p.update(shield=.5, magnet=.6)
    return p

def make(pat, w, r):
    U = r.uniform
    if pat == "reef": return [reef(U(.7, 3.4))]
    if pat == "bridge": return [bridge(U(2.7, 6.3))]
    if pat == "gate": return [gate(U(1.6, 4.3), w)]
    if pat == "stairs_up":
        h0, st = U(.6, 1.1), U(.75, .95); out = []
        for i in range(3): e = reef(min(h0 + st * i, 3.5)); e["tight"] = i > 0; out.append(e)
        return out
    if pat == "stairs_down":
        b0, st = U(5.8, 6.4), U(.8, .95); out = []
        for i in range(3): e = bridge(max(b0 - st * i, 2.6)); e["tight"] = i > 0; out.append(e)
        return out
    if pat == "zigzag":
        a = reef(U(2.4, 3.2)); m = bridge(U(3.0, 3.8)); m["tight"] = True; c = reef(U(2.2, 3.0)); c["tight"] = True
        return [a, m, c]
    if pat == "drawbridge":
        d = item("drawbridge"); d["b"] = U(5.8, 6.6); d["amp"] = d["b"] - U(2.5, 2.9); d["period"] = U(2.4, 3.4)
        d["phase"] = U(0, math.tau); d["depth"] = 1.6; d["nat"] = max(d["b"] - d["amp"] - TOP - .45, WMIN + .1); return [d]
    if pat == "breather":
        d = item("breather"); d["h"] = U(.2, .6); d["amp"] = U(1.8, 2.8); d["period"] = U(2.2, 3.2)
        d["phase"] = U(0, math.tau); d["nat"] = min(d["h"] + d["amp"] + DRAFT + .45, WMAX - .1); return [d]
    if pat == "boost": return [pick("boost", U(1.8, 4.4))]
    if pat == "slow_gate": return [pick("slow", U(1.6, 4.0)), gate(U(1.6, 4.3), w * .85)]
    return [pick(pat, U(1.8, 4.4))]

def generate(l, r):
    sp, ri, fa = speed_for(l), rise_for(l), fall_for(l)
    react, w = max(.95 - (l - 1) * .025, .5), max(1.8 - (l - 1) * .06, .85)
    ws = patterns(l); items = []; z = 34; before = [REST]; boost_end = -1
    q = ["reef", "bridge", "reef"] if l == 1 else (["boost"] if l == 3 else [])
    for _ in range(min(5 + l, 18)):
        pat = q.pop(0) if q else r.choices(list(ws), weights=list(ws.values()))[0]
        for s in make(pat, w, r):
            nat = s["nat"]; mv = max(((nat - lv) / ri if nat > lv else (lv - nat) / fa) for lv in before)
            eff = sp * BOOST_MULT if z < boost_end else sp
            gap = eff * (react + mv * 1.3) + 3.2 + r.uniform(0, eff * (.15 if s.get("tight") else .45))
            z += gap; s["z"] = z; items.append(s)
            if s["kind"] == "boost": boost_end = z + sp * BOOST_MULT * BOOST_TIME
            before = [nat] if s["kind"] in OBS else before + [nat]
    return items, z + sp * 3 + 10

def play(l, r, interval, greedy):
    items, finish = generate(l, r); ri, fa, sp = rise_for(l), fall_for(l), speed_for(l)
    w, v, bz, t, nxt_dec, hold = REST, 0.0, 0.0, 0.0, 0.0, False
    boost = slow = 0.0; dt = 1 / 120; got = set()
    while bz < finish:
        cand = [e for e in items if e["z"] + e["depth"] / 2 > bz - HL and (e["kind"] in OBS or (greedy and e["kind"] == "boost" and id(e) not in got))]
        if cand:
            e = cand[0]
            if e["kind"] in OBS:
                eta = max(0.0, (e["z"] - bz) / (sp * (BOOST_MULT if boost > 0 else 1) * (SLOW_MULT if slow > 0 else 1)))
                # worst case over the next 0.6 s around arrival
                los = [ (h_at(e, t + eta + k * .1) + DRAFT if e["h"] > -50 else WMIN) for k in range(-3, 4)]
                his = [ (b_at(e, t + eta + k * .1) - TOP if e["b"] < 50 else WMAX) for k in range(-3, 4)]
                lo, hi = max(los) + .12, min(his) - .12
                if hi < lo:  # moving thing: be at the always-safe side
                    lo, hi = (WMIN, b_at(e, 0) - e["amp"] - TOP - .12) if e["kind"] == "drawbridge" else (h_at(e, 0) + e["amp"] + DRAFT + .12, WMAX)
                tgt = (lo + hi) / 2 if hi < WMAX else min(lo + .35, WMAX)
                if e["h"] < -50: tgt = max(WMIN, hi - .35)
            else:
                tgt = e["y"] - PO
        else:
            tgt = REST
        if t >= nxt_dec:
            hold = (w + v * abs(v) / (2 * ACC) + v * interval) < tgt; nxt_dec = t + interval
        target_v = ri if hold else -fa
        v += max(-ACC * dt, min(ACC * dt, target_v - v)); w += v * dt
        if w <= WMIN: w, v = WMIN, max(v, 0)
        if w >= WMAX: w, v = WMAX, min(v, 0)
        cur = sp * (BOOST_MULT if boost > 0 else 1) * (SLOW_MULT if slow > 0 else 1)
        bz += cur * dt; t += dt; boost = max(0, boost - dt); slow = max(0, slow - dt)
        for e in items:
            if e["kind"] in OBS and e["z"] - e["depth"] / 2 < bz + HL and e["z"] + e["depth"] / 2 > bz - HL:
                h, b = h_at(e, t), b_at(e, t)
                cl = min((w - DRAFT + GRACE) - h if h > -50 else 9, (b - TOP + GRACE) - w if b < 50 else 9)
                if cl < 0: return False, e["kind"]
            elif e["kind"] in ("boost", "slow") and id(e) not in got and abs(e["z"] - bz) < .6:
                if abs(w + PO - e["y"]) < .95:
                    got.add(id(e))
                    if e["kind"] == "boost": boost = BOOST_TIME
                    else: slow = SLOW_TIME
    return True, None

if __name__ == "__main__":
    for interval in (0.05, 0.15, 0.2):
        for greedy in (False, True):
            fails = {}
            for l in range(1, 31):
                for seed in range(4):
                    ok, why = play(l, random.Random(l * 100 + seed), interval, greedy)
                    if not ok: fails.setdefault(l, []).append(why)
            first = min(fails) if fails else None
            print(f"interval={interval} grabs_boosts={greedy}: first failing level={first}  failing levels={sorted(fails)}  causes={sorted({c for v in fails.values() for c in v})}")
