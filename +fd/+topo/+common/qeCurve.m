function Qe = qeCurve(singleS, tGrid, f0)
%FD.TOPO.COMMON.QECURVE  External Q vs tap position from S11 group delay.
%   singleS(t, f) returns S (1x1xF) of one resonator tapped at t.
%   Qe = w0 * tau(w0) / 4  (Hong & Lancaster eq. 8.?: tapped resonator).
fz = f0 * linspace(0.6, 1.4, 4001);
Qe = nan(size(tGrid));
for i = 1:numel(tGrid)
    S = singleS(tGrid(i), fz);
    ph = unwrap(angle(squeeze(S(1,1,:)))).';
    tau = -gradient(ph, 2*pi*fz);
    [tmax, im] = max(tau);
    Qe(i) = 2*pi*fz(im) * tmax / 4;
end
end
