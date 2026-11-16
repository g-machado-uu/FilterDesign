function S = idealBP(spec, info, f)
%FD.TOPO.COMMON.IDEALBP  Coupled-resonator target with the resonators' Qu.
[s21, s11] = fd.idealBPF(info.g, info.f0, info.FBW, f, info.Qu);
S = [s21; s11];
end
