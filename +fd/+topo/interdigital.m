function T = interdigital()
%FD.TOPO.INTERDIGITAL  Interdigital (quarter-wave, alternately grounded) bandpass.
T = fd.topo.base();
T.id = 'interdigital'; T.name = 'Interdigital'; T.kind = 'BP';
T.blurb = ['Quarter-wave resonators grounded through vias at alternate ends, ' ...
    'all side by side. Compact (half the length of a hairpin), strong ' ...
    'coupling for moderate gaps, good for 5-50 % bandwidth. The next ' ...
    'passband is at 3 f0. Each resonator couples to both neighbours.'];
T.defaults = struct('f1', 2.7e9, 'f2', 3.1e9, 'n', 5, 'type', 'Chebyshev', ...
    'ripple', 0.1, 'fs', 3.5e9, 'As', 30);
T.orderLim = [3 9]; T.orderOdd = true;
T.params = struct('field', {'Zr', 'D'}, 'label', {'Resonator Z (Ω)', 'Via Ø (mm)'}, ...
    'default', {50, 0.5}, 'lim', {[20 120], [0.3 1.5]}, ...
    'tip', {'Impedance of each resonator line (sets its width).', ...
            'Via drill diameter. Typical prototype-fab minimum: 0.3 mm.'});
T.synth   = @synth;
T.model   = @(d, sub, f) fd.interdigitalS(d, sub, f);
T.toolbox = @(d, sub) fd.toToolbox('interdigital', d, sub);
T.fgrid   = @fd.topo.common.fgridBP;
T.ideal   = @fd.topo.common.idealBP;
T.pack    = @pack;
T.tune    = @tune;
T.dims    = @dims;
T.steps   = @steps;
T.curves  = @fd.topo.common.curvesKQ;
T.warn    = @fd.topo.common.warnBP;
T.em      = 'section';
T.emSection = @emSection;
T.calSpec = struct('field', {'kS', 'dL', 'dtap'}, 'x0', {1, 0, 0}, ...
    'lb', {0.4, -2e-3, -2e-3}, 'ub', {2.0, 2e-3, 2e-3}, 'scale', {1, 1e-3, 1e-3});
end

function [d, I] = synth(spec, sub)
c0 = 299792458;
f0 = sqrt(spec.f1*spec.f2); FBW = (spec.f2 - spec.f1)/f0; n = spec.n;
g = fd.prototype(n, spec.type, spec.ripple);
M = FBW ./ sqrt(g(2:n) .* g(3:n+1));
Qe = [g(1)*g(2), g(n+1)*g(n+2)] / FBW;
W = fd.mslWidth(spec.Zr, sub, f0);
D = spec.D*1e-3;
[Zr, ee, ~, Qu] = fd.msl(W, sub, f0); lamg = c0/(f0*sqrt(ee));
d = struct('n', n, 'W', W, 'L', [], 's', zeros(1, n-1), 'tap', NaN, 'D', D, ...
    'viaOff', D/2 + 0.025e-3, 'Wp', fd.mslWidth(50, sub, f0), 'Lp', max(5e-3, 4*sub.h), ...
    'sPair', 10*sub.h);
lossless = sub; lossless.tand = 0; lossless.sigma = 1e12;
% resonator length: quarter wave, then tuned so a lone resonator sits at f0
L0 = lamg/4 + d.viaOff - fd.openEnd(W, sub); d.L = repmat(L0, 1, n);
for it = 1:6
    dd = d; dd.sPair = 25*sub.h;
    fr = mean(pairPeaks(dd, lossless, f0));
    d.L = d.L * (1 + (fr - f0)/f0);
    if abs(fr - f0)/f0 < 1e-4, break; end
end
sGrid = logspace(log10(max(0.05e-3, 0.05*sub.h)), log10(6*sub.h), 22);
kGrid = fd.topo.common.kCurve(@(s, fz) fd.interdigitalS(setf(d, 'sPair', s), lossless, fz, 'pair'), sGrid, f0);
sRaw = fd.topo.common.invert(sGrid, kGrid, M);
d.s = max(sRaw, spec.minGap);
tGrid = linspace(0.04, 0.9, 26) * d.L(1);
QeGrid = fd.topo.common.qeCurve(@(t, fz) fd.interdigitalS(setf(d, 'tap', t), lossless, fz, 'single'), tGrid, f0);
d.tap = fd.topo.common.invert(tGrid, QeGrid, Qe(1), false);
d.tap = min(max(d.tap, 0.3e-3), 0.95*d.L(1));
I = struct('f0', f0, 'FBW', FBW, 'g', g, 'M', M, 'Qe', Qe, 'W', W, 'Zr', Zr, ...
    'ee', ee, 'lamg', lamg, 'L0', L0, 'Qu', Qu, 'ILest', 4.343*sum(g(2:n+1))/(FBW*Qu), ...
    'sGrid', sGrid, 'kGrid', kGrid, 'tGrid', tGrid, 'QeGrid', QeGrid, ...
    'sRaw', sRaw, 'gapLimited', sRaw < spec.minGap, 'Lv', fd.viaL(D, sub.h));
