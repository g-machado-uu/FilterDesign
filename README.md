# Microstrip Filter Designer (MATLAB)

A teaching app for designing microstrip filters without HFSS: type a specification,
see the layout, the dimensions and the response, tune the dimensions with sliders
(instant feedback), check with full-wave EM, and export Gerbers for fabrication.

```matlab
cd FilterDesign
FilterDesigner            % open the app
run tests/validateModels.m  % self-check, ~1 min, no EM
```

Requires MATLAB R2026b (tested), RF PCB Toolbox, RF Toolbox, Optimization Toolbox.
Runs on Linux, Windows and macOS.

**Manual (for students):** `manual/FilterDesignManual.pdf` (LaTeX source and
`makeFigures.m`, which regenerates the screenshots, in `manual/`).

## Topologies (12)
| Response | Topology | EM check |
|---|---|---|
| Lowpass | Stepped-impedance, open-stub (quasi-lumped) | full design |
| Highpass | Shorted-stub (distributed; passband fc..k·fc) | section (one stub) |
| Bandpass | Hairpin, interdigital, edge-coupled lines, shorted-stub (wideband) | section |
| Bandstop | Open-stub, spurline (notch) | section / full |
| Resonator | Ring, split-ring (SRR), complementary SRR (CSRR) | full + calibration |

One file per topology in `+fd/+topo/` (contract in `+fd/+topo/base.m`), listed in
`fd.topologies` (which also says why combline, cross-coupled open-loop and SIW are
left out). Bandpass coupled-resonator filters follow Hong & Lancaster (g → k, Qe →
gaps/taps via k(s), Qe(t) design curves); stub filters use quarter-wave stub
synthesis + optimisation; resonators are sized to land on f0. Example frequencies
deliberately avoid the UK 5G bands.

## Student workflow
1. **Spec** – band edges (or cutoff), response, ripple, order (*Suggest order* helps).
2. **Board** – FR4 (default) or an RF laminate (RO4350B, RO4003C, RO3003, RO3010, RT/duroid 5880, I-Tera, FR408HR, PTFE). FR4 is lossy: a narrow
   bandpass on FR4 costs several dB; the app tells you how much.
3. **Synthesise** – read the *Design steps* tab: every number from g-values to mm.
4. **Tune** – move sliders and learn: longer arms → lower frequency; smaller gaps →
   wider band; tap position → match. *Optimise* does it automatically.
5. **EM calibrate** (section topologies) – MoM of a small section (e.g. two hairpins,
   ~3 GB, ~4 min on an i7), then the circuit model is corrected to agree with EM
   ("space mapping"). **EM full design** for small designs (lowpass, spurline,
   resonators) offers the same calibration. Optimise again.
6. **Export** – dimensions CSV, design .mat, .s2p (circuit/EM), PNGs, Gerber zip
   (connectors not included – add SMA footprints at the port line ends).

## Code layout
```
FilterDesigner.m        app (programmatic uifigure), topology-agnostic
+fd/topologies.m        registry;  +fd/+topo/*.m  one file per topology
+fd/                    engine – usable from scripts without the app
  msl, mslWidth         microstrip: Hammerstad-Jensen + Kirschning-Jansen, losses
  cmsl, cmslFD          coupled lines from a 2D field solver (cached table)
  mtlFD, mtlNN, mtlMatrices  multi-conductor lines (interdigital, spurline)
  prototype, minOrder   lowpass prototypes;  idealLadder, idealBPF, idealLPF targets
  circuitS, el          nodal circuit solver ('line','stub','cline','mtl', lumped)
  *S, *Synth            circuit models and synthesis per structure
  optimiseDesign        lsqnonlin tuning (multi-start via T.starts)
  calibrate, applyCal   EM space-mapping calibration (knobs in T.calSpec)
  toToolbox, csrrPcb    RF PCB Toolbox objects (MoM, layout, Gerber)
  emPrepare, emRun, emSection   EM workflow (converged mesh, memory guard)
  writeGerber, substrates
tests/                  validateModels (fast), runSectionFR4, runEMValidation (MoM)
manual/                 LaTeX manual + screenshot script
```

## Validation (2026-11-16, R2026b)
- Microstrip Z0 vs `txlineMicrostrip`: within 0.7 %. εeff vs converged MoM:
  RO4003C 0.813 mm 2.678 vs 2.682; FR4 1.6 mm 3.493 vs 3.489.
- **RF PCB Toolbox default MoM mesh is not converged for filters**: εeff 2.19 (RO4003C)
  and 3.99 (FR4) instead of ~2.68 / 3.49, i.e. 6–10 % frequency error. Two-line tests
  converge at mesh edge ≈ λg/50; `fd.emPrepare` sets this and checks memory first.
- **Garg-Bahl coupled-line formulas** (quoted in Hong & Lancaster) overestimate
  Ze − Zo by 30–70 % for s/h > 1 compared with a 2D field solution; the app uses
  the field solver.
- Hairpin bend: centreline length puts resonance 8 % low vs converged MoM; a corner
  shortening of ≈1·W per right-angle corner fixes it (0.2 %) on RO4003C.
- FR4 5-pole design, 2-hairpin section MoM (mesh 0.91 mm, 3 GB, 7 pts, 4 min):
  calibration reduces model error from 0.31 to 0.011 (rms |S|).
- Full 5-pole FR4 hairpin at a converged mesh needs ~19 GB – too large for laptops,
  hence section-level calibration.
- All 12 topologies land on target with the circuit model (validateModels: band
  edges within 3 % of f0, resonances within 0.03 %).
- **Pending:** converged-MoM check of the 10 topologies added in milestone 2
  (`tests/runEMValidation.m`, ~1 h). Run it only on a stable machine.

## Limits of the circuit model
Neglects coupling between non-adjacent resonators, feed-to-feed leakage, and
T-junction/step parasitics (partly absorbed by EM calibration). Far stopbands
look deeper than reality. FR4 Dk varies ±0.2 lot to lot: fabricate a test
resonator first if frequency accuracy matters.

## Memory safety
MoM memory grows quickly with mesh density (the substrate is volume-meshed).
Every EM action estimates memory first and refuses above 40 % of free RAM (max 12 GB).
