function [C, Ca] = mtlNN(W, s, sub)
%FD.MTLNN  Fast nearest-neighbour capacitance matrices for N equal strips.
%   [C, Ca] = fd.mtlNN(W, s, sub)   W scalar width, s 1x(N-1) gaps
%   Built from the cached two-line field-solver tables (fd.cmsl): mutual
%   capacitance of each neighbouring pair, and each strip's ground
%   capacitance reduced by the shielding of the neighbour on each side.
%   Instant after the first call; agrees with the full N-strip solve
%   (fd.mtlFD) to a few % (see tests/validateModels.m).
c0 = 299792458;
N = numel(s) + 1;
[Z1, e1] = fd.msl(W, sub, 0);
C0 = sqrt(e1)/(c0*Z1); C0a = 1/(c0*Z1*sqrt(e1));
Cm = zeros(1, N-1); Cma = Cm; D = Cm; Da = Cm;
for k = 1:N-1
    m = fd.cmsl(W, s(k), sub, 0);
    Ce = sqrt(m.ee0)/(c0*m.Ze0); Co = sqrt(m.eo0)/(c0*m.Zo0);
    Cea = 1/(c0*m.Ze0*sqrt(m.ee0)); Coa = 1/(c0*m.Zo0*sqrt(m.eo0));
    Cm(k) = (Co - Ce)/2; Cma(k) = (Coa - Cea)/2;
    D(k) = C0 - Ce; Da(k) = C0a - Cea;          % shielding by one neighbour
end
C = build(C0, Cm, D, N); Ca = build(C0a, Cma, Da, N);
end

function C = build(C0, Cm, D, N)
C = zeros(N);
for i = 1:N
    g = C0;
    if i > 1, g = g - D(i-1); C(i, i-1) = -Cm(i-1); end
    if i < N, g = g - D(i);   C(i, i+1) = -Cm(i);   end
    C(i, i) = g + sum(-C(i, :));
end
end
