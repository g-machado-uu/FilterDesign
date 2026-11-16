% VALIDATEMODELS  Fast self-check of the design engine (no MoM, ~1 min).
%   Run from the project folder:  run tests/validateModels.m
%   Each line prints PASS/FAIL with the numbers compared.
addpath(fileparts(fileparts(mfilename('fullpath'))));
addpath(fileparts(mfilename('fullpath')));

% 1. prototype values (Hong & Lancaster table 3.2, n = 5, 0.1 dB)
g = fd.prototype(5, 'Chebyshev', 0.1);
ref = [1 1.1468 1.3712 1.9750 1.3712 1.1468 1];
check('Chebyshev g-values n=5 0.1 dB', max(abs(g - ref)) < 1e-3, 'max err %.1e', max(abs(g - ref)));

% 2. microstrip impedance vs RF PCB Toolbox
sub = struct('er', 4.5, 'h', 1.6e-3, 'tand', 0.02, 't', 35e-6, 'sigma', 5.8e7);
W = fd.mslWidth(50, sub, 3.5e9);
tl = txlineMicrostrip('Width', W, 'Height', sub.h, 'EpsilonR', sub.er, 'Thickness', 35e-6);
Zt = getZ0(tl, 3.5e9);
check('50-ohm width vs txlineMicrostrip', abs(Zt - 50) < 1.5, 'W = %.3f mm, toolbox Z0 = %.2f', W*1e3, Zt);

% 3. coupled lines: graded field solver vs uniform-grid reference
r = fd.cmslFD(0.99e-3, 1.5e-3, 0.813e-3, 3.55);
q = laplaceCoupled(0.99e-3, 1.5e-3, 0.813e-3, 3.55, 24);
e = max(abs([r.Ze/q.Ze - 1, r.Zo/q.Zo - 1]));
check('coupled-line solver vs uniform FD', e < 0.03, 'Ze %.1f/%.1f, Zo %.1f/%.1f', r.Ze, q.Ze, r.Zo, q.Zo);

% 4. hairpin synthesis lands on the specified band (circuit model)
S = fd.substrates; s4 = S(1); s4.h = 1.6e-3;
spec = struct('f1', 2.7e9, 'f2', 3.1e9, 'n', 5, 'type', 'Chebyshev', 'ripple', 0.1, ...
              'Zr', 50, 'slotFactor', 2, 'minGap', 0.15e-3);
[d, info] = fd.hairpinSynth(spec, s4);
f = linspace(2.2e9, 3.7e9, 1601); Sp = fd.hairpinS(d, s4, f);
a = 20*log10(abs(squeeze(Sp(2,1,:)))).'; [pk, ~] = max(a); b = f(a >= pk - 3);
[t21] = fd.idealBPF(info.g, info.f0, info.FBW, f, info.Qu); at = 20*log10(abs(t21));
bt = f(at >= max(at) - 3);
err = max(abs([b(1) - bt(1), b(end) - bt(end)]))/info.f0;
check('hairpin synthesis vs ideal 3 dB band', err < 0.02, ...
      'model %.3f-%.3f, ideal %.3f-%.3f GHz', b(1)/1e9, b(end)/1e9, bt(1)/1e9, bt(end)/1e9);

% 5. stepped-impedance LPF cutoff after optimisation
sp = struct('fc', 2.5e9, 'n', 5, 'type', 'Chebyshev', 'ripple', 0.1, 'Z0', 50, 'ZL', 20, 'ZH', 110, 'minGap', 0.15e-3);
[dl, il] = fd.sirSynth(sp, s4); dl = fd.optimiseDesign(fd.topo.sir(), dl, s4, sp, il);
f = linspace(0.05e9, 5e9, 2000); Sl = fd.sirS(dl, s4, f);
a = 20*log10(abs(squeeze(Sl(2,1,:)))).'; f3 = f(find(a < -3, 1));
[l21] = fd.idealLPF(fd.prototype(5, 'Chebyshev', 0.1), sp.fc, f); i3 = f(find(20*log10(abs(l21)) < -3, 1));
check('LPF -3 dB frequency vs ideal ladder', abs(f3/i3 - 1) < 0.05, 'model %.3f, ideal %.3f GHz', f3/1e9, i3/1e9);

