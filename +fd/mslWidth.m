function W = mslWidth(Z0, sub, f)
%FD.MSLWIDTH  Strip width (m) that gives impedance Z0 at frequency f.
%   W = fd.mslWidth(50, sub, 3.5e9)
if nargin < 3, f = 1e9; end
g = @(lw) fd.msl(exp(lw), sub, f) - Z0;     % solve in log(W): Z0 is monotonic in W
lo = log(sub.h*0.01); hi = log(sub.h*30);
if g(lo) < 0 || g(hi) > 0
    error('fd:mslWidth', ['%.0f ohm is not realisable on this substrate ' ...
        '(width would be outside 0.01h .. 30h).'], Z0);
end
W = exp(fzero(g, [lo hi]));
end
