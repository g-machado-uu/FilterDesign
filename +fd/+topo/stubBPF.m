function T = stubBPF()
%FD.TOPO.STUBBPF  Wideband bandpass: shorted quarter-wave stubs.
T = fd.topo.base();
T.id = 'stubBPF'; T.name = 'Shorted-stub (wideband)'; T.kind = 'BP';
T.blurb = ['Quarter-wave stubs shorted to ground with vias, joined by ' ...
    'quarter-wave 50 Ω lines. Each stub is a parallel resonator. Suited to ' ...
    'WIDE bands (> ~40 %): for narrow bands the stubs become impractically ' ...
    'wide. The response repeats at 3 f0.'];
T.defaults = struct('f1', 0.8e9, 'f2', 1.6e9, 'n', 3, 'type', 'Chebyshev', ...
    'ripple', 0.1, 'fs', 0.5e9, 'As', 20);
T.orderLim = [1 9]; T.orderOdd = true;
T.params = struct('field', {'ZsMin'}, 'label', {'Min stub Z (Ω)'}, 'default', {12}, ...
    'lim', {[5 60]}, 'tip', {'Lowest stub impedance allowed (widest stub).'});
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
T.emSection = @(d, sub, spec) fd.topo.common.stubSection(d, sub, spec, 'BP');
T.calSpec = struct('field', {'dLs', 'kV'}, 'x0', {0, 1}, 'lb', {-3e-3, 0.2}, 'ub', {3e-3, 5}, 'scale', {1e-3, 1});
end

function [d, info] = synth(spec, sub)
f0 = sqrt(spec.f1*spec.f2); FBW = (spec.f2 - spec.f1)/f0;
g = fd.prototype(spec.n, spec.type, spec.ripple);
[d, info] = fd.topo.common.stubQW(f0, FBW, g, true, sub, [spec.ZsMin 150]);
end

function S = ladder(spec, info, f)
[a, b] = fd.idealLadder(info.g, 'BP', f, spec.f1, spec.f2); S = [a; b];
end

function L = steps(d0, I, s, ~)
L = {'STEP 1 - Specification', ...
     sprintf('  f0 = %.4f GHz, FBW = %.3f (%.0f %%)', I.f0/1e9, I.FBW, 100*I.FBW), ...
     sprintf('STEP 2 - Prototype (%s, n = %d): g = %s', s.type, s.n, mat2str(round(I.g, 4))), ...
     'STEP 3 - Each shorted quarter-wave stub = shunt parallel resonator', ...
     '  slope b = (pi/4)/Zs must equal Y0 g_i / FBW  ->  Zs_i = pi FBW Z0 / (4 g_i)', ...
     sprintf('  Zs = %s Ω', mat2str(round(I.ZsRaw, 1)))};
if any(I.clipped), L{end+1} = sprintf('  clipped to realisable widths -> %s Ω', mat2str(round(I.Zs, 1))); end
L{end+1} = 'STEP 4 - Lengths: quarter-wave at f0';
L{end+1} = sprintf('  connecting 50 Ω lines lambda_g/4 = %.2f mm', d0.seg(1)*1e3);
L{end+1} = sprintf('  stubs (shortened for the via inductance) = %s mm', mat2str(round(d0.Ls*1e3, 2)));
L{end+1} = sprintf('  stub widths = %s mm', mat2str(round(d0.Ws*1e3, 2)));
L{end+1} = 'NOTE - the simple formula is exact only for narrow bands: press Optimise.';
end

function w = warn(d, I, ~, ~)
w = {};
if any(I.clipped)
    w{end+1} = sprintf(['The band is too narrow for stubs: ideal stub Z = %s Ω. They were clipped; ' ...
        'use a coupled-resonator topology (hairpin, interdigital, coupled-line) for narrow bands.'], ...
        mat2str(round(I.ZsRaw, 1)));
end
if any(d.Ws > d.seg(1)/2)
    w{end+1} = 'Stubs are very wide compared with their spacing - T-junction effects will be large; check with EM.';
end
end
