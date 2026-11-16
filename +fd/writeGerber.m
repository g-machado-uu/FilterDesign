function files = writeGerber(obj, folder, name)
%FD.WRITEGERBER  Write RS-274X Gerber + Excellon files (JLCPCB accepts these).
%   files = fd.writeGerber(obj, folder, name)
%   obj is an RF PCB Toolbox object (from fd.toToolbox). Uses the generic
%   PCBWay writer format (standard Gerber) with its upload hook DISABLED,
%   so nothing is sent anywhere. Connectors are not added: put SMA
%   footprints on the port line ends in your PCB tool, or use edge-mount
%   SMAs on the board edge.
if nargin < 3, name = 'filter'; end
w = PCBServices.PCBWayWriter;
w.Filename = name;
w.PostWriteFcn = @(o) [];           % default would open the PCBWay website
w.CreateArchiveFile = true;
here = pwd; c = onCleanup(@() cd(here));
cd(folder);
before = dir(folder);
if ~isa(obj, 'pcbComponent'), obj = pcbComponent(obj); end   % catalog objects must be converted
gerberWrite(obj, w);
after = dir(fullfile(folder, '**', '*'));
after = after(~[after.isdir]);
files = setdiff(fullfile({after.folder}, {after.name}), ...
                fullfile({before.folder}, {before.name}));
end
