function [cal, fit] = calibrateHairpin(dSec, sub, sEM)
%FD.CALIBRATEHAIRPIN  Fit circuit-model corrections to an EM simulation.
%   [cal, fit] = fd.calibrateHairpin(dSec, sub, sEM)
%     dSec  dimensions of the simulated section (usually 2 hairpins)
%     sEM   sparameters object from MoM of that section
%   cal fields (apply to the full design with fd.applyCal):
%     cK    bend shortening factor   (moves the resonant frequency)
%     kS    coupling scale           (sets the bandwidth)
%     dtap  tap position offset (m)  (sets the external Q / match)
%   This is "space mapping": the fast model is corrected so that it agrees
%   with the slow, accurate one, then the fast model is used for design.
f = sEM.Frequencies(:).';
e21 = abs(squeeze(sEM.Parameters(2,1,:))).';
e11 = abs(squeeze(sEM.Parameters(1,1,:))).';
x0 = [fd.cornerK(), 1, 0];
lb = [0.3, 0.3, -1.5e-3*1e3];  ub = [1.7, 2.0, 1.5e-3*1e3];
x0(3) = 0;
    function r = res(x)
        dd = dSec; dd.cK = x(1); dd.kS = x(2); dd.dtap = x(3)*1e-3;
        S = fd.hairpinS(dd, sub, f);
        r = [abs(squeeze(S(2,1,:))).' - e21, abs(squeeze(S(1,1,:))).' - e11].';
    end
opts = optimoptions('lsqnonlin', 'Display', 'off', 'MaxIterations', 80);
r0 = res(x0);
[x, rn] = lsqnonlin(@res, x0, lb, ub, opts);
cal = struct('cK', x(1), 'kS', x(2), 'dtap', x(3)*1e-3);
fit = struct('rms0', sqrt(mean(r0.^2)), 'rms', sqrt(rn/numel(r0)), 'f', f);
end
