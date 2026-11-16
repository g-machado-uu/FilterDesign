function [S21, S11] = idealBPF(g, f0, FBW, f, Qu)
%FD.IDEALBPF  Ideal coupled-resonator bandpass response (coupling matrix).
%   [S21, S11] = fd.idealBPF(g, f0, FBW, f, Qu)
%     g    prototype values from fd.prototype ([g0 .. g(n+1)])
%     f0   centre frequency (Hz), FBW fractional bandwidth (e.g. 0.14)
%     f    frequency vector (Hz)
%     Qu   resonator unloaded Q (Inf = lossless)
%   This is what a perfect synthesis would give: synchronously tuned
%   resonators with couplings M(i,i+1) = FBW/sqrt(g_i g_i+1) and external
%   Q = g0 g1 / FBW (Hong & Lancaster, sec. 7.1.2).
if nargin < 5, Qu = Inf; end
n  = numel(g) - 2;
mi = 1 ./ sqrt(g(2:n) .* g(3:n+1));              % normalised couplings
m  = diag(mi, 1) + diag(mi, -1);
qe1 = g(1)*g(2); qen = g(n+1)*g(n+2);
q  = zeros(n); q(1,1) = 1/qe1; q(n,n) = 1/qen;
U  = eye(n);
S21 = zeros(size(f)); S11 = S21;
for k = 1:numel(f)
    p = 1j/FBW * (f(k)/f0 - f0/f(k)) + 1/(FBW*Qu);
    A = q + p*U - 1j*m;
    Ai = A \ U;
    S21(k) = 2/sqrt(qe1*qen) * Ai(n, 1);
    S11(k) = 1 - 2/qe1 * Ai(1, 1);
end
end
