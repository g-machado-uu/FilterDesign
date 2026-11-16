function k = cornerK()
%FD.CORNERK  Right-angle bend shortening factor used by the hairpin model.
%   Each 90-degree corner of a hairpin shortens the resonator by k*W
%   relative to its centreline length. Calibrated against converged RF PCB
%   Toolbox MoM (mesh edge ~ lambda_g/50); see README.md, "Validation".
k = 1.0;
end
