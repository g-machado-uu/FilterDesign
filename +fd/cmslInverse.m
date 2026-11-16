function [W, s, got] = cmslInverse(Ze, Zo, sub, sMin)
%FD.CMSLINVERSE  Width and gap of symmetric coupled microstrips for given Ze, Zo.
%   [W, s, got] = fd.cmslInverse(Ze, Zo, sub, sMin)
%   Solves the 2D field problem (fd.cmslFD) inside a least-squares search
%   in log(W), log(s). s is limited to >= sMin (fab limit); got returns the
%   Ze, Zo actually achieved.
if nargin < 4, sMin = 0.05e-3; end
h = sub.h; er = sub.er; Zm = sqrt(Ze*Zo);
W0 = fd.mslWidth(Zm, sub, 0);
opt = struct('res', 25, 'box', 20);
    function r = res(x)
        q = fd.cmslFD(exp(x(1)), exp(x(2)), h, er, opt);
        r = [log(q.Ze/Ze); log(q.Zo/Zo)];
    end
x0 = [log(W0), log(max(h*0.5*exp(-3*(Ze - Zo)/(Ze + Zo)*3), sMin))];
lb = [log(0.05*h), log(sMin)]; ub = [log(10*h), log(10*h)];
x = lsqnonlin(@res, x0, lb, ub, optimoptions('lsqnonlin', 'Display', 'off', ...
    'FunctionTolerance', 1e-10, 'StepTolerance', 1e-8, 'MaxIterations', 60));
W = exp(x(1)); s = exp(x(2));
q = fd.cmslFD(W, s, h, er, opt); got = [q.Ze q.Zo];
end
