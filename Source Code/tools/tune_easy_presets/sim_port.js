# SI assistance metadata: This code used the help of SI.
const fs = require('fs');
const path = require('path');

const DATA = path.join(__dirname, '..', '..', 'data');
const J = (f) => JSON.parse(fs.readFileSync(path.join(DATA, f), 'utf8'));
const G0 = 9.80665, MU = 3.986e14, RE = 6.371e6, RHO0 = 1.225, H = 8500;

const engines = Object.fromEntries(J('engines.json').engines.map(e => [e.id, e]));
const matsJ = J('materials.json');
const materials = Object.fromEntries(matsJ.materials.map(m => [m.id, m]));
const qModel = matsJ.q_limit_model;
const noseJ = J('nose_shapes.json');
const noseShapes = Object.fromEntries(noseJ.nose_shapes.map(n => [n.id, n]));
const dragModel = noseJ.drag_model;
const noseAreal = noseJ.nose_mass_model.areal_factor;
const dvJ = J('delta_v_map.json');

function requiredDeltaV(mission) {
  const legs = Object.fromEntries(dvJ.legs.map(l => [l.id, l]));
  const prof = dvJ.mission_profiles.find(p => p.id === mission.profile);
  const out = prof.outbound_legs.reduce((a, l) => a + legs[l].delta_v_ms, 0);
  const bonus = prof.spin_bonus ? dvJ.earth_rotation.equator_speed_ms * Math.cos(mission.latitude_deg * Math.PI / 180) : 0;
  let raise = 0;
  if (prof.orbit_raise && mission.target_altitude_km > prof.parking_altitude_km) {
    const r1 = RE + prof.parking_altitude_km * 1000, r2 = RE + mission.target_altitude_km * 1000;
    raise = Math.sqrt(MU / r1) * (Math.sqrt(2 * r2 / (r1 + r2)) - 1) + Math.sqrt(MU / r2) * (1 - Math.sqrt(2 * r1 / (r1 + r2)));
  }
  return (out - bonus + raise) * (1 + dvJ.margins.default_margin_fraction);
}

function finCN(N, S, d, Cr, Ct, Xr) {
  if (N <= 0 || S <= 0) return 0;
  const R = d / 2, lf = Math.hypot(S, Xr + Ct / 2 - Cr / 2);
  return (1 + R / (S + R)) * (4 * N * (S / d) ** 2) / (1 + Math.sqrt(1 + (2 * lf / (Cr + Ct)) ** 2));
}
function finX(Xb, Xr, Cr, Ct) { const c = Cr + Ct; return Xb + (Xr / 3) * (Cr + 2 * Ct) / c + (1 / 6) * (c - Cr * Ct / c); }
const blend = (sl, vac, h) => vac - (vac - sl) * Math.exp(-Math.max(h, 0) / H);
const rho = (h) => RHO0 * Math.exp(-Math.max(h, 0) / H);

function ascentMaxQ(m0, prop, tsl, tvac, isl, ivac, cd, A, dt = 0.05) {
  if (m0 <= 0 || tsl <= 0) return { lifted: false, q: 0 };
  let m = m0, p = prop, h = 0, v = 0, qm = 0, lifted = false;
  for (let i = 0; i < 72000 && p > 0; i++) {
    const th = blend(tsl, tvac, h), isp = blend(isl, ivac, h), b = Math.min(th / (isp * G0) * dt, p);
    const g = MU / (RE + h) ** 2, dr = 0.5 * rho(h) * v * v * cd * A * Math.sign(v);
    let a = (th - dr) / m - g;
    if (h <= 0 && a < 0) a = 0; else lifted = true;
    v += a * dt; h = Math.max(h + v * dt, 0); m -= b; p -= b;
    const q = 0.5 * rho(h) * v * v;
    if (q > qm) qm = q;
  }
  return { lifted, q: qm };
}

