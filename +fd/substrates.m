function S = substrates()
%FD.SUBSTRATES  Substrate presets: laminates that prototype PCB fabs commonly stock.
%   S = fd.substrates() returns a struct array with fields
%     name, er, tand, hList (m, typical core/dielectric thicknesses),
%     t (copper, m), sigma (S/m), note
%
%   er is the manufacturer's DESIGN Dk (the value to use for microstrip
%   design; it differs from the "process" Dk in the headline of the
%   datasheet). tand is at ~10 GHz. Thicknesses are the common ones: each
%   fab stocks only some of them, so check your fab's material list before
%   ordering and use "Custom" for anything else.
%
%   Where these come from (fab lists change; checked 2026-11):
%   * FR4: generic Dk 4.3-4.7, not tightly controlled (+/-0.2), tan(delta)
%     ~0.02 at a few GHz: expect a few % frequency shift and measure a test
%     resonator to calibrate. Offered everywhere.
%   * Rogers RO4350B / RO4003C: the most widely offered RF laminates
%     (e.g. PCBWay, Eurocircuits - RO4350B in its RF pool at 0.25 /
%     0.50 mm, RO4003C as a non-pooled option).
%   * Rogers RO3003, RO3010, RT/duroid 5880: PTFE-based, offered by e.g.
%     PCBWay and most RF specialist fabs (ask for a quote).
%   * Isola I-Tera MT40: the other material in Eurocircuits' RF pool.
%   * FR408HR: OSH Park's 4-layer stackup; a microstrip on the top layer
%     sees the 0.2 mm prepreg to the inner-layer ground (Dk 3.61 at 1 GHz).
%   * PTFE (generic "Teflon"): several fabs sell PTFE boards without naming
%     the laminate - CONFIRM THE Dk WITH THE FAB before relying on it.

oz1 = 35e-6; cu = 5.8e7;
S(1) = mk('FR4 (standard)', 4.5, 0.020, [0.4 0.6 0.8 1.0 1.2 1.6 2.0]*1e-3, oz1, cu, ...
    'Cheap and fast, offered everywhere. Lossy (Qu ~ 60-90) and Dk varies +/-0.2.');
S(2) = mk('Rogers RO4350B', 3.66, 0.0037, [0.254 0.508 0.762 1.524]*1e-3, oz1, cu, ...
    'The most common RF laminate. Low loss (Qu ~ 150-250), tight Dk. Good for narrowband filters.');
S(3) = mk('Rogers RO4003C', 3.55, 0.0027, [0.203 0.305 0.406 0.508 0.813 1.524]*1e-3, oz1, cu, ...
    'Like RO4350B with slightly lower loss; also widely offered. Not flame-rated (UL94).');
S(4) = mk('Rogers RO3003 (PTFE)', 3.00, 0.0010, [0.13 0.25 0.50 0.75 1.52]*1e-3, oz1, cu, ...
    'Very low loss, very stable Dk. PTFE: dearer and offered by fewer fabs.');
S(5) = mk('Rogers RO3010 (high Dk)', 11.2, 0.0022, [0.13 0.25 0.64 1.28]*1e-3, oz1, cu, ...
    'High Dk: resonators shrink by ~1/sqrt(Dk) - compact sensors. Narrow 50 Ω lines.');
S(6) = mk('Rogers RT/duroid 5880', 2.20, 0.0009, [0.127 0.254 0.381 0.508 0.787 1.575]*1e-3, oz1, cu, ...
    'Lowest loss, low Dk (larger circuits). PTFE: soft, dearer, fewer fabs.');
S(7) = mk('Isola I-Tera MT40', 3.45, 0.0031, [0.25 0.50]*1e-3, oz1, cu, ...
    'Low-loss RF laminate offered in some pooled RF services; similar to RO4350B.');
S(8) = mk('FR408HR (4-layer, top to L2)', 3.61, 0.0092, [0.2 1.6]*1e-3, oz1, cu, ...
    'Better than FR4. On a 4-layer board use h = 0.2 mm (top layer over the inner ground).');
S(9) = mk('PTFE (generic, confirm Dk)', 2.65, 0.0015, [0.762 1.524]*1e-3, oz1, cu, ...
    'Lowest-cost PTFE option at some fabs. Dk here is a placeholder - confirm it with the fab.');
S(10) = mk('Custom', 4.4, 0.02, 1.6e-3, oz1, cu, 'Enter your own values.');
end

function s = mk(name, er, tand, hList, t, sigma, note)
s = struct('name', name, 'er', er, 'tand', tand, 'hList', hList, ...
           't', t, 'sigma', sigma, 'note', note);
end
