function [d, info] = hairpinSynth(spec, sub)
%FD.HAIRPINSYNTH  Synthesise a microstrip hairpin bandpass filter.
%   [d, info] = fd.hairpinSynth(spec, sub)
%   spec fields: f1, f2 (passband edges, Hz), n, type, ripple (dB),
%                Zr (resonator line impedance, ohm), slotFactor (slot = k*W),
%                minGap (m, smallest gap the fab can etch)
%   d: dimension struct used by fd.hairpinS / fd.hairpinToolbox
%   info: every intermediate number, for the teaching panel.
%
%   Steps (Hong & Lancaster, ch. 7):
%    1. Lowpass prototype g-values for the requested response.
%    2. Coupling coefficients M(i,i+1) = FBW/sqrt(g_i g_i+1) and external
%       quality factors Qe = g0 g1/FBW, Qe_out = g_n g_n+1/FBW.
%    3. Resonator: strip width W from Zr; arm length La so one hairpin
%       resonates at f0 (half a guided wavelength around the U).
%    4. Design curve k(s): two hairpins, weakly fed, resonate at f_a, f_b;
%       k = (f_b^2 - f_a^2)/(f_b^2 + f_a^2). Invert to get each gap s.
%    5. Design curve Qe(t): one hairpin tapped at t; Qe = w0*tau/4 where tau
%       is the group delay of S11 at resonance. Invert to get the tap.

f0  = sqrt(spec.f1*spec.f2);
FBW = (spec.f2 - spec.f1)/f0;
n   = spec.n;
g   = fd.prototype(n, spec.type, spec.ripple);
M   = FBW ./ sqrt(g(2:n) .* g(3:n+1));
Qe  = [g(1)*g(2), g(n+1)*g(n+2)] / FBW;

% --- resonator ------------------------------------------------------------
W  = fd.mslWidth(spec.Zr, sub, f0);
Wp = fd.mslWidth(50, sub, f0);
d  = struct('n', n, 'W', W, 'La', NaN, 'slot', spec.slotFactor*W, ...
            's', zeros(1, n-1), 'tap', [NaN NaN], 'Wp', Wp, ...
            'Lp', max(5e-3, 4*sub.h), 'sPair', 10*sub.h);
[Zr, ee, ~, Qu] = fd.msl(W, sub, f0);
lamg = 299792458/(f0*sqrt(ee));
dl = fd.openEnd(W, sub);
La0 = (lamg/2 - d.slot - 2*dl)/2;                 % centreline = lambda_g/2
if La0 < 2*W
    error('fd:hairpinSynth', 'Resonator too short - use a narrower line or smaller slot.');
end
lossless = sub; lossless.tand = 0; lossless.sigma = 1e12;

% tune La so an isolated hairpin resonates exactly at f0 (secant)
fres = @(La) pairFreqs(setfield(setfield(d, 'La', La), 'sPair', 20*sub.h), lossless, f0); %#ok<SFLD>
d.La = La0;
for it = 1:6
    fr = mean(fres(d.La));
    d.La = d.La * (1 + 1.0*(fr - f0)/f0);         % f ~ 1/length
    if abs(fr - f0)/f0 < 1e-4, break; end
end

% --- design curve k(s) ----------------------------------------------------
sGrid = logspace(log10(max(0.05e-3, 0.05*sub.h)), log10(6*sub.h), 25);
kGrid = nan(size(sGrid));
for i = 1:numel(sGrid)
    dd = d; dd.sPair = sGrid(i);
    fp = pairFreqs(dd, lossless, f0);
    if numel(fp) == 2, kGrid(i) = (fp(2)^2 - fp(1)^2)/(fp(2)^2 + fp(1)^2); end
end
ok = ~isnan(kGrid) & kGrid > 0;
s = exp(interp1(log(kGrid(ok)), log(sGrid(ok)), log(M), 'linear', 'extrap'));
sMinWarn = s < spec.minGap;
d.s = max(s, spec.minGap);

% --- design curve Qe(t) ---------------------------------------------------
armL  = d.La - d.W/2;
tGrid = linspace(0.03, 0.97, 30) * armL;
QeGrid = nan(size(tGrid));
fz = f0 * linspace(0.6, 1.4, 4001);
for i = 1:numel(tGrid)
    dd = d; dd.tap = [tGrid(i) NaN];
    S = fd.hairpinS(dd, lossless, fz, 'single');
    ph = unwrap(angle(squeeze(S(1,1,:)))).';
    tau = -gradient(ph, 2*pi*fz);
    [tmax, im] = max(tau);
    QeGrid(i) = 2*pi*fz(im) * tmax / 4;
end
okq = isfinite(QeGrid) & QeGrid > 0;
tap = interp1(log(QeGrid(okq)), tGrid(okq), log(Qe), 'linear', 'extrap');
tap = min(max(tap, 0.2e-3), armL - 0.2e-3);
d.tap = tap;

info = struct('f0', f0, 'FBW', FBW, 'g', g, 'M', M, 'Qe', Qe, ...
    'W', W, 'Zr', Zr, 'ee', ee, 'lamg', lamg, 'dl', dl, 'La0', La0, ...
    'Qu', Qu, 'ILest', 4.343*sum(g(2:n+1))/(FBW*Qu), ...
    'sGrid', sGrid, 'kGrid', kGrid, 'tGrid', tGrid, 'QeGrid', QeGrid, ...
    'sRaw', s, 'gapLimited', sMinWarn);
end

function fp = pairFreqs(d, sub, f0)
% resonant frequencies of a weakly fed hairpin pair (peaks of |S21|)
fz = f0 * linspace(0.55, 1.45, 6001);
S  = fd.hairpinS(d, sub, fz, 'pair');
a  = abs(squeeze(S(2,1,:))).';
[~, loc] = findpeaks(a, 'SortStr', 'descend', 'NPeaks', 2);
fp = sort(fz(loc));
if numel(fp) == 1, fp = [fp fp]; end
end
