function S = sirS(d, sub, f)
%FD.SIRS  Circuit-model S-parameters of a stepped-impedance lowpass filter.
%   Cascade of port line, alternating low-Z / high-Z lines, port line.
%   Step-width discontinuities are neglected.
f = f(:).';
[ZL, eL, aL] = fd.msl(d.WL, sub, f);
[ZH, eH, aH] = fd.msl(d.WH, sub, f);
[Zp, ep, ap] = fd.msl(d.Wp, sub, f);
el = fd.el('line', [1 2], 'Zc', Zp, 'ee', ep, 'alpha', ap, 'len', d.Lp);
for i = 1:d.n
    if mod(i, 2), Z = ZL; e = eL; a = aL; else, Z = ZH; e = eH; a = aH; end
    el(end+1) = fd.el('line', [i+1 i+2], 'Zc', Z, 'ee', e, 'alpha', a, 'len', d.len(i)); %#ok<AGROW>
end
el(end+1) = fd.el('line', [d.n+2 d.n+3], 'Zc', Zp, 'ee', ep, 'alpha', ap, 'len', d.Lp);
S = fd.circuitS(el, d.n+3, [1 d.n+3], f, 50);
end
