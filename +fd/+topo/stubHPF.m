function T = stubHPF()
%FD.TOPO.STUBHPF  Distributed highpass: shorted stubs + quarter-wave lines.
T = fd.topo.base();
T.id = 'stubHPF'; T.name = 'Shorted-stub (distributed)'; T.kind = 'HP';
T.blurb = ['A true microstrip highpass does not exist: transmission lines ' ...
    'repeat their behaviour. This "distributed highpass" uses shorted ' ...
    'stubs that are a quarter wave at f0 = fc(1+k)/2: it passes from fc up ' ...
    'to about k*fc (the "upper edge factor" k), then stops again near 2 f0.'];
T.defaults = struct('fc', 1.0e9, 'n', 5, 'type', 'Chebyshev', 'ripple', 0.1, ...
    'fs', 0.7e9, 'As', 25);
T.orderLim = [1 9]; T.orderOdd = true;
T.params = struct('field', {'fu', 'ZsMin'}, ...
    'label', {'Upper edge factor k', 'Min stub Z (Ω)'}, 'default', {3, 12}, ...
    'lim', {[1.5 5], [5 60]}, ...
    'tip', {'Passband extends from fc to about k*fc.', 'Lowest stub impedance allowed (widest stub).'});
T.synth   = @synth;
T.model   = @(d, sub, f) fd.stubS(d, sub, f);
T.toolbox = @(d, sub) fd.toToolbox('stub', d, sub);
T.fgrid   = @(spec, info) linspace(0.05, spec.fu + 1.2, 801)*spec.fc;
T.optgrid = @(spec, info) linspace(0.3, 0.95*spec.fu, 241)*spec.fc;
% the narrow-band stub formulas put a wide band too high: also start the
% optimiser from longer stubs/lines and keep the best
T.starts  = @(d, varargin) arrayfun(@(k) scaleLen(d, k), [1.1 1.2 1.3], 'UniformOutput', false);
T.ideal   = @(spec, info, f) ladder(spec, info, f);
T.pack    = @(d, sub, spec, info) fd.topo.common.stubPack(d, sub, spec, info, {'Ls', 'Ws', 'seg'});
T.tune    = @fd.topo.common.stubTune;
T.dims    = @(d, spec, sub) fd.topo.common.stubDims(d, '50 Ω line');
T.steps   = @steps;
T.warn    = @warn;
T.em      = 'section';
T.emSection = @(d, sub, spec) fd.topo.common.stubSection(d, sub, spec, 'HP');
T.calSpec = struct('field', {'dLs', 'kV'}, 'x0', {0, 1}, 'lb', {-3e-3, 0.2}, 'ub', {3e-3, 5}, 'scale', {1e-3, 1});
end

function [d, info] = synth(spec, sub)
f0 = spec.fc*(1 + spec.fu)/2; FBW = 2*(f0 - spec.fc)/f0;
g = fd.prototype(spec.n, spec.type, spec.ripple);
[d, info] = fd.topo.common.stubQW(f0, FBW, g, true, sub, [spec.ZsMin 150]);
end

function S = ladder(spec, info, f)
[a, b] = fd.idealLadder(info.g, 'HP', f, spec.fc); S = [a; b];
end

function L = steps(d0, I, s, ~)
L = {'STEP 1 - Map the highpass onto a very wide bandpass', ...
     sprintf('  passband fc .. k fc = %.3f .. %.3f GHz  ->  f0 = fc(1+k)/2 = %.3f GHz, FBW = %.2f', ...
        s.fc/1e9, s.fu*s.fc/1e9, I.f0/1e9, I.FBW), ...
     sprintf('STEP 2 - Prototype (%s, n = %d): g = %s', s.type, s.n, mat2str(round(I.g, 4))), ...
     'STEP 3 - Shorted quarter-wave stubs, Zs_i = pi FBW Z0 / (4 g_i)', ...
     sprintf('  Zs = %s Ω, widths %s mm', mat2str(round(I.Zs, 1)), mat2str(round(d0.Ws*1e3, 2))), ...
     sprintf('STEP 4 - Stubs %s mm, 50 Ω lines %.2f mm (quarter-wave at f0)', mat2str(round(d0.Ls*1e3, 2)), d0.seg(1)*1e3), ...
     'STEP 5 - Optimise against the ideal LC highpass up to 0.95 k fc.', ...
     'NOTE - above ~(2k-1) fc... the stubs become half-wave and the filter stops again.'};
end

function w = warn(~, I, s, ~)
w = {sprintf(['Distributed highpass: usable passband ends near %.2f GHz ' ...
    '(the stubs are half a wavelength at %.2f GHz).'], s.fu*s.fc/1e9, 2*I.f0/1e9)};
if any(I.clipped), w{end+1} = 'Some stub impedances were clipped to realisable widths.'; end
end

function d = scaleLen(d, k)
d.Ls = k*d.Ls; d.seg = k*d.seg;
end
