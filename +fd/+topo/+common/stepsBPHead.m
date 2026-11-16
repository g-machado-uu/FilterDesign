function L = stepsBPHead(I, s)
%FD.TOPO.COMMON.STEPSBPHEAD  Steps 1-3 of a coupled-resonator bandpass design.
L = {};
L{end+1} = 'STEP 1 - Specification';
L{end+1} = sprintf('  f0 = sqrt(f1 f2) = %.4f GHz,  FBW = (f2-f1)/f0 = %.4f (%.1f %%)', I.f0/1e9, I.FBW, 100*I.FBW);
rip = ''; if strcmp(s.type, 'Chebyshev'), rip = sprintf(' %.2f dB', s.ripple); end
L{end+1} = sprintf('STEP 2 - Lowpass prototype (%s%s, n = %d)', s.type, rip, s.n);
L{end+1} = sprintf('  g = %s', mat2str(round(I.g, 4)));
L{end+1} = 'STEP 3 - Coupling coefficients and external Q';
L{end+1} = sprintf('  M(i,i+1) = FBW / sqrt(g_i g_i+1) = %s', mat2str(round(I.M, 4)));
L{end+1} = sprintf('  Qe = g0 g1 / FBW = %.2f (in), %.2f (out)', I.Qe(1), I.Qe(2));
end