function evaluateEasy(nose, body, fins, enginePreset, materialPreset, upper, payload, required) {
  const d = body.diameter_m, mat = materials[materialPreset.material], ns = noseShapes[nose.shape];
  const eng = engines[enginePreset.engine_id], n = enginePreset.count;
  const stages = [{
    L: body.length_m, prop: body.propellant_mass_kg, dry: Math.PI * d * body.length_m * mat.areal_density_kg_m2,
    tsl: eng.thrust_sl_N * n, tvac: eng.thrust_vac_N * n, isl: eng.isp_sl, ivac: eng.isp_vac, em: eng.mass_kg * n, eL: enginePreset.section_length_m,
  }];
  if (upper && upper.engine_id) {
    const ue = engines[upper.engine_id], uc = upper.count || 1;
    stages.push({
      L: upper.propellant_mass_kg * upper.ullage_factor / (upper.propellant_density_kg_m3 * Math.PI * d * d / 4),
      prop: upper.propellant_mass_kg, dry: upper.dry_mass_kg,
      tsl: (ue.thrust_sl_N || 0) * uc, tvac: ue.thrust_vac_N * uc, isl: ue.isp_sl || 0, ivac: ue.isp_vac, em: ue.mass_kg * uc, eL: upper.section_length_m,
    });
  }

  const segs = [];
  const Ln = nose.length_to_diameter * d, R = d / 2;
  segs.push({ st: -1, dry: Math.PI * R * Math.hypot(R, Ln) * mat.areal_density_kg_m2 * noseAreal, prop: 0, cg: ns.cg_fraction * Ln });
  let x = Ln;
  segs.push({ st: -1, dry: payload.mass_kg, prop: 0, cg: x + payload.length_m / 2 }); x += payload.length_m;
  for (let i = stages.length - 1; i >= 0; i--) {
    const s = stages[i];
    segs.push({ st: i, dry: s.dry, prop: s.prop, cg: x + s.L / 2 }); x += s.L;
    segs.push({ st: i, dry: s.em, prop: 0, cg: x + s.eL / 2 }); x += s.eL;
  }
  const len = x, finLE = len - fins.position_from_tail_m - fins.root_chord_m;
  segs.push({ st: 0, dry: fins.mass_kg, prop: 0, cg: finLE + fins.root_chord_m / 2 });
  const liftoff = segs.reduce((a, s) => a + s.dry + s.prop, 0);
  const cg = (emptyFirst) => { let m = 0, mo = 0; for (const s of segs) { const k = s.dry + (emptyFirst && s.st === 0 ? 0 : s.prop); m += k; mo += k * s.cg; } return mo / m; };

  const checks = {};
  const twr = stages[0].tsl / (liftoff * G0);
  checks.liftoff = stages[0].tsl <= 0 || twr < 1.0 ? 'fail' : twr < 1.1 ? 'warn' : 'pass';

  const cnf = finCN(fins.count, fins.span_m, d, fins.root_chord_m, fins.tip_chord_m, fins.sweep_m);
  const xcp = (2 * ns.barrowman_x_factor * Ln + cnf * finX(finLE, fins.sweep_m, fins.root_chord_m, fins.tip_chord_m)) / (2 + cnf);
  const sm0 = (xcp - cg(false)) / d, sm1 = (xcp - cg(true)) / d;
  const cls = (m) => m < 0 ? ['unstable', 'fail'] : m < 1 ? ['marginal', 'fail'] : m > 3 ? ['over_stable', 'warn'] : ['stable', 'pass'];
  checks.stability_liftoff = cls(sm0)[1];
  checks.stability_burnout = cls(sm1)[1];

  const stageDry = stages.map((_, i) => segs.filter(g => g.st === i).reduce((a, g) => a + g.dry, 0));
  const pay = segs.filter(g => g.st < 0).reduce((a, g) => a + g.dry, 0);
  let dv = 0; const m0s = [];
  for (let i = 0; i < stages.length; i++) {
    let above = pay;
    for (let j = i + 1; j < stages.length; j++) above += stageDry[j] + stages[j].prop;
    const m0 = above + stageDry[i] + stages[i].prop, mf = above + stageDry[i];
    const isp = i === 0 && stages[i].isl > 0 ? (stages[i].isl + stages[i].ivac) / 2 : stages[i].ivac;
    m0s.push(m0); dv += isp * G0 * Math.log(m0 / mf);
  }
  const ratio = dv / required;
  checks.range = ratio >= 1.1 ? 'pass' : ratio >= 1.0 ? 'warn' : 'fail';

  const alreadyFailed = Object.values(checks).includes('fail');
  if (!alreadyFailed) {
    const A = Math.PI * d * d / 4, finA = fins.count * (fins.root_chord_m + fins.tip_chord_m) / 2 * fins.span_m;
    const cd = ns.base_cd + dragModel.fin_cd_per_area_ratio * finA / A;
    const s0 = stages[0], asc = ascentMaxQ(liftoff, s0.prop, s0.tsl, s0.tvac, s0.isl, s0.ivac, cd, A);
    const ql = mat.max_q_pa * Math.min(qModel.max_factor, Math.max(qModel.min_factor, qModel.reference_fineness / (len / d)));
    checks.structure = !asc.lifted ? 'pass' : asc.q > ql ? 'fail' : asc.q > ql * qModel.warn_fraction ? 'warn' : 'pass';
  } else {
    checks.structure = 'skipped';
  }
  for (let i = 1; i < stages.length; i++) checks['upper_twr_stage_' + (i + 1)] = stages[i].tvac / (m0s[i] * G0) > 0.5 ? 'pass' : 'warn';

  const vals = Object.values(checks);
  const overall = vals.includes('fail') ? 'fail' : vals.includes('warn') ? 'warn' : 'pass';
  return { overall, checks, twr, sm0, sm1, ratio };
}

module.exports = { J, engines, requiredDeltaV, evaluateEasy };
