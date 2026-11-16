function T = csrr()
%FD.TOPO.CSRR  Complementary split-ring resonator etched in the ground plane.
T = fd.topo.base();
T.id = 'csrr'; T.name = 'Complementary SRR (CSRR)'; T.kind = 'RES';
T.blurb = ['The "negative" of an SRR: two split-ring SLOTS etched in the ' ...
    'ground plane under a 50 Ω line. The line''s electric field excites it ' ...
    'and it shorts the line to ground at resonance: a deep NOTCH. The ' ...
    'fields are strongest in the slots on the back side of the board - a ' ...
    'convenient sensing area away from the line. Note: the board is not ' ...
    'fully grounded any more, so mount it with the slots free.'];
T.defaults = struct('f0', 2.45e9, 'n', 1, 'type', 'Butterworth', 'ripple', 0.1, 'fs', 2.45e9, 'As', 10);
T.hasOrder = false;
T.params = struct('field', {'w', 'sp', 'gs'}, ...
    'label', {'Slot width (mm)', 'Metal between slots (mm)', 'Split (mm)'}, ...
    'default', {0.5, 0.4, 0.5}, 'lim', {[0.15 3], [0.15 3], [0.15 3]}, ...
    'tip', {'Width of each slot ring.', 'Copper strip left between the two slots.', ...
            'Metal bridge across each slot ring.'});
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
    'Lline', NaN, 'Wb', NaN);
    function r = err(a)
        dd = d; dd.a = a; [~, fzr] = fd.csrrS(setL(dd), sub, []);
        r = log(fzr/spec.f0);
    end
d.a = fzero(@err, [2*w + 0.4e-3, 80e-3]);
d = setL(d);
[Ls, Cs, fs, parts] = fd.srrLC(d.a, w, sp, sub, true);
I = struct('f0', spec.f0, 'Ls', Ls, 'Cs', Cs, 'fself', fs, 'parts', parts, 'aOut', d.a + 2*(sp + w));
end

function d = setL(d)
aOut = d.a + 2*(d.sp + d.w);
d.Lline = max(aOut + 20e-3, 30e-3); d.Wb = max(aOut + 16e-3, 25e-3);
end

function [x0, lb, ub, unpack] = packA(d)
x0 = d.a*1e3; lb = 0.5*x0; ub = 1.5*x0;
unpack = @(x) setL(setfield(d, 'a', x*1e-3)); %#ok<SFLD>
end

function rows = tune(d, spec, ~)
rows = {'Inner slot ring size a', 'a', 1, 0.5*d.a, 1.5*d.a, false;
        'Slot width', 'w', 1, spec.minGap, 3*d.w, false;
        'Metal between slots', 'sp', 1, 0.15e-3, 4*d.sp, false};
end

function c = dims(d, ~, ~)
mm = @(x) round(x*1e3, 3); aOut = d.a + 2*(d.sp + d.w);
c = {'Inner slot ring outer side a', mm(d.a), 'Sets f0 most strongly';
     'Outer slot ring outer side', mm(aOut), 'Overall CSRR size';
     'Slot width', mm(d.w), 'Both slot rings (etched in the GROUND)';
     'Metal between slots', mm(d.sp), 'Copper strip between the rings';
     'Split', mm(d.gs), 'Metal bridge in each ring (opposite sides)';
     'Line width', mm(d.W0), '50 Ω line on top, centred over the CSRR';
     'Board', sprintf('%.1f x %.1f', d.Lline*1e3, d.Wb*1e3), 'Length x width (mm)'};
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
     'NOTE - approximate (+/-15 %): run "EM full" (small and fast) and "Calibrate".'};
end
