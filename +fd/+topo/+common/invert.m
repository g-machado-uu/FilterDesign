function x = invert(xGrid, yGrid, y, logx)
%FD.TOPO.COMMON.INVERT  Read a design curve backwards: x such that curve(x) = y.
if nargin < 4, logx = true; end
ok = isfinite(yGrid) & yGrid > 0;
xg = xGrid(ok); yg = yGrid(ok);
[yg, i] = unique(yg); xg = xg(i);
if logx
    x = exp(interp1(log(yg), log(xg), log(y), 'linear', 'extrap'));
else
    x = interp1(log(yg), xg, log(y), 'linear', 'extrap');
end
end
