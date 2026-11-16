function T = ring()
%FD.TOPO.RING  Gap-coupled microstrip ring resonator (resonatorRing).
T = fd.topo.base();
T.id = 'ring'; T.name = 'Ring resonator'; T.kind = 'RES';
T.blurb = ['A closed microstrip ring, weakly coupled to two feed lines ' ...
    'through small gaps. It resonates when its mean circumference is a ' ...
    'whole number of guided wavelengths (2 pi Rm = m lambda_g), giving ' ...
    'transmission peaks. Widely used to measure substrate permittivity ' ...
    'and loss, and as a sensor: anything placed on the ring shifts f0 ' ...
    'and lowers Q.'];
T.defaults = struct('f0', 2.45e9, 'n', 1, 'type', 'Butterworth', 'ripple', 0.1, 'fs', 2.45e9, 'As', 10);
T.hasOrder = false;
T.params = struct('field', {'Zr', 'gap', 'mode'}, ...
    'label', {'Ring Z (Ω)', 'Coupling gap (mm)', 'Mode m'}, 'default', {50, 0.3, 1}, ...
    'lim', {[20 120], [0.1 3], [1 4]}, ...
    'tip', {'Impedance (width) of the ring strip.', ...
            'Feed-to-ring gap: smaller = stronger coupling, lower loaded Q.', ...
            'Resonance order: circumference = m guided wavelengths.'});
T.synth   = @synth;
T.model   = @(d, sub, f) fd.ringS(d, sub, f);
T.toolbox = @(d, sub) fd.toToolbox('ring', d, sub);
T.fgrid   = @fd.topo.common.fgridRES;
T.ideal   = @(varargin) [];
T.pack    = @(d, varargin) packR(d);
T.objective = @(S, f, spec, info) 100*(fd.topo.common.peakFreq(S, f, false) - spec.f0)/spec.f0;
T.optgrid = @(spec, info) linspace(0.8, 1.2, 1601)*spec.f0;
T.tune    = @tune;
T.dims    = @dims;
T.steps   = @steps;
T.calSpec = struct('field', {'kR', 'kC'}, 'x0', {1, 1}, 'lb', {0.85, 0.2}, 'ub', {1.15, 5}, 'scale', {1, 1});
end

function [d, I] = synth(spec, sub)
c0 = 299792458; f0 = spec.f0; m = round(spec.mode);
Wr = fd.mslWidth(spec.Zr, sub, f0); [~, ee] = fd.msl(Wr, sub, f0);
lamg = c0/(f0*sqrt(ee)); Rm0 = m*lamg/(2*pi);
d = struct('Rout', Rm0 + Wr/2, 'Wr', Wr, 'gap', max(spec.gap*1e-3, spec.minGap), ...
    'Wp', fd.mslWidth(50, sub, f0), 'Lp', max(8e-3, 4*sub.h));
for it = 1:8                                     % put the m-th peak on f0
    fz = f0*linspace(0.85, 1.15, 1501);
    fr = fd.topo.common.peakFreq(fd.ringS(d, sub, fz), fz, false);
    Rm = (d.Rout - Wr/2)*fr/f0; d.Rout = Rm + Wr/2;
    if abs(fr - f0)/f0 < 2e-4, break; end
end
[~, ~, ~, Qu] = fd.msl(Wr, sub, f0);
I = struct('f0', f0, 'm', m, 'ee', ee, 'lamg', lamg, 'Rm0', Rm0, 'Qu', Qu, 'Cg', fd.gapC(min(d.Wp, Wr), d.gap, sub));
end

function [x0, lb, ub, unpack] = packR(d)
x0 = d.Rout*1e3; lb = 0.7*x0; ub = 1.3*x0;
unpack = @(x) setfield(d, 'Rout', x*1e-3); %#ok<SFLD>
end

function rows = tune(d, spec, ~)
rows = {'Outer radius', 'Rout', 1, 0.7*d.Rout, 1.3*d.Rout, false;
        'Ring width', 'Wr', 1, 0.2e-3, min(3*d.Wr, 0.8*d.Rout), false;
        'Coupling gap', 'gap', 1, spec.minGap, 3e-3, false};
end

function c = dims(d, ~, ~)
mm = @(x) round(x*1e3, 3);
c = {'Outer radius', mm(d.Rout), 'Ring outer edge';
     'Mean radius', mm(d.Rout - d.Wr/2), 'Centre of the ring strip (sets f0)';
     'Ring width', mm(d.Wr), 'Ring strip width';
     'Coupling gap', mm(d.gap), 'Feed line end to ring (sets loaded Q)';
     'Feed width', mm(d.Wp), '50 Ω feed line'; 'Feed length', mm(d.Lp), 'Each side'};
end

function L = steps(d0, I, s, sub)
L = {sprintf('STEP 1 - Target f0 = %.4f GHz, mode m = %d', s.f0/1e9, I.m), ...
     sprintf('STEP 2 - Ring strip %.0f Ω on %s h = %.2f mm: W = %.3f mm, eps_eff = %.3f', s.Zr, sub.name, sub.h*1e3, d0.Wr*1e3, I.ee), ...
     sprintf('STEP 3 - Resonance: 2 pi Rm = m lambda_g  ->  Rm = %.3f mm (lambda_g = %.2f mm)', I.Rm0*1e3, I.lamg*1e3), ...
     sprintf('STEP 4 - The coupling gaps load the ring slightly; corrected Rm = %.3f mm', (d0.Rout - d0.Wr/2)*1e3), ...
     sprintf('  outer radius %.3f mm; gap capacitance ~ %.3f pF (approximate)', d0.Rout*1e3, I.Cg*1e12), ...
     sprintf('STEP 5 - Unloaded Q of the line ~ %.0f. Measured: Qu = QL / (1 - 10^(-IL/20))', I.Qu), ...
     'NOTE - also resonates at m = 2, 3... (2 f0, 3 f0): useful to check eps_r.'};
end
