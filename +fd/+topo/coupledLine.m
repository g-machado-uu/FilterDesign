function T = coupledLine()
%FD.TOPO.COUPLEDLINE  Edge-coupled (parallel-coupled half-wave) bandpass.
T = fd.topo.base();
T.id = 'coupledLine'; T.name = 'Edge-coupled lines'; T.kind = 'BP';
T.blurb = ['The textbook microstrip bandpass (Cohn 1958): a staircase of ' ...
    'quarter-wave coupled-line sections, each acting as an admittance ' ...
    'inverter between half-wave resonators. Easy to understand and design ' ...
    'in closed form; long, and the first/last gaps get very small for wide ' ...
    'bands. Spurious passband at 2 f0.'];
T.defaults = struct('f1', 2.7e9, 'f2', 3.1e9, 'n', 3, 'type', 'Chebyshev', ...
    'ripple', 0.1, 'fs', 3.5e9, 'As', 20);
T.orderLim = [1 9];
T.synth   = @synth;
T.model   = @(d, sub, f) fd.coupledLineS(d, sub, f);
T.toolbox = @(d, sub) fd.toToolbox('coupledLine', d, sub);
T.fgrid   = @fd.topo.common.fgridBP;
T.ideal   = @fd.topo.common.idealBP;
T.pack    = @pack;
T.tune    = @tune;
T.dims    = @dims;
T.steps   = @steps;
T.warn    = @warn;
T.em      = 'section';
T.emSection = @emSection;
T.calSpec = struct('field', {'kS', 'dL'}, 'x0', {1, 0}, 'lb', {0.4, -2e-3}, 'ub', {2, 2e-3}, 'scale', {1, 1e-3});
end

function [obj, dSec, f, info] = emSection(d, sub, spec)
% the first (tightest) coupled section, twice: a 1-pole filter
f0 = sqrt(spec.f1*spec.f2); B = spec.f2 - spec.f1;
dSec = d; dSec.n = 1; dSec.W = d.W([1 1]); dSec.s = d.s([1 1]); dSec.L = d.L([1 1]);
dSec.Lp = max(4e-3, 2*sub.h);
for c = {'kS', 'dL'}, if isfield(dSec, c{1}), dSec = rmfield(dSec, c{1}); end, end
obj = fd.toToolbox('coupledLine', dSec, sub);
f = linspace(f0 - 1.5*B, f0 + 1.5*B, 7);
[obj, info] = fd.emPrepare(obj, sub, f0);
end

function [d, I] = synth(spec, sub)
c0 = 299792458; Z0 = 50;
f0 = sqrt(spec.f1*spec.f2); FBW = (spec.f2 - spec.f1)/f0; n = spec.n; K = n + 1;
g = fd.prototype(n, spec.type, spec.ripple);
J = zeros(1, K);
J(1) = sqrt(pi*FBW/(2*g(1)*g(2)));
for j = 2:n, J(j) = pi*FBW/(2*sqrt(g(j)*g(j+1))); end
J(K) = sqrt(pi*FBW/(2*g(n+1)*g(n+2)));
Ze = Z0*(1 + J + J.^2); Zo = Z0*(1 - J + J.^2);
W = zeros(1, K); s = W; L = W; got = zeros(K, 2);
half = ceil(K/2);
for k = 1:half                                   % symmetric: solve half
    [W(k), s(k), got(k, :)] = fd.cmslInverse(Ze(k), Zo(k), sub, spec.minGap);
    W(K+1-k) = W(k); s(K+1-k) = s(k); got(K+1-k, :) = got(k, :);
end
for k = 1:K
    m = fd.cmsl(W(k), s(k), sub, f0);
    L(k) = c0/(4*f0*sqrt((m.ee + m.eo)/2)) - fd.openEnd(W(k), sub);
