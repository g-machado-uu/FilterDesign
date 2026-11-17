function [L, Wb, xc] = csrrBoard(d)
%FD.CSRRBOARD  Board length L, width Wb and CSRR centres xc (m) for a CSRR
%   design: N cells (default 1) a gap gp apart (edge to edge) along the
%   line, plus a margin. Recomputed from d so it follows the sliders.
N = 1; gp = 0;
if isfield(d, 'N'), N = d.N; end
if isfield(d, 'gp'), gp = d.gp; end
aOut = d.a + 2*(d.sp + d.w);
xc = ((1:N) - (N + 1)/2)*(aOut + gp);
L = max(N*aOut + (N - 1)*gp + 20e-3, 30e-3);
Wb = max(aOut + 16e-3, 25e-3);
end
