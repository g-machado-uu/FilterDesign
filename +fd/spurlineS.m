function S = spurlineS(d, sub, f)
%FD.SPURLINES  Circuit model of a microstrip spurline notch (filterSpurline).
%   d fields (m): W0 total line width (= port width), Wc spur width, sp slot
%   between spur and main path, Lc spur (coupled) length, gL gap at the spur's
%   free end, double (spurs on both sides), Lp port lines.
%   The spur and the main path form an asymmetric coupled pair (2D field
%   solution, cached), tied together at the input end; the spur's far end is
%   open, coupled to the output by the end-gap capacitance.
f = f(:).'; w = 2*pi*f;
if d.double, Wm = d.W0 - 2*(d.Wc + d.sp); Wv = [d.Wc Wm d.Wc]; sv = [d.sp d.sp]; main = 2; spurs = [1 3];
else,        Wm = d.W0 - d.Wc - d.sp;     Wv = [Wm d.Wc];      sv = d.sp;          main = 1; spurs = 2; end
if Wm <= 0, error('fd:spurline', 'Spur + slot are wider than the line.'); end
[C, Ca] = cachedC(Wv, sv, sub);
[Zp, Yp] = fd.mtlMatrices(C, Ca, Wv, sub, f);
N = numel(Wv); A = 1; B = 2; P1 = 3; P2 = 4; nn = 4;
ends = zeros(1, N);
for k = 1:N, if k == main, ends(k) = B; else, nn = nn + 1; ends(k) = nn; end, end
el = fd.el('mtl', [repmat(A, 1, N) ends], 'Zp', Zp, 'Yp', Yp, 'len', d.Lc);
[Zs, es, as] = fd.msl(d.Wc, sub, f);
Cg = fd.gapC(d.Wc, d.gL, sub);
for k = spurs
    el(end+1) = fd.el('series', [ends(k) B], 'Y', 1j*w*Cg); %#ok<AGROW>
    el(end+1) = fd.el('stub', ends(k), 'Zc', Zs, 'ee', es, 'alpha', as, 'len', 0.5*fd.openEnd(d.Wc, sub)); %#ok<AGROW>
end
[Zq, eq, aq] = fd.msl(d.W0, sub, f);
el(end+1) = fd.el('line', [P1 A], 'Zc', Zq, 'ee', eq, 'alpha', aq, 'len', d.Lp);
el(end+1) = fd.el('line', [B P2], 'Zc', Zq, 'ee', eq, 'alpha', aq, 'len', d.Lp + d.gL);
S = fd.circuitS(el, nn, [P1 P2], f, 50);
end

function [C, Ca] = cachedC(W, s, sub)
persistent cache
if isempty(cache), cache = containers.Map('KeyType', 'char', 'ValueType', 'any'); end
key = sprintf('%.4e_', [W s sub.h sub.er]);
if isKey(cache, key), v = cache(key); C = v{1}; Ca = v{2}; return; end
[C, Ca] = fd.mtlFD(W, s, sub.h, sub.er);
if cache.Count > 200, remove(cache, cache.keys{1}); end
cache(key) = {C, Ca};
end
