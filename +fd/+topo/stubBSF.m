function T = stubBSF()
%FD.TOPO.STUBBSF  Bandstop: open quarter-wave stubs on a 50-ohm line.
T = fd.topo.base();
T.id = 'stubBSF'; T.name = 'Open-stub'; T.kind = 'BS';
T.blurb = ['Open-circuited quarter-wave stubs short the line at f0 (each is a ' ...
    'series resonator to ground), spaced by quarter-wave 50 Ω lines. ' ...
    'Narrow stopbands need very high stub impedances, so this suits WIDE ' ...
    'stopbands (> ~40 %); for a narrow notch use the spurline.'];
T.defaults = struct('f1', 1.0e9, 'f2', 1.8e9, 'n', 3, 'type', 'Butterworth', ...
    'ripple', 0.1, 'fs', 1.34e9, 'As', 20);
T.orderLim = [1 9]; T.orderOdd = true;
T.params = struct('field', {'ZsMax'}, 'label', {'Max stub Z (Ω)'}, 'default', {130}, ...
    'lim', {[60 180]}, 'tip', {'Highest stub impedance allowed (narrowest stub).'});
T.synth   = @synth;
T.model   = @(d, sub, f) fd.stubS(d, sub, f);
T.toolbox = @(d, sub) fd.toToolbox('stub', d, sub);
T.fgrid   = @(spec, info) linspace(0.05, 2.0, 801)*info.f0;
T.optgrid = @(spec, info) linspace(0.3, 1.7, 241)*info.f0;
T.ideal   = @(spec, info, f) ladder(spec, info, f);
T.pack    = @(d, sub, spec, info) fd.topo.common.stubPack(d, sub, spec, info, {'Ls', 'Ws', 'seg'});
T.tune    = @fd.topo.common.stubTune;
T.dims    = @(d, spec, sub) fd.topo.common.stubDims(d, '50 Ω line (quarter-wave inverters)');
T.steps   = @steps;
T.warn    = @warn;
T.em      = 'section';
T.emSection = @(d, sub, spec) fd.topo.common.stubSection(d, sub, spec, 'BS');
T.calSpec = struct('field', {'dLs'}, 'x0', {0}, 'lb', {-3e-3}, 'ub', {3e-3}, 'scale', {1e-3});
end

function [d, info] = synth(spec, sub)
f0 = sqrt(spec.f1*spec.f2); FBW = (spec.f2 - spec.f1)/f0;
g = fd.prototype(spec.n, spec.type, spec.ripple);
[d, info] = fd.topo.common.stubQW(f0, FBW, g, false, sub, [10 spec.ZsMax]);
end

function S = ladder(spec, info, f)
[a, b] = fd.idealLadder(info.g, 'BS', f, spec.f1, spec.f2); S = [a; b];
end

function L = steps(d0, I, s, ~)
L = {'STEP 1 - Specification (f1, f2 = band edges where the attenuation equals', ...
     '  the ripple, or 3 dB for Butterworth)', ...
     sprintf('  f0 = %.4f GHz, FBW = %.3f (%.0f %%)', I.f0/1e9, I.FBW, 100*I.FBW), ...
     sprintf('STEP 2 - Prototype (%s, n = %d): g = %s', s.type, s.n, mat2str(round(I.g, 4))), ...
     'STEP 3 - Each open quarter-wave stub = series resonator to ground', ...
     '  slope x = (pi/4) Zs must equal Z0 / (FBW g_i)  ->  Zs_i = 4 Z0 / (pi FBW g_i)', ...
     sprintf('  Zs = %s Ω', mat2str(round(I.ZsRaw, 1)))};
if any(I.clipped), L{end+1} = sprintf('  clipped to realisable widths -> %s Ω', mat2str(round(I.Zs, 1))); end
L{end+1} = sprintf('STEP 4 - Stubs lambda/4 minus open-end extension: %s mm', mat2str(round(d0.Ls*1e3, 2)));
L{end+1} = sprintf('  stub widths %s mm, 50 Ω lines %.2f mm', mat2str(round(d0.Ws*1e3, 2)), d0.seg(1)*1e3);
end

function w = warn(~, I, ~, ~)
w = {};
if any(I.clipped)
    w{end+1} = sprintf(['Stopband too narrow for open stubs: ideal stub Z = %s Ω (too thin to make). ' ...
        'Clipped - the stopband will be wider than asked. For a narrow notch use the spurline.'], ...
        mat2str(round(I.ZsRaw, 0)));
end
end
