function curvesKQ(axA, axB, d0, I)
%FD.TOPO.COMMON.CURVESKQ  Plot the k(s) and Qe(t) design curves with targets.
cla(axA); hold(axA, 'on'); ok = ~isnan(I.kGrid) & I.kGrid > 0;
plot(axA, I.sGrid(ok)*1e3, I.kGrid(ok), 'b-', 'LineWidth', 1.5);
plot(axA, d0.s*1e3, I.M, 'ro', 'MarkerFaceColor', 'r');
axA.YScale = 'log'; grid(axA, 'on'); xlabel(axA, 'gap s (mm)'); ylabel(axA, 'coupling k');
title(axA, 'Design curve k(s)', 'FontWeight', 'normal'); hold(axA, 'off');
cla(axB); hold(axB, 'on'); ok = isfinite(I.QeGrid) & I.QeGrid > 0;
plot(axB, I.tGrid(ok)*1e3, I.QeGrid(ok), 'b-', 'LineWidth', 1.5);
tq = d0.tap; if numel(tq) == 1, tq = [tq tq]; end
plot(axB, tq*1e3, I.Qe, 'ro', 'MarkerFaceColor', 'r');
axB.YScale = 'log'; grid(axB, 'on'); xlabel(axB, 'tap position t (mm)'); ylabel(axB, 'external Q');
title(axB, 'Design curve Qe(t)', 'FontWeight', 'normal'); hold(axB, 'off');
end
