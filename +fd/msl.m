function [Z0, ee, alpha, Qu] = msl(W, sub, f)
%FD.MSL  Single microstrip line: impedance, effective permittivity, loss.
%   [Z0, ee, alpha, Qu] = fd.msl(W, sub, f)
%     W     strip width (m), scalar
%     sub   substrate struct (see fd.substrates): er, h, tand, t, sigma
%     f     frequency vector (Hz). Use f = 0 for the quasi-static values.
%   Returns
%     Z0    characteristic impedance (ohm), size of f
%     ee    effective permittivity (with dispersion), size of f
%     alpha attenuation (Np/m) = conductor + dielectric
%     Qu    unloaded Q of a resonator made from this line
%
%   Models: Hammerstad-Jensen (1980) static Z0/ee, Kirschning-Jansen (1982)
%   dispersion, simple Rs/(Z0*W) conductor loss and the standard filling-
%   factor dielectric loss. Accuracy ~1-2% for 0.1 < W/h < 10.

er = sub.er; h = sub.h;
u  = W / h;
eta0 = 376.730313;

% --- quasi-static (Hammerstad-Jensen) -------------------------------------
a  = 1 + log((u^4 + (u/52)^2) / (u^4 + 0.432)) / 49 + log(1 + (u/18.1)^3) / 18.7;
b  = 0.564 * ((er - 0.9) / (er + 3))^0.053;
ee0 = (er + 1)/2 + (er - 1)/2 * (1 + 10/u)^(-a*b);
F  = 6 + (2*pi - 6) * exp(-(30.666/u)^0.7528);
Z01 = eta0/(2*pi) * log(F/u + sqrt(1 + (2/u)^2));   % air-filled impedance
Zs  = Z01 / sqrt(ee0);

% --- dispersion (Kirschning-Jansen) ---------------------------------------
fn = f(:).' * 1e-9 * h * 1e3;                         % GHz*mm
P1 = 0.27488 + (0.6315 + 0.525 ./ (1 + 0.0157*fn).^20) * u - 0.065683*exp(-8.7513*u);
P2 = 0.33622 * (1 - exp(-0.03442*er));
P3 = 0.0363 * exp(-4.6*u) * (1 - exp(-(fn/38.7).^4.97));
P4 = 1 + 2.751 * (1 - exp(-(er/15.916)^8));
P  = P1 .* P2 .* ((0.1844 + P3*P4) .* fn).^1.5763;
ee = er - (er - ee0) ./ (1 + P);
if er > 1 + 1e-9
    Z0 = Zs * (ee - 1)/(ee0 - 1) .* sqrt(ee0 ./ ee);  % Bahl approximation
else
    Z0 = Zs * ones(size(ee));                          % air: no dispersion
end

% --- losses -----------------------------------------------------------------
mu0 = 4*pi*1e-7; c0 = 299792458;
Rs  = sqrt(pi * f(:).' * mu0 / sub.sigma);
ac  = Rs ./ (Z0 * W);                                   % conductor (Np/m)
k0  = 2*pi*f(:).'/c0;
ad  = k0 .* er .* (ee - 1) .* sub.tand ./ (2*sqrt(ee) * max(er - 1, eps));  % dielectric
alpha = ac + ad;
beta  = k0 .* sqrt(ee);
Qu = beta ./ (2*alpha);

Z0 = reshape(Z0, size(f)); ee = reshape(ee, size(f));
alpha = reshape(alpha, size(f)); Qu = reshape(Qu, size(f));
end
