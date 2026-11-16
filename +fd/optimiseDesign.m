function [d, report] = optimiseDesign(T, d, sub, spec, info, varargin)
%FD.OPTIMISEDESIGN  Tune dimensions so the circuit model matches the target.
%   [d, report] = fd.optimiseDesign(T, d, sub, spec, info)
%   T is a topology (fd.topologies). The variables come from T.pack, the
%   target from T.objective or, by default, from T.ideal: linear |S21| and
%   |S11| are matched (which weights the passband and band edges) with a
%   light dB term for the skirts. Uses lsqnonlin when the Optimization
%   Toolbox is available, otherwise fminsearch.
%   Options: 'MaxIter' (default 60).
p = inputParser; p.addParameter('MaxIter', 60); p.parse(varargin{:}); o = p.Results;
if isempty(T.pack), report = struct('cost0', NaN, 'cost', NaN); return; end
if isempty(T.optgrid), f = T.fgrid(spec, info); else, f = T.optgrid(spec, info); end
f = f(round(linspace(1, numel(f), min(numel(f), 241))));
starts = {d};
if isfield(T, 'starts') && ~isempty(T.starts), starts = [starts, T.starts(d, spec, info)]; end
tgt = []; if isempty(T.objective), tgt = T.ideal(spec, info, f); end
best = []; cost0 = NaN;
for k = 1:numel(starts)          % multi-start for wideband designs (T.starts)
    [dk, c0, ck, xk0, xk] = solve(starts{k});
    if k == 1, cost0 = c0; x0 = xk0; end
    if isempty(best) || ck < best.cost, best = struct('d', dk, 'cost', ck, 'x', xk); end
end
if best.cost > cost0, best = struct('d', d, 'cost', cost0, 'x', x0); end   % never make it worse
d = best.d;
report = struct('cost0', cost0, 'cost', best.cost, 'x0', x0, 'x', best.x);

    function [dOut, c0, c, x0_, x] = solve(dS)
        [x0_, lb, ub, unpack] = T.pack(dS, sub, spec, info);
        if isempty(T.objective)
            res = @(x) match(T.model(unpack(x), sub, f), tgt);
        else
            res = @(x) T.objective(T.model(unpack(x), sub, f), f, spec, info);
        end
        r0 = res(x0_); c0 = sum(r0.^2);
        if license('test', 'Optimization_Toolbox') && exist('lsqnonlin', 'file')
            opts = optimoptions('lsqnonlin', 'Display', 'off', 'MaxIterations', o.MaxIter, ...
                'FunctionTolerance', 1e-9, 'StepTolerance', 1e-9);
            x = lsqnonlin(res, x0_, lb, ub, opts);
        else
            clip = @(x) min(max(x, lb), ub);
            x = clip(fminsearch(@(x) sum(res(clip(x)).^2), x0_, optimset('MaxIter', 40*o.MaxIter, 'Display', 'off')));
        end
        c = sum(res(x).^2);
        if c > c0, x = x0_; c = c0; end
        dOut = unpack(x);
    end
end

function r = match(S, tgt)
m21 = abs(squeeze(S(2,1,:))).'; m11 = abs(squeeze(S(1,1,:))).';
a21 = abs(tgt(1,:)); a11 = abs(tgt(2,:));
db = @(x) max(20*log10(x + 1e-12), -60);
r = [a21 - m21, a11 - m11, 0.01*(db(a21) - db(m21))].';
end
