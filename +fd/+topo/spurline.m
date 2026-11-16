function T = spurline()
%FD.TOPO.SPURLINE  Spurline notch (narrow bandstop) - filterSpurline.
T = fd.topo.base();
T.id = 'spurline'; T.name = 'Spurline (notch)'; T.kind = 'BS';
T.blurb = ['An L-shaped slot cut into the line leaves a quarter-wave "spur" ' ...
    'coupled to the main path. At f0 the spur resonates and reflects the ' ...
    'signal: a narrow notch with no stubs sticking out - the whole filter ' ...
    'is as wide as the 50 Ω line. Typical use: reject one interferer ' ...
    '(e.g. 2.4 GHz Wi-Fi). Notch centre = f0 = sqrt(f1 f2); its width is ' ...
    'set mostly by the spur width and slot, not by f1-f2.'];
T.defaults = struct('f1', 2.40e9, 'f2', 2.4835e9, 'n', 1, 'type', 'Butterworth', ...
    'ripple', 0.1, 'fs', 2.44e9, 'As', 20);
T.hasOrder = false; T.orderLim = [1 1];
T.params = struct('field', {'Wc', 'sp', 'nSpur'}, ...
    'label', {'Spur width (mm)', 'Slot (mm)', 'Spurs (1 or 2)'}, 'default', {0.6, 0.2, 1}, ...
    'lim', {[0.15 3], [0.1 2], [1 2]}, ...
    'tip', {'Width of the spur strip.', 'Slot between spur and main path (>= fab minimum gap).', ...
            '2 = a spur on each side (deeper notch).'});
T.synth   = @synth;
T.model   = @(d, sub, f) fd.spurlineS(d, sub, f);
T.toolbox = @(d, sub) fd.toToolbox('spurline', d, sub);
T.fgrid   = @(spec, info) linspace(0.4, 1.6, 801)*info.f0;
T.ideal   = @(varargin) [];
T.pack    = @pack;
T.objective = @(S, f, spec, info) notchErr(S, f, info);
T.optgrid = @(spec, info) linspace(0.7, 1.3, 1201)*info.f0;
T.tune    = @tune;
T.dims    = @dims;
T.steps   = @steps;
T.warn    = @warn;
end

function [d, I] = synth(spec, sub)
c0 = 299792458; f0 = sqrt(spec.f1*spec.f2);
W0 = fd.mslWidth(50, sub, f0);
d = struct('W0', W0, 'Wc', spec.Wc*1e-3, 'sp', max(spec.sp*1e-3, spec.minGap), ...
    'Lc', NaN, 'gL', max(spec.sp*1e-3, spec.minGap), 'double', round(spec.nSpur) == 2, ...
    'Lp', max(5e-3, 3*sub.h));
[~, es] = fd.msl(d.Wc, sub, f0);
d.Lc = c0/(4*f0*sqrt(es));
I = struct('f0', f0, 'L0', d.Lc, 'es', es);
for it = 1:8                                      % move the notch onto f0
    fz = f0*linspace(0.6, 1.4, 1601);
    fn = fd.topo.common.peakFreq(fd.spurlineS(d, sub, fz), fz, true);
    d.Lc = d.Lc * fn/f0;
    if abs(fn - f0)/f0 < 2e-4, break; end
end
end

function r = notchErr(S, f, info)
fn = fd.topo.common.peakFreq(S, f, true);
r = 100*(fn - info.f0)/info.f0;
end

function [x0, lb, ub, unpack] = pack(d, ~, ~, ~)
x0 = d.Lc*1e3; lb = 0.6*x0; ub = 1.4*x0;
unpack = @(x) setfield(d, 'Lc', x*1e-3); %#ok<SFLD>
end

function rows = tune(d, spec, ~)
rows = {'Spur length', 'Lc', 1, 0.6*d.Lc, 1.4*d.Lc, false;
        'Spur width', 'Wc', 1, 0.15e-3, 0.45*d.W0, false;
        'Slot', 'sp', 1, spec.minGap, 0.4*d.W0, false;
        'End gap', 'gL', 1, spec.minGap, 2e-3, false};
end

function c = dims(d, ~, ~)
mm = @(x) round(x*1e3, 3);
if d.double, nm = 'two spurs (one each side)'; else, nm = 'one spur'; end
c = {'Line width W0', mm(d.W0), ['50 Ω line, ' nm];
     'Spur length', mm(d.Lc), 'Coupled length (about a quarter wave)';
     'Spur width', mm(d.Wc), 'Width of the spur strip';
     'Slot', mm(d.sp), 'Gap between spur and main path';
     'End gap', mm(d.gL), 'Gap at the free end of the spur';
     'Port line length', mm(d.Lp), 'Feed line each side'};
end

function L = steps(d0, I, ~, sub)
L = {'STEP 1 - Notch frequency f0 = sqrt(f1 f2)', sprintf('  f0 = %.4f GHz', I.f0/1e9), ...
     'STEP 2 - 50 Ω line width', sprintf('  W0 = %.3f mm on %s h = %.2f mm', d0.W0*1e3, sub.name, sub.h*1e3), ...
     'STEP 3 - The spur is a quarter-wave resonator open at its far end:', ...
     sprintf('  first guess L = lambda_g/4 = %.2f mm (eps_eff of the spur = %.3f)', I.L0*1e3, I.es), ...
     'STEP 4 - The coupling to the main path shifts the notch; the length is', ...
     sprintf('  corrected with the circuit model until the notch sits at f0: L = %.2f mm', d0.Lc*1e3), ...
     'TRY - a wider spur or narrower slot = wider, deeper notch.'};
end

function w = warn(d, ~, ~, ~)
w = {};
if d.Wc < 0.15e-3, w{end+1} = 'Spur narrower than 0.15 mm - check JLCPCB track width.'; end
end
