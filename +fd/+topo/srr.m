function T = srr()
%FD.TOPO.SRR  Square split-ring resonators beside a microstrip line.
T = fd.topo.base();
T.id = 'srr'; T.name = 'Split-ring (SRR)'; T.kind = 'RES';
T.blurb = ['Two concentric split rings placed next to a 50 Ω line (one ' ...
    'pair, a ring on each side). The line''s magnetic field excites them; ' ...
    'at resonance they take energy from the line: a sharp NOTCH in S21. ' ...
    'Much smaller than a half-wave resonator (the gap between the rings ' ...
    'adds capacitance). Strong field in the ring gap = sensing region.'];
T.defaults = struct('f0', 2.45e9, 'n', 1, 'type', 'Butterworth', 'ripple', 0.1, 'fs', 2.45e9, 'As', 10);
T.hasOrder = false;
T.params = struct('field', {'w', 'sp', 'gc', 'N'}, ...
    'label', {'Ring width (mm)', 'Ring spacing (mm)', 'Gap to line (mm)', 'Ring pairs'}, ...
    'default', {0.5, 0.3, 0.25, 1}, 'lim', {[0.15 3], [0.1 3], [0.1 3], [1 5]}, ...
    'tip', {'Width of each ring.', 'Gap between inner and outer ring (sets the capacitance).', ...
            'Gap between line edge and outer ring (sets coupling / notch depth).', ...
            'Number of ring pairs along the line (deeper, wider notch).'});
T.synth   = @synth;
T.model   = @(d, sub, f) fd.srrS(d, sub, f);
T.toolbox = @(d, sub) fd.toToolbox('srr', d, sub);
T.fgrid   = @fd.topo.common.fgridRES;
T.ideal   = @(varargin) [];
T.pack    = @(d, varargin) packA(d);
T.objective = @(S, f, spec, info) 100*(fd.topo.common.peakFreq(S, f, true) - spec.f0)/spec.f0;
T.optgrid = @(spec, info) linspace(0.7, 1.3, 1601)*spec.f0;
T.tune    = @tune;
T.dims    = @dims;
T.steps   = @steps;
T.calSpec = struct('field', {'kF', 'kM'}, 'x0', {1, 1}, 'lb', {0.7, 0.2}, 'ub', {1.4, 5}, 'scale', {1, 1});
end

function [d, I] = synth(spec, sub)
w = spec.w*1e-3; sp = max(spec.sp*1e-3, spec.minGap);
a = fd.topo.common.solveSize(@(a) getf0(a, w, sp, sub), spec.f0, [w*2 + 0.3e-3, 60e-3], 'An SRR', ...
    ['make "Ring width" and "Ring spacing" smaller (a smaller SRR then fits), ' ...
     'or use a lower-εr board. Above ~10 GHz an SRR gets very small and hard to make.'], ...
    ['make "Ring spacing" smaller (more capacitance), use a higher-εr board, ' ...
     'or accept a higher f0.']);
aOut = a + 2*(sp + w);
d = struct('a', a, 'w', w, 'sp', sp, 'gs', max(sp, 0.3e-3), 'gc', max(spec.gc*1e-3, spec.minGap), ...
    'N', round(spec.N), 'gp', max(2e-3, aOut/2), 'W0', fd.mslWidth(50, sub, spec.f0));
[Ls, Cs, f0, parts] = fd.srrLC(a, w, sp, sub);
I = struct('f0', spec.f0, 'Ls', Ls, 'Cs', Cs, 'fcalc', f0, 'parts', parts, 'aOut', aOut);
end

function f0 = getf0(a, w, sp, sub), [~, ~, f0] = fd.srrLC(a, w, sp, sub); end

function [x0, lb, ub, unpack] = packA(d)
x0 = d.a*1e3; lb = 0.5*x0; ub = 1.5*x0;
unpack = @(x) setfield(d, 'a', x*1e-3); %#ok<SFLD>
end

function rows = tune(d, spec, ~)
rows = {'Inner ring size a', 'a', 1, 0.5*d.a, 1.5*d.a, false;
        'Ring width', 'w', 1, 0.15e-3, 3*d.w, false;
        'Ring spacing', 'sp', 1, spec.minGap, 4*d.sp, false;
        'Gap to line', 'gc', 1, spec.minGap, 3e-3, false};
if d.N > 1
    rows(end+1, :) = {'Gap between pairs', 'gp', 1, spec.minGap, max(3*d.gp, 10e-3), false};
end
end

function c = dims(d, ~, ~)
mm = @(x) round(x*1e3, 3); aOut = d.a + 2*(d.sp + d.w);
c = {'Inner ring outer side a', mm(d.a), 'RingLengthInner (sets f0 most strongly)';
     'Outer ring outer side', mm(aOut), 'Overall SRR size';
     'Ring width', mm(d.w), 'Both rings'; 'Ring spacing', mm(d.sp), 'Gap between the rings';
     'Split gap', mm(d.gs), 'Cut in each ring (opposite sides)';
     'Gap to line', mm(d.gc), 'Line edge to outer ring';
     'Line width', mm(d.W0), '50 Ω'; 'Line length', mm(fd.srrLine(d)), 'Board length';
     'Ring pairs', d.N, 'One ring each side of the line per pair'};
if d.N > 1
    c(end+1:end+2, :) = {'Gap between pairs', mm(d.gp), 'Edge to edge, along the line (outer ring to outer ring)';
                         'Pair pitch', mm(d.gp + aOut), 'Centre to centre, along the line'};
end
end

function L = steps(d0, I, s, sub)
p = I.parts;
L = {sprintf('STEP 1 - Target f0 = %.4f GHz on %s h = %.2f mm', s.f0/1e9, sub.name, sub.h*1e3), ...
     'STEP 2 - Equivalent circuit (Marques / Baena): a series LsCs loop', ...
     sprintf('  mean loop side am = a + spacing = %.3f mm, effective width 2w + s = %.3f mm', p.am*1e3, p.we*1e3), ...
     sprintf('  Ls = (2 mu0 am/pi)(ln(4 am/we) - 0.774) = %.3f nH', I.Ls*1e9), ...
     sprintf('  ring-to-ring capacitance per length (field solver) = %.2f pF/m', p.Cpul*1e12), ...
     sprintf('  Cs = (4 am Cpul)/4 (two halves in series) = %.4f pF', I.Cs*1e12), ...
     sprintf('STEP 3 - f0 = 1/(2 pi sqrt(Ls Cs)); solved for a = %.3f mm (outer size %.3f mm)', d0.a*1e3, I.aOut*1e3), ...
     'STEP 4 - Coupling: the line''s field threads the rings (mutual inductance M);', ...
     '  each ring adds (w M)^2 / Z_SRR in series with the line -> notch at f0.', ...
     sprintf('STEP 5 - %d pair(s) along the line, %.2f mm apart edge to edge (pitch %.2f mm):', ...
             d0.N, d0.gp*1e3, (d0.gp + I.aOut)*1e3), ...
     '  more pairs = deeper, wider notch. Pairs too close also couple to each other', ...
     '  (not in this model), which shifts and splits the notch.', ...
     'NOTE - this model is approximate (+/-10-15 %): run "EM full" (small and fast)', ...
     '  and "Calibrate" to correct it.'};
end
