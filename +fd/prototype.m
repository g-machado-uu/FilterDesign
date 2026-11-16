function g = prototype(n, type, rippleDb)
%FD.PROTOTYPE  Lowpass prototype element values g0 .. g(n+1).
%   g = fd.prototype(n, 'Chebyshev', 0.1)   % 0.1 dB ripple
%   g = fd.prototype(n, 'Butterworth')
%   Returns a row vector [g0 g1 ... gn g(n+1)] (Hong & Lancaster, sec. 3.1).
g = zeros(1, n+2); g(1) = 1;
switch lower(type)
    case 'butterworth'
        k = 1:n;
        g(2:n+1) = 2*sin((2*k - 1)*pi/(2*n));
        g(n+2) = 1;
    case 'chebyshev'
        beta  = log(coth(rippleDb/17.37));
        gam   = sinh(beta/(2*n));
        g(2)  = 2/gam * sin(pi/(2*n));
        for i = 2:n
            num = 4*sin((2*i-1)*pi/(2*n)) * sin((2*i-3)*pi/(2*n));
            den = gam^2 + sin((i-1)*pi/n)^2;
            g(i+1) = num/den / g(i);
        end
        if mod(n, 2), g(n+2) = 1; else, g(n+2) = coth(beta/4)^2; end
    otherwise
        error('fd:prototype', 'Unknown response type "%s".', type);
end
end
