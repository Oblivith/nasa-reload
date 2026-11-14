# Sim Spec v2 — FINAL (replaces The_Inheritance_Sim_Spec.md)
*One real-physics engine. Three ways to put numbers into it. Real data in, real data used to prove it works.*

---

## 0. The Big Picture

```
 EASY  (pick simple shapes)     ┐
 MEDIUM (0–1 sliders vs a real  ├──► converts to REAL VALUES ──► ONE PHYSICS ENGINE ──► results
        reference rocket)       │    (metres, kg, kN, s)          (stability, range,     shown per mode:
 HARD  (raw real numbers)       ┘                                  liftoff, structure,    ✓/✗ · gauges · raw
                                                                   launch sim)
```

**Why this design wins on every judging criterion:**
| Criterion | How we hit it |
|---|---|
| **Validity** | Real equations (Barrowman, Tsiolkovsky, orbital mechanics), real 1960s data, sim *validated against real flights* |
| **Relevance** | Exactly the brief: design, trade-offs, resources, simulation, feedback, difficulty levels |
| **Creativity** | Story mode + three input styles on one engine |
| **Impact** | Works for a 10-year-old and an aerospace student |
| **Presentation** | Live mission control launch is a great 30-second demo moment |

**Two questions decide every mission** (from the team's idea):
1. **Will it fly straight?** → *Stability* (atmosphere)
2. **Can it get there (and back)?** → *Range* (Δv)
Plus two hard gates: **can it lift off** (thrust-to-weight) and **will it hold together** (Max-Q vs structure).

---

## 1. The Rocket Model (segments)

The rocket is built bottom to top from segments. Every segment has mass, length, and position.

| Segment | Parameters (real units, used by the engine) |
|---|---|
| **Nose cone** | shape (cone / ogive / parabolic / blunt capsule), length L_n, mass |
| **Payload section** | the spacecraft (satellite/capsule) mass, length |
| **Body / tanks** | length, diameter d, material (aluminium / steel / titanium), propellant mass |
| **Engine section** | engine choice (real data: thrust SL/vac, Isp SL/vac, mass; nozzle is part of the engine) |
| **Fins** | count N (3/4), root chord C_r, tip chord C_t, span S, sweep X_r, position from tail |
| **Upper stages** (L2+) | same as body + engine, stacked |
| **Options** | gimballed engine (steers, allows less fins, costs $), escape tower (crewed) |

Dry structure mass = tank/body area × material areal density (derived from real tank mass fractions).

---

## 2. The Physics Engine

### 2.1 Stability: centre of pressure vs centre of mass (Barrowman, subsonic)
All distances measured from the nose tip. d = body diameter, R = d/2.

**Nose cone:**
- CNα_nose = 2
- X_nose = 0.666·L_n (cone) · 0.466·L_n (ogive) · 0.5·L_n (parabolic)

**Fins:**
- L_f = √( S² + (X_r + C_t/2 − C_r/2)² )
- CNα_fins = [1 + R/(S+R)] · [4N(S/d)²] / [1 + √(1 + (2L_f/(C_r+C_t))²)]
- X_fins = X_b + (X_r/3)·(C_r+2C_t)/(C_r+C_t) + (1/6)·[(C_r+C_t) − C_r·C_t/(C_r+C_t)]
  (X_b = distance from nose tip to fin root leading edge)

**Centre of pressure:** X_cp = (CNα_nose·X_nose + CNα_fins·X_fins) / (CNα_nose + CNα_fins)

**Centre of mass:** X_cg = Σ(mᵢ·xᵢ) / Σmᵢ, computed **at liftoff and at burnout** (propellant mass → 0, so CG moves).

**Static margin** = (X_cp − X_cg) / d, in calibres.
| Margin | Result |
|---|---|
| < 0 | Unstable: tumbles (fail) |
| 0–1 | Marginal: wobbles, extra drag; fails unless the engine is gimballed |
| 1–2 | ✓ Stable |
| > 3 | Over-stable: weathercocks into the wind, extra losses (warning) |

*Gimballed engine:* treat margin ≥ 0.3 as flyable. Real orbital rockets steer this way.

### 2.2 Liftoff gate
- TWR = Thrust_SL / (m_total · g₀) must be > 1.2. Below 1: no liftoff. 1.0–1.2: liftoff but huge gravity losses (sim will show it).

### 2.3 Range: Δv (can it get there and back?)
- Per stage: Δv = Isp · g₀ · ln(m₀ / m_f)
- Total Δv = Σ stages
- **Required Δv** = mission Δv budget from the map (ground→orbit ≈ 9,400 m/s incl. losses, minus Earth-spin bonus 465·cos(lat); Moon legs per the old spec section 2), **plus return legs if the mission needs a return**, plus a margin.
- Range ratio = Δv_available / Δv_required. ≥ 1.0 = can make it; ≥ 1.1 = safe margin.
- *The launch sim then tells the real story:* actual gravity/drag losses from the player's real shape replace the 9,400 estimate.

### 2.4 Structure (Max-Q)
- Dynamic pressure q = ½ρv² (from the launch sim, ρ = 1.225·e^(−h/8500))
- Each material has a max q it tolerates (scaled by diameter and length: long, thin rockets are weaker)
- q_max > limit → structural failure at Max-Q

### 2.5 Drag
- Cd = base (by nose shape: ogive lowest, blunt highest) + fins term (∝ fin area / body cross-section) + extra if the margin is marginal (wobble)
- Drag = ½ρv²·Cd·(π·R²)

### 2.6 Launch simulation (2D, fixed time steps)
As in old spec section 6.5: thrust blending sea-level→vacuum, mass flow, gravity μ/r², atmosphere, drag, gravity turn, staging, cutoff at target orbit, apogee/perigee from vis-viva, reliability rolls, live telemetry. The stability and structure checks above feed in as failure conditions during flight.

### 2.7 Mission systems (keep simple for the demo)
Power (solar/battery through eclipses), data vs comms, orbit lifetime, heat shield for return. Old spec section 3, unchanged. **Level 1 only needs power + comms + lifetime.**

---

## 3. The Three Input Modes

All three produce the *same* list of real values for the engine.

### EASY: pick simple descriptive options (2–3 each)
Players see plain words and pictures, not part names or numbers. Each option secretly maps to real-unit values (based on real hardware) for the engine.
| Part | Options (each is a real-value preset) |
|---|---|
| Nose cone | Pointy · Rounded · Fat/Blunt |
| Body | Short & thin · Medium · Tall & fat (sets length + diameter + fuel) |
| Material | Light (aluminium) · Strong (steel) |
| Engine | Small & cheap · Medium · Big & powerful |
| Fins | Small · Medium · Large (fixed count 4, preset shape) |
**Output:** ✓/✗ per check with a plain-English reason: *"Your rocket tips over: the fins are too small to keep the back behind the front. Try bigger fins, or put heavy parts higher up."*

### MEDIUM: normalised sliders vs a real reference rocket
- Each parameter is a slider 0 → 1. **0.5 = the real reference rocket's value**; 0 and 1 = the allowed min/max (e.g. 0.5×–2× the reference).
- Converted to real units before going into the engine: `real = min + slider·(max − min)`.
- Reference rockets (pick per level): **Redstone-class** (L1), Atlas-class, Titan-class, Saturn-class (later levels).
**Output:** 0–1 gauges: Stability, Range, Liftoff, Structure, with green/yellow/red zones. Hover to see the real number.

### HARD: raw real numbers
- Number fields in real units for every parameter in section 1, plus gravity-turn pitch-kick angle.
- Player can type their own predicted Δv and static margin. The game shows theirs vs the engine's after the run.
**Output:** raw values: static margin (calibres) at liftoff/burnout, X_cp, X_cg, Δv per stage, TWR, q_max, final apogee/perigee, plus the formula used.

**Rocket drawing:** generated automatically from the numbers (cylinder + cone + flat fins). CP and CG are drawn on the rocket as markers (the classic red/blue dots) in all modes. Very visual and very educational.

---

## 4. Real Data's Two Jobs (the team's research role)

1. **Inputs:** engines, materials, reference rockets, Δv map, from NASA sources.
2. **Validation (the pitch point):** enter real rockets' specs in Hard mode and compare the sim's results with real flight records (e.g. Mercury-Redstone's peak altitude and velocity, Atlas reaching orbit). Put the comparison table in the submission:

| Rocket | Real result | Our sim | Error |
|---|---|---|---|
| Mercury-Redstone (suborbital) | ~187 km apogee | ? | ? |
| Atlas (orbit) | orbit ~160 × 260 km | ? | ? |

> **Pitch line:** "Three ways to design, one real physics engine, validated against real 1960s flights."

---

## 5. What gets built when (≈30 h left)

| Priority | Piece | Owner | Model |
|---|---|---|---|
| 1 | Data JSON + reference rockets | AI draft → friends verify | Sonnet |
| 2 | Engine maths: Barrowman, CG, Δv, TWR + tests | AI | **Fable, high** |
| 3 | Easy-mode builder + auto-drawn rocket with CP/CG markers | AI | Opus |
| 4 | Launch sim + mission control readouts | AI | **Fable, high** (or Opus + Fable review) |
| 5 | Results screen (✓/✗ reasons) + debrief | AI | Opus |
| 6 | Medium mode sliders | AI | Sonnet |
| 7 | Opening cutscene + Level 1 story triggers | AI + writer | Opus |
| 8 | Hard mode fields | AI | Sonnet |
| 9 | Validation table vs real rockets | Friends | — |
| 10 | Credits/AI disclosure, web export, submit | AI + you | Sonnet |

**Cut order if behind:** Hard mode → Medium mode → power/comms detail → campus hub (use a menu). **Never cut:** Easy mode, stability + range maths, launch sim, the validation table.

---

## 6. Updated prompts

**Step 2 (replaces the old Step 2):**
```
Read /docs/Sim_Spec_v2_FINAL.md (it replaces the old sim spec). Create pure GDScript sim classes in /scripts/sim, no UI:
- RocketGeometry.gd: rocket = list of segments (nose, payload, body/tanks, engine, fins, upper stages) with mass, length, position. Function to compute positions from nose tip.
- Stability.gd: Barrowman CNα and X for nose (cone/ogive/parabolic) and fins exactly as in section 2.1; X_cp; X_cg at liftoff and burnout; static margin in calibres; classification (unstable/marginal/stable/over-stable) with gimbal rule.
- RocketMath.gd: stage Δv (Tsiolkovsky), total Δv, TWR, burn time.
- MissionBudget.gd: required Δv from the Δv map + Earth rotation bonus + return legs + margin; range ratio.
- Aero.gd: Cd model and drag (section 2.5), dynamic pressure, material q limits.
- OrbitMath.gd: circular velocity, period, vis-viva, Hohmann.
- RocketEvaluator.gd: takes a full design (real units), returns a report with every check: name, value, threshold, pass/warn/fail, and a plain-English reason string + a technical reason string.
Then a test scene that evaluates a Redstone-class reference rocket and prints the full report, and unit tests for: Barrowman with a known textbook model rocket example, a Hohmann 200→400 km (~58 + ~57 m/s), and Tsiolkovsky.
```

**Step 3 (replaces the old Step 3):**
```
Build the Rocket Builder with three input modes from section 3 of /docs/Sim_Spec_v2_FINAL.md, all producing the same real-unit design for RocketEvaluator:
- Easy: descriptive preset buttons per part with pictures (Pointy/Rounded/Fat nose, Small/Medium/Large fins, etc.) from /data/presets.json, each mapping to real-unit values
- Medium: 0–1 sliders mapped to min/max around the level's reference rocket (0.5 = reference), from /data/reference_rockets.json
- Hard: numeric fields in real units
The mode is switchable at any time; switching converts the current design (Easy→Medium→Hard keeps the same real values).
Draw the rocket procedurally from the numbers (2D side view: cylinder, nose shape, fins) with CG (blue) and CP (red) markers updating live. Results panel: Easy = ✓/✗ + plain reason, Medium = 0–1 gauges, Hard = raw values + formulas. 1960s console styling.
```
