function [obj, dSec, f, info] = emSection(d, sub, spec, nPts)
%FD.EMSECTION  Small EM test structure for calibrating the hairpin model.
%   [obj, dSec, f, info] = fd.emSection(d, sub, spec, nPts)
%   Builds the first two hairpins of the design (first gap, real taps),
%   with short feed lines and a tight ground plane to save memory, and sets
%   a converged mesh (fd.emPrepare). f = nPts frequencies covering the
%   section's response. Check info.ok before simulating.
if nargin < 4, nPts = 7; end
f0 = sqrt(spec.f1*spec.f2); FBW = (spec.f2 - spec.f1)/f0;
dSec = d; dSec.n = 2; dSec.s = d.s(1); dSec.tap = d.tap([1 1]);
dSec.Lp = min(d.Lp, 3e-3);
dSec = rmfield(dSec, intersect({'cK','kS','dtap'}, fieldnames(dSec)));
obj = fd.toToolbox('hairpin', dSec, sub);
obj.GroundPlaneWidth = dSec.La + 6*sub.h;
f = f0 * (1 + 1.6*FBW*linspace(-1, 1, nPts));
[obj, info] = fd.emPrepare(obj, sub, f0);    % mesh sized at f0 (memory)
end
