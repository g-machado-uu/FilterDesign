function S = hairpinS(d, sub, f, mode)
%FD.HAIRPINS  Circuit-model S-parameters of a microstrip hairpin filter.
%   S = fd.hairpinS(d, sub, f)            full filter, 2x2xF
%   S = fd.hairpinS(d, sub, f, 'pair')    two resonators, very weakly fed
%                                          at their outer open ends (used to
%                                          extract coupling k vs gap)
%   S = fd.hairpinS(d, sub, f, 'single')  one resonator tapped at d.tap(1),
%                                          1x1xF (used to extract Qe vs tap)
%
%   Dimension struct d (all metres), same meaning as RF PCB Toolbox
%   filterHairpin:
%     n     number of resonators (filter order)
%     W     resonator strip width
%     La    arm length (outer edge to outer edge)
%     slot  gap between the two arms of one hairpin
%     s     1x(n-1) gaps between neighbouring hairpins (edge to edge)
%     tap   [tin tout] tap position measured from the bend centreline
%     Wp    port (feed) line width, Lp port line length
%
%   Geometry: hairpins alternate (open ends up/down). Arm i-right couples
%   to arm (i+1)-left along La - W; each arm keeps a short W/2 stub at its
%   open end. Coupling inside one hairpin (across the slot), coupling to
%   non-neighbours, bend and T-junction parasitics are neglected - the EM
%   check (MoM) shows how much these matter.

if nargin < 4, mode = 'filter'; end
switch mode
    case 'filter', n = d.n; Z0 = 50;
    case 'pair',   n = 2;   Z0 = 1e5;
    case 'single', n = 1;   Z0 = 50;
end
f = f(:).';
[Zr, er, ar] = fd.msl(d.W, sub, f);
[Zp, ep, ap] = fd.msl(d.Wp, sub, f);
dl = fd.openEnd(d.W, sub);
line = @(a, b, L) fd.el('line', [a b], 'Zc', Zr, 'ee', er, 'alpha', ar, 'len', L);
stub = @(a, L) fd.el('stub', a, 'Zc', Zr, 'ee', er, 'alpha', ar, 'len', L);

nn = 0; el = fd.el('line', [1 1]); el(:) = [];
    function k = node(), nn = nn + 1; k = nn; end

Lb = zeros(1, n); Rb = Lb; Lc = Lb; Rc = Lb;
armL = d.La - d.W/2;                       % bend centre -> open edge
ports = [];
% Right-angle corners make the U electrically shorter than its centreline
% (current takes the inside corner). Each corner shortens it by cK*W;
% cK was calibrated against converged MoM (see README.md).
if isfield(d, 'cK'), cK = d.cK; else, cK = fd.cornerK(); end
barLen = max(d.slot + d.W - 2*cK*d.W, 0.1*d.W);
for i = 1:n
    Lb(i) = node(); Rb(i) = node();
    el(end+1) = line(Lb(i), Rb(i), barLen); %#ok<AGROW> bend
end

% --- couplings between neighbouring hairpins ------------------------------
Lcpl = d.La - d.W;
for i = 1:n-1
    Rc(i) = node(); Lc(i+1) = node();
    if strcmp(mode, 'pair'), s = d.sPair; else, s = d.s(i); end
    m = fd.cmsl(d.W, s, sub, f);
    if isfield(d, 'kS') && d.kS ~= 1        % EM calibration: scale coupling
        Zm = sqrt(m.Ze .* m.Zo);
        m.Ze = Zm .* (m.Ze ./ Zm).^d.kS; m.Zo = Zm .* (m.Zo ./ Zm).^d.kS;
    end
    if mod(i, 2)   % hairpin i opens upward: its bend is at the bottom
        nodes = [Rb(i) Rc(i) Lc(i+1) Lb(i+1)];
    else
        nodes = [Rc(i) Rb(i) Lb(i+1) Lc(i+1)];
    end
    el(end+1) = fd.el('cline', nodes, 'Ze', m.Ze, 'Zo', m.Zo, 'ee', m.ee, ...
        'eo', m.eo, 'ae', m.ae, 'ao', m.ao, 'len', Lcpl); %#ok<AGROW>
    el(end+1) = stub(Rc(i),   d.W/2 + dl); %#ok<AGROW>
    el(end+1) = stub(Lc(i+1), d.W/2 + dl); %#ok<AGROW>
end

% --- outer arms: tapped feed, weak feed, or free -------------------------
    function outer(bend, t)
        if isnan(t)                                 % free arm
            el(end+1) = stub(bend, armL + dl);
        elseif isinf(t)                             % weak port at open end
            p = node(); el(end+1) = line(bend, p, armL + dl); ports(end+1) = p;
        else                                        % tapped 50-ohm feed
            if isfield(d, 'dtap'), t = t + d.dtap; end   % EM calibration
            t = min(max(t, 0.05e-3), armL - 0.05e-3);
            T = node(); P = node();
            el(end+1) = line(bend, T, t);
            el(end+1) = stub(T, armL - t + dl);
            el(end+1) = fd.el('line', [T P], 'Zc', Zp, 'ee', ep, 'alpha', ap, ...
                'len', d.Lp + d.W/2);
            ports(end+1) = P;
        end
    end
switch mode
    case 'filter', outer(Lb(1), d.tap(1)); outer(Rb(n), d.tap(end));
    case 'pair',   outer(Lb(1), Inf);      outer(Rb(n), Inf);
    case 'single', outer(Lb(1), d.tap(1)); outer(Rb(1), NaN);
end

S = fd.circuitS(el, nn, ports, f, Z0);
end
