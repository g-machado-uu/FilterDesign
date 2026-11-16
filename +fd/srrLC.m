function [Ls, Cs, f0, parts] = srrLC(a, w, sp, sub, comp)
%FD.SRRLC  Equivalent-circuit L and C of a square split-ring resonator.
%   [Ls, Cs, f0] = fd.srrLC(a, w, sp, sub)          SRR on a grounded board
%   [Ls, Cs, f0] = fd.srrLC(a, w, sp, sub, true)    complementary (CSRR):
%                                                   values of the dual SRR
%   a  outer side of the inner ring (RingLengthInner), w ring (or slot)
%   width, sp spacing between the rings (or metal between the slots).
%
%   Model (Marques/Baena): the two rings share a current loop of mean side
%   am = a + sp and effective width we = 2w + sp:
%     Ls = (2 mu0 am / pi) (ln(4 am / we) - 0.774)   (square loop, flat strip)
%   The rings' distributed capacitance C0 = 4 am * Cpul is split by the two
%   cuts into two halves in series: Cs = C0 / 4.
%     SRR : Cpul = mutual capacitance of the two coupled microstrips (field
%           solver tables, includes the ground plane);
%     CSRR: Cpul of two coplanar strips in eps_avg = (er+1)/2 (no ground),
%           then Babinet's principle gives a parallel Lr, Cr with the same f0.
%   Expect +/-10-15 % on f0 - EM tells the truth.
if nargin < 5, comp = false; end
mu0 = 4*pi*1e-7; e0 = 8.8541878128e-12; c0 = 299792458;
am = a + sp; we = 2*w + sp;
Ls = 2*mu0*am/pi * (log(4*am/we) - 0.774);
if comp
    eav = (sub.er + 1)/2; k = sp/(sp + 2*w);
    Cpul = e0*eav*ellipke(1 - k^2)/ellipke(k^2);
else
    m = fd.cmsl(w, sp, sub, 0);
    Ce = sqrt(m.ee0)/(c0*m.Ze0); Co = sqrt(m.eo0)/(c0*m.Zo0);
    Cpul = (Co - Ce)/2;
end
Cs = 4*am*Cpul/4;
f0 = 1/(2*pi*sqrt(Ls*Cs));
parts = struct('am', am, 'we', we, 'Cpul', Cpul);
end
