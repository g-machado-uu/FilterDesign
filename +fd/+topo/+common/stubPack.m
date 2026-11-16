function [x0, lb, ub, unpack] = stubPack(d, ~, spec, ~, which)
%FD.TOPO.COMMON.STUBPACK  Optimiser variables for stub topologies (symmetric).
%   which: cellstr of fields to vary, any of {'Ls', 'Ws', 'seg'}.
n = d.n; nu = ceil(n/2); nsu = ceil((n-1)/2);
wmin = max(spec.minGap, 0.15e-3);
x0 = []; lb = []; ub = []; map = {};
for k = 1:numel(which)
    switch which{k}
        case 'Ls',  v = d.Ls(1:nu);   l = 0.5*v; u = 1.5*v;
        case 'Ws',  v = d.Ws(1:nu);   l = max(wmin, 0.3*v); u = max(3*v, 2e-3);
        case 'seg', v = d.seg(1:nsu); l = 0.5*v; u = 1.5*v;
    end
    map{end+1} = {which{k}, numel(x0) + (1:numel(v))}; %#ok<AGROW>
    x0 = [x0, v]; lb = [lb, l]; ub = [ub, u]; %#ok<AGROW>
end
x0 = x0*1e3; lb = lb*1e3; ub = ub*1e3;
    function dd = un(x)
        dd = d; x = x*1e-3;
        for m = 1:numel(map)
            v = x(map{m}{2}); fld = map{m}{1}; N = numel(dd.(fld));
            dd.(fld) = [v, fliplr(v(1:N - numel(v)))];
        end
    end
unpack = @un;
end
