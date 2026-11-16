% RUNEMVALIDATION  Converged-mesh MoM check of every topology's default design.
%   Long-running (tens of minutes). Memory is capped per run (memCapGB) and
%   designs whose EM model does not fit are skipped and reported.
%   Results: tests/results/emValidation.mat (one entry per topology) and a
%   printed summary. Used for the manual's validation table.
addpath(fileparts(fileparts(mfilename('fullpath'))));
memCapGB = 9; maxSecPerPt = 150;
S = fd.substrates; sub = S(1); sub.h = 1.6e-3;
Tall = fd.topologies();
if ~exist('only', 'var'), only = {Tall.id}; end
resDir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(resDir, 'dir'), mkdir(resDir); end
resFile = fullfile(resDir, 'emValidation.mat');
if isfile(resFile), R = load(resFile); R = R.R; else, R = struct(); end
for T = Tall
    if ~any(strcmp(T.id, only)), continue; end
    fprintf('\n=== %s (%s) ===\n', T.name, T.kind);
    spec = T.defaults; spec.minGap = 0.15e-3;
    for p = T.params, spec.(p.field) = p.default; end
    try
        [d, info] = T.synth(spec, sub);
        if ~isempty(T.pack) && ~strcmp(T.kind, 'RES')
            d = fd.optimiseDesign(T, d, sub, spec, info);
        end
        if strcmp(T.em, 'section')
            [obj, dSim, f, ei] = T.emSection(d, sub, spec);
            [ei.ok] = deal(ei.memGB <= memCapGB);
        else
            dSim = d; obj = T.toolbox(d, sub);
            f0 = fd.topo.common.centre(T, spec, info);
            [obj, ei] = fd.emPrepare(obj, sub, f0, memCapGB);
            f = fd.topo.common.emFreqs(T, spec, info, 'coarse');
        end
        fprintf('mesh %.2f mm, memory %s (cap %g GB)\n', ei.edge*1e3, ei.memStr, memCapGB);
        if ~ei.ok, fprintf('SKIPPED: too large\n'); R.(T.id) = struct('skipped', true, 'mem', ei.memStr); continue; end
        t0 = tic; s1 = sparameters(obj, f(1)); tp = toc(t0);
        fprintf('first point %.0f s\n', tp);
        if tp > maxSecPerPt, fprintf('SKIPPED: too slow\n'); R.(T.id) = struct('skipped', true, 'mem', ei.memStr, 'tPt', tp); continue; end
        sE = fd.emRun(obj, f(2:end));
        P = cat(3, s1.Parameters, sE.Parameters); fE = [f(1), sE.Frequencies(:).'];
        if any(strcmp(T.id, {'ring','srr','csrr','spurline','stubBSF'}))   % refine round the resonance
            notch = ~strcmp(T.id, 'ring');
            [fr] = fd.topo.common.peakFreq(P, fE, notch);
            f2 = fr*(1 + linspace(-0.04, 0.04, 7)); f2 = setdiff(f2, fE);
            s2 = fd.emRun(obj, f2);
            [fE, i] = sort([fE, s2.Frequencies(:).']); P = cat(3, P, s2.Parameters); P = P(:, :, i);
        end
        sEM = sparameters(P, fE, 50);
        Sc = T.model(dSim, sub, fE);
        r = struct('skipped', false, 'f', fE, 'Sem', P, 'Scirc', Sc, 'd', dSim, 'mem', ei.memStr, ...
                   'edge', ei.edge, 'tTotal', toc(t0), 'spec', spec);
        r.errRaw = sqrt(mean(abs(abs(Sc(:)) - abs(P(:))).^2));
        if ~isempty(T.calSpec)
            [cal, fit] = fd.calibrate(T, dSim, sub, sEM);
            r.cal = cal; r.rms0 = fit.rms0; r.rms = fit.rms;
            fprintf('calibration: %s  rms %.3f -> %.3f\n', strjoin(cellfun(@(k) sprintf('%s=%.3g', k, cal.(k)), fieldnames(cal)', 'UniformOutput', false), ', '), fit.rms0, fit.rms);
        end
        if any(strcmp(T.id, {'ring','srr','csrr','spurline','stubBSF'}))
            notch = ~strcmp(T.id, 'ring');
            fe = fd.topo.common.peakFreq(P, fE, notch);
            ff = linspace(fE(1), fE(end), 4001); fc_ = fd.topo.common.peakFreq(T.model(dSim, sub, ff), ff, notch);
            r.fEM = fe; r.fCirc = fc_;
            fprintf('resonance: EM %.4f GHz, circuit %.4f GHz (%+.1f %%)\n', fe/1e9, fc_/1e9, 100*(fc_/fe - 1));
        end
        fprintf('done in %.0f s, rms |S| error (raw model) %.3f\n', r.tTotal, r.errRaw);
        R.(T.id) = r;
    catch e
        fprintf('FAILED: %s (%s line %d)\n', e.message, e.stack(1).name, e.stack(1).line);
        R.(T.id) = struct('skipped', true, 'error', e.message);
    end
    save(resFile, 'R');
end