end

function fp = pairPeaks(d, sub, f0)
fz = f0*linspace(0.5, 1.5, 4001);
S = fd.interdigitalS(d, sub, fz, 'pair'); a = abs(squeeze(S(2,1,:))).';
[~, loc] = findpeaks(a, 'SortStr', 'descend', 'NPeaks', 2); fp = fz(loc);
end

function s = setf(s, f, v), s.(f) = v; end

function [x0, lb, ub, unpack] = pack(d, sub, spec, ~)
n = d.n; ns = ceil((n-1)/2);
x0 = [d.L(1), d.L(2), d.s(1:ns), d.tap]*1e3;
lb = [0.85*d.L(1), 0.85*d.L(2), repmat(spec.minGap, 1, ns), 0.3e-3]*1e3;
ub = [1.15*d.L(1), 1.15*d.L(2), repmat(6*sub.h, 1, ns), 0.9*d.L(1)]*1e3;
x0 = min(max(x0, lb), ub);
    function dd = un(x)
        x = x*1e-3; dd = d;
        dd.L = [x(1), repmat(x(2), 1, n-2), x(1)];
        s = x(3:2+ns); dd.s = [s, fliplr(s(1:floor((n-1)/2)))];
        dd.tap = x(3+ns);
    end
unpack = @un;
end

function rows = tune(d, spec, sub)
rows = cell(0, 6);
for i = 1:d.n
    rows(end+1, :) = {sprintf('Resonator %d length', i), 'L', i, 0.8*d.L(i), 1.2*d.L(i), true}; %#ok<AGROW>
end
for i = 1:d.n - 1
    rows(end+1, :) = {sprintf('Gap s%d (res %d–%d)', i, i, i+1), 's', i, spec.minGap, max(4*d.s(i), 3*sub.h), true}; %#ok<AGROW>
end
rows(end+1, :) = {'Tap (from shorted end)', 'tap', 1, 0.3e-3, 0.9*min(d.L), false};
end

function c = dims(d, spec, ~)
mm = @(x) round(x*1e3, 3);
c = {'Strip width W', mm(d.W), sprintf('Resonator line, %.0f Ω', spec.Zr);
     'Via diameter', mm(d.D), 'Drill, one via per resonator at its grounded end';
     'Port line width', mm(d.Wp), '50 Ω feed line';
     'Port line length', mm(d.Lp), 'Feed line'};
for i = 1:d.n
    c(end+1, :) = {sprintf('Resonator %d length', i), mm(d.L(i)), 'Grounded end to open end'}; %#ok<AGROW>
end
for i = 1:d.n - 1
    c(end+1, :) = {sprintf('Gap s%d', i), mm(d.s(i)), sprintf('Edge-to-edge (sets M%d%d)', i, i+1)}; %#ok<AGROW>
end
c(end+1, :) = {'Tap', mm(d.tap), 'Feed centre from the grounded end of resonator 1 (sets Qe)'};
end

function L = steps(d0, I, s, sub)
L = fd.topo.common.stepsBPHead(I, s);
L{end+1} = 'STEP 4 - Resonator (quarter wave, shorted by a via)';
L{end+1} = sprintf('  %.0f Ω line on %s h=%.2f mm -> W = %.3f mm, eps_eff = %.3f', s.Zr, sub.name, sub.h*1e3, I.W*1e3, I.ee);
L{end+1} = sprintf('  lambda_g/4 = %.2f mm; via Ø%.2f mm has L = %.3f nH (makes it look longer)', I.lamg/4*1e3, d0.D*1e3, I.Lv*1e9);
L{end+1} = sprintf('  length tuned so one resonator resonates at f0: L = %.2f mm', d0.L(1)*1e3);
L{end+1} = 'STEP 5 - Gaps and tap from the design curves (->)';
L{end+1} = sprintf('  gaps s = %s mm', mat2str(round(d0.s*1e3, 3)));
L{end+1} = sprintf('  tap  t = %.3f mm from the grounded end', d0.tap*1e3);
if any(I.gapLimited), L{end+1} = sprintf('  !! some gaps were limited to the %.2f mm fab minimum', s.minGap*1e3); end
L = [L, fd.topo.common.stepsLoss(I)];
L{end+1} = 'NOTE - the end resonators are loaded by the feeds: Optimise lengthens/shortens them.';
end

function [obj, dSec, f, info] = emSection(d, sub, spec)
f0 = sqrt(spec.f1*spec.f2); FBW = (spec.f2 - spec.f1)/f0;
dSec = d; dSec.n = 3; dSec.L = d.L([1 2 1]); dSec.s = d.s([1 1]); dSec.Lp = min(d.Lp, 3e-3);
dSec = fd.applyCal(dSec, [], fd.topo.interdigital());
obj = fd.toToolbox('interdigital', dSec, sub);
try, obj.GroundPlaneWidth = max(dSec.L) + 6*sub.h; catch, end
f = f0*(1 + 1.6*FBW*linspace(-1, 1, 7));
[obj, info] = fd.emPrepare(obj, sub, f0);
end
