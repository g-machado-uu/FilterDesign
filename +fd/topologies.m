function T = topologies()
%FD.TOPOLOGIES  All topologies available in the app, grouped by response.
%   T = fd.topologies()  struct array (see fd.topo.base for the fields)
%
%   Not included (and why):
%   * Combline (filterCombline): the toolbox object has no vias (implicit
%     short), drives its loading capacitors through an internal lumped port
%     and cannot be exported to pcbComponent/Gerber - it could not be
%     modelled or fabricated faithfully.
%   * Open-loop with cross-coupling (filterOpenLoop): needs cross-coupled
%     (quasi-elliptic) synthesis and EM-extracted mixed couplings - an
%     advanced topic, planned.
%   * SIW (SIWFilter): a waveguide technology, not microstrip.
T = [fd.topo.sir(), fd.topo.stubLPF(), ...                     % lowpass
     fd.topo.stubHPF(), ...                                    % highpass
     fd.topo.hairpin(), fd.topo.interdigital(), ...            % bandpass
     fd.topo.coupledLine(), fd.topo.stubBPF(), ...
     fd.topo.stubBSF(), fd.topo.spurline(), ...                % bandstop
     fd.topo.ring(), fd.topo.srr(), fd.topo.csrr()];           % resonators
end
