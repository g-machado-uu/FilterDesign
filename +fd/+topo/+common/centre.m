function f0 = centre(T, spec, info)
%FD.TOPO.COMMON.CENTRE  Characteristic frequency of a design (for meshing).
switch T.kind
    case {'BP', 'BS'}, f0 = sqrt(spec.f1*spec.f2);
    case 'LP', f0 = 1.5*spec.fc;
    case 'HP', f0 = spec.fc*(1 + spec.fu)/2;
    case 'RES', f0 = spec.f0;
end
if nargin > 2 && isstruct(info) && isfield(info, 'f0') && ~strcmp(T.kind, 'HP'), f0 = info.f0; end
end
