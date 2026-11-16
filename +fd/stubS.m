function S = stubS(d, sub, f)
%FD.STUBS  Circuit model of a line with shunt stubs (RF PCB Toolbox filterStub).
%   d fields (m): n stubs; W0 series-line width; seg 1x(n-1) line lengths
%   between stubs; Ws, Ls 1xn stub widths and lengths (Ls measured from the
%   series-line centre to the stub tip, as in filterStub); short 1xn
%   (true = via to ground at the tip, via diameter = Ws/2 as in the
%   toolbox); Wp, Lp port lines.
%   T-junction and width-step parasitics are neglected.
f = f(:).';
[Z0, e0, a0] = fd.msl(d.W0, sub, f);
[Zp, ep, ap] = fd.msl(d.Wp, sub, f);
n = d.n; nodes = 1:n; nn = n + 2; P1 = n + 1; P2 = n + 2;
el = fd.el('line', [P1 1], 'Zc', Zp, 'ee', ep, 'alpha', ap, 'len', d.Lp);
el(end+1) = fd.el('line', [n P2], 'Zc', Zp, 'ee', ep, 'alpha', ap, 'len', d.Lp);
for i = 1:n-1
    el(end+1) = fd.el('line', [nodes(i) nodes(i+1)], 'Zc', Z0, 'ee', e0, 'alpha', a0, 'len', d.seg(i)); %#ok<AGROW>
end
w = 2*pi*f;
dLs = 0; if isfield(d, 'dLs'), dLs = d.dLs; end   % EM calibration: T-junction/end
kV = 1;  if isfield(d, 'kV'),  kV = d.kV;  end    % EM calibration: via inductance
for i = 1:n
    [Zs, es, as] = fd.msl(d.Ws(i), sub, f);
    if d.short(i)
        nn = nn + 1; v = nn;
        el(end+1) = fd.el('line', [nodes(i) v], 'Zc', Zs, 'ee', es, 'alpha', as, 'len', d.Ls(i) + dLs); %#ok<AGROW>
        Lv = kV*fd.viaL(d.Ws(i)/2, sub.h);
        el(end+1) = fd.el('shunt', v, 'Y', 1./(1j*w*Lv)); %#ok<AGROW>
    else
        el(end+1) = fd.el('stub', nodes(i), 'Zc', Zs, 'ee', es, 'alpha', as, ...
            'len', d.Ls(i) + dLs + fd.openEnd(d.Ws(i), sub)); %#ok<AGROW>
    end
end
S = fd.circuitS(el, nn, [P1 P2], f, 50);
end
