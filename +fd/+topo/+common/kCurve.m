function k = kCurve(pairS, sGrid, f0)
%FD.TOPO.COMMON.KCURVE  Coupling coefficient vs gap from a weakly fed pair.
%   pairS(s, f) must return S (2x2xF) of two resonators fed very weakly.
%   The two transmission peaks fa < fb give k = (fb^2 - fa^2)/(fb^2 + fa^2)
%   (Hong & Lancaster eq. 8.23, synchronously tuned).
fz = f0 * linspace(0.55, 1.45, 6001);
k = nan(size(sGrid));
for i = 1:numel(sGrid)
    S = pairS(sGrid(i), fz);
    a = abs(squeeze(S(2,1,:))).';
    [~, loc] = findpeaks(a, 'SortStr', 'descend', 'NPeaks', 2);
    if numel(loc) == 2
        fp = sort(fz(loc)); k(i) = (fp(2)^2 - fp(1)^2)/(fp(2)^2 + fp(1)^2);
    end
end
end
