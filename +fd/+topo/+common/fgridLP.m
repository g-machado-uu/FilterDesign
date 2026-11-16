function f = fgridLP(spec, ~)
%FD.TOPO.COMMON.FGRIDLP  Plot grid for lowpass: 0.02 fc .. 2.5 fc.
f = linspace(0.02, 2.5, 801) * spec.fc;
end
