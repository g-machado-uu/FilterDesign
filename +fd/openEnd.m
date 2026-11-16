function dl = openEnd(W, sub)
%FD.OPENEND  Open-end length extension of a microstrip (Hammerstad, m).
%   The fringing field at an open end makes the line look longer by dl.
[~, ee] = fd.msl(W, sub, 0);
u = W/sub.h;
dl = 0.412 * sub.h * (ee + 0.3)/(ee - 0.258) * (u + 0.264)/(u + 0.8);
end
