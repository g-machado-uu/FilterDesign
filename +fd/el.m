function e = el(kind, n, varargin)
%FD.EL  Create a circuit element for fd.circuitS.
%   fd.el('line',   [a b],       'Zc',Z,'ee',ee,'alpha',a,'len',L)
%   fd.el('stub',   a,           'Zc',Z,'ee',ee,'alpha',a,'len',L)   open stub
%   fd.el('cline',  [a1 b1 a2 b2],'Ze',..,'Zo',..,'ee',..,'eo',..,'ae',..,'ao',..,'len',L)
%   fd.el('shunt',  a,           'Y', Yvec)
%   fd.el('series', [a b],       'Y', Yvec)
%   Zc/ee/alpha etc. may be scalars or vectors over frequency.
e = struct('kind', kind, 'n', n, 'Zc', [], 'ee', [], 'alpha', [], 'len', [], ...
           'Ze', [], 'Zo', [], 'eo', [], 'ae', [], 'ao', [], 'Y', [], 'Zp', [], 'Yp', []);
for k = 1:2:numel(varargin)
    e.(varargin{k}) = varargin{k+1};
end
end