end
[~, ~, ~, Qu] = fd.msl(mean(W), sub, f0);
d = struct('n', n, 'W', W, 's', s, 'L', L, 'Wp', fd.mslWidth(Z0, sub, f0), 'Lp', max(5e-3, 3*sub.h));
I = struct('f0', f0, 'FBW', FBW, 'g', g, 'J', J, 'Ze', Ze, 'Zo', Zo, 'got', got, ...
    'Qu', Qu, 'ILest', 4.343*sum(g(2:n+1))/(FBW*Qu), 'gapLimited', abs(got(:,2).' - Zo) > 0.02*Zo);
end

function [x0, lb, ub, unpack] = pack(d, sub, spec, ~)
K = d.n + 1; h = ceil(K/2);
x0 = [d.L(1:h), d.s(1:h)]*1e3;
lb = [0.85*d.L(1:h), repmat(spec.minGap, 1, h)]*1e3;
ub = [1.15*d.L(1:h), max(3*d.s(1:h), 2*sub.h)]*1e3;
x0 = min(max(x0, lb), ub);
    function dd = un(x)
        x = x*1e-3; dd = d; Lh = x(1:h); sh = x(h+1:2*h);
        dd.L = [Lh, fliplr(Lh(1:K-h))]; dd.s = [sh, fliplr(sh(1:K-h))];
    end
unpack = @un;
end

function rows = tune(d, spec, sub)
rows = cell(0, 6); K = d.n + 1;
for k = 1:K
    rows(end+1, :) = {sprintf('Section %d length', k), 'L', k, 0.8*d.L(k), 1.2*d.L(k), true}; %#ok<AGROW>
end
for k = 1:K
    rows(end+1, :) = {sprintf('Section %d gap', k), 's', k, spec.minGap, max(4*d.s(k), 2*sub.h), true}; %#ok<AGROW>
end
end

function c = dims(d, ~, ~)
mm = @(x) round(x*1e3, 3);
c = {'Port line width', mm(d.Wp), '50 Ω feed line'; 'Port line length', mm(d.Lp), 'Feed line'};
for k = 1:d.n + 1
    c(end+1, :) = {sprintf('Section %d width', k), mm(d.W(k)), 'Both strips of this coupled section'}; %#ok<AGROW>
    c(end+1, :) = {sprintf('Section %d gap', k), mm(d.s(k)), 'Edge-to-edge (sets the inverter J)'}; %#ok<AGROW>
    c(end+1, :) = {sprintf('Section %d length', k), mm(d.L(k)), 'Coupled length (quarter wave minus open end)'}; %#ok<AGROW>
end
end

function L = steps(d0, I, s, sub)
L = {'STEP 1 - Specification', sprintf('  f0 = %.4f GHz, FBW = %.4f', I.f0/1e9, I.FBW), ...
     sprintf('STEP 2 - Prototype (%s, n = %d): g = %s', s.type, s.n, mat2str(round(I.g, 4))), ...
     'STEP 3 - Admittance inverters (Hong & Lancaster eq. 5.15)', ...
     '  J01/Y0 = sqrt(pi FBW/(2 g0 g1)),  Jj,j+1/Y0 = pi FBW / (2 sqrt(gj gj+1))', ...
     sprintf('  J/Y0 = %s', mat2str(round(I.J, 4))), ...
     'STEP 4 - Even/odd impedances  Ze = Z0(1 + J + J^2),  Zo = Z0(1 - J + J^2)', ...
     sprintf('  Ze = %s Ω', mat2str(round(I.Ze, 2))), sprintf('  Zo = %s Ω', mat2str(round(I.Zo, 2))), ...
     sprintf('STEP 5 - Width and gap from a 2D field solution on %s h=%.2f mm', sub.name, sub.h*1e3), ...
     sprintf('  W = %s mm', mat2str(round(d0.W*1e3, 3))), sprintf('  s = %s mm', mat2str(round(d0.s*1e3, 3))), ...
     '  (closed-form formulas exist, but overestimate coupling by 30-70 % for wide gaps)', ...
     'STEP 6 - Length: quarter wave at the average of the even/odd velocities, minus open end', ...
     sprintf('  L = %s mm', mat2str(round(d0.L*1e3, 3)))};
if any(I.gapLimited), L{end+1} = sprintf('  !! gaps limited to %.2f mm: achieved Zo differs from the target', s.minGap*1e3); end
L = [L, {'STEP 7 - Loss estimate', sprintf('  Qu = %.0f, IL(f0) ~ %.2f dB', I.Qu, I.ILest)}];
end

function w = warn(d, I, spec, ~)
w = {};
if any(I.gapLimited)
    w{end+1} = sprintf(['The first/last gap would need to be below %.2f mm (achieved Zo %s vs %s Ω). ' ...
        'Narrow the band, lower the order, use a thinner board, or tapped resonators (hairpin).'], ...
        spec.minGap*1e3, mat2str(round(I.got(:,2).', 1)), mat2str(round(I.Zo, 1)));
end
if I.ILest > 3, w{end+1} = sprintf('Expected insertion loss %.1f dB (Qu = %.0f).', I.ILest, I.Qu); end
if numel(d.L) && sum(d.L) > 0.15, w{end+1} = sprintf('The filter is %.0f mm long.', sum(d.L)*1e3); end
end
