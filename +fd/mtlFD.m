function [C, Ca] = mtlFD(W, s, h, er, opt)
%FD.MTLFD  Maxwell capacitance matrices of N parallel microstrips (2D field solve).
%   [C, Ca] = fd.mtlFD(W, s, h, er)
%     W   1xN strip widths (m), s 1x(N-1) gaps between neighbours (m)
%   C  is the per-unit-length capacitance matrix with the dielectric (F/m),
%   Ca the same in air. The inductance matrix is L = mu0*eps0*inv(Ca).
%   Finite-volume solution on a graded grid (zero-thickness strips),
%   N solves per matrix. ~40 ms per strip.
if nargin < 5, opt = struct(); end
if ~isfield(opt, 'res'), opt.res = 30; end
if ~isfield(opt, 'box'), opt.box = 20; end
N = numel(W);
xl = zeros(1, N); x = 0;
for k = 1:N, xl(k) = x; x = x + W(k); if k < N, x = x + s(k); end, end
tot = x; xl = xl - tot/2;                         % strip k spans [xl(k), xl(k)+W(k)]
hmin = min([W, s, h]) / opt.res;
side = opt.box*h + 2*max(W);
keys = unique([-tot/2 - side, xl, xl + W, tot/2 + side]);
xg = grade(keys, hmin, h, 1.25);
yg = unique([grade([0 h], hmin, h/4, 1.25), grade([h, h + opt.box*h], hmin, h, 1.25)]);
[~, jh] = min(abs(yg - h)); yg(jh) = h;
C  = solveAll(xg, yg, jh, xl, W, er);
Ca = solveAll(xg, yg, jh, xl, W, 1);
end

function C = solveAll(x, y, jh, xl, W, er)
e0 = 8.8541878128e-12;
nx = numel(x); ny = numel(y); Nn = nx*ny; N = numel(W);
id = reshape(1:Nn, nx, ny);
dxl = diff(x); dyl = diff(y);
epsLayer = ones(1, ny-1); epsLayer(1:jh-1) = er;
hb = [0, dyl/2]; ha = [dyl/2, 0]; eb = [0, epsLayer]; ea = [epsLayer, 0];
[I1, J1] = ndgrid(1:nx-1, 1:ny);
Gh = (eb(J1).*hb(J1) + ea(J1).*ha(J1)) ./ dxl(I1);
[I2, J2] = ndgrid(1:nx, 1:ny-1);
wx = [dxl/2, 0] + [0, dxl/2];
Gv = epsLayer(J2) .* wx(I2) ./ dyl(J2);
a = [reshape(id(1:nx-1, :), [], 1); reshape(id(:, 1:ny-1), [], 1)];
b = [reshape(id(2:nx, :), [], 1);   reshape(id(:, 2:ny), [], 1)];
g = [Gh(:); Gv(:)];
L = sparse([a; b; a; b], [b; a; a; b], [-g; -g; g; g], Nn, Nn);
fixed = false(nx, ny); fixed([1 nx], :) = true; fixed(:, [1 ny]) = true;
owner = zeros(nx, 1);
for k = 1:N
    on = x >= xl(k) - 1e-12 & x <= xl(k) + W(k) + 1e-12;
    owner(on) = k; fixed(on, jh) = true;
end
f = ~fixed(:);
dec = decomposition(L(f, f));
C = zeros(N);
for k = 1:N
    V = zeros(nx, ny); V(owner == k, jh) = 1;
    Vv = V(:); Vv(f) = -(dec \ (L(f, ~f) * Vv(~f)));
    Q = L * Vv;                                   % net "charge" at each node
    Qn = reshape(Q, nx, ny);
    for j = 1:N, C(j, k) = e0 * sum(Qn(owner == j, jh)); end
end
C = (C + C.')/2;
end

function p = grade(keys, hmin, hmax, rate)
p = keys(1);
for k = 1:numel(keys)-1
    a = keys(k); L = keys(k+1) - a;
    if L <= 0, continue; end
    left = []; pos = 0; st = hmin;
    while pos + st < L/2, pos = pos + st; left(end+1) = pos; st = min(st*rate, hmax); end %#ok<AGROW>
    seg = unique([left, L - fliplr(left), L]);
    p = [p, a + seg]; %#ok<AGROW>
end
p = unique(p);
p = p([true, diff(p) > hmin/4]);
end
