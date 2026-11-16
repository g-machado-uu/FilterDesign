function f = fgridBP(spec, info)
%FD.TOPO.COMMON.FGRIDBP  Plot grid around a passband/stopband: f0 +/- 3.2 FBW.
f0 = sqrt(spec.f1*spec.f2); B = (spec.f2 - spec.f1)/f0;
if nargin > 1 && isstruct(info) && isfield(info, 'f0'), f0 = info.f0; end
f = linspace(max(f0*(1 - 3.2*B), 0.05*f0), f0*(1 + 3.2*B), 801);
end
