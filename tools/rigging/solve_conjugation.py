"""Offline solve: find per-bone conjugation D_b mapping Blender pose deltas onto
Roblox bone frames, simulate playback, score against ground truth, emit winner.

  D_b = inv(L_b) @ D_parent @ C_b   (recursive; D at armature root = candidate P)
  T_b = inv(D_b) @ B_b @ D_b
"""
import json, math, itertools

S = "/private/tmp/claude-501/-Users-jason-Documents-HaloAndHorns/35c99d45-e986-4baa-9686-67954732ee42/scratchpad"
L = json.load(open(f"{S}/blender_rests.json"))
C = json.load(open(f"{S}/roblox_rests.json"))
D_DATA = json.load(open(f"{S}/walk_pose_deltas.json"))
TRUTH = json.load(open(f"{S}/meshy_walk_truth.json"))

# ---------- quat helpers (w,x,y,z) ----------
def qmul(a, b):
    aw, ax, ay, az = a; bw, bx, by, bz = b
    return (aw*bw - ax*bx - ay*by - az*bz,
            aw*bx + ax*bw + ay*bz - az*by,
            aw*by - ax*bz + ay*bw + az*bx,
            aw*bz + ax*by - ay*bx + az*bw)
def qinv(q): return (q[0], -q[1], -q[2], -q[3])
def qrot(q, v):
    qv = (0.0, v[0], v[1], v[2])
    r = qmul(qmul(q, qv), qinv(q))
    return [r[1], r[2], r[3]]
def qnorm(q):
    m = math.sqrt(sum(x*x for x in q)) or 1
    return tuple(x / m for x in q)
def axis_angle(axis, deg):
    r = math.radians(deg) / 2
    s = math.sin(r)
    return qnorm((math.cos(r), axis[0]*s, axis[1]*s, axis[2]*s))

# ---------- hierarchy ----------
children = {}
roots = []
for b, e in C.items():
    p = e["parent"]
    if p == "":
        roots.append(b)
    else:
        children.setdefault(p, []).append(b)

FRAMES = D_DATA["frames"]
FEET = ["frontleg2", "R_frontleg2", "backleg2", "R_backleg2"]

def simulate(P):
    # compute D per bone
    D = {}
    def walkD(b, Dp):
        Lq = qnorm(tuple(L[b]["quat"]))
        Cq = qnorm(tuple(C[b]["quat"]))
        D[b] = qnorm(qmul(qmul(qinv(Lq), Dp), Cq))
        for c in children.get(b, []):
            walkD(c, D[b])
    for r in roots:
        walkD(r, P)
    # simulate world chain per frame
    trace = []
    for fr in FRAMES:
        world = {}
        def walkW(b, Wq, Wp):
            Cq = qnorm(tuple(C[b]["quat"])); Cp = C[b]["pos"]
            Bq = qnorm(tuple(fr["bones"][b]["quat"])); Bp = fr["bones"][b]["pos"]
            Tq = qnorm(qmul(qmul(qinv(D[b]), Bq), D[b]))
            Tp = qrot(qinv(D[b]), Bp)
            # node = W * C * T
            q1 = qmul(Wq, Cq)
            p1 = [Wp[i] + qrot(Wq, Cp)[i] for i in range(3)]
            q2 = qmul(q1, Tq)
            p2 = [p1[i] + qrot(q1, Tp)[i] for i in range(3)]
            world[b] = (q2, p2)
            for c in children.get(b, []):
                walkW(c, q2, p2)
        for r in roots:
            walkW(r, (1.0, 0.0, 0.0, 0.0), [0.0, 0.0, 0.0])
        trace.append({b: world[b][1] for b in world})
    return D, trace

