function r = cmslFD(W, s, h, er, opt)
%FD.CMSLFD  Quasi-static coupled-microstrip parameters by 2D field solution.
%   r = fd.cmslFD(W, s, h, er) returns Ze, Zo, ee, eo (static) for two
%   zero-thickness strips of width W, gap s, on height h, permittivity er.
%   Finite-volume solution of Laplace's equation on a graded grid (fine at
%   the strip edges), even and odd modes, with and without dielectric.
%   Typical run time 20-60 ms. Agrees with Hammerstad-Jensen to ~1% for a
%   single line; closed-form coupled-line formulas (Garg-Bahl) overestimate
%   Ze - Zo by 30-70% for s/h > 1, which is why this solver is used.

if nargin < 5, opt = struct(); end
if ~isfield(opt, 'res'), opt.res = 40; end
if ~isfield(opt, 'box'), opt.box = 25; end
hmin = min([W, s, h]) / opt.res;
side = opt.box*h + 5*W; top = opt.box*h;
xk = [0, s/2, s/2 + W];                                   % right half (symmetric)
x  = grade([xk, s/2 + W + side], hmin, h, 1.25);
x  = unique([-fliplr(x), x]);
y  = unique([grade([0 h], hmin, h/4, 1.25), grade([h, h + top], hmin, h, 1.25)]);
nx = numel(x); ny = numel(y); [~, jh] = min(abs(y - h)); y(jh) = h;
strip1 = x >= s/2 - 1e-12 & x <= s/2 + W + 1e-12;         % right strip
strip2 = x <= -s/2 + 1e-12 & x >= -s/2 - W - 1e-12;       % left strip

e0 = 8.8541878128e-12; c0 = 299792458;
C = zeros(2, 2);
for mode = 1:2                                            % 1 even, 2 odd
    v2 = 1; if mode == 2, v2 = -1; end
    for k = 1:2                                           % 1 dielectric, 2 air
        epsr = er; if k == 2, epsr = 1; end
        C(mode, k) = e0 * energy(x, y, jh, strip1, strip2, v2, epsr);
    end
end
Z  = 1 ./ (c0 * sqrt(C(:,1) .* C(:,2)));
ee = C(:,1) ./ C(:,2);
r = struct('Ze', Z(1), 'Zo', Z(2), 'ee', ee(1), 'eo', ee(2));
end

function U = energy(x, y, jh, st1, st2, v2, er)
% Assemble edge conductances G (finite volume) and solve; return U = C/V^2
nx = numel(x); ny = numel(y); N = nx*ny;
id = reshape(1:N, nx, ny);
dxl = diff(x); dyl = diff(y);
epsLayer = ones(1, ny-1); epsLayer(1:jh-1) = er;          % layer between rows j,j+1
% half-heights of each node's control volume, split below/above the node
hb = [0, dyl/2]; ha = [dyl/2, 0];
eb = [0, epsLayer]; ea = [epsLayer, 0];
% horizontal edges (i,j)-(i+1,j)
[I1, J1] = ndgrid(1:nx-1, 1:ny);
Gh = (eb(J1).*hb(J1) + ea(J1).*ha(J1)) ./ dxl(I1);
% vertical edges (i,j)-(i,j+1)
[I2, J2] = ndgrid(1:nx, 1:ny-1);
wx = [dxl/2, 0] + [0, dxl/2];
Gv = epsLayer(J2) .* wx(I2) ./ dyl(J2);
a = [reshape(id(1:nx-1, :), [], 1); reshape(id(:, 1:ny-1), [], 1)];
b = [reshape(id(2:nx, :), [], 1);   reshape(id(:, 2:ny), [], 1)];
g = [Gh(:); Gv(:)];
L = sparse([a; b; a; b], [b; a; a; b], [-g; -g; g; g], N, N);
V = zeros(nx, ny); fixed = false(nx, ny);
fixed([1 nx], :) = true; fixed(:, [1 ny]) = true;
fixed(st1, jh) = true; V(st1, jh) = 1;
fixed(st2, jh) = true; V(st2, jh) = v2;
f = ~fixed(:); Vv = V(:);
Vv(f) = -L(f, f) \ (L(f, ~f) * Vv(~f));
U = 0.5 * sum(g .* (Vv(a) - Vv(b)).^2);                   % = C_per_line for +-1
end

function p = grade(keys, hmin, hmax, rate)
% points through 'keys' with spacing hmin at each key, growing geometrically
p = keys(1);
for k = 1:numel(keys)-1
    a = keys(k); b = keys(k+1); L = b - a; seg = [];
    st = hmin; pos = 0; left = []; while pos + st < L/2, pos = pos + st; left(end+1) = pos; st = min(st*rate, hmax); end %#ok<AGROW>
    right = L - fliplr(left);
    seg = unique([left, right, L]);
    gaps = diff([0 seg]); if any(gaps < hmin/4), seg = seg(gaps >= hmin/4 | seg == L); end
    p = [p, a + seg]; %#ok<AGROW>
end
p = unique(p);
end
