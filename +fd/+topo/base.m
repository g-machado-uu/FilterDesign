function T = base()
%FD.TOPO.BASE  Default (empty) topology definition. Every topology file
%calls this and fills in what it supports. The app only talks to these
%fields, so adding a topology = adding one file to +fd/+topo and listing it
%in fd.topologies.
%
%  Identity
%    id, name     short id and display name
%    kind         'LP' | 'HP' | 'BP' | 'BS' | 'RES'
%    blurb        one-paragraph description shown in the app
%  Specification
%    defaults     struct: f1,f2 (BP/BS) | fc (LP/HP) | f0 (RES), n, type,
%                 ripple, fs, As (order helper)
%    hasOrder     false for single resonators / notches
%    orderLim     [min max];  orderOdd  true -> only odd orders
%    params       struct array (field, label, default, lim, tip): extra
%                 numbers stored in spec.(field)
%  Engine (function handles)
%    synth(spec, sub)        -> [d, info]   dimensions + intermediate values
%    model(d, sub, f)        -> S (2x2xF)   fast circuit model
%    toolbox(d, sub)         -> RF PCB Toolbox object (layout/EM/Gerber)
%    fgrid(spec, info)       -> plotting frequencies
%    ideal(spec, info, f)    -> [S21; S11] target, or [] for none
%    pack(d, sub, spec, info)-> [x0, lb, ub, unpack]  optimiser variables
%    objective(S, f, spec, info) -> residual vector (optional; default:
%                                   match the ideal response)
%    optgrid(spec, info)     -> frequencies used by the optimiser
%                               (optional; default fgrid)
%    starts(d, spec, info)   -> cell of extra starting designs (optional;
%                               the optimiser keeps the best result)
%  Teaching / UI
%    tune(d, spec, sub)      -> rows {label, field, idx, min, max, mirror}
%    dims(d, spec, sub)      -> rows {name, value_mm, meaning}
%    steps(d0, info, spec, sub) -> cellstr, the worked design
%    curves(axA, axB, d0, info) -> plot design curves (optional)
%    warn(d, info, spec, sub)   -> cellstr of advice
%  EM
%    em          'section' (calibrate on a small section) | 'full'
%    emSection(d, sub, spec)  -> [obj, dSec, f, info]
%    calSpec     struct array (field, x0, lb, ub, scale) of model knobs
T = struct( ...
    'id', '', 'name', '', 'kind', '', 'blurb', '', ...
    'defaults', struct(), 'hasOrder', true, 'orderLim', [1 9], 'orderOdd', false, ...
    'params', struct('field', {}, 'label', {}, 'default', {}, 'lim', {}, 'tip', {}), ...
    'synth', [], 'model', [], 'toolbox', [], 'fgrid', [], 'ideal', [], ...
    'pack', [], 'objective', [], 'optgrid', [], 'starts', [], ...
    'tune', [], 'dims', [], 'steps', [], 'curves', [], 'warn', @(varargin) {}, ...
    'em', 'full', 'emSection', [], ...
    'calSpec', struct('field', {}, 'x0', {}, 'lb', {}, 'ub', {}, 'scale', {}));
end
