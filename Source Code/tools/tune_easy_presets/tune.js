# SI assistance metadata: This code used the help of SI.
const fs = require('fs');
const path = require('path');
const { J, requiredDeltaV, evaluateEasy } = require('./sim_port.js');

const presets = J('presets.json');
const byId = (arr) => Object.fromEntries(arr.map(p => [p.id, p]));
const NOSES = presets.nose, MATERIALS = presets.material;
const PAYLOAD = { length_m: 1.0, mass_kg: 20.0 };
const REQUIRED = requiredDeltaV({ profile: 'leo', target_altitude_km: 400, latitude_deg: 28.5 });
const LARGE_FINS = byId(presets.fins).large;

const round = (v, step) => Math.round(v / step) * step;
const tankMax = (L, d) => Math.PI * d * d / 4 * L * 1000 / 1.1;
function bodyGrid(Ls, ds, fills) {
  const out = [];
  for (const L of Ls) for (const d of ds) for (const f of fills) out.push({ length_m: L, diameter_m: d, propellant_mass_kg: round(f * tankMax(L, d), 100) });
  return out;
}
const BODY_GRID = {
  short_thin: bodyGrid([11, 13, 15], [1.8, 2.0, 2.2, 2.4], [0.85, 1.0]),
  medium: bodyGrid([16, 18, 20], [2.4, 2.6, 2.8, 3.0], [0.85, 1.0]),
  tall_fat: bodyGrid([21, 24, 27], [3.05, 3.2, 3.4], [0.85, 1.0]),
};
const ENGINE_CHOICES = {
  R2: { engine_id: 'redstone_class', count: 2, section_length_m: 3.5 },
  R3: { engine_id: 'redstone_class', count: 3, section_length_m: 3.5 },
  R4: { engine_id: 'redstone_class', count: 4, section_length_m: 3.5 },
  K1: { engine_id: 'kerosene_booster', count: 1, section_length_m: 4.0 },
  K2: { engine_id: 'kerosene_booster', count: 2, section_length_m: 4.0 },
  K3: { engine_id: 'kerosene_booster', count: 3, section_length_m: 4.0 },
};
const ENGINE_SLOTS = { small_cheap: ['R2', 'R3', 'R4', 'K1'], medium: ['K1', 'K2'], big_powerful: ['K2', 'K3'] };
const THRUST = { R2: 2 * 350, R3: 3 * 350, R4: 4 * 350, K1: 1500, K2: 3000, K3: 4500 };
const upperOf = (P) => ({ engine_id: 'hypergolic_upper', count: 1, section_length_m: 1.5, propellant_mass_kg: P, dry_mass_kg: round(P * 0.07, 10), propellant_density_kg_m3: 1200, ullage_factor: 1.1 });
const UPPER_GRID = { small: [4000, 5000, 6000, 7000, 8000, 9000], big: [12000, 14000, 16000, 18000, 20000, 22000] };
const UPPER_MIN_RATIO = 1.8;
const finOf = (root, span) => ({ count: 4, root_chord_m: root, tip_chord_m: root / 2, span_m: span, sweep_m: root / 2, position_from_tail_m: 0, mass_kg: round(32 * 4 * (root + root / 2) / 2 * span, 10) });
const CURRENT_FINS = byId(presets.fins);
const FIN_GRID = {
  small: [{ ...CURRENT_FINS.small, current: true }, ...[1.4, 1.8, 2.2].flatMap(r => [0.8, 1.1, 1.4].map(s => finOf(r, s)))],
  medium: [{ ...CURRENT_FINS.medium, current: true }, ...[2.4, 2.8].flatMap(r => [1.5, 1.8, 2.1].map(s => finOf(r, s)))],
};
const finArea = (f) => (f.root_chord_m + f.tip_chord_m) / 2 * f.span_m;

const UPPER_OPTS = [{ key: 'none', up: null }, ...UPPER_GRID.small.map(P => ({ key: 'S' + P, up: upperOf(P) })), ...UPPER_GRID.big.map(P => ({ key: 'B' + P, up: upperOf(P) }))];
const FIN_OPTS = [...FIN_GRID.small.map((f, i) => ({ key: 's' + i, f })), ...FIN_GRID.medium.map((f, i) => ({ key: 'm' + i, f })), { key: 'L', f: LARGE_FINS }];
function cell(body, eng, up, fins) {
  const c = { ok: 0, clean: 0, fatSmall: 0, over: 0 };
  for (const nose of NOSES) for (const mat of MATERIALS) {
    const r = evaluateEasy(nose, body, fins, eng, mat, up, PAYLOAD, REQUIRED);
    if (r.overall === 'fail') continue;
    c.ok++;
    if (r.overall === 'pass') c.clean++;
    if (nose.id === 'fat') c.fatSmall++;
    if (r.checks.stability_burnout === 'warn') c.over++;
  }
  return c;
}
const t0 = Date.now();
const CELLS = {};
let cellCount = 0;
for (const slot in BODY_GRID) {
  CELLS[slot] = BODY_GRID[slot].map(body => {
    const byEng = {};
    for (const ek of new Set(Object.values(ENGINE_SLOTS).flat())) {
      byEng[ek] = {};
      for (const u of UPPER_OPTS) { byEng[ek][u.key] = {}; for (const f of FIN_OPTS) { byEng[ek][u.key][f.key] = cell(body, ENGINE_CHOICES[ek], u.up, f.f); cellCount++; } }
    }
    return byEng;
  });
}
console.log(`Evaluated ${cellCount} cells (${cellCount * 6} rockets) in ${((Date.now() - t0) / 1000).toFixed(1)} s. Required dv ${REQUIRED.toFixed(0)} m/s.`);

