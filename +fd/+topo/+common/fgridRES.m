function f = fgridRES(spec, ~)
%FD.TOPO.COMMON.FGRIDRES  Plot grid around a single resonance: 0.5 f0 .. 1.5 f0.
f = linspace(0.5, 1.5, 1201) * spec.f0;
end
