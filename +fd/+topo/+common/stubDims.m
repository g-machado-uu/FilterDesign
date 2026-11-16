function c = stubDims(d, lineName)
%FD.TOPO.COMMON.STUBDIMS  Dimension table shared by the stub topologies.
mm = @(x) round(x*1e3, 3);
c = {'Series line width', mm(d.W0), lineName;
     'Port line width', mm(d.Wp), '50 Ω feed line';
     'Port line length', mm(d.Lp), 'Feed line length each side'};
for i = 1:d.n
    if d.short(i), k = 'shorted (via at tip, Ø = width/2)'; else, k = 'open'; end
    c(end+1, :) = {sprintf('Stub %d length', i), mm(d.Ls(i)), ['From line centre to tip, ' k]}; %#ok<AGROW>
    c(end+1, :) = {sprintf('Stub %d width', i), mm(d.Ws(i)), sprintf('%.1f Ω stub', fd.msl(d.Ws(i), struct('er', d.er, 'h', d.h, 'tand', 0, 'sigma', 5.8e7), 0))}; %#ok<AGROW>
end
for i = 1:d.n - 1
    c(end+1, :) = {sprintf('Line %d–%d length', i, i+1), mm(d.seg(i)), 'Series line between stubs'}; %#ok<AGROW>
end
end