const SLOTS = ['short_thin', 'medium', 'tall_fat'];
const ENG_IDS = ['small_cheap', 'medium', 'big_powerful'];
function distance(t) {
  const frac = t.ok / 486;
  let d = 0;
  d += 100 * Math.max(0, 0.15 - frac, frac - 0.25);
  d += 10 * Math.max(0, 10 - t.clean);
  d += 20 * t.bodyOk.filter(n => n === 0).length + 20 * t.engOk.filter(n => n === 0).length;
  d += 15 * t.engClean.filter(n => n === 0).length;
  d += 50 * t.bad;
  d += 5 * t.lbClean + (t.lbOver === 0 ? 5 : 0);

  d += Math.abs(frac - 0.20);
  d += 0.02 * Math.max(0, 15 - Math.min(...t.bodyOk, ...t.engOk));
  d += 0.3 * t.finsChanged;
  return d;
}
let best = null, bestFixed = null, setsScored = 0;
const engCombos = [];
for (const a of ENGINE_SLOTS.small_cheap) for (const b of ENGINE_SLOTS.medium) for (const c of ENGINE_SLOTS.big_powerful) if (THRUST[a] < THRUST[b] && THRUST[b] < THRUST[c]) engCombos.push([a, b, c]);
const smallFins = FIN_OPTS.filter(f => f.key[0] === 's'), mediumFins = FIN_OPTS.filter(f => f.key[0] === 'm');
const uS = UPPER_OPTS.filter(u => u.key[0] === 'S'), uB = UPPER_OPTS.filter(u => u.key[0] === 'B');

for (const eng of engCombos) for (const us of uS) for (const ub of uB) for (const fs_ of smallFins) for (const fm of mediumFins) {
  if (+ub.key.slice(1) < UPPER_MIN_RATIO * +us.key.slice(1)) continue;
  if (!(finArea(fs_.f) < 0.75 * finArea(fm.f) && finArea(fm.f) < 0.75 * finArea(LARGE_FINS))) continue;
  const finsChanged = (fs_.f.current ? 0 : 1) + (fm.f.current ? 0 : 1);
  const finKeys = [fs_.key, fm.key, 'L'], upKeys = ['none', us.key, ub.key];

  const per = {};
  for (const slot of SLOTS) per[slot] = CELLS[slot].map(byEng => {
    const v = { ok: 0, clean: 0, eng: [0, 0, 0], engClean: [0, 0, 0], bad: 0, lbClean: 0, lbOver: 0 };
    eng.forEach((ek, ei) => {
      for (const uk of upKeys) for (const fk of finKeys) {
        const c = byEng[ek][uk][fk];
        v.ok += c.ok; v.clean += c.clean; v.eng[ei] += c.ok; v.engClean[ei] += c.clean;
        if (uk === 'none') v.bad += c.ok;
        if (fk[0] === 's') v.bad += c.fatSmall;
        if (slot === 'tall_fat' && ei === 0) v.bad += c.ok;
        if (fk === 'L' && uk === ub.key) { v.lbClean += c.clean; v.lbOver += c.over; }
      }
    });
    return v;
  });
  const S = BODY_GRID.short_thin, M = BODY_GRID.medium, T = BODY_GRID.tall_fat;
  for (let i = 0; i < S.length; i++) for (let j = 0; j < M.length; j++) {
    if (M[j].length_m < S[i].length_m + 3 || M[j].diameter_m < S[i].diameter_m + 0.2 || M[j].propellant_mass_kg <= S[i].propellant_mass_kg) continue;
    for (let k = 0; k < T.length; k++) {
      if (T[k].length_m < M[j].length_m + 3 || T[k].diameter_m < M[j].diameter_m + 0.2 || T[k].propellant_mass_kg <= M[j].propellant_mass_kg) continue;
      const a = per.short_thin[i], b = per.medium[j], c = per.tall_fat[k];
      const t = {
        ok: a.ok + b.ok + c.ok, clean: a.clean + b.clean + c.clean, bad: a.bad + b.bad + c.bad,
        lbClean: a.lbClean + b.lbClean + c.lbClean, lbOver: a.lbOver + b.lbOver + c.lbOver,
        bodyOk: [a.ok, b.ok, c.ok], engOk: [0, 1, 2].map(e => a.eng[e] + b.eng[e] + c.eng[e]),
        engClean: [0, 1, 2].map(e => a.engClean[e] + b.engClean[e] + c.engClean[e]), finsChanged,
      };
      const d = distance(t); setsScored++;
      const cand = { d, t, sel: { bodies: [i, j, k], eng, us: us.key, ub: ub.key, fs: fs_.key, fm: fm.key } };
      if (!best || d < best.d) best = cand;
      if (finsChanged === 0 && (!bestFixed || d < bestFixed.d)) bestFixed = cand;
    }
  }
}
console.log(`Scored ${setsScored} candidate preset sets in ${((Date.now() - t0) / 1000).toFixed(1)} s total.`);

