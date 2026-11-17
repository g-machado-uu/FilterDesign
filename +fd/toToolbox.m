function obj = toToolbox(type, d, sub)
%FD.TOTOOLBOX  Build the RF PCB Toolbox object for a design (for MoM/Gerber).
%   obj = fd.toToolbox('hairpin', d, sub)
%   obj = fd.toToolbox('sir', d, sub)        stepped-impedance lowpass
%   Conductor is copper with the substrate's copper thickness.
diel = dielectric('Name', 'sub', 'EpsilonR', sub.er, 'LossTangent', sub.tand, ...
                  'Thickness', sub.h);
cond = metal('Copper'); cond.Thickness = sub.t;
switch type
    case 'hairpin'
        obj = filterHairpin('FilterOrder', d.n);
        obj.Height = sub.h; obj.Substrate = diel; obj.Conductor = cond;
        obj.Resonator = ubendRightAngle('Length', [d.La d.slot d.La], ...
                                        'Width', [d.W d.W d.W]);
        obj.Spacing = d.s; obj.ResonatorOffset = zeros(1, d.n);
        obj.PortLineWidth = d.Wp; obj.PortLineLength = d.Lp;
        yb = -d.La/2 + d.W/2;                       % bend centre of hairpin 1
        yin = yb + d.tap(1);
        if mod(d.n, 2), yout = yb + d.tap(2);       % last hairpin bend at bottom
        else,           yout = -yb - d.tap(2);      % last hairpin bend at top
        end
        obj.FeedOffset = [yin yout];
        setIf(obj, 'GroundPlaneWidth', d.La + 2*max(5e-3, 5*sub.h));
    case 'sir'
        obj = filterStepImpedanceLowPass('FilterOrder', d.n);
        obj.Height = sub.h; obj.Substrate = diel; obj.Conductor = cond;
        obj.LowZLineWidth = d.WL; obj.HighZLineWidth = d.WH;
        obj.LowZLineLength = d.len(1:2:end); obj.HighZLineLength = d.len(2:2:end);
        obj.PortLineWidth = d.Wp; obj.PortLineLength = d.Lp;
        setIf(obj, 'GroundPlaneWidth', d.WL + 2*max(5e-3, 5*sub.h));
    case 'stub'
        obj = filterStub;
        obj.Height = sub.h; obj.Substrate = diel; obj.Conductor = cond;
        SL = sum(d.seg);
        obj.PortLineLength = d.Lp; obj.PortLineWidth = d.Wp;
        obj.SeriesLineLength = max(SL, 1e-4); obj.SeriesLineWidth = d.W0;
        x = -SL/2 + [0, cumsum(d.seg)];
        obj.StubOffsetX = x; obj.StubLength = d.Ls; obj.StubWidth = d.Ws;
        obj.StubDirection = double(mod(0:d.n-1, 2) == 0);   % alternate sides
        obj.StubShort = double(d.short);
        setIf(obj, 'GroundPlaneWidth', 2*(max(d.Ls) + max(3e-3, 4*sub.h)));
        setIf(obj, 'GroundPlaneLength', SL + 2*d.Lp);
    case 'interdigital'
        obj = filterInterdigital('FilterOrder', d.n);
        obj.Height = sub.h; obj.Substrate = diel; obj.Conductor = cond;
        obj.ResonatorLength = d.L; obj.ResonatorWidth = d.W;
        obj.ResonatorSpacing = d.s; obj.ResonatorOffset = 0;
        obj.PortLineLength = d.Lp; obj.PortLineWidth = d.Wp;
        obj.FeedOffset = -d.L(1)/2 + d.tap;
        obj.ViaDiameter = d.D;
        setIf(obj, 'GroundPlaneWidth', max(d.L) + 2*max(3e-3, 4*sub.h));
        setIf(obj, 'GroundPlaneLength', d.n*d.W + sum(d.s) + 2*d.Lp);
    case 'coupledLine'
        obj = filterCoupledLine('FilterOrder', d.n);
        obj.Height = sub.h; obj.Substrate = diel; obj.Conductor = cond;
        obj.CoupledLineLength = d.L; obj.CoupledLineWidth = d.W; obj.CoupledLineSpacing = d.s;
        obj.PortLineLength = d.Lp; obj.PortLineWidth = d.Wp;
        span = sum(d.W) + sum(d.s) + d.Wp;            % vertical staircase extent
        setIf(obj, 'GroundPlaneWidth', 2*span + 2*max(3e-3, 4*sub.h));
        setIf(obj, 'GroundPlaneLength', sum(d.L) + 2*d.Lp);
    case 'spurline'
        obj = filterSpurline;
        obj.Height = sub.h; obj.Substrate = diel; obj.Conductor = cond;
        obj.PortLineWidth = d.W0; obj.PortLineLength = d.Lp;
        obj.CoupledLineWidth = d.Wc; obj.CoupledLineSpacing = d.sp;
        obj.CoupledLineLength = d.Lc; obj.LineGap = d.gL;
        if d.double, obj.LineType = 'Double'; else, obj.LineType = 'Single'; end
        setIf(obj, 'GroundPlaneLength', d.Lc + d.gL + 2*d.Lp);
        setIf(obj, 'GroundPlaneWidth', d.W0 + 2*max(5e-3, 5*sub.h));
    case 'ring'
        obj = resonatorRing;
        obj.Height = sub.h; obj.Substrate = diel; obj.Conductor = cond;
        obj.RingRadiusOuter = d.Rout; obj.RingWidth = d.Wr; obj.CouplingGap = d.gap;
        obj.PortLineLength = d.Lp; obj.PortLineWidth = d.Wp;
        setIf(obj, 'GroundPlaneLength', 2*(d.Rout + d.gap + d.Lp));
        setIf(obj, 'GroundPlaneWidth', 2*d.Rout + 2*max(3e-3, 4*sub.h));
    case 'srr'
        obj = resonatorSplitRingSquare;
        obj.Height = sub.h; obj.Substrate = diel; obj.Conductor = cond;
        obj.RingLengthInner = d.a; obj.RingWidth = d.w; obj.RingSpacing = d.sp;
        obj.SplitGap = d.gs; obj.CouplingGap = d.gc; obj.NumResonator = d.N;
        obj.ResonatorSpacing = d.gp; obj.PortLineWidth = d.W0;    % edge-to-edge gap
        Lline = fd.srrLine(d);
        obj.PortLineLength = Lline; setIf(obj, 'GroundPlaneLength', Lline);
        aOut = d.a + 2*(d.sp + d.w);
        setIf(obj, 'GroundPlaneWidth', 2*(d.W0/2 + d.gc + aOut) + 2*max(3e-3, 4*sub.h));
    case 'csrr'
        obj = fd.csrrPcb(d, sub);
    otherwise
        error('fd:toToolbox', 'Unknown type "%s".', type);
end
end

function setIf(obj, prop, val)
% ground-plane sizes are read-only (auto-sized) on some toolbox objects
try, obj.(prop) = val; catch, end
end
