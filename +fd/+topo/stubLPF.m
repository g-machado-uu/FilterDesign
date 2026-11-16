function T = stubLPF()
%FD.TOPO.STUBLPF  Quasi-lumped lowpass: high-Z line + open stubs (capacitors).
T = fd.topo.base();
T.id = 'stubLPF'; T.name = 'Open-stub (quasi-lumped)'; T.kind = 'LP';
T.blurb = ['A thin high-impedance line (series inductors) loaded with short ' ...
    'open stubs (shunt capacitors). Sharper than the stepped-impedance ' ...
    'filter for the same order because stubs make better capacitors; the ' ...
    'stubs resonate (a quarter wave) well above fc, adding attenuation poles.'];
T.defaults = struct('fc', 1.0e9, 'n', 5, 'type', 'Chebyshev', 'ripple', 0.1, ...
    'fs', 1.6e9, 'As', 25);
T.orderLim = [1 11]; T.orderOdd = true;
T.params = struct('field', {'ZH', 'Zs'}, 'label', {'Line Z (Ω)', 'Stub Z (Ω)'}, ...
    'default', {110, 30}, 'lim', {[60 160], [10 60]}, ...
    'tip', {'Impedance of the thin series line (acts as L).', ...
            'Impedance of the open stubs (acts as C). Lower = shorter stubs.'});
T.synth   = @synth;
T.model   = @(d, sub, f) fd.stubS(d, sub, f);
T.toolbox = @(d, sub) fd.toToolbox('stub', d, sub);
T.fgrid   = @fd.topo.common.fgridLP;
T.ideal   = @(spec, info, f) ladder(spec, info, f);
T.pack    = @(d, sub, spec, info) fd.topo.common.stubPack(d, sub, spec, info, {'Ls', 'seg'});
T.tune    = @fd.topo.common.stubTune;
T.dims    = @(d, spec, sub) fd.topo.common.stubDims(d, 'High-Z series line (acts as L)');
T.steps   = @steps;
T.warn    = @warn;
T.em      = 'full';
T.calSpec = struct('field', {'dLs'}, 'x0', {0}, 'lb', {-3e-3}, 'ub', {3e-3}, 'scale', {1e-3});
end

function [d, info] = synth(spec, sub)
n = spec.n; Z0 = 50; fc = spec.fc; wc = 2*pi*fc; c0 = 299792458;
g = fd.prototype(n, spec.type, spec.ripple);
WH = fd.mslWidth(spec.ZH, sub, fc); [ZH, eH] = fd.msl(WH, sub, fc); bH = wc*sqrt(eH)/c0;
Ws = fd.mslWidth(spec.Zs, sub, fc); [Zs, es] = fd.msl(Ws, sub, fc); bs = wc*sqrt(es)/c0;
nC = (n + 1)/2; Ls = zeros(1, nC); seg = zeros(1, nC - 1);
for k = 1:nC                                   % capacitors: elements 1,3,5...
    gC = g(2*k);                               % g(i+1) with i = 2k-1
    Ls(k) = atan(gC*Zs/Z0)/bs - fd.openEnd(Ws, sub) + WH/2;
end
for k = 1:nC - 1                               % inductors: elements 2,4,...
    gL = g(2*k + 1);
    a = gL*Z0/ZH;
    if a >= 1, error('fd:stubLPF', 'Line impedance too low for this filter: raise Line Z.'); end
    seg(k) = asin(a)/bH;
end
d = struct('n', nC, 'W0', WH, 'seg', seg, 'Ws', repmat(Ws, 1, nC), 'Ls', Ls, ...
    'short', false(1, nC), 'Wp', fd.mslWidth(Z0, sub, fc), 'Lp', max([5e-3, 3*sub.h, Ws/2 + 2e-3]), ...
    'er', sub.er, 'h', sub.h, 'order', n);
info = struct('g', g, 'ZH', ZH, 'Zs', Zs, 'eH', eH, 'es', es);
end

function S = ladder(spec, info, f)
[a, b] = fd.idealLadder(info.g, 'LP', f, spec.fc); S = [a; b];
end

function L = steps(d0, I, s, ~)
L = {sprintf('STEP 1 - Lowpass prototype (%s, n = %d), fc = %.3f GHz', s.type, s.n, s.fc/1e9), ...
     sprintf('  g = %s   (odd elements = shunt C = stubs, even = series L = line)', mat2str(round(I.g, 4))), ...
     sprintf('STEP 2 - Series line %.0f Ω (W = %.3f mm), stubs %.0f Ω (W = %.3f mm)', I.ZH, d0.W0*1e3, I.Zs, d0.Ws(1)*1e3), ...
     'STEP 3 - Inductor -> line length  l = asin(g Z0 / ZH) / beta', ...
     sprintf('  line lengths = %s mm', mat2str(round(d0.seg*1e3, 3))), ...
     'STEP 4 - Capacitor -> open stub   l = atan(g Zs / Z0) / beta  (minus open end, plus half the line)', ...
     sprintf('  stub lengths = %s mm (from line centre)', mat2str(round(d0.Ls*1e3, 3))), ...
     'NOTE - the stubs also load the line between them: press Optimise.'};
end

function w = warn(d, ~, ~, ~)
w = {};
if d.W0 < 0.15e-3, w{end+1} = sprintf('Series line %.3f mm is below a safe JLCPCB track width.', d.W0*1e3); end
end
