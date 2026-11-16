function L = viaL(D, h)
%FD.VIAL  Inductance of a cylindrical via of diameter D through height h (H).
%   Goldfarb & Pucel (1991): L = mu0/(2 pi) [h ln((h + sqrt(r^2+h^2))/r)
%                                 + 1.5 (r - sqrt(r^2+h^2))]
r = D/2; mu0 = 4*pi*1e-7; q = sqrt(r^2 + h^2);
L = mu0/(2*pi) * (h*log((h + q)/r) + 1.5*(r - q));
end
