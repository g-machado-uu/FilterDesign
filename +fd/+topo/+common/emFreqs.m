function f = emFreqs(T, spec, info, stage)
%FD.TOPO.COMMON.EMFREQS  Frequencies for a full-filter EM run (few points,
%where they tell most). stage 'coarse' only; resonances are refined later.
n = 11;
switch T.kind
    case 'BP'
        f0 = sqrt(spec.f1*spec.f2); B = (spec.f2 - spec.f1);
        f = linspace(spec.f1 - 0.8*B, spec.f2 + 0.8*B, n);
        if any(strcmp(T.id, {'stubBPF'})), f = linspace(0.3, 1.7, n)*f0; end
    case 'BS'
        f0 = sqrt(spec.f1*spec.f2);
        f = linspace(0.4, 1.6, n)*f0;
        if strcmp(T.id, 'spurline'), f = linspace(0.75, 1.25, 9)*f0; end
    case 'LP', f = linspace(0.2, 2.2, n)*spec.fc;
    case 'HP', f = linspace(0.4, 0.95*spec.fu, n)*spec.fc;
    case 'RES', f = linspace(0.75, 1.25, 9)*spec.f0;
end
f = max(f, 1e6);
end
