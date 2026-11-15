# THE INHERITANCE — Mission Sim Technical Spec
*The engineering core. Real formulas, simplified where needed. All numbers are ballpark: have your research person verify them against NASA sources before submission.*

---

## 0. Design Philosophy
- **Real physics, real calculations.** People who know orbital mechanics should be able to plan a mission on paper and have the game agree with them.
- **Layered difficulty.** The same sim underneath, but how much the game helps you changes:

| Mode | Who it's for | What the game does |
|---|---|---|
| **Cadet** | Beginners, kids | Auto-calculates Δv, power and data. Shows green/red bars. Tooltips explain each concept. |
| **Engineer** (default) | Students who know some physics | Shows the formulas and inputs. The player picks parts and the game computes, but the player must plan the Δv budget and burn sequence themselves. |
| **Flight Director** | People who actually know stuff | No auto-totals. The player enters their own calculated values (burn Δv, orbit altitude, launch window, battery size) into the mission plan. The sim runs the *real* physics, so wrong maths = wrong outcome. An in-game **slide rule / engineer's notebook** calculator is available, period-style. |

Story is identical in all modes. Mode can be changed anytime.

---

## 1. Rocket Design (stage builder)

The player builds a rocket stage by stage from **engines + tanks + structure**.

### Core formulas
- **Tsiolkovsky rocket equation:** Δv = Isp · g₀ · ln(m₀ / m_f)
  - g₀ = 9.80665 m/s²
  - m₀ = wet mass of everything above and including this stage; m_f = same minus this stage's propellant
- **Total Δv** = sum of all stage Δv values
- **Thrust-to-weight (TWR)** = Thrust / (m₀ · g). First stage must be **> 1.2** or it can't lift off. Upper stages need > ~0.5.
- **Burn time** = m_propellant · Isp · g₀ / Thrust

### Engine catalog (60s-style, values inspired by real engines)
| Engine | Thrust | Isp (sea level / vacuum) | Mass | Cost | Unlock | Notes |
|---|---|---|---|---|---|---|
| **Redstone-class** (alcohol/LOX) | 350 kN | 215 / 235 s | 0.7 t | $ | L1 | Cheap, weak |
| **Kerosene booster** (RP-1/LOX) | 1,500 kN | 260 / 295 s | 1.8 t | $$ | L1 | Workhorse first stage |
| **Hypergolic upper** | 450 kN | — / 310 s | 0.6 t | $$ | L2 | Restartable, reliable, toxic |
| **Hydrogen upper** (LH₂/LOX) | 900 kN | — / 420 s | 1.6 t | $$$ | L4 | Best efficiency; tanks are bulky |
| **Heavy booster** | 6,700 kN | 265 / 300 s | 8.4 t | $$$$ | L5 | Moon-class only |
| **Small lander engine** | 45 kN | — / 310 s | 0.15 t | $ | L5 | Throttleable |

### Tanks
- Fuel/oxidizer tanks have a **dry-mass ratio**: tank mass ≈ 5–8% of propellant mass (hydrogen tanks ≈ 10–12%, since LH₂ is low density).
- Sizes: S / M / L / XL, or a slider for custom propellant mass.

### Structure / extras
Interstage, fairing (protects payload; jettisoned), escape tower (crewed missions only; adds mass, saves the crew on a launch failure).

---

## 2. Δv Budget & Orbits

### Δv map (Earth–Moon, approximate)
| Leg | Δv (m/s) |
|---|---|
| Ground → Low Earth Orbit (~200 km), incl. gravity + drag losses | ~9,400 |
| LEO → raise orbit | via Hohmann (see below) |
| LEO → Trans-Lunar Injection | ~3,150 |
| Lunar orbit insertion | ~850 |
| Lunar descent & landing | ~2,000 |
| Lunar ascent to orbit | ~1,850 |
| Trans-Earth injection | ~950 |
| Earth re-entry | 0 (aerobraking; needs a heat shield) |

**Launch site bonus:** launching east from a low-latitude site gives free Δv from Earth's spin: v = 465 · cos(latitude) m/s (Cape Canaveral, 28.5° → ~408 m/s). Polar orbits don't get this bonus, and retrograde costs extra.

