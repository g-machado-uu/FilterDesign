function [d, info] = sirSynth(spec, sub)
%FD.SIRSYNTH  Synthesise a stepped-impedance microstrip lowpass filter.
%   [d, info] = fd.sirSynth(spec, sub)
%   spec fields: fc (Hz), n (odd), type ('Chebyshev'/'Butterworth'),
%                ripple (dB), Z0, ZL (low impedance), ZH (high impedance)
%   d fields (m): n, WL, WH, len (1xn: odd entries low-Z, even high-Z),
%                 Wp, Lp
%   info: g, step-by-step values for the teaching panel.
%
%   Method (Hong & Lancaster sec. 5.1): shunt C -> short low-Z line,
%   series L -> short high-Z line. The first-pass lengths are
%       l_C = lambda_gL/(2 pi) * asin(wc C ZL),  l_L = lambda_gH/(2 pi) * asin(wc L / ZH)
%   then refined so each section also accounts for the small L (or C)
%   contributed by its neighbours.

n = spec.n; Z0 = spec.Z0; fc = spec.fc; wc = 2*pi*fc;
g = fd.prototype(n, spec.type, spec.ripple);
WL = fd.mslWidth(spec.ZL, sub, fc); WH = fd.mslWidth(spec.ZH, sub, fc);
[ZL, eL] = fd.msl(WL, sub, fc);  [ZH, eH] = fd.msl(WH, sub, fc);
c0 = 299792458; bL = wc*sqrt(eL)/c0; bH = wc*sqrt(eH)/c0;

isC = logical(mod(1:n, 2));                      % 1,3,5... are capacitors
X = zeros(1, n);                                 % required wc*C or wc*L
X(isC)  = g(1+find(isC))/Z0;                     % wc*C (S)
X(~isC) = g(1+find(~isC))*Z0;                    % wc*L (ohm)
arg = [X(isC)*ZL, X(~isC)/ZH];
if any(arg >= 1)
    error('fd:sirSynth', ['Impedance ratio too small for this filter: ' ...
        'raise ZH or lower ZL (needs g*Z0/ZH < 1 and g*ZL/Z0 < 1).']);
end
len = zeros(1, n);
len(isC)  = asin(X(isC)*ZL)/bL;
len(~isC) = asin(X(~isC)/ZH)/bH;
len0 = len;
for it = 1:20                                    % neighbour correction
    for i = 1:n
        nb = [i-1 i+1]; nb = nb(nb >= 1 & nb <= n);
        if isC(i)
            extra = sum(tan(bH*len(nb)/2))/ZH;
            len(i) = asin(max(X(i) - extra, 1e-3) * ZL)/bL;
        else
            extra = ZL*sum(tan(bL*len(nb)/2));
            len(i) = asin(max(X(i) - extra, 1e-3) / ZH)/bH;
        end
    end
end

d = struct('n', n, 'WL', WL, 'WH', WH, 'len', len, ...
    'Wp', fd.mslWidth(Z0, sub, fc), 'Lp', max(5e-3, 3*sub.h));
info = struct('g', g, 'ZL', ZL, 'ZH', ZH, 'eL', eL, 'eH', eH, ...
    'lenFirstPass', len0, 'X', X, 'isC', isC);
end
