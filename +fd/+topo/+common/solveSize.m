function a = solveSize(fOf, f0, lim, what, toHigher, toLower)
%FD.TOPO.COMMON.SOLVESIZE  Find the size a in [lim(1) lim(2)] with fOf(a) = f0.
%   fOf(a) must fall as a grows (bigger resonator -> lower frequency).
%   If f0 is out of reach, raise an error that says which frequencies are
%   reachable with the current settings and what to change (toHigher /
%   toLower: advice text), instead of fzero's "endpoints must differ in sign".
fMax = fOf(lim(1)); fMin = fOf(lim(2));
G = @(x) x/1e9;
if f0 > fMax
    error('fd:range', ['%s cannot reach f0 = %.3g GHz with these settings.\n\n' ...
        'Even the smallest one that fits these widths (%.2f mm) resonates at %.3g GHz, ' ...
        'so the reachable range is about %.3g - %.3g GHz.\n\nTo go higher: %s'], ...
        what, G(f0), lim(1)*1e3, G(fMax), G(fMin), G(fMax), toHigher);
end
if f0 < fMin
    error('fd:range', ['%s cannot reach f0 = %.3g GHz with these settings.\n\n' ...
        'It would have to be bigger than %.0f mm (at that size it resonates at %.3g GHz), ' ...
        'so the reachable range is about %.3g - %.3g GHz.\n\nTo go lower: %s'], ...
        what, G(f0), lim(2)*1e3, G(fMin), G(fMin), G(fMax), toLower);
end
a = fzero(@(x) log(fOf(x)/f0), lim);
end
