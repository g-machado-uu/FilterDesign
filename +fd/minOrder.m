function n = minOrder(type, rippleDb, omegaS, AsDb)
%FD.MINORDER  Smallest order meeting a stopband attenuation.
%   n = fd.minOrder(type, rippleDb, omegaS, AsDb)
%   omegaS is the normalised stopband frequency (lowpass prototype),
%   e.g. for a bandpass: omegaS = (fs/f0 - f0/fs)/FBW.
omegaS = abs(omegaS);
switch lower(type)
    case 'butterworth'
        n = ceil(log10(10^(AsDb/10) - 1) / (2*log10(omegaS)));
    case 'chebyshev'
        n = ceil(acosh(sqrt((10^(AsDb/10) - 1)/(10^(rippleDb/10) - 1))) / acosh(omegaS));
end
n = max(n, 1);
end
