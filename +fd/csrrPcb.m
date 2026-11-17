function p = csrrPcb(d, sub)
%FD.CSRRPCB  pcbComponent of a 50-ohm line over a square CSRR in the ground.
%   Top: straight line W0 x L. Bottom: L x Wb ground with N cells of two
%   concentric square slot rings (slot width w, metal sp between them)
%   under the line, a gap gp apart (fd.csrrBoard). The inner ring's metal bridge (split) is on +x,
%   the outer ring's on -x, as in Baena et al. (2005).
diel = dielectric('Name', 'sub', 'EpsilonR', sub.er, 'LossTangent', sub.tand, 'Thickness', sub.h);
[L, Wb, xc] = fd.csrrBoard(d);
top = traceRectangular('Length', L, 'Width', d.W0, 'Center', [0 0]);
gnd = traceRectangular('Length', L, 'Width', Wb, 'Center', [0 0]);
a1 = d.a; a2 = d.a + 2*(d.sp + d.w);                % outer sides of the slot rings
for x0 = xc
    gnd = gnd - slotRing(a1, d.w, d.gs, +1, x0) - slotRing(a2, d.w, d.gs, -1, x0);
end
p = pcbComponent;
p.Name = 'CSRR';
p.BoardShape = traceRectangular('Length', L, 'Width', Wb, 'Center', [0 0]);
p.BoardThickness = sub.h;
p.Layers = {top, diel, gnd};
p.FeedLocations = [-L/2 0 1 3; L/2 0 1 3];
p.FeedDiameter = d.W0/2;
cond = metal('Copper'); cond.Thickness = sub.t; p.Conductor = cond;
end

function s = slotRing(a, w, gs, side, x0)
% square annulus of outer side a and width w centred at (x0, 0), with a
% metal bridge of width gs left in the middle of the side at x0 + side*a/2
outer = traceRectangular('Length', a, 'Width', a, 'Center', [x0 0]);
inner = traceRectangular('Length', a - 2*w, 'Width', a - 2*w, 'Center', [x0 0]);
bridge = traceRectangular('Length', w*1.02, 'Width', gs, 'Center', [x0 + side*(a/2 - w/2) 0]);
s = outer - inner - bridge;
end