function describe(label, c) {
  const { t, sel } = c;
  const bodies = sel.bodies.map((bi, s) => ({ id: SLOTS[s], ...BODY_GRID[SLOTS[s]][bi] }));
  const fin = (k) => FIN_OPTS.find(f => f.key === k).f;
  console.log(`\n${label}  (distance ${c.d.toFixed(3)})`);
  console.log(`  success ${t.ok}/486 = ${(100 * t.ok / 486).toFixed(1)}%  clean ${t.clean}  bad ${t.bad}  Large+Big: ${t.lbClean} clean, ${t.lbOver} over-stable`);
  console.log(`  successes by body ${JSON.stringify(Object.fromEntries(SLOTS.map((s, i) => [s, t.bodyOk[i]])))}  by engine ${JSON.stringify(Object.fromEntries(ENG_IDS.map((e, i) => [e, t.engOk[i]])))}`);
  console.log(`  clean passes by engine ${JSON.stringify(Object.fromEntries(ENG_IDS.map((e, i) => [e, t.engClean[i]])))}`);
  for (const b of bodies) console.log(`  body   ${b.id.padEnd(12)} ${b.length_m} m x ${b.diameter_m} m, ${b.propellant_mass_kg} kg propellant`);
  sel.eng.forEach((ek, i) => console.log(`  engine ${ENG_IDS[i].padEnd(12)} ${ENGINE_CHOICES[ek].count} x ${ENGINE_CHOICES[ek].engine_id}`));
  console.log(`  upper  small ${sel.us.slice(1)} kg, big ${sel.ub.slice(1)} kg propellant (structure 7%)`);
  for (const [n, k] of [['small', sel.fs], ['medium', sel.fm]]) { const f = fin(k); console.log(`  fins   ${n.padEnd(12)} root ${f.root_chord_m} tip ${f.tip_chord_m} span ${f.span_m} sweep ${f.sweep_m} mass ${f.mass_kg}${f.current ? ' (unchanged)' : ''}`); }
  return { bodies, fin };
}
describe('BEST WITH FINS UNCHANGED', bestFixed);
const chosen = describe('BEST OVERALL (applied with --write)', best);

if (process.argv.includes('--write')) {
  const out = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'data', 'presets.json'), 'utf8'));
  const note = 'Tuned by tools/tune_easy_presets/tune.js for Level 1 gameplay balance (MADE UP for balance, not sourced).';
  for (const b of out.body) {
    const v = chosen.bodies.find(x => x.id === b.id);
    Object.assign(b, { length_m: v.length_m, diameter_m: v.diameter_m, propellant_mass_kg: v.propellant_mass_kg });
    b.source = `${note} Propellant is ${Math.round(100 * v.propellant_mass_kg / round(tankMax(v.length_m, v.diameter_m), 100))}% of what the tank holds at 1,000 kg/m3 with 10% ullage.`;
  }
  best.sel.eng.forEach((ek, i) => {
    const e = out.engine.find(x => x.id === ENG_IDS[i]);
    Object.assign(e, ENGINE_CHOICES[ek]);
    e.source = `Points at engines.json '${ENGINE_CHOICES[ek].engine_id}' x ${ENGINE_CHOICES[ek].count} (a cluster). Count and section length tuned by tools/tune_easy_presets/tune.js for Level 1 balance.`;
  });
  for (const [id, key] of [['small', best.sel.us], ['big', best.sel.ub]]) {
    const u = out.upper_stage.find(x => x.id === id); const P = +key.slice(1);
    u.propellant_mass_kg = P; u.dry_mass_kg = round(P * 0.07, 10);
    u.source = `${note} Structure is 7% of propellant; propellant density from tanks.json 'hypergolic'; engine from engines.json 'hypergolic_upper'.`;
  }
  for (const [id, key] of [['small', best.sel.fs], ['medium', best.sel.fm]]) {
    const f = chosen.fin(key); if (f.current) continue;
    const e = out.fins.find(x => x.id === id);
    Object.assign(e, { root_chord_m: f.root_chord_m, tip_chord_m: f.tip_chord_m, span_m: f.span_m, sweep_m: f.sweep_m, mass_kg: f.mass_kg });
    e.source = `${note} Same shape as the other presets (tip and sweep = root / 2); mass 32 kg per m2 of total planform, like the Large fins.`;
  }
  fs.writeFileSync(path.join(__dirname, '..', '..', 'data', 'presets.json'), JSON.stringify(out, null, 2) + '\n');
  console.log('\nWrote data/presets.json');
}
