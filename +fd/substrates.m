function S = substrates()
%FD.SUBSTRATES  Substrate presets for boards that JLCPCB can manufacture.
%   S = fd.substrates() returns a struct array with fields
%     name, er, tand, hList (m, available core thicknesses), t (copper, m),
%     sigma (S/m), note
%
%   Values (check the JLCPCB order page before fabricating; they change):
%   * FR4: JLCPCB publishes Dk = 4.5 for 2-layer boards. FR4 Dk is not
%     tightly controlled (+/-0.2) and tan(delta) ~0.02 at a few GHz, so
%     expect a few % frequency shift - measure a test resonator to calibrate.
%   * RO4350B: Rogers "design Dk" 3.66 (process Dk 3.48), tan(delta) 0.0037.
%     JLCPCB lists 0.51 / 0.76 / 1.52 mm thicknesses.
%   * PTFE: JLCPCB offers PTFE ("Teflon") boards, but the exact laminate and
%     Dk are not clearly published - CONFIRM Dk WITH JLCPCB before ordering.

oz1 = 35e-6; cu = 5.8e7;
S(1) = mk('FR4 (JLCPCB standard)', 4.5, 0.020, [0.4 0.6 0.8 1.0 1.2 1.6 2.0]*1e-3, oz1, cu, ...
    'Cheap and fast. Lossy (Qu ~ 60-90) and Dk varies +/-0.2.');
S(2) = mk('Rogers RO4350B (JLCPCB)', 3.66, 0.0037, [0.508 0.762 1.524]*1e-3, oz1, cu, ...
    'Low loss (Qu ~ 150-250), tight Dk. Good for narrowband filters.');
S(3) = mk('PTFE (JLCPCB, confirm Dk)', 2.65, 0.0015, [0.762 1.524]*1e-3, oz1, cu, ...
    'Lowest loss. Dk value here is a placeholder - confirm with JLCPCB.');
S(4) = mk('Custom', 4.4, 0.02, 1.6e-3, oz1, cu, 'Enter your own values.');
end

function s = mk(name, er, tand, hList, t, sigma, note)
s = struct('name', name, 'er', er, 'tand', tand, 'hList', hList, ...
           't', t, 'sigma', sigma, 'note', note);
end
