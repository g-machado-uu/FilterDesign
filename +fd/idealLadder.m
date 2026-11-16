function [S21, S11] = idealLadder(g, kind, f, fa, fb, Z0)
%FD.IDEALLADDER  Ideal lumped LC ladder for lowpass/highpass/bandpass/bandstop.
%   [S21, S11] = fd.idealLadder(g, 'LP', f, fc)
%   [S21, S11] = fd.idealLadder(g, 'HP', f, fc)
%   [S21, S11] = fd.idealLadder(g, 'BP', f, f1, f2)
%   [S21, S11] = fd.idealLadder(g, 'BS', f, f1, f2)
%   g from fd.prototype. Element 1 is a shunt element (C-first ladder).
%   Standard frequency transformations (Hong & Lancaster sec. 3.2):
%     LP: shunt C, series L       HP: shunt L, series C
%     BP: shunt parallel LC, series series-LC
%     BS: shunt series-LC, series parallel-LC
if nargin < 6, Z0 = 50; end
if nargin < 5 || isempty(fb), fb = fa; end
n = numel(g) - 2;
switch upper(kind)
    case {'LP', 'HP'}, wc = 2*pi*fa;
    otherwise, w0 = 2*pi*sqrt(fa*fb); FBW = (fb - fa)/sqrt(fa*fb);
end
S21 = zeros(size(f)); S11 = S21;
for k = 1:numel(f)
    w = 2*pi*f(k); T = eye(2);
    for i = 1:n
        gi = g(i+1); shunt = mod(i, 2) == 1;
        switch upper(kind)
            case 'LP'
                if shunt, X = 1j*w*gi/(Z0*wc); else, X = 1j*w*gi*Z0/wc; end
            case 'HP'                                  % shunt L = Z0/(wc g), series C = 1/(Z0 wc g)
                if shunt, X = 1/(1j*w*Z0/(wc*gi)); else, X = 1/(1j*w/(Z0*wc*gi)); end
            case 'BP'
                O = (w/w0 - w0/w)/FBW;
                if shunt, X = 1j*O*gi/Z0; else, X = 1j*O*gi*Z0; end
            case 'BS'
                O = -FBW/((w/w0 - w0/w) + 1e-12);  % (avoid 1/0 exactly at f0)
                if shunt, X = 1j*O*gi/Z0; else, X = 1j*O*gi*Z0; end
        end
        if shunt, T = T*[1 0; X 1]; else, T = T*[1 X; 0 1]; end
    end
    Z2 = Z0*g(end);
    A = T(1,1); B = T(1,2); C = T(2,1); D = T(2,2);
    den = A*Z2 + B + C*Z0*Z2 + D*Z0;
    S21(k) = 2*sqrt(Z0*Z2)/den;
    S11(k) = (A*Z2 + B - C*Z0*Z2 - D*Z0)/den;
end
end
