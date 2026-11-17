function [S, fz] = csrrS(d, sub, f)
%FD.CSRRS  Microstrip line over a CSRR etched in the ground plane.
%   d fields (m): a (outer side of the inner slot ring), w slot width, sp
%   metal between the slots, gs split, W0 line width, N cells along the
%   line a gap gp apart (edge to edge; optional, default 1); board size
%   from fd.csrrBoard; optional kF, kC (EM calibration).
%   N cells: N identical shunt branches, line sections in between (the
%   cell-to-cell coupling is not modelled).
%   Model (Baena/Bonache): the line couples to the CSRR's inner patch through
%   Cc; the CSRR is a parallel Lr-Cr tank to ground (Babinet dual of the
%   SRR). This gives a transmission zero at f_z = 1/(2 pi sqrt(Lr (Cc+Cr)))
%   - the notch you see, slightly below the CSRR's own resonance.
f = f(:).'; w = 2*pi*f; mu0 = 4*pi*1e-7; e0 = 8.8541878128e-12;
[Ls, Cs] = fd.srrLC(d.a, d.w, d.sp, sub, true);
eav = (sub.er + 1)/2; eta2 = mu0/(e0*eav);
Cr = 4*Ls/eta2; Lr = Cs*eta2/4;                  % Babinet dual
if isfield(d, 'kF'), Lr = Lr/d.kF^2; end
patch = max(d.a - 2*d.w, 0.2*d.a);
Cc = 1.3 * e0*sub.er * d.W0*patch/sub.h;         % line over the inner patch (+fringing)
if isfield(d, 'kC'), Cc = Cc*d.kC; end
fz = 1/(2*pi*sqrt(Lr*(Cc + Cr)));               % transmission zero (lossless)
if isempty(f), S = []; return; end
G = w*Cr*sub.tand + 1e-4;                        % tank loss (dielectric + radiation, approx.)
Ysh = 1j*w*Cr + 1./(1j*w*Lr) + G;
Zb = 1./(1j*w*Cc) + 1./Ysh;
[Z0, e0l, a0] = fd.msl(d.W0, sub, f);
[L, ~, xc] = fd.csrrBoard(d); N = numel(xc);
edges = [-L/2, xc, L/2];                         % port 1 = node 1, cell k = node k+1
el = fd.el('shunt', 2, 'Y', 1./Zb); el(:) = [];
for k = 1:N + 1
    el(end+1) = fd.el('line', [k k+1], 'Zc', Z0, 'ee', e0l, 'alpha', a0, 'len', edges(k+1) - edges(k)); %#ok<AGROW>
end
for k = 1:N, el(end+1) = fd.el('shunt', k + 1, 'Y', 1./Zb); end %#ok<AGROW>
S = fd.circuitS(el, N + 2, [1 N+2], f, 50);
end
