"""Apply the verified converter formula to a pose-deltas JSON:
world-delta x Ry(180)*Rx(-90) x vertical-axis negation, rotations only.
Usage: python3 convert_deltas.py <deltas.json> <out.json>
"""
import json, math, sys

S = "/private/tmp/claude-501/-Users-jason-Documents-HaloAndHorns/35c99d45-e986-4baa-9686-67954732ee42/scratchpad"
L = json.load(open(sys.argv[4] if len(sys.argv) > 4 else f"{S}/blender_rests.json"))
C = json.load(open(sys.argv[5] if len(sys.argv) > 5 else f"{S}/roblox_rests.json"))
DD = json.load(open(sys.argv[1]))

def qmul(a, b):
    aw, ax, ay, az = a; bw, bx, by, bz = b
    return (aw*bw-ax*bx-ay*by-az*bz, aw*bx+ax*bw+ay*bz-az*by,
            aw*by-ax*bz+ay*bw+az*bx, aw*bz+ax*by-ay*bx+az*bw)
def qinv(q): return (q[0], -q[1], -q[2], -q[3])
def qn(q):
    m = math.sqrt(sum(x*x for x in q)) or 1
    return tuple(x/m for x in q)
def aa(ax, deg):
    r = math.radians(deg)/2; s = math.sin(r)
    return qn((math.cos(r), ax[0]*s, ax[1]*s, ax[2]*s))

children = {}; roots = []
for b, e in C.items():
    p = e["parent"]
    (roots.append(b) if p == "" else children.setdefault(p, []).append(b))

def blender_worldq(fr):
    world = {}
    def walk(b, Wq):
        q = qmul(qmul(Wq, qn(tuple(L[b]["quat"]))), qn(tuple(fr["bones"][b]["quat"])))
        world[b] = qn(q)
        for c in children.get(b, []): walk(c, q)
    for r in roots: walk(r, (1, 0, 0, 0))
    return world

rest_fr = {"bones": {b: {"quat": [1, 0, 0, 0], "pos": [0, 0, 0]} for b in C}}
WB_rest = blender_worldq(rest_fr)
Vw = {}
def chainV(b, q):
    q2 = qn(qmul(q, qn(tuple(C[b]["quat"])))); Vw[b] = q2
    for c in children.get(b, []): chainV(c, q2)
for r in roots: chainV(r, (1, 0, 0, 0))

AX = qmul(aa((0, 1, 0), 180), aa((1, 0, 0), -90))

out = []
for fr in DD["frames"]:
    WB = blender_worldq(fr)
    row = {"time": fr["time"], "bones": {}}
    achieved = {}
    def solve(b, parent_q):
        q1 = qmul(parent_q, qn(tuple(C[b]["quat"])))
        delta_b = qmul(WB[b], qinv(WB_rest[b]))
        d = qmul(qmul(AX, delta_b), qinv(AX))
        if len(sys.argv) > 3 and sys.argv[3] == "invpitch":
            d = qn((d[0], -d[1], -d[2], d[3]))  # pitch + vertical negation (experiment)
        else:
            d = qn((d[0], d[1], -d[2], d[3]))  # vertical-axis negation (the "#3" tweak)
        target = qn(qmul(d, Vw[b]))
        Tq = qn(qmul(qinv(qn(q1)), target))
        row["bones"][b] = {"pos": [0.0, 0.0, 0.0], "quat": [round(v, 6) for v in Tq]}
        achieved[b] = target
        for c in children.get(b, []): solve(c, achieved[b])
    for r in roots: solve(r, (1, 0, 0, 0))
    out.append(row)
json.dump({"hierarchy": DD["hierarchy"], "fps": DD["fps"], "frames": out}, open(sys.argv[2], "w"))
print("CONVERTED", sys.argv[2], len(out), "frames")