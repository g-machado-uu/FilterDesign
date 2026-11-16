function C = gapC(W, s, sub)
%FD.GAPC  Approximate series capacitance of a microstrip gap of width W (F).
%   C = fd.gapC(W, s, sub)  W facing width, s gap length.
%   Quasi-static estimate: the slot-term of the Garg-Bahl gap capacitance
%   (field between the facing edges through the substrate and the air
%   above) times the facing width. Accuracy ~+/-30%: it sets how strongly
%   a gap-coupled resonator is fed (loaded Q, insertion loss), not its
%   resonant frequency. EM gives the real value.
e0 = 8.8541878128e-12;
eav = (sub.er + 1)/2;
C = W * e0 * eav/pi * log(coth(pi*s/(4*sub.h)));
end