### Orbital mechanics formulas
- μ (Earth) = 3.986 × 10¹⁴ m³/s², Earth radius R = 6,371 km
- **Circular orbit speed:** v = √(μ / r), where r = R + altitude
- **Orbital period:** T = 2π · √(r³ / μ)
- **Vis-viva:** v = √(μ · (2/r − 1/a))
- **Hohmann transfer** (r₁ → r₂):
  - Δv₁ = √(μ/r₁) · (√(2r₂/(r₁+r₂)) − 1)
  - Δv₂ = √(μ/r₂) · (1 − √(2r₁/(r₁+r₂)))
- **Plane change:** Δv = 2v · sin(Δi/2). Very expensive, which is a good lesson.

### Orbit options (with trade-offs)
| Orbit | Altitude | Period | Lifetime (drag, rough) | Pros | Cons |
|---|---|---|---|---|---|
| **Very Low** | 200 km | ~88 min | days–weeks | Cheapest | Decays fast |
| **Low** | 400 km | ~92 min | ~1–2 years | Good balance | Some drag |
| **Medium-Low** | 800 km | ~101 min | decades | Long life | More Δv; more radiation |
| **Polar** | 600–800 km | ~97–101 min | years+ | Covers the whole Earth | No spin bonus |
| **High Elliptical** | 500 × 40,000 km | ~12 h | years | Long comms windows over one region | Lots of Δv; passes through radiation belts |

**Lifetime model:** use a simple lookup table by altitude, modified by spacecraft mass/area (heavy, compact = lasts longer). Optional: solar activity events shorten it.

---

## 3. Spacecraft Subsystems

### 3.1 Power
- **Solar panels:** P = 1,361 W/m² × area × efficiency × cos(angle)
  - 60s silicon cells ≈ 10% efficient → ~136 W/m² max, ~35 kg per kW of panels (rough)
- **Eclipse:** in LEO, ~35 min of each ~90 min orbit is in Earth's shadow. Panels make 0 W in the shadow.
- **Batteries:** must cover load × eclipse time, with depth-of-discharge limits.
  - Battery needed (Wh) = Load (W) × Eclipse time (h) / DoD (use 0.3–0.5 to keep 60s batteries alive)
  - 60s silver-zinc / nickel-cadmium: ~30–100 Wh/kg
- **Fuel cells** (L4+): high power, no sunlight needed, but they consume reactants (mass that runs out → limits mission duration). Produce water as a bonus for crewed missions.
- **Rule:** average generation ≥ average load, and the battery covers every eclipse. Otherwise systems shut down in the sim.

### 3.2 Communications & Data
- **Ground station passes:** in LEO, a station sees the spacecraft for ~5–12 min per pass, a few passes per day.
- **Data downlinked per pass** = data rate × pass time
- **Data generated** = Σ (instrument data rate × operating time)
- **Storage:** tape recorder capacity (60s style: a few MB). If storage fills between passes, extra data is lost.
- **Rule:** data generated ≤ storage + downlink capacity, or science is lost.
- More ground stations cost money but add passes. Higher orbits give longer passes, but the signal gets weaker (lower data rate).
- **Optional (Flight Director):** simplified link budget, where data rate falls with distance² and rises with antenna size and transmitter power.

### 3.3 Instruments
| Instrument | Mass | Power | Data rate | Science value | Notes |
|---|---|---|---|---|---|
| Radiation counter (Geiger) | 2 kg | 1 W | low | ★ | Cheap, classic |
| Magnetometer | 3 kg | 3 W | low | ★★ | Needs a boom (more mass) |
| Micrometeorite detector | 4 kg | 2 W | low | ★ | |
| Film camera | 25 kg | 15 W | — (film canister returned physically) | ★★★ | Needs a return capsule |
| TV camera | 15 kg | 30 W | HIGH | ★★★ | Eats comms bandwidth |
| Spectrometer | 12 kg | 20 W | medium | ★★★ | |
| Surface sampler (Moon) | 40 kg | 25 W | low | ★★★★ | Needs landing |

### 3.4 Thermal & Shielding
- **Heat shield for re-entry:** required mass scales with re-entry speed (LEO return ~7.8 km/s, lunar return ~11 km/s).
  - Simplified: shield mass ≈ k × capsule mass × (v/7.8)², tiers Thin / Standard / Heavy
- **Radiation shielding:** extra mass protects crew/electronics. High orbits and Van Allen belt passes increase dose.

