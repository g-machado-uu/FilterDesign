function T = csrr()
%FD.TOPO.CSRR  Complementary split-ring resonator etched in the ground plane.
T = fd.topo.base();
T.id = 'csrr'; T.name = 'Complementary SRR (CSRR)'; T.kind = 'RES';
T.blurb = ['The "negative" of an SRR: two split-ring SLOTS etched in the ' ...
    'ground plane under a 50 Ω line. The line''s electric field excites it ' ...
    'and it shorts the line to ground at resonance: a deep NOTCH. The ' ...
    'fields are strongest in the slots on the back side of the board - a ' ...
    'convenient sensing area away from the line. Several CSRRs in a row ' ...
    'along the line give a deeper, wider notch. Note: the board is not ' ...
    'fully grounded any more, so mount it with the slots free.'];
T.defaults = struct('f0', 2.45e9, 'n', 1, 'type', 'Butterworth', 'ripple', 0.1, 'fs', 2.45e9, 'As', 10);
T.hasOrder = false;
T.params = struct('field', {'w', 'sp', 'gs', 'N'}, ...
    'label', {'Slot width (mm)', 'Metal between slots (mm)', 'Split (mm)', 'CSRRs along the line'}, ...
    'default', {0.5, 0.4, 0.5, 1}, 'lim', {[0.15 3], [0.15 3], [0.15 3], [1 5]}, ...
    'tip', {'Width of each slot ring.', 'Copper strip left between the two slots.', ...
            'Metal bridge across each slot ring.', ...
            'Number of identical CSRRs in a row under the line (deeper, wider notch).'});
T.synth   = @synth;
T.model   = @(d, sub, f) fd.csrrS(d, sub, f);
T.toolbox = @(d, sub) fd.toToolbox('csrr', d, sub);
T.fgrid   = @fd.topo.common.fgridRES;
T.ideal   = @(varargin) [];
T.pack    = @(d, varargin) packA(d);
T.objective = @(S, f, spec, info) 100*(fd.topo.common.peakFreq(S, f, true) - spec.f0)/spec.f0;
T.optgrid = @(spec, info) linspace(0.6, 1.4, 1601)*spec.f0;
T.tune    = @tune;
T.dims    = @dims;
T.steps   = @steps;
T.calSpec = struct('field', {'kF', 'kC'}, 'x0', {1, 1}, 'lb', {0.6, 0.2}, 'ub', {1.6, 5}, 'scale', {1, 1});
end

function [d, I] = synth(spec, sub)
w = max(spec.w*1e-3, spec.minGap); sp = spec.sp*1e-3;
d = struct('a', NaN, 'w', w, 'sp', sp, 'gs', spec.gs*1e-3, 'W0', fd.mslWidth(50, sub, spec.f0), ...
    'N', round(spec.N), 'gp', 0);
    function fzr = fOf(a)
        dd = d; dd.a = a; [~, fzr] = fd.csrrS(dd, sub, []);
    end
d.a = fd.topo.common.solveSize(@fOf, spec.f0, [2*w + 0.4e-3, 80e-3], 'A CSRR', ...
    ['make "Slot width" and "Metal between slots" smaller (a smaller CSRR then fits), ' ...
     'or use a lower-εr board. Above ~10 GHz a CSRR gets very small and hard to make.'], ...
    ['make "Metal between slots" smaller (more capacitance), use a higher-εr board, ' ...
     'or accept a higher f0.']);
aOut = d.a + 2*(sp + w);
d.gp = max(2e-3, aOut/2);                          % gap between CSRRs (edge to edge)
[Ls, Cs, fs, parts] = fd.srrLC(d.a, w, sp, sub, true);
I = struct('f0', spec.f0, 'Ls', Ls, 'Cs', Cs, 'fself', fs, 'parts', parts, 'aOut', aOut);
end

function [x0, lb, ub, unpack] = packA(d)
x0 = d.a*1e3; lb = 0.5*x0; ub = 1.5*x0;
unpack = @(x) setfield(d, 'a', x*1e-3); %#ok<SFLD>
end

function rows = tune(d, spec, ~)
rows = {'Inner slot ring size a', 'a', 1, 0.5*d.a, 1.5*d.a, false;
        'Slot width', 'w', 1, spec.minGap, 3*d.w, false;
        'Metal between slots', 'sp', 1, 0.15e-3, 4*d.sp, false};
if d.N > 1
    rows(end+1, :) = {'Gap between CSRRs', 'gp', 1, spec.minGap, max(3*d.gp, 10e-3), false};
end
end

function c = dims(d, ~, ~)
mm = @(x) round(x*1e3, 3); aOut = d.a + 2*(d.sp + d.w); [L, Wb] = fd.csrrBoard(d);
c = {'Inner slot ring outer side a', mm(d.a), 'Sets f0 most strongly';
     'Outer slot ring outer side', mm(aOut), 'Overall CSRR size';
     'Slot width', mm(d.w), 'Both slot rings (etched in the GROUND)';
     'Metal between slots', mm(d.sp), 'Copper strip between the rings';
     'Split', mm(d.gs), 'Metal bridge in each ring (opposite sides)';
     'Line width', mm(d.W0), '50 Ω line on top, centred over the CSRR';
     'Board', sprintf('%.1f x %.1f', L*1e3, Wb*1e3), 'Length x width (mm)';
     'CSRRs along the line', d.N, 'Identical cells in a row under the line'};
if d.N > 1
    c(end+1:end+2, :) = {'Gap between CSRRs', mm(d.gp), 'Edge to edge, along the line (outer slot to outer slot)';
                         'CSRR pitch', mm(d.gp + aOut), 'Centre to centre, along the line'};
end
end

function L = steps(d0, I, s, sub)
p = I.parts;
L = {sprintf('STEP 1 - Target notch f0 = %.4f GHz on %s h = %.2f mm', s.f0/1e9, sub.name, sub.h*1e3), ...
     'STEP 2 - Babinet: a CSRR behaves like the dual of an SRR of the same shape:', ...
     '  a parallel Lr-Cr tank to ground with the same resonance as that SRR.', ...
     sprintf('  dual SRR: Ls = %.3f nH, Cs = %.4f pF (coplanar strips, eps_avg = %.2f)', I.Ls*1e9, I.Cs*1e12, (sub.er+1)/2), ...
     sprintf('  -> the CSRR alone resonates at %.3f GHz', I.fself/1e9), ...
     'STEP 3 - The line couples to the inner patch through Cc (line over patch).', ...
     '  The notch is where Lr resonates with Cc + Cr - below the CSRR''s own f0.', ...
     sprintf('STEP 4 - Size solved for the notch at f0: a = %.3f mm (outer %.3f mm)', d0.a*1e3, I.aOut*1e3), ...
     sprintf('STEP 5 - %d CSRR(s) along the line, %.2f mm apart edge to edge (pitch %.2f mm):', ...
             d0.N, d0.gp*1e3, (d0.gp + I.aOut)*1e3), ...
     '  each cell is a shunt tank to ground; more cells = deeper, wider notch. Cells too', ...
     '  close also couple to each other (not in this model), which shifts the notch.', ...
     'NOTE - approximate (+/-15 %): run "EM full" (small and fast) and "Calibrate".'};
end
