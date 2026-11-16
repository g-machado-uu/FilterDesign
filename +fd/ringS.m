function S = ringS(d, sub, f)
%FD.RINGS  Gap-coupled microstrip ring resonator (resonatorRing).
%   d fields (m): Rout outer radius, Wr ring width, gap feed-to-ring gap,
%   Wp, Lp feed lines. The ring is two half-rings (pi*Rmean each, curvature
%   neglected) between the two feed points; each feed couples through a
%   series gap capacitance (fd.gapC) - this sets the loaded Q, not f0.
f = f(:).'; w = 2*pi*f;
Rm = d.Rout - d.Wr/2;
if isfield(d, 'kR'), Rm = Rm*d.kR; end           % EM calibration (curvature etc.)
[Zr, er, ar] = fd.msl(d.Wr, sub, f); [Zp, ep, ap] = fd.msl(d.Wp, sub, f);
Cg = fd.gapC(min(d.Wp, d.Wr), d.gap, sub);
if isfield(d, 'kC'), Cg = Cg*d.kC; end
P1 = 1; E1 = 2; R1 = 3; R2 = 4; E2 = 5; P2 = 6;
lp = @(a, b) fd.el('line', [a b], 'Zc', Zp, 'ee', ep, 'alpha', ap, 'len', d.Lp);
arc = @() fd.el('line', [R1 R2], 'Zc', Zr, 'ee', er, 'alpha', ar, 'len', pi*Rm);
el = [lp(P1, E1), lp(E2, P2), arc(), arc(), ...
      fd.el('series', [E1 R1], 'Y', 1j*w*Cg), fd.el('series', [R2 E2], 'Y', 1j*w*Cg), ...
      fd.el('stub', E1, 'Zc', Zp, 'ee', ep, 'alpha', ap, 'len', 0.5*fd.openEnd(d.Wp, sub)), ...
      fd.el('stub', E2, 'Zc', Zp, 'ee', ep, 'alpha', ap, 'len', 0.5*fd.openEnd(d.Wp, sub))];
S = fd.circuitS(el, 6, [P1 P2], f, 50);
end
