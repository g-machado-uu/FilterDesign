function [d, info] = stubQW(f0, FBW, g, isShort, sub, ZsLim)
%FD.TOPO.COMMON.STUBQW  Quarter-wave stub filter synthesis (uniform 50-ohm line).
%   Shunt quarter-wave stubs separated by quarter-wave 50-ohm lines, which
%   act as admittance/impedance inverters J = Y0 (Hong & Lancaster
%   sec. 5.2 and 6.1, simplified to equal connecting lines).
%   Shorted stubs (bandpass): each stub is a shunt parallel resonator with
%     susceptance slope b = (pi/4) Ys, and b_i = Y0 g_i / FBW
%     ->  Zs_i = pi FBW Z0 / (4 g_i)
%   Open stubs (bandstop): each stub is a shunt series resonator with
%     reactance slope x = (pi/4) Zs, and x_i = Z0 / (FBW g_i)
%     ->  Zs_i = 4 Z0 / (pi FBW g_i)
%   Stub impedances are clipped to ZsLim = [min max] (realisable widths).
Z0 = 50; n = numel(g) - 2; c0 = 299792458; w0 = 2*pi*f0;
gi = g(2:n+1);
if isShort, ZsRaw = pi*FBW*Z0 ./ (4*gi); else, ZsRaw = 4*Z0 ./ (pi*FBW*gi); end
Zs = min(max(ZsRaw, ZsLim(1)), ZsLim(2));
W0 = fd.mslWidth(Z0, sub, f0); [~, e0] = fd.msl(W0, sub, f0);
lam0 = c0/(f0*sqrt(e0));
Ws = zeros(1, n); Ls = Ws;
for i = 1:n
    Ws(i) = fd.mslWidth(Zs(i), sub, f0);
    [Zi, ei] = fd.msl(Ws(i), sub, f0); b = w0*sqrt(ei)/c0;
    if isShort
        Lv = fd.viaL(Ws(i)/2, sub.h);
        Ls(i) = (pi/2 - atan(w0*Lv/Zi))/b;          % via inductance -> shorter
    else
        Ls(i) = pi/(2*b) - fd.openEnd(Ws(i), sub);  % open-end fringing -> shorter
    end
end
d = struct('n', n, 'W0', W0, 'seg', repmat(lam0/4, 1, n-1), 'Ws', Ws, 'Ls', Ls, ...
    'short', repmat(logical(isShort), 1, n), 'Wp', W0, 'Lp', max([5e-3, 3*sub.h, max(Ws)/2 + 2e-3]), ...
    'er', sub.er, 'h', sub.h);
info = struct('f0', f0, 'FBW', FBW, 'g', g, 'ZsRaw', ZsRaw, 'Zs', Zs, ...
    'clipped', ZsRaw < ZsLim(1) | ZsRaw > ZsLim(2), 'lam0', lam0, 'e0', e0);
end