### 3.5 Attitude Control & Computer
- Spin-stabilized (cheap, can't point instruments) vs 3-axis (expensive, lets cameras point; uses RCS propellant)
- **Guidance computer:** 60s computers have tiny memory. Each mission phase/instrument uses "computer words." Too many → it doesn't fit. A fun, real 60s constraint.

### 3.6 Crew systems (L3+)
- Oxygen: ~0.84 kg/person/day · Water: ~3 kg/person/day · Food: ~0.6–1.8 kg/person/day
- CO₂ scrubbers (lithium hydroxide canisters) per crew-day
- Recommended margins: +50% consumables for crewed missions (Dot will remind you)

---

## 4. Mission Planner (the "flight plan")
After building, the player writes the flight plan as a list of phases:

1. Launch (site, azimuth → inclination)
2. Orbit insertion (target altitude)
3. Burns: each with Δv, which stage/engine, and timing
4. Operations: which instruments run, for how long
5. Comms schedule (auto in Cadet/Engineer, manual in Flight Director)
6. Return / landing (if applicable)

The sim checks every phase in order: enough Δv in the stage? Enough power? Enough data space? Enough consumables? Did the shield survive?

**Flight Director mode:** the player types their own calculated Δv values. If they under-calculate, the burn falls short and the craft ends in the wrong orbit. That's what the sim shows, and the debrief shows the correct maths next to theirs.

---

## 5. Designs: Save, Load, Share
- **Blueprint library:** save any design; reload and modify it in later levels
- **Dad's blueprints:** early sketches unlock through the story and appear in the library as partial templates
- **Share code:** export a design as a short code to compare with friends (the challenge lists save/share/compare)
- **Compare view:** two designs side by side: mass, Δv, cost, science, success probability

---

## 6. Simulation Engine

1. **Validate:** mass vs rocket, TWR, Δv per phase, power balance, data balance, consumables
2. **Run the timeline:** step through phases (each orbit or day as a tick)
3. **Random events:** each part has a reliability %, rolled per phase. Redundancy (two of a part) = both must fail. Event cards from the story apply here too.
4. **Outcome:** Success / Partial / Failure + the failure type (feeds the outcome cutscenes)
5. **Debrief:**
   - Timeline graph: power, battery charge, data stored, fuel over time
   - "Where it went wrong," with the player's numbers vs what was needed
   - The real formula used
   - A "what NASA actually did" fact

**Monte Carlo option (Flight Director):** run the mission 100× to see the success probability of a design. A real engineering technique, and very satisfying.

---

## 6.5 Launch Sim: Live Mission Control

The launch isn't a canned animation. It's a **real-time physics flight using the player's exact rocket**, shown from a 1960s mission control room. The numbers on the consoles are the actual sim values.

### The room (screen layout)
- **Big wall screen:** world map / ascent trajectory plot (altitude vs downrange) drawing live, plus a small rocket camera view (brick rocket, exhaust, stage separations)
- **Consoles** (each staffed by a cast member, with live readouts):
  - **FLIGHT** (protagonist): overall status, the abort button
  - **BOOSTER** (Dot): thrust, propellant remaining per stage, engine status, TWR
  - **FIDO** (flight dynamics, Victor): altitude, velocity, downrange, flight path angle, predicted orbit (apogee/perigee)
  - **CAPCOM** (Jo on the ground, or talking to Jo on crewed flights)
  - **EECOM / power** (Sparks doubling up): bus voltage, battery charge, comms signal
  - **GUIDANCE / computer:** pitch program, guidance memory, errors
- **Clock:** T-minus / T-plus mission elapsed time
- **Time controls:** 1× / 5× / 20×, plus auto-pause on key events

### Sequence
1. **GO / NO-GO poll** (T-5 min): each console reports GO or NO-GO based on the *real* pre-flight checks (TWR, Δv margin, power, weather event card). The player can hold, scrub or proceed. A NO-GO is a warning, not a block (except physically impossible builds).
2. **Countdown:** T-10 … ignition … liftoff (only if TWR > 1). TWR just barely above 1 = slow, scary liftoff and big gravity losses.
3. **Ascent events** called out by the cast as they happen in the physics:
   - "Tower cleared"
   - "Roll program", then the pitch-over (gravity turn starts)
   - **"Max-Q"**: max aerodynamic pressure, computed live (½ρv²)
   - **Staging**: BECO/MECO when a stage's propellant hits 0 → separation → next stage ignition
   - Fairing jettison (above ~100 km)
   - **SECO / orbit insertion:** engine cutoff when target velocity is reached, or when fuel runs out
4. **Result:** FIDO reads out the achieved orbit: "Apogee 412, perigee 388. We have an orbit!" Or: "Perigee is below the atmosphere… she's coming back down."

### Physics (simple 2D, runs at ~20–50 ticks/sec)
Per tick (dt):
```
thrust    = engine.thrust (Isp & thrust blend from sea-level → vacuum with altitude)
mdot      = thrust / (Isp * g0)
mass     -= mdot * dt
gravity   = mu / r^2                      (decreases with altitude)
density   = rho0 * exp(-alt / 8500)       (exponential atmosphere)
drag      = 0.5 * density * v^2 * Cd * A
accel     = (thrust - drag)/mass along heading, minus gravity toward Earth centre
pitch     = gravity turn: vertical until ~1 km, small kick, then follow the velocity vector
            (Flight Director mode: player sets pitch-kick angle & altitude: a real skill)
position += velocity * dt;  velocity += accel * dt
add Earth's rotation bonus at launch (465*cos(lat) m/s eastward)
```
- When a stage is empty → drop its dry mass → next stage
- When velocity ≥ orbital velocity for current altitude and perigee > ~150 km → cut off → orbit achieved
- Calculate apogee/perigee from the state vector with vis-viva

This means *gravity losses, drag losses and staging efficiency come out of the physics*. Two rockets with the same Δv on paper can perform differently, which is exactly what real engineers deal with.

### Failures (from physics + reliability rolls, never scripted)
| What happens | Cause in the sim | Console callout |
|---|---|---|
| Rocket can't lift off | TWR < 1 | BOOSTER: "No liftoff! Shut it down!" |
| Falls short of orbit | Not enough Δv / bad pitch program | FIDO: "We're not going to make orbit." |
| Structural break-up at Max-Q | Too much thrust low in the atmosphere + reliability roll | Telemetry freezes to static |
| Engine-out | Reliability roll | BOOSTER: "Engine 2 is out!" (remaining engines burn longer, if enough Δv) |
| Staging failure | Reliability roll on separation | "No separation!" |
| Wrong orbit | Under/over-burn | Achieved orbit ≠ target; can be fixed with spare Δv later |

**Abort (crewed missions):** the player can hit ABORT. The escape tower or abort mode depends on the phase and the parts they included. No escape tower + launch failure = crewed abort cutscene still keeps the crew safe (story rule), but the score takes a big hit and Dot is *not* happy.

### After the launch
- The ascent plot, telemetry graphs and event log feed straight into the debrief
- The rest of the mission (orbit ops, transfers, landing) runs in a faster "mission ops" view with the same console room
- Re-entry gets its own mini-mission-control sequence: blackout (no signal for ~4 min), the tense wait, then the "Still here" moment

### 2-day scope
- **Must:** countdown, 2D physics ascent, staging, live altitude/velocity/fuel readouts, orbit-or-not result
- **Nice:** GO/NO-GO poll, character callouts, Max-Q, trajectory plot
- **Stretch:** engine-out, abort modes, player pitch program, re-entry blackout sequence

---

## 7. Worked Example (for the tutorial / pitch)
**L1 BEACON-1:** 20 kg satellite to 400 km.
- Need ~9.4 km/s to LEO (incl. losses) − ~0.4 km/s from the Cape's spin ≈ 9.0 km/s, plus a small Hohmann raise from 200 → 400 km:
  - r₁ = 6,571 km, r₂ = 6,771 km → Δv₁ ≈ 58 m/s, Δv₂ ≈ 57 m/s → ~115 m/s
- Total ≈ 9.1–9.2 km/s
- Two-stage kerosene + hypergolic rocket: check each stage with Tsiolkovsky, and check the first stage's TWR > 1.2.
- Power: radiation counter 1 W + radio 4 W + computer 2 W = 7 W. Eclipse ~0.6 h → battery ≈ 7 × 0.6 / 0.4 ≈ 10.5 Wh → ~0.2 kg (at 50 Wh/kg). Solar: needs ~7 W × (90/55) ≈ 11.5 W average → ~0.1 m² of panels.

*(Have someone double-check these numbers; they're for showing the method.)*

---

## 8. Build Priority (2 days)
1. Data: parts catalog as a JSON file (engines, tanks, orbits, instruments, power)
2. Rocket builder + Tsiolkovsky + TWR check
3. Orbit picker + Δv budget + Hohmann
4. Power + data balance
5. Sim timeline + debrief graphs
6. Cadet/Engineer modes (Flight Director manual entry is a stretch)
7. Stretch: save/share codes, Monte Carlo, crew systems, computer memory
