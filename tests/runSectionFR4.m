% Converged-mesh MoM of the first two hairpins of the FR4 n78 design, then
% calibrate the circuit model. Results saved to tests/results/sectionFR4.mat
S = fd.substrates; sub = S(1); sub.h = 1.6e-3;
spec = struct('f1',3.3e9,'f2',3.8e9,'n',5,'type','Chebyshev','ripple',0.1, ...
              'Zr',50,'slotFactor',2,'minGap',0.15e-3);
d = fd.hairpinSynth(spec, sub);
[obj, dSec, f, info] = fd.emSection(d, sub, spec, 7);
fprintf('edge %.2f mm, memory %s (budget %.1f GB) ok=%d\n', info.edge*1e3, info.memStr, info.budgetGB, info.ok);
if ~info.ok, error('Section does not fit the memory budget.'); end
sEM = fd.emRun(obj, f, @(k,n,t) fprintf('  point %d/%d, %.1f s/pt\n', k, n, t) < 0);
[cal, fit] = fd.calibrateHairpin(dSec, sub, sEM);
fprintf('cal: cK=%.3f kS=%.3f dtap=%.3f mm; rms %.3f -> %.3f\n', cal.cK, cal.kS, cal.dtap*1e3, fit.rms0, fit.rms);
if ~exist(fullfile(fileparts(mfilename('fullpath')), 'results'), 'dir')
    mkdir(fullfile(fileparts(mfilename('fullpath')), 'results'));
end
save(fullfile(fileparts(mfilename('fullpath')), 'results', 'sectionFR4.mat'), ...
     'd', 'dSec', 'sEM', 'cal', 'fit', 'spec', 'sub');
