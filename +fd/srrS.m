function S = srrS(d, sub, f)
%FD.SRRS  Microstrip line loaded by pairs of square SRRs (resonatorSplitRingSquare).
%   d fields (m): a, w, sp, gs, gc (gap line-to-ring), N pairs, gp (gap
%   between pairs, edge to edge as in the toolbox), W0 line width; line
%   length from fd.srrLine; optional kF
%   (frequency scale) and kM (coupling scale) from EM calibration.
%   Each SRR couples magnetically to the line: it adds a series impedance
%   (w M)^2 / Zsrr to the line, Zsrr = R + j w Ls + 1/(j w Cs). One ring sits
%   each side of the line (the toolbox places them in pairs).
%   M: flux of the line current (and its ground-plane image) through the
%   ring's mean loop.
f = f(:).'; w = 2*pi*f; mu0 = 4*pi*1e-7;
[Ls, Cs] = fd.srrLC(d.a, d.w, d.sp, sub);
if isfield(d, 'kF'), Cs = Cs/d.kF^2; end
am = d.a + d.sp;
y1 = d.W0/2 + d.gc + d.w/2; y2 = y1 + am;
h2 = (2*sub.h)^2;
M = mu0*am/(2*pi) * (log(y2/y1) - 0.5*log((y2^2 + h2)/(y1^2 + h2)));
if isfield(d, 'kM'), M = M*d.kM; end
w0 = 1/sqrt(Ls*Cs);
Rs = sqrt(pi*f*mu0/sub.sigma);
R = Rs*4*am/d.w + w0*Ls*sub.tand*0.5;            % copper + dielectric (approx.)
Zsrr = R + 1j*w*Ls + 1./(1j*w*Cs);
Zser = 2*(w*M).^2 ./ Zsrr;                       % two rings per position
[Z0, e0, a0] = fd.msl(d.W0, sub, f);
pitch = d.gp + d.a + 2*(d.sp + d.w);             % centre to centre
x = ((1:d.N) - (d.N + 1)/2)*pitch;                % ring-pair centres
Lline = fd.srrLine(d);
edges = [-Lline/2, x, Lline/2];
nn = 0; el = fd.el('line', [1 1]); el(:) = [];
P1 = 1; nn = 1; prev = P1;
for k = 1:d.N
    a = nn + 1; b = nn + 2; nn = nn + 2;
    el(end+1) = fd.el('line', [prev a], 'Zc', Z0, 'ee', e0, 'alpha', a0, 'len', edges(k+1) - edges(k)); %#ok<AGROW>
    el(end+1) = fd.el('series', [a b], 'Y', 1./Zser); %#ok<AGROW>
    prev = b;
end
nn = nn + 1; P2 = nn;
el(end+1) = fd.el('line', [prev P2], 'Zc', Z0, 'ee', e0, 'alpha', a0, 'len', edges(end) - edges(end-1));
S = fd.circuitS(el, nn, [P1 P2], f, 50);
end