def analyze(rows, get, up_axis):
    fwd = [0, 0, 0]
    for r in rows:
        h = get(r, "head"); p = get(r, "Hips")
        d = [h[i] - p[i] for i in range(3)]
        d[up_axis] = 0
        for i in range(3): fwd[i] += d[i]
    m = math.sqrt(sum(x*x for x in fwd)) or 1
    fwd = [x/m for x in fwd]
    up = [0,0,0]; up[up_axis] = 1
    right = [fwd[2]*up[1]-fwd[1]*up[2], fwd[0]*up[2]-fwd[2]*up[0], fwd[1]*up[0]-fwd[0]*up[1]]
    mm = math.sqrt(sum(x*x for x in right)) or 1
    right = [x/mm for x in right]
    res = {}
    for foot in FEET:
        fore, lat, vert = [], [], []
        for r in rows:
            f = get(r, foot); p = get(r, "Hips")
            d = [f[i]-p[i] for i in range(3)]
            fore.append(sum(d[i]*fwd[i] for i in range(3)))
            lat.append(sum(d[i]*right[i] for i in range(3)))
            vert.append(d[up_axis])
        res[foot] = (max(fore)-min(fore), max(lat)-min(lat), max(vert)-min(vert))
    return res

truth_amp = analyze(TRUTH, lambda r, k: r[k], 2)

CANDS = {
    "I": (1.0, 0.0, 0.0, 0.0),
    "Rx90": axis_angle((1,0,0), 90),
    "Rx-90": axis_angle((1,0,0), -90),
    "Ry180": axis_angle((0,1,0), 180),
    "Ry90": axis_angle((0,1,0), 90),
    "Ry-90": axis_angle((0,1,0), -90),
    "Rx90*Ry180": qmul(axis_angle((1,0,0), 90), axis_angle((0,1,0), 180)),
    "Rx-90*Ry180": qmul(axis_angle((1,0,0), -90), axis_angle((0,1,0), 180)),
    "Rz180": axis_angle((0,0,1), 180),
    "Rz90": axis_angle((0,0,1), 90),
    "Rz-90": axis_angle((0,0,1), -90),
    "Rx180": axis_angle((1,0,0), 180),
}

# height normalization: amplitudes scale with skeleton size
def sim_height(trace):
    ys = [p[1] for r in trace[:1] for p in r.values()]
    return (max(ys) - min(ys)) or 1

results = []
for name, P in CANDS.items():
    D, trace = simulate(P)
    scale = 1.62 / max(sim_height(trace), 0.3)
    sim_amp_raw = analyze(trace, lambda r, k: r[k], 1)  # roblox sim: Y up
    sim_amp = {f: tuple(v * scale for v in sim_amp_raw[f]) for f in FEET}
    err = 0
    for foot in FEET:
        for i in range(3):
            err += abs(sim_amp[foot][i] - truth_amp[foot][i])
    results.append((err, name, sim_amp, D))

results.sort(key=lambda x: x[0])
print("TRUTH amps:", {f: tuple(round(v,2) for v in truth_amp[f]) for f in FEET})
for err, name, amp, _ in results[:4]:
    print(f"cand {name:14s} err={err:.3f}  " + "  ".join(
        f"{f}:{tuple(round(v,2) for v in amp[f])}" for f in FEET))

# emit winner poses
err, name, amp, D = results[0]
print("WINNER:", name, "err", round(err, 3))
out_frames = []
for fr in FRAMES:
    row = {"time": fr["time"], "bones": {}}
    for b, e in fr["bones"].items():
        if b not in D: continue
        Bq = qnorm(tuple(e["quat"])); Bp = e["pos"]
        Tq = qnorm(qmul(qmul(qinv(D[b]), Bq), D[b]))
        Tp = qrot(qinv(D[b]), Bp)
        row["bones"][b] = {"pos": [round(v, 6) for v in Tp],
                           "quat": [round(v, 6) for v in Tq]}
    out_frames.append(row)
json.dump({"hierarchy": D_DATA["hierarchy"], "fps": D_DATA["fps"], "frames": out_frames},
          open(f"{S}/walk_pose_solved.json", "w"))
print("WROTE walk_pose_solved.json")