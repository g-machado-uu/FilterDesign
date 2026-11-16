function S = coupledLineS(d, sub, f)
%FD.COUPLEDLINES  Circuit model of an edge-coupled (parallel-coupled) bandpass.
%   d fields (m): n (order), W, s, L (1x(n+1) per coupled section), Wp, Lp.
%   Each section is a symmetric coupled pair with its two far ends open
%   (open-end fringing added); width steps between sections are neglected.
f = f(:).';
[Zp, ep, ap] = fd.msl(d.Wp, sub, f);
K = d.n + 1; nn = 0;
    function k = node(), nn = nn + 1; k = nn; end
P1 = node(); A = node();
el = fd.el('line', [P1 A], 'Zc', Zp, 'ee', ep, 'alpha', ap, 'len', d.Lp);
for k = 1:K
    m = fd.cmsl(d.W(k), d.s(k), sub, f);
    if isfield(d, 'kS')                          % EM calibration: coupling scale
        Zm = sqrt(m.Ze .* m.Zo); m.Ze = Zm.*(m.Ze./Zm).^d.kS; m.Zo = Zm.*(m.Zo./Zm).^d.kS;
    end
    Lk = d.L(k); if isfield(d, 'dL'), Lk = Lk + d.dL; end
    [Zr, er, ar] = fd.msl(d.W(k), sub, f); dl = fd.openEnd(d.W(k), sub);
    O1 = node(); O2 = node(); B = node();
    el(end+1) = fd.el('cline', [A O1 O2 B], 'Ze', m.Ze, 'Zo', m.Zo, 'ee', m.ee, ...
        'eo', m.eo, 'ae', m.ae, 'ao', m.ao, 'len', Lk); %#ok<AGROW>
    el(end+1) = fd.el('stub', O1, 'Zc', Zr, 'ee', er, 'alpha', ar, 'len', dl); %#ok<AGROW>
    el(end+1) = fd.el('stub', O2, 'Zc', Zr, 'ee', er, 'alpha', ar, 'len', dl); %#ok<AGROW>
    A = B;
end
P2 = node();
el(end+1) = fd.el('line', [A P2], 'Zc', Zp, 'ee', ep, 'alpha', ap, 'len', d.Lp);
S = fd.circuitS(el, nn, [P1 P2], f, 50);
end
