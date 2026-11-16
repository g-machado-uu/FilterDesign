function s = emRun(obj, f, progress)
%FD.EMRUN  MoM sweep one frequency at a time, with progress and cancel.
%   s = fd.emRun(obj, f)                 plain
%   s = fd.emRun(obj, f, @(k, n, tPer) stop)
%   The progress callback gets the point index, the total and the seconds
%   per point so far; if it returns true the sweep stops and s holds the
%   points finished so far (or [] if none).
if nargin < 3, progress = []; end
P = zeros(2, 2, 0); done = []; t0 = tic;
for k = 1:numel(f)
    sk = sparameters(obj, f(k));
    P(:, :, end+1) = sk.Parameters; %#ok<AGROW>
    done(end+1) = f(k); %#ok<AGROW>
    if ~isempty(progress) && progress(k, numel(f), toc(t0)/k)
        break
    end
end
if isempty(done), s = []; else, s = sparameters(P, done, 50); end
end
