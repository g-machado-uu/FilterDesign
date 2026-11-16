function [cal, fit] = calibrate(T, dSec, sub, sEM)
%FD.CALIBRATE  Fit a topology's circuit-model correction knobs to EM data.
%   [cal, fit] = fd.calibrate(T, dSec, sub, sEM)
%   T.calSpec lists the knobs (field, start, bounds, scale). They are
%   fitted so the circuit model of the simulated section dSec reproduces
%   the EM |S21| and |S11| ("space mapping"). Apply them with fd.applyCal.
f = sEM.Frequencies(:).';
e21 = abs(squeeze(sEM.Parameters(2,1,:))).';
e11 = abs(squeeze(sEM.Parameters(1,1,:))).';
cs = T.calSpec; sc = [cs.scale];
x0 = [cs.x0]./sc; lb = [cs.lb]./sc; ub = [cs.ub]./sc;
    function r = res(x)
        dd = dSec;
        for k = 1:numel(cs), dd.(cs(k).field) = x(k)*sc(k); end
        S = T.model(dd, sub, f);
        r = [abs(squeeze(S(2,1,:))).' - e21, abs(squeeze(S(1,1,:))).' - e11].';
    end
r0 = res(x0);
[x, rn] = lsqnonlin(@res, x0, lb, ub, optimoptions('lsqnonlin', 'Display', 'off', 'MaxIterations', 80));
cal = struct();
for k = 1:numel(cs), cal.(cs(k).field) = x(k)*sc(k); end
fit = struct('rms0', sqrt(mean(r0.^2)), 'rms', sqrt(rn/numel(r0)), 'f', f);
end
