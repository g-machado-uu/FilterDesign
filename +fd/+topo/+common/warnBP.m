function w = warnBP(d, I, spec, ~)
%FD.TOPO.COMMON.WARNBP  Advice for coupled-resonator bandpass designs.
w = {};
if I.ILest > 3
    w{end+1} = sprintf(['Expected insertion loss %.1f dB. Narrow bandwidth (%.1f %%) on a lossy ' ...
        'board (Qu = %.0f) costs loss: widen the band, lower the order or use a Rogers board.'], ...
        I.ILest, 100*I.FBW, I.Qu);
end
if isfield(I, 'gapLimited') && any(I.gapLimited)
    w{end+1} = sprintf('Some gaps hit the %.2f mm fab limit - coupling will be weaker than designed.', spec.minGap*1e3);
end
end
