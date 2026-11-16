function [fr, depth, Q] = peakFreq(S, f, notch)
%FD.TOPO.COMMON.PEAKFREQ  Resonance from |S21|: peak (notch=false) or dip.
%   Returns the frequency, the |S21| there (dB) and the loaded Q from the
%   3 dB width (NaN if it cannot be measured inside f).
a = 20*log10(abs(squeeze(S(2,1,:)))).';
if notch, [depth, i] = min(a); ref = depth + 3; in = a <= ref;
else,     [depth, i] = max(a); ref = depth - 3; in = a >= ref; end
fr = f(i);
lo = find(~in(1:i), 1, 'last'); hi = i - 1 + find(~in(i:end), 1, 'first');
if isempty(lo) || isempty(hi), Q = NaN; else, Q = fr/(f(hi) - f(lo)); end
end
