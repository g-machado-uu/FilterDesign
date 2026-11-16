function [S21, S11] = idealLPF(g, fc, f, Z0)
%FD.IDEALLPF  Response of the ideal lumped LC ladder lowpass filter.
%   g from fd.prototype, cutoff fc (Hz). Element 1 is a shunt capacitor
%   (C-first ladder), matching the stepped-impedance layout that starts and
%   ends with a low-impedance (wide) section.
if nargin < 4, Z0 = 50; end
n = numel(g) - 2; wc = 2*pi*fc;
S21 = zeros(size(f)); S11 = S21;
for k = 1:numel(f)
    w = 2*pi*f(k); T = eye(2);
    for i = 1:n
        if mod(i, 2), Y = 1j*w*g(i+1)/(Z0*wc); T = T*[1 0; Y 1];   % shunt C
        else,         Z = 1j*w*g(i+1)*Z0/wc;   T = T*[1 Z; 0 1];   % series L
        end
    end
    [S21(k), S11(k)] = abcd2s(T, Z0, Z0*g(end));
end
end

function [s21, s11] = abcd2s(T, Z1, Z2)
A = T(1,1); B = T(1,2); C = T(2,1); D = T(2,2);
den = A*Z2 + B + C*Z1*Z2 + D*Z1;
s21 = 2*sqrt(Z1*Z2) / den;
s11 = (A*Z2 + B - C*Z1*Z2 - D*Z1) / den;
end
