function L = srrLine(d)
%FD.SRRLINE  Line (board) length for an SRR design: all N pairs, the N-1
%   gaps gp between them, and a margin at each end. Recomputed from d so it
%   follows the sliders.
aOut = d.a + 2*(d.sp + d.w);
L = max(d.N*aOut + (d.N - 1)*d.gp + 2*max(10e-3, aOut), 30e-3);
end
