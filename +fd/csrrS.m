function [S, fz] = csrrS(d, sub, f)
%FD.CSRRS  Microstrip line over a CSRR etched in the ground plane.
%   d fields (m): a (outer side of the inner slot ring), w slot width, sp
%   metal between the slots, gs split, W0 line width, Lline, Wb board
%   width; optional kF, kC (EM calibration).
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
el = [fd.el('line', [1 2], 'Zc', Z0, 'ee', e0l, 'alpha', a0, 'len', d.Lline/2), ...
      fd.el('line', [2 3], 'Zc', Z0, 'ee', e0l, 'alpha', a0, 'len', d.Lline/2), ...
      fd.el('shunt', 2, 'Y', 1./Zb)];
S = fd.circuitS(el, 3, [1 3], f, 50);
end
