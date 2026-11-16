function m = cmsl(W, s, sub, f)
%FD.CMSL  Symmetric coupled microstrip lines: even/odd-mode parameters.
%   m = fd.cmsl(W, s, sub, f) returns a struct with fields (size of f)
%     Ze, Zo     even/odd-mode impedances (ohm)
%     ee, eo     even/odd-mode effective permittivities
%     ae, ao     even/odd-mode attenuation (Np/m)
%     Ze0, Zo0, ee0, eo0  quasi-static values
%   W strip width (m), s gap (m), sub substrate struct, f frequency (Hz).
%
%   Static values come from a 2D field solution (fd.cmslFD), tabulated over
%   the gap once per (W, h, er) and interpolated, then scaled so the
%   isolated line matches Hammerstad-Jensen exactly. (The closed-form
%   Garg-Bahl formulas were tried first and overestimate the coupling by
%   30-70% for s > h; see README.md, "Validation".)
%   Dispersion: each mode is scaled with the single-line Kirschning-Jansen
%   factor. Losses: same simple models as fd.msl, per mode.

T = table4(W, sub.h, sub.er);
ls = log(min(max(s, T.s(1)), T.s(end)));
Ze0 = exp(interp1(T.ls, log(T.Ze), ls, 'pchip'));
Zo0 = exp(interp1(T.ls, log(T.Zo), ls, 'pchip'));
ee0 = interp1(T.ls, T.ee, ls, 'pchip');
eo0 = interp1(T.ls, T.eo, ls, 'pchip');

[~, eeS]  = fd.msl(W, sub, f);
[~, eeS0] = fd.msl(W, sub, 0);
r = (sub.er - eeS) / (sub.er - eeS0);            % 1 at DC, -> 0 at high f
m.ee = sub.er - (sub.er - ee0) * r;
m.eo = sub.er - (sub.er - eo0) * r;
m.Ze = Ze0 * sqrt(ee0 ./ m.ee);
m.Zo = Zo0 * sqrt(eo0 ./ m.eo);

c0 = 299792458; mu0 = 4*pi*1e-7;
Rs = sqrt(pi * f * mu0 / sub.sigma);
k0 = 2*pi*f/c0;
ad = @(e) k0 .* sub.er .* (e - 1) .* sub.tand ./ (2*sqrt(e) * (sub.er - 1));
m.ae = Rs ./ (m.Ze * W) + ad(m.ee);
m.ao = Rs ./ (m.Zo * W) + ad(m.eo);
m.Ze0 = Ze0; m.Zo0 = Zo0; m.ee0 = ee0; m.eo0 = eo0;
end

function T = table4(W, h, er)
% cached field-solver table over the gap for one (W, h, er)
persistent cache
if isempty(cache), cache = containers.Map('KeyType', 'char', 'ValueType', 'any'); end
key = sprintf('%.4e_%.4e_%.4f', W, h, er);
if isKey(cache, key), T = cache(key); return; end
s = logspace(log10(0.02*h), log10(10*h), 22);
Ze = zeros(size(s)); Zo = Ze; ee = Ze; eo = Ze;
for i = 1:numel(s)
    q = fd.cmslFD(W, s(i), h, er);
    Ze(i) = q.Ze; Zo(i) = q.Zo; ee(i) = q.ee; eo(i) = q.eo;
end
% calibrate the solver's ~1% discretisation bias to Hammerstad-Jensen
q = fd.cmslFD(W, 100*h, h, er);
Zhj = fd.msl(W, struct('er', er, 'h', h, 'tand', 0, 'sigma', 5.8e7), 0);
k = Zhj / ((q.Ze + q.Zo)/2);
T = struct('s', s, 'ls', log(s), 'Ze', Ze*k, 'Zo', Zo*k, 'ee', ee, 'eo', eo);
if cache.Count > 50, remove(cache, cache.keys{1}); end
cache(key) = T;
end
