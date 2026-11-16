function T = sir()
%FD.TOPO.SIR  Stepped-impedance (hi-Z / lo-Z) lowpass filter.
T = fd.topo.base();
T.id = 'sir'; T.name = 'Stepped-impedance'; T.kind = 'LP';
T.blurb = ['Alternating short wide (low-Z, acts as shunt C) and narrow ' ...
    '(high-Z, acts as series L) line sections. Simple and compact; the ' ...
    'stopband rolls off slower than the ideal LC ladder and re-opens near ' ...
    'the frequency where sections become a half wavelength.'];
T.defaults = struct('fc', 1.0e9, 'n', 5, 'type', 'Chebyshev', 'ripple', 0.1, ...
    'fs', 1.6e9, 'As', 25);
T.orderLim = [1 11]; T.orderOdd = true;
T.params = struct('field', {'ZL', 'ZH'}, 'label', {'Low Z (Ω)', 'High Z (Ω)'}, ...
    'default', {20, 110}, 'lim', {[8 45], [60 160]}, ...
    'tip', {'Impedance of the wide sections (lower = better C, but wider).', ...
            'Impedance of the narrow sections (higher = better L, but thinner).'});
T.synth   = @synth;
T.model   = @(d, sub, f) fd.sirS(d, sub, f);
T.toolbox = @(d, sub) fd.toToolbox('sir', d, sub);
T.fgrid   = @fd.topo.common.fgridLP;
T.ideal   = @(spec, info, f) ladder(info, spec, f);
T.pack    = @pack;
T.tune    = @tune;
T.dims    = @dims;
T.steps   = @steps;
T.warn    = @warn;
end

function [d, info] = synth(spec, sub)
spec.Z0 = 50;
[d, info] = fd.sirSynth(spec, sub);
end

function S = ladder(info, spec, f)
[a, b] = fd.idealLadder(info.g, 'LP', f, spec.fc); S = [a; b];
end

function [x0, lb, ub, unpack] = pack(d, ~, ~, ~)
n = d.n; nu = ceil(n/2);
x0 = d.len(1:nu)*1e3; lb = 0.3*x0; ub = 2.0*x0;
    function dd = un(x), dd = d; L = x*1e-3; dd.len = [L, fliplr(L(1:floor(n/2)))]; end
unpack = @un;
end

function rows = tune(d, ~, ~)
rows = cell(0, 6);
for i = 1:d.n
    nm = 'high-Z'; if mod(i, 2), nm = 'low-Z'; end
    rows(end+1, :) = {sprintf('Section %d (%s) length', i, nm), 'len', i, 0.3*d.len(i), 2*d.len(i), true}; %#ok<AGROW>
end
end

function c = dims(d, spec, ~)
mm = @(x) round(x*1e3, 3);
c = {'Low-Z width WL', mm(d.WL), sprintf('%.0f Ω line (acts as shunt C)', spec.ZL);
     'High-Z width WH', mm(d.WH), sprintf('%.0f Ω line (acts as series L)', spec.ZH);
     'Port line width', mm(d.Wp), '50 Ω feed line';
     'Port line length', mm(d.Lp), 'Feed line length each side'};
for i = 1:d.n
    if mod(i, 2), m = sprintf('Low-Z (C = g%d)', i); else, m = sprintf('High-Z (L = g%d)', i); end
    c(end+1, :) = {sprintf('Section %d length', i), mm(d.len(i)), m}; %#ok<AGROW>
end
end

function L = steps(d0, I, s, ~)
L = {sprintf('STEP 1 - Lowpass prototype (%s, n = %d), fc = %.3f GHz', s.type, s.n, s.fc/1e9), ...
     sprintf('  g = %s', mat2str(round(I.g, 4))), 'STEP 2 - Element values (Z0 = 50 Ω)'};
for i = 1:s.n
    if I.isC(i), L{end+1} = sprintf('  C%d = g%d/(Z0 wc) = %.3f pF', i, i, I.g(i+1)/(50*2*pi*s.fc)*1e12); %#ok<AGROW>
    else,        L{end+1} = sprintf('  L%d = g%d Z0/wc = %.3f nH', i, i, I.g(i+1)*50/(2*pi*s.fc)*1e9); end %#ok<AGROW>
end
L{end+1} = sprintf('STEP 3 - Lines: low Z = %.1f Ω (W = %.3f mm), high Z = %.1f Ω (W = %.3f mm)', I.ZL, d0.WL*1e3, I.ZH, d0.WH*1e3);
L{end+1} = 'STEP 4 - Section lengths  l = lambda_g/(2 pi) * asin(wc C ZL)  or  asin(wc L / ZH)';
L{end+1} = sprintf('  first pass                  : %s mm', mat2str(round(I.lenFirstPass*1e3, 3)));
L{end+1} = sprintf('  with neighbour correction   : %s mm', mat2str(round(d0.len*1e3, 3)));
L{end+1} = 'NOTE - short lines only approximate L and C, so the stopband';
L{end+1} = '  rolls off slower than the ideal ladder (compare the curves).';
end

function w = warn(d, I, s, ~)
w = {};
if d.WH < 0.15e-3, w{end+1} = sprintf('High-Z line is %.3f mm wide - below a safe JLCPCB track width (0.15 mm).', d.WH*1e3); end
lam = 299792458/(s.fc*sqrt(I.eL));
if d.WL > lam/8, w{end+1} = sprintf('Low-Z line is wide (%.1f mm > lambda/8): expect transverse resonances; raise Low Z.', d.WL*1e3); end
end
