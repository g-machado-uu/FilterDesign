function S = circuitS(el, nNodes, ports, f, Z0)
%FD.CIRCUITS  S-parameters of a network of transmission-line elements.
%   S = fd.circuitS(el, nNodes, ports, f, Z0)
%     el      struct array of elements (build with fd.el)
%     nNodes  number of nodes (ground is implicit)
%     ports   node index of each port, e.g. [1 7]
%     f       frequency vector (Hz)
%     Z0      port reference impedance (ohm), default 50
%   Returns S as nPorts x nPorts x numel(f).
%
%   Method: nodal admittance matrix. Each element adds its Y-matrix
%   ("stamp") to the nodes it connects; ports are Norton sources with
%   internal impedance Z0, and S_ij = (2/Z0)*inv(Yt)_ij - delta_ij.

if nargin < 5, Z0 = 50; end
F = numel(f); f = reshape(f, 1, 1, F);
Y = zeros(nNodes, nNodes, F);
w = 2*pi*f; c0 = 299792458;

for e = el
    switch e.kind
        case 'line'            % 2-port uncoupled line: nodes [a b]
            g  = gam(e.alpha, e.ee, w, c0);
            y1 = coth(g*e.len) ./ pr(e.Zc);
            y2 = -csch(g*e.len) ./ pr(e.Zc);
            Y = stamp(Y, e.n, cat(1, [y1 y2], [y2 y1]));
        case 'stub'            % open-circuited stub to ground at node n
            g  = gam(e.alpha, e.ee, w, c0);
            Y = stamp(Y, e.n, tanh(g*e.len) ./ pr(e.Zc));
        case 'cline'           % symmetric coupled pair: nodes [a1 b1 a2 b2]
            ge = gam(e.ae, e.ee, w, c0);  go = gam(e.ao, e.eo, w, c0);
            Ze = pr(e.Ze); Zo = pr(e.Zo);
            e11 = coth(ge*e.len)./Ze;  e12 = -csch(ge*e.len)./Ze;
            o11 = coth(go*e.len)./Zo;  o12 = -csch(go*e.len)./Zo;
            s11 = (e11+o11)/2; s12 = (e12+o12)/2;   % same line
            m11 = (e11-o11)/2; m12 = (e12-o12)/2;   % between lines
            M = cat(1, [s11 s12 m11 m12], [s12 s11 m12 m11], ...
                       [m11 m12 s11 s12], [m12 m11 s12 s11]);
            Y = stamp(Y, e.n, M);
        case 'mtl'             % N coupled lines: nodes [a1..aN b1..bN]
            N = numel(e.n)/2; M = zeros(2*N, 2*N, F);
            for k = 1:F
                Zk = e.Zp(:, :, k); [T, Lam] = eig(Zk * e.Yp(:, :, k));
                g = sqrt(diag(Lam)); g(real(g) < 0) = -g(real(g) < 0);
                Ti = inv(T); %#ok<MINV>
                Yc = Zk \ (T * diag(g) * Ti);
                Y11 = Yc * T * diag(coth(g*e.len)) * Ti;
                Y12 = -Yc * T * diag(csch(g*e.len)) * Ti;
                M(:, :, k) = [Y11 Y12; Y12 Y11];
            end
            Y = stamp(Y, e.n, M);
        case 'shunt'           % lumped shunt admittance to ground (vector over f)
            Y = stamp(Y, e.n, pr(e.Y));
        case 'series'          % lumped series admittance between two nodes
            y = pr(e.Y);
            Y = stamp(Y, e.n, cat(1, [y -y], [-y y]));
        otherwise
            error('fd:circuitS', 'Unknown element kind "%s".', e.kind);
    end
end

P = numel(ports);
for k = 1:P
    Y(ports(k), ports(k), :) = Y(ports(k), ports(k), :) + 1/Z0;
end
B = zeros(nNodes, P); B(sub2ind(size(B), ports, 1:P)) = 1;
V = pagemldivide(Y, repmat(B, 1, 1, F));          % nNodes x P x F
S = (2/Z0) * V(ports, :, :) - eye(P);
end

function g = gam(alpha, ee, w, c0)
g = pr(alpha) + 1j * w .* sqrt(pr(ee)) / c0;
end

function x = pr(x)
% put a frequency vector on the 3rd (page) dimension; scalars pass through
if ~isscalar(x), x = reshape(x, 1, 1, []); end
end

function Y = stamp(Y, n, M)
F = size(Y, 3);
if size(M, 3) == 1, M = repmat(M, 1, 1, F); end
if numel(unique(n)) == numel(n)
    Y(n, n, :) = Y(n, n, :) + M;
else                                   % repeated nodes (ports tied together)
    for i = 1:numel(n)
        for j = 1:numel(n)
            Y(n(i), n(j), :) = Y(n(i), n(j), :) + M(i, j, :);
        end
    end
end
end
