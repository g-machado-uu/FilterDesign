function [Zp, Yp] = mtlMatrices(C, Ca, W, sub, f)
%FD.MTLMATRICES  Per-unit-length Z and Y matrices of N coupled microstrips.
%   [Zp, Yp] = fd.mtlMatrices(C, Ca, W, sub, f)   (N x N x F arrays)
%   C, Ca  Maxwell capacitance matrices with / without dielectric (fd.mtlFD
%          or fd.mtlNN). W 1xN strip widths. Dispersion: the dielectric
%   part of C is scaled with the single-line Kirschning-Jansen factor.
%   Losses: R = 2 Rs/W per strip, G from tan(delta) on the dielectric part.
mu0 = 4*pi*1e-7; e0 = 8.8541878128e-12;
N = size(C, 1); F = numel(f); f = f(:).';
Lm = mu0*e0 * inv(Ca); %#ok<MINV>
[~, eS]  = fd.msl(mean(W), sub, f);
[~, eS0] = fd.msl(mean(W), sub, 0);
r = (eS - 1) / (eS0 - 1);
Rs = sqrt(pi * f * mu0 / sub.sigma);
fill = sub.er / max(sub.er - 1, eps);
Zp = zeros(N, N, F); Yp = Zp;
Cd = C - Ca;
for k = 1:F
    w = 2*pi*f(k);
    Ck = Ca + Cd * r(k);
    Zp(:, :, k) = diag(2*Rs(k) ./ W) + 1j*w*Lm;
    Yp(:, :, k) = w*sub.tand*fill*Cd*r(k) + 1j*w*Ck;
end
end
