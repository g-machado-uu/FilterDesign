function rows = stubTune(d, spec, ~)
%FD.TOPO.COMMON.STUBTUNE  Slider rows shared by the stub topologies.
rows = cell(0, 6);
wmin = max(spec.minGap, 0.15e-3);
for i = 1:d.n
    rows(end+1, :) = {sprintf('Stub %d length', i), 'Ls', i, 0.4*d.Ls(i), 1.6*d.Ls(i), true}; %#ok<AGROW>
end
for i = 1:d.n
    rows(end+1, :) = {sprintf('Stub %d width', i), 'Ws', i, wmin, max(2.5*d.Ws(i), 3e-3), true}; %#ok<AGROW>
end
for i = 1:d.n - 1
    rows(end+1, :) = {sprintf('Line %d–%d length', i, i+1), 'seg', i, 0.4*d.seg(i), 1.6*d.seg(i), true}; %#ok<AGROW>
end
end
