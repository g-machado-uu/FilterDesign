function T = hairpin()
%FD.TOPO.HAIRPIN  Hairpin (folded half-wave) coupled-resonator bandpass.
T = fd.topo.base();
T.id = 'hairpin'; T.name = 'Hairpin'; T.kind = 'BP';
T.blurb = ['Half-wave resonators folded into a U. Neighbouring arms couple ' ...
    'along their length; the gap sets the coupling (bandwidth), the tap ' ...
    'position sets the external Q (match). Compact and popular for 5-20 % ' ...
    'bandwidth.'];
T.defaults = struct('f1', 2.7e9, 'f2', 3.1e9, 'n', 5, 'type', 'Chebyshev', ...
    'ripple', 0.1, 'fs', 3.5e9, 'As', 30);
T.orderLim = [2 9];
T.params = struct('field', {'Zr', 'slotFactor'}, ...
    'label', {'Resonator Z (Ω)', 'Slot / W'}, 'default', {50, 2}, ...
    'lim', {[20 120], [0.5 10]}, ...
    'tip', {'Impedance of the resonator line (sets its width W).', ...
            'Gap between the two arms of one hairpin, as a multiple of W.'});
T.synth   = @(spec, sub) fd.hairpinSynth(spec, sub);
T.model   = @(d, sub, f) fd.hairpinS(d, sub, f);
T.toolbox = @(d, sub) fd.toToolbox('hairpin', d, sub);
T.fgrid   = @fd.topo.common.fgridBP;
T.ideal   = @fd.topo.common.idealBP;
T.pack    = @pack;
T.tune    = @tune;
T.dims    = @dims;
T.steps   = @steps;
T.curves  = @fd.topo.common.curvesKQ;
T.warn    = @fd.topo.common.warnBP;
T.em      = 'section';
T.emSection = @(d, sub, spec) fd.emSection(d, sub, spec);
T.calSpec = struct('field', {'cK', 'kS', 'dtap'}, 'x0', {fd.cornerK(), 1, 0}, ...
    'lb', {0.3, 0.3, -1.5e-3}, 'ub', {1.7, 2.0, 1.5e-3}, 'scale', {1, 1, 1e-3});
end

function [x0, lb, ub, unpack] = pack(d, sub, spec, info)
n = d.n; ns = ceil((n-1)/2); symTap = abs(info.g(n+2) - 1) < 1e-9;
armL = d.La - d.W/2;
x0 = [d.La, d.s(1:ns), d.tap(1)] * 1e3;
lb = [0.85*d.La, repmat(spec.minGap, 1, ns), 0.2e-3] * 1e3;
ub = [1.15*d.La, repmat(6*sub.h, 1, ns), armL - 0.2e-3] * 1e3;
if ~symTap, x0(end+1) = d.tap(2)*1e3; lb(end+1) = lb(end); ub(end+1) = ub(end); end
x0 = min(max(x0, lb), ub);
    function dd = un(x)
        x = x*1e-3; dd = d; dd.La = x(1);
        s = x(2:1+ns); dd.s = [s, fliplr(s(1:floor((n-1)/2)))];
        if symTap, dd.tap = [x(2+ns) x(2+ns)]; else, dd.tap = x(2+ns:3+ns); end
    end
unpack = @un;
end

function rows = tune(d, spec, sub)
armL = d.La - d.W/2;
rows = {'Arm length La', 'La', 1, 0.75*d.La, 1.25*d.La, false};
for i = 1:d.n - 1
    rows(end+1, :) = {sprintf('Gap s%d (res %d–%d)', i, i, i+1), 's', i, ...
        spec.minGap, max(4*d.s(i), 3*sub.h), true}; %#ok<AGROW>
end
rows(end+1, :) = {'Input tap (from bend)', 'tap', 1, 0.2e-3, armL - 0.2e-3, true};
rows(end+1, :) = {'Output tap (from bend)', 'tap', 2, 0.2e-3, armL - 0.2e-3, true};
end

function c = dims(d, spec, ~)
mm = @(x) round(x*1e3, 3);
c = {'Strip width W', mm(d.W), sprintf('Resonator line, %.0f Ω', spec.Zr);
     'Arm length La', mm(d.La), 'Outer length of each arm of the U';
     'Slot', mm(d.slot), 'Gap between the two arms of one hairpin';
     'Port line width', mm(d.Wp), '50 Ω feed line';
     'Port line length', mm(d.Lp), 'Feed line from board edge to the tap'};
for i = 1:d.n - 1
    c(end+1, :) = {sprintf('Gap s%d', i), mm(d.s(i)), ...
        sprintf('Edge-to-edge, hairpin %d to %d (sets coupling M%d%d)', i, i+1, i, i+1)}; %#ok<AGROW>
end
c(end+1, :) = {'Input tap', mm(d.tap(1)), 'Feed centre, from the bend centreline (sets Qe)'};
c(end+1, :) = {'Output tap', mm(d.tap(2)), 'Same, output side'};
end

function L = steps(d0, I, s, sub)
L = fd.topo.common.stepsBPHead(I, s);
L{end+1} = 'STEP 4 - Resonator';
L{end+1} = sprintf('  %.0f Ω line on %s h=%.2f mm, er=%.2f -> W = %.3f mm', s.Zr, sub.name, sub.h*1e3, sub.er, I.W*1e3);
L{end+1} = sprintf('  eps_eff = %.3f, lambda_g = %.2f mm, open-end extension %.3f mm', I.ee, I.lamg*1e3, I.dl*1e3);
L{end+1} = sprintf('  Half-wave U: arm La = %.2f mm (first guess %.2f mm, then tuned', d0.La*1e3, I.La0*1e3);
L{end+1} = '  so one hairpin resonates at f0, including the bend correction)';
L{end+1} = 'STEP 5 - Physical gaps and taps (from the design curves ->)';
L{end+1} = sprintf('  gaps s = %s mm', mat2str(round(d0.s*1e3, 3)));
L{end+1} = sprintf('  taps t = %s mm from the bend centreline', mat2str(round(d0.tap*1e3, 3)));
if any(I.gapLimited), L{end+1} = sprintf('  !! some gaps were limited to the %.2f mm fab minimum', s.minGap*1e3); end
L = [L, fd.topo.common.stepsLoss(I)];
end
