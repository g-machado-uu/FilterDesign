function r = laplaceCoupled(W, s, h, er, nPerMin)
%LAPLACECOUPLED  Quasi-static reference for symmetric coupled microstrip.
%   r = laplaceCoupled(W, s, h, er) solves Laplace's equation on a 2D grid
%   (finite differences, zero-thickness strips, grounded box far away) for
%   the even and odd modes, with and without the dielectric, and returns
%   Ze, Zo, ee, eo. With s = Inf it returns the single line (Z, ee).
%   Used only to validate the closed-form formulas in fd.cmsl / fd.msl.
if nargin < 5, nPerMin = 16; end
single = isinf(s); if single, s = 4*h; end
dx = min([W, s, h]) / nPerMin;
side = 12*h; top = 12*h;
X = 2*W + s + 2*side; Y = h + top;
nx = round(X/dx) + 1; ny = round(Y/dx) + 1;
x = linspace(-X/2, X/2, nx); y = linspace(0, Y, ny); dx = x(2) - x(1);
jh = round(h/dx) + 1;                                % grid row of the strips
s1 = abs(x + (s/2 + W/2)) <= W/2 + 1e-12;            % left strip
s2 = abs(x - (s/2 + W/2)) <= W/2 + 1e-12;            % right strip
if single, s2(:) = false; s1 = abs(x) <= W/2 + 1e-12; end
modes = {'even', 'odd'}; if single, modes = {'even'}; end
for mi = 1:numel(modes)
    v2 = 1; if strcmp(modes{mi}, 'odd'), v2 = -1; end
    for ei = 1:2
        e = 1; if ei == 1, e = er; end
        C(mi, ei) = solveC(nx, ny, jh, s1, s2, v2, e, dx); %#ok<AGROW>
    end
end
if single, C = 2*C; end   % one strip: U = C/2 (two strips at +-1: U = C per line)
c0 = 299792458;
Z  = 1 ./ (c0 * sqrt(C(:,1) .* C(:,2)));
ee = C(:,1) ./ C(:,2);
r.Ze = Z(1); r.ee = ee(1);
if ~single, r.Zo = Z(2); r.eo = ee(2); end
end

function C = solveC(nx, ny, jh, s1, s2, v2, er, dx)
e0 = 8.8541878128e-12;
% permittivity per cell (cells between grid rows j and j+1)
epsCell = ones(ny-1, 1); epsCell(1:jh-1) = er;       % dielectric below strips
N = nx*ny; id = @(i, j) (j-1)*nx + i;
fixed = false(nx, ny); V = zeros(nx, ny);
fixed(:, 1) = true; fixed(:, end) = true; fixed(1, :) = true; fixed(end, :) = true;
fixed(s1, jh) = true; V(s1, jh) = 1;
fixed(s2, jh) = true; V(s2, jh) = v2;
I = []; J = []; S = [];
[ii, jj] = ndgrid(1:nx, 1:ny);
free = ~fixed(:);
% 5-point stencil with face permittivities
eN = zeros(nx, ny); eS = eN;
eN(:, 1:ny-1) = repmat(epsCell.', nx, 1);           % face above node (j -> j+1)
eS(:, 2:ny)   = repmat(epsCell.', nx, 1);           % face below node
eE = (eN + eS)/2; eW = eE;                           % horizontal faces: average
k = id(ii, jj);
nbr = {id(min(ii+1,nx), jj), eE; id(max(ii-1,1), jj), eW; ...
       id(ii, min(jj+1,ny)), eN; id(ii, max(jj-1,1)), eS};
diagv = zeros(nx, ny);
for q = 1:4
    I = [I; k(:)]; J = [J; nbr{q,1}(:)]; S = [S; nbr{q,2}(:)]; %#ok<AGROW>
    diagv = diagv + nbr{q,2};
end
A = sparse([I; k(:)], [J; k(:)], [S; -diagv(:)], N, N);
b = -A(:, ~free) * V(~free);
Vf = V(:); Vf(free) = A(free, free) \ b(free);
V = reshape(Vf, nx, ny);
% energy: U = 1/2 * sum eps |grad V|^2 * dx^2 ; per-line C = U (V = +-1)
gx = diff(V, 1, 1) / dx; gy = diff(V, 1, 2) / dx;
epsX = (eN(1:nx-1, :) + eS(1:nx-1, :) + eN(2:nx, :) + eS(2:nx, :))/4;
Ux = sum(sum(epsX .* gx.^2)) * dx^2;
Uy = sum(sum(eN(:, 1:ny-1) .* gy.^2)) * dx^2;
C = e0 * 0.5 * (Ux + Uy);
end
