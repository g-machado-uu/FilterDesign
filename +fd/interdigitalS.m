function S = interdigitalS(d, sub, f, mode)
%FD.INTERDIGITALS  Circuit model of a microstrip interdigital bandpass filter.
%   S = fd.interdigitalS(d, sub, f)            full filter (2x2xF)
%   S = fd.interdigitalS(d, sub, f, 'pair')    2 resonators, weak feeds at the
%                                              open ends (coupling extraction)
%   S = fd.interdigitalS(d, sub, f, 'single')  1 resonator tapped at d.tap (1x1xF)
%
%   d fields (m): n, W, L (1xn), s (1x(n-1)), tap (from the shorted end of
%   resonator 1; both feeds sit at the same y, as in filterInterdigital),
%   D (via diameter), viaOff (via centre to strip end), Wp, Lp.
%   Optional EM-calibration knobs: kS (coupling scale), dL (length offset),
%   dtap (tap offset).
%
%   All resonators are modelled together as N coupled lines (multi-
%   conductor line, nearest-neighbour capacitances from the field-solver
%   tables) over their common length, split at the tap plane. Resonators
%   are shorted at alternate ends through a via (Goldfarb-Pucel inductance).
if nargin < 4, mode = 'filter'; end
f = f(:).'; w = 2*pi*f;
L = d.L; if isfield(d, 'dL'), L = L + d.dL; end
tap = d.tap; if isfield(d, 'dtap'), tap = tap + d.dtap; end
switch mode
    case 'filter', N = d.n; s = d.s; Z0 = 50;
    case 'pair',   N = 2; L = [L(1) L(1)]; s = d.sPair; Z0 = 1e5;
    case 'single', N = 1; L = L(1); s = []; Z0 = 50;
end
if N > 1, [C, Ca] = fd.mtlNN(d.W, s, sub);
else
    c0 = 299792458; [Z1, e1] = fd.msl(d.W, sub, 0);
    C = sqrt(e1)/(c0*Z1); Ca = 1/(c0*Z1*sqrt(e1));
end
if isfield(d, 'kS') && N > 1                     % scale the mutual terms
    C = scaleMutual(C, d.kS); Ca = scaleMutual(Ca, d.kS);
end
[Zp, Yp] = fd.mtlMatrices(C, Ca, repmat(d.W, 1, N), sub, f);
[Zr, er, ar] = fd.msl(d.W, sub, f);
dl = fd.openEnd(d.W, sub);
Yv = 1 ./ (1j*w*fd.viaL(d.D, sub.h));

Lc = min(L); yB = -Lc/2 + d.viaOff; yT = Lc/2 - d.viaOff;
nn = 0; el = fd.el('line', [1 1]); el(:) = []; ports = [];
    function k = node(), nn = nn + 1; k = nn; end
B = zeros(1, N); M = B; Tt = B;
for i = 1:N, B(i) = node(); Tt(i) = node(); end
if strcmp(mode, 'pair')
    el(end+1) = fd.el('mtl', [B Tt], 'Zp', Zp, 'Yp', Yp, 'len', yT - yB);
else
    yTap = min(max(-L(1)/2 + tap, yB + 0.1e-3), yT - 0.1e-3);
    for i = 1:N, M(i) = node(); end
    el(end+1) = fd.el('mtl', [B M],  'Zp', Zp, 'Yp', Yp, 'len', yTap - yB);
    el(end+1) = fd.el('mtl', [M Tt], 'Zp', Zp, 'Yp', Yp, 'len', yT - yTap);
end
for i = 1:N
    e = (L(i) - Lc)/2;
    if mod(i, 2), sh = B(i); op = Tt(i); else, sh = Tt(i); op = B(i); end
    if e > 1e-6
        v = node();
        el(end+1) = fd.el('line', [sh v], 'Zc', Zr, 'ee', er, 'alpha', ar, 'len', e); %#ok<AGROW>
        el(end+1) = fd.el('shunt', v, 'Y', Yv); %#ok<AGROW>
    else
        el(end+1) = fd.el('shunt', sh, 'Y', Yv); %#ok<AGROW>
    end
    el(end+1) = fd.el('stub', op, 'Zc', Zr, 'ee', er, 'alpha', ar, 'len', e + d.viaOff + dl); %#ok<AGROW>
end
switch mode
    case 'pair'
        ports = [Tt(1) B(2)];                    % open ends (voltage maxima)
    otherwise
        [Zq, eq, aq] = fd.msl(d.Wp, sub, f);
        P1 = node(); el(end+1) = fd.el('line', [M(1) P1], 'Zc', Zq, 'ee', eq, 'alpha', aq, 'len', d.Lp + d.W/2);
        ports = P1;
        if strcmp(mode, 'filter')
            P2 = node(); el(end+1) = fd.el('line', [M(N) P2], 'Zc', Zq, 'ee', eq, 'alpha', aq, 'len', d.Lp + d.W/2);
            ports = [P1 P2];
        end
end
S = fd.circuitS(el, nn, ports, f, Z0);
end

function C = scaleMutual(C, k)
g = sum(C, 2);                                   % capacitance to ground
M = C - diag(diag(C)); M = k*M;
C = M + diag(g - sum(M, 2));
end
