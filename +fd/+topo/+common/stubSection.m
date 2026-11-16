function [obj, dSec, f, info] = stubSection(d, sub, spec, kind)
%FD.TOPO.COMMON.STUBSECTION  One stub on a through line, for EM calibration.
%   The middle (usually widest) stub of the design alone on a 50-ohm line.
%   Small enough for a converged MoM mesh; calibrates the stub-length
%   offset (T-junction + open end) and, for shorted stubs, the via.
k = ceil(d.n/2);
dSec = d; dSec.n = 1; dSec.seg = []; dSec.Ws = d.Ws(k); dSec.Ls = d.Ls(k);
dSec.short = d.short(k); dSec.Lp = max([4e-3, 2*sub.h, dSec.Ws/2 + 2e-3]);
for c = {'dLs', 'kV'}, if isfield(dSec, c{1}), dSec = rmfield(dSec, c{1}); end, end
obj = fd.toToolbox('stub', dSec, sub);
switch kind
    case 'LP', fc = spec.fc; f = linspace(0.3, 2.4, 7)*fc; fm = 1.5*fc;
    case 'HP', fm = spec.fc*(1 + spec.fu)/2; f = linspace(0.4, 1.8, 7)*fm;
    otherwise, fm = sqrt(spec.f1*spec.f2); f = linspace(0.4, 1.8, 7)*fm;
end
[obj, info] = fd.emPrepare(obj, sub, fm);
end
