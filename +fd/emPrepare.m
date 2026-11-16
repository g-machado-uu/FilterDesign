function [obj, info] = emPrepare(obj, sub, fmax, maxMemGB)
%FD.EMPREPARE  Set a converged MoM mesh and check that it fits in memory.
%   [obj, info] = fd.emPrepare(obj, sub, fmax, maxMemGB)
%   The RF PCB Toolbox default mesh is far too coarse for filters: it gave
%   eps_eff 2.19 instead of 2.68 (0.8 mm RO4003C) and 3.99 instead of 3.49
%   (1.6 mm FR4) - a 6-10% frequency error. Two-line tests converged at
%   MaxEdgeLength ~ lambda_g/50 on both boards (README.md, "Validation").
%   info.memGB is the toolbox's memory estimate; info.ok is false if it
%   exceeds maxMemGB (default: 40% of free RAM, max 12 GB).
if nargin < 4 || isempty(maxMemGB), maxMemGB = defaultBudget(); end
[~, ee] = fd.msl(fd.mslWidth(50, sub, fmax), sub, fmax);
lamg = 299792458/(fmax*sqrt(ee));
edge = lamg/50;
mesh(obj, 'MaxEdgeLength', edge);
memStr = memoryEstimate(obj, fmax);
info.edge = edge;
info.memGB = parseMem(memStr);
info.memStr = memStr;
info.budgetGB = maxMemGB;
info.ok = info.memGB <= maxMemGB;
end

function gb = parseMem(s)
tok = regexp(strtrim(s), '([\d.]+)\s*([KMGT]?B)', 'tokens', 'once');
if isempty(tok), gb = Inf; return; end
v = str2double(tok{1});
switch tok{2}
    case 'KB', gb = v/1024^2; case 'MB', gb = v/1024;
    case 'GB', gb = v;        case 'TB', gb = v*1024; otherwise, gb = v/1024^3;
end
end

function gb = defaultBudget()
gb = 4;
try
    if ispc
        m = memory; gb = m.MemAvailableAllArrays/1024^3;
    elseif ismac
        [~, o] = system('vm_stat | grep -E "Pages (free|inactive)"');
        tk = regexp(o, '(\d+)\.', 'tokens');
        pages = sum(cellfun(@(c) str2double(c{1}), tk));
        [~, ps] = system('pagesize'); gb = pages*str2double(ps)/1024^3;
        if ~isfinite(gb) || gb <= 0, gb = 8; end
    else
        [~, o] = system('awk ''/MemAvailable/ {print $2}'' /proc/meminfo');
        gb = str2double(o)/1024^2;
    end
catch
end
gb = min(0.4*gb, 12);
end
