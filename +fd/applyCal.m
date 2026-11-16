function d = applyCal(d, cal, T)
%FD.APPLYCAL  Attach EM-calibration knobs to a design, or remove them.
%   d = fd.applyCal(d, cal)        copy every field of cal into d
%   d = fd.applyCal(d, [], T)      remove the knobs listed in T.calSpec
if isempty(cal)
    if nargin > 2, flds = {T.calSpec.field}; else, flds = {'cK', 'kS', 'dtap', 'dL'}; end
    d = rmfield(d, intersect(flds, fieldnames(d)));
    return
end
fn = fieldnames(cal);
for k = 1:numel(fn), d.(fn{k}) = cal.(fn{k}); end
end