% 6. EM calibration result (from tests/runSectionFR4.m, if it has been run)
res = fullfile(fileparts(mfilename('fullpath')), 'results', 'sectionFR4.mat');
if isfile(res)
    R = load(res);
    check('EM-calibrated model vs MoM (FR4 section)', R.fit.rms < 0.05, ...
          'rms |S| error %.3f -> %.3f (cK %.2f, kS %.2f, dtap %.2f mm)', ...
          R.fit.rms0, R.fit.rms, R.cal.cK, R.cal.kS, R.cal.dtap*1e3);
else
    fprintf('SKIP  EM calibration (run tests/runSectionFR4.m, ~4 min, 3 GB)\n');
end

% 7. every topology: synthesis (+ circuit optimisation) meets its target
for T = fd.topologies()
    sp = T.defaults; sp.minGap = 0.15e-3;
    for p = T.params, sp.(p.field) = p.default; end
    [d, info] = T.synth(sp, s4);
    if ~strcmp(T.kind, 'RES'), d = fd.optimiseDesign(T, d, s4, sp, info); end
    f = T.fgrid(sp, info); f = linspace(f(1), f(end), 4001);
    Sm = T.model(d, s4, f); a = 20*log10(abs(squeeze(Sm(2,1,:)))).';
    I = T.ideal(sp, info, f); if ~isempty(I), ai = 20*log10(abs(I(1,:))); end
    nm = sprintf('%s (%s)', T.name, T.kind);
    switch T.kind
        case 'BP'
            [m1, m2] = edges3(f, a, true); [i1, i2] = edges3(f, ai, true);
            e = max(abs([m1 - i1, m2 - i2]))/info.f0; tol = 0.03;
            check(nm, e < tol, '3 dB band %.3f-%.3f GHz, ideal %.3f-%.3f (err %.1f %% of f0, tol %.0f %%)', ...
                m1/1e9, m2/1e9, i1/1e9, i2/1e9, 100*e, 100*tol);
        case 'LP'
            m = f(find(a < -3, 1)); i = f(find(ai < -3, 1));
            check(nm, abs(m/i - 1) < 0.05, '-3 dB at %.3f GHz, ideal %.3f GHz', m/1e9, i/1e9);
        case 'HP'
            m = f(find(a > -3, 1)); i = f(find(ai > -3, 1));
            check(nm, abs(m/i - 1) < 0.05, '-3 dB at %.3f GHz, ideal %.3f GHz', m/1e9, i/1e9);
        case 'BS'
            f0 = sqrt(sp.f1*sp.f2); rej = -interp1(f, a, f0);
            if isempty(I)            % spurline: a single notch at f0
                fr = fd.topo.common.peakFreq(Sm, f, true);
                check(nm, abs(fr/f0 - 1) < 0.01 && rej > 10, 'notch %.4f GHz (target %.4f), %.1f dB', fr/1e9, f0/1e9, rej);
            else
                [m1, m2] = edges3(f, a, false); [i1, i2] = edges3(f, ai, false);
                e = max(abs([m1 - i1, m2 - i2]))/f0;
                check(nm, e < 0.08 && rej > 20, '-3 dB stop band %.3f-%.3f GHz, ideal %.3f-%.3f; %.0f dB at f0', ...
                    m1/1e9, m2/1e9, i1/1e9, i2/1e9, rej);
            end
        case 'RES'   % synthesis alone (no optimisation) must land on f0
            fr = fd.topo.common.peakFreq(Sm, f, ~strcmp(T.id, 'ring'));
            check(nm, abs(fr/sp.f0 - 1) < 0.01, 'resonance %.4f GHz, target %.4f GHz', fr/1e9, sp.f0/1e9);
    end
end

function [f1, f2] = edges3(f, a, pass)
% -3 dB edges of the passband (pass) or stop band round the extreme value
if pass, [pk, i] = max(a); m = a >= pk - 3; else, [~, i] = min(a); m = a <= -3; end
lo = find(~m(1:i), 1, 'last') + 1; if isempty(lo), lo = 1; end
hi = i - 1 + find(~m(i:end), 1, 'first') - 1; if isempty(hi), hi = numel(f); end
f1 = f(lo); f2 = f(hi);
end

function check(name, ok, varargin)
if ok, tag = 'PASS'; else, tag = 'FAIL'; end
fprintf('%-4s  %-42s %s\n', tag, name, sprintf(varargin{:}));
end
