classdef FilterDesigner < handle
%FILTERDESIGNER  Teaching app: design microstrip filters and resonators,
%see their layout, dimensions and response, tune them live, check them
%with EM and export them for fabrication (Gerber).
%
%   FilterDesigner              % open the app
%   app = FilterDesigner;       % keep a handle (for scripting/screenshots)
%   app.select('interdigital')  % switch topology programmatically
%
%   Workflow
%     1. Choose the response (lowpass, highpass, bandpass, bandstop or a
%        single resonator) and then the topology.
%     2. Enter the specification and choose the board (substrate presets).
%     3. "Synthesise" computes dimensions step by step (see "Design steps").
%     4. Move the sliders in "Tune" - the response updates instantly
%        (circuit model). "Optimise" tunes automatically.
%     5. "EM calibrate" / "EM full" run an accurate MoM simulation and can
%        correct the circuit model. Then optimise again.
%     6. "Export" writes dimensions, S-parameters, layout and Gerbers.
%
%   Every topology is one file in +fd/+topo (listed in fd.topologies);
%   the app only uses the fields documented in fd.topo.base.
%   Requires RF PCB Toolbox, RF Toolbox, Optimization Toolbox (optional).

    properties (Access = public)
        Fig
    end

    properties (Access = private)
        % --- state -----------------------------------------------------
        All                    % fd.topologies()
        T                      % current topology definition
        Spec                   % specification struct
        Sub                    % substrate struct
        D                      % current dimensions
        DSynth                 % dimensions straight from synthesis
        Info                   % synthesis intermediate values
        Cal  = []              % EM calibration knobs (struct) or []
        EM   = []              % struct: f, S, label
        F                      % plot frequency grid
        Ideal                  % [S21; S11] target on F, or []
        SubList                % fd.substrates()
        Busy = false
        % --- UI handles ------------------------------------------------
        KindDD; TopoDD; Blurb
        FA; FB; FALbl; FBLbl
        RespDD; RippleEF; OrderSP; FsEF; AsEF; SuggestBtn; MinGapEF
        ParamGrid; ParamEF = gobjects(0)
        SubDD; HDD; ErEF; TandEF; CuEF; SubNote
        SynthBtn; OptBtn; CalBtn; EMBtn; AdvCB; ResetBtn; ExportBtn
        Status
        AxResp; AxLay
        LIdeal21; LIdeal11; L21; L11; LEM21; LEM11
        Tabs; TuneGrid; SymCB; DimTable; StepsGrid; StepsText; AxK; AxQ; HelpText
        Sliders = struct('h', {}, 'ef', {}, 'name', {}, 'idx', {}, 'mirror', {})
        RightGrid
        Wide = []
    end

    properties (Constant, Access = private)
        KINDS = {'LP', 'HP', 'BP', 'BS', 'RES'}
        KINDNAMES = {'Lowpass', 'Highpass', 'Bandpass', 'Bandstop (notch)', 'Resonator / sensor'}
        INTPARAMS = {'N', 'mode', 'nSpur'}     % params that are counts
    end

    % =====================================================================
    methods
        function app = FilterDesigner(id)
            if nargin < 1, id = 'hairpin'; end
            app.SubList = fd.substrates();
            app.All = fd.topologies();
            app.buildUI();
            app.SubDD.Value = 1; app.onSubChanged();
            k = find(strcmp(app.HDD.Items, '1.6 mm'), 1);
            if ~isempty(k), app.HDD.Value = app.HDD.ItemsData{k}; end
            app.select(id);
        end

        function delete(app)
            if ~isempty(app.Fig) && isvalid(app.Fig), delete(app.Fig); end
        end

        function select(app, id)
            %SELECT  Switch to topology ID (fd.topologies ids) and load its
            %example specification. Nothing is computed until Synthesise.
            k = find(strcmp({app.All.id}, id), 1);
            if isempty(k), error('fd:app', 'Unknown topology "%s".', id); end
            app.KindDD.Value = app.All(k).kind; app.fillTopologies();
            app.TopoDD.Value = id; app.onTopoChanged();
        end

        function run(app, action)
            %RUN  Press a button from a script: 'synthesise' | 'optimise' | 'reset'.
            switch action
                case 'synthesise', app.synthesise();
                case 'optimise',   app.optimise();
                case 'reset',      app.resetDims();
            end
        end

        function showTab(app, name)
            %SHOWTAB  Bring a tab to the front ('Tune', 'Dimensions', ...).
            t = findobj(app.Tabs.Children, 'Title', name);
            if ~isempty(t), app.Tabs.SelectedTab = t(1); end
        end
    end

    % =====================================================================
    methods (Access = private)

        % ------------------------------------------------------------ UI --
        function buildUI(app)
            app.Fig = uifigure('Name', 'Microstrip Filter Designer', ...
                'Position', [40 40 1460 900], 'CloseRequestFcn', @(~,~) delete(app));
            g = uigridlayout(app.Fig, [1 2]);
            g.ColumnWidth = {350, '1x'}; g.Padding = [6 6 6 6];

            % ---------------- left column: inputs & actions ---------------
            L = uigridlayout(g, [5 1]); L.RowHeight = {'fit', 'fit', 'fit', 'fit', '1x'};
            L.Padding = [0 0 0 0]; L.Scrollable = 'on';

            p = uipanel(L, 'Title', '1. What to design', 'FontWeight', 'bold');
            pg = uigridlayout(p, [3 2]); pg.RowHeight = {24, 24, 84};
            pg.ColumnWidth = {80, '1x'}; pg.Padding = [6 4 6 4];
            uilabel(pg, 'Text', 'Response');
            app.KindDD = uidropdown(pg, 'Items', app.KINDNAMES, 'ItemsData', app.KINDS, ...
                'ValueChangedFcn', @(~,~) app.onKindChanged());
            uilabel(pg, 'Text', 'Topology');
            app.TopoDD = uidropdown(pg, 'Items', {'-'}, 'ValueChangedFcn', @(~,~) app.onTopoChanged());
            app.Blurb = uitextarea(pg, 'Editable', 'off', 'FontSize', 11, 'FontAngle', 'italic');
            app.Blurb.Layout.Column = [1 2];

            p = uipanel(L, 'Title', '2. Specification', 'FontWeight', 'bold');
            pg = uigridlayout(p, [6 4]); pg.RowHeight = {24, 24, 24, 24, 26, 'fit'};
            pg.ColumnWidth = {75, 95, '1x', 55}; pg.Padding = [6 4 6 4];
            app.FALbl = uilabel(pg, 'Text', 'f1 (GHz)');
            app.FA = uieditfield(pg, 'numeric', 'Value', 2.7, 'Limits', [0.01 100]);
            app.FBLbl = uilabel(pg, 'Text', 'f2 (GHz)');
            app.FB = uieditfield(pg, 'numeric', 'Value', 3.1, 'Limits', [0.01 100]);
            uilabel(pg, 'Text', 'Response');
            app.RespDD = uidropdown(pg, 'Items', {'Chebyshev', 'Butterworth'});
            app.RespDD.ValueChangedFcn = @(~,~) set(app.RippleEF, 'Enable', strcmp(app.RespDD.Value, 'Chebyshev'));
            uilabel(pg, 'Text', 'Ripple (dB)');
            app.RippleEF = uieditfield(pg, 'numeric', 'Value', 0.1, 'Limits', [0.001 3]);
            uilabel(pg, 'Text', 'Order n');
            app.OrderSP = uispinner(pg, 'Value', 5, 'Limits', [1 9], 'Step', 1, 'RoundFractionalValues', 'on');
            uilabel(pg, 'Text', 'Min gap (mm)');
            app.MinGapEF = uieditfield(pg, 'numeric', 'Value', 0.15, 'Limits', [0.05 5], ...
                'Tooltip', 'Smallest copper gap/track your fab can make. Typical 2-layer prototype fabs: 0.1-0.15 mm.');
            uilabel(pg, 'Text', 'Need (dB)', 'Tooltip', 'Order helper: attenuation you need ...');
            app.AsEF = uieditfield(pg, 'numeric', 'Value', 30, 'Limits', [1 150]);
            uilabel(pg, 'Text', 'at f (GHz)', 'Tooltip', '... at this frequency.');
            app.FsEF = uieditfield(pg, 'numeric', 'Value', 3.5, 'Limits', [0.01 100]);
            app.SuggestBtn = uibutton(pg, 'Text', 'Suggest order for this attenuation', ...
                'ButtonPushedFcn', @(~,~) app.suggestOrder());
            app.SuggestBtn.Layout.Column = [1 4];
            app.ParamGrid = uigridlayout(pg, [1 2]); app.ParamGrid.Layout.Column = [1 4];
            app.ParamGrid.ColumnWidth = {'1x', 70}; app.ParamGrid.Padding = [0 0 0 0];

            p = uipanel(L, 'Title', '3. Board', 'FontWeight', 'bold');
            pg = uigridlayout(p, [5 4]); pg.RowHeight = {24, 24, 24, 24, 'fit'};
            pg.ColumnWidth = {'1x', 70, '1x', 70}; pg.Padding = [6 4 6 4];
            app.SubDD = uidropdown(pg, 'Items', {app.SubList.name}, 'ItemsData', 1:numel(app.SubList), ...
                'ValueChangedFcn', @(~,~) app.onSubChanged());
            app.SubDD.Layout.Column = [1 4];
            uilabel(pg, 'Text', 'Thickness');
            app.HDD = uidropdown(pg, 'Items', {'1.6 mm'});
            app.HDD.Layout.Column = [2 4];
            uilabel(pg, 'Text', 'εr');
            app.ErEF = uieditfield(pg, 'numeric', 'Value', 4.5, 'Limits', [1.01 20]);
            uilabel(pg, 'Text', 'tan δ');
            app.TandEF = uieditfield(pg, 'numeric', 'Value', 0.02, 'Limits', [0 0.2]);
            uilabel(pg, 'Text', 'Copper (µm)');
            app.CuEF = uieditfield(pg, 'numeric', 'Value', 35, 'Limits', [5 200]);
            uilabel(pg, 'Text', ' '); uilabel(pg, 'Text', ' ');
            app.SubNote = uilabel(pg, 'Text', '', 'WordWrap', 'on', 'FontAngle', 'italic');
            app.SubNote.Layout.Column = [1 4];

            p = uipanel(L, 'Title', '4. Actions', 'FontWeight', 'bold');
            pg = uigridlayout(p, [5 2]); pg.RowHeight = {30, 30, 30, 24, 30}; pg.Padding = [6 4 6 4];
            app.SynthBtn = uibutton(pg, 'Text', 'Synthesise', 'FontWeight', 'bold', ...
                'BackgroundColor', [0.20 0.45 0.80], 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) app.synthesise());
            app.SynthBtn.Layout.Column = [1 2];
            app.OptBtn = uibutton(pg, 'Text', 'Optimise (circuit)', 'ButtonPushedFcn', @(~,~) app.optimise());
            app.ResetBtn = uibutton(pg, 'Text', 'Reset to synthesis', 'ButtonPushedFcn', @(~,~) app.resetDims());
            app.CalBtn = uibutton(pg, 'Text', 'EM calibrate', 'ButtonPushedFcn', @(~,~) app.emCalibrate(), ...
                'Tooltip', 'Accurate MoM of a small section, then correct the circuit model.');
            app.EMBtn = uibutton(pg, 'Text', 'EM full design', 'ButtonPushedFcn', @(~,~) app.emFull(), ...
                'Tooltip', 'MoM of the whole design.');
            app.AdvCB = uicheckbox(pg, 'Text', 'Allow coarse-mesh EM (qualitative only)', 'Value', false);
            app.AdvCB.Layout.Column = [1 2];
            app.ExportBtn = uibutton(pg, 'Text', 'Export…', 'ButtonPushedFcn', @(~,~) app.exportAll());
            app.ExportBtn.Layout.Column = [1 2];

            app.Status = uitextarea(L, 'Editable', 'off', 'FontName', 'Monospaced', 'FontSize', 11);

            % ---------------- right column: plots & tabs ------------------
            R = uigridlayout(g, [3 2]); R.ColumnWidth = {'1.2x', '1x'};
            R.Padding = [0 0 0 0]; app.RightGrid = R;
            app.AxResp = uiaxes(R); grid(app.AxResp, 'on'); hold(app.AxResp, 'on');
            xlabel(app.AxResp, 'Frequency (GHz)'); ylabel(app.AxResp, 'dB');
            app.LIdeal21 = plot(app.AxResp, NaN, NaN, 'k--', 'LineWidth', 1, 'DisplayName', 'Ideal |S21|');
            app.LIdeal11 = plot(app.AxResp, NaN, NaN, ':', 'Color', [0.4 0.4 0.4], 'DisplayName', 'Ideal |S11|');
            app.L21 = plot(app.AxResp, NaN, NaN, '-', 'Color', [0.10 0.35 0.75], 'LineWidth', 2, 'DisplayName', 'Circuit |S21|');
            app.L11 = plot(app.AxResp, NaN, NaN, '-', 'Color', [0.85 0.45 0.10], 'LineWidth', 1.5, 'DisplayName', 'Circuit |S11|');
            app.LEM21 = plot(app.AxResp, NaN, NaN, 'o', 'Color', [0.10 0.35 0.75], 'MarkerFaceColor', [0.6 0.75 1], 'DisplayName', 'EM |S21|');
            app.LEM11 = plot(app.AxResp, NaN, NaN, 's', 'Color', [0.85 0.45 0.10], 'MarkerFaceColor', [1 0.8 0.6], 'DisplayName', 'EM |S11|');
            legend(app.AxResp, 'Location', 'southeast');
            app.AxLay = uiaxes(R); axis(app.AxLay, 'equal'); app.AxLay.Box = 'on';
            xlabel(app.AxLay, 'x (mm)'); ylabel(app.AxLay, 'y (mm)');

            app.Tabs = uitabgroup(R);
            t = uitab(app.Tabs, 'Title', 'Tune');
            tg = uigridlayout(t, [2 1]); tg.RowHeight = {26, '1x'};
            app.SymCB = uicheckbox(tg, 'Text', 'Keep symmetric (move mirror-image dimensions together)', 'Value', true);
            app.TuneGrid = uigridlayout(tg, [1 3]); app.TuneGrid.Scrollable = 'on';
            app.TuneGrid.ColumnWidth = {190, '1x', 90};

            t = uitab(app.Tabs, 'Title', 'Dimensions');
            tg = uigridlayout(t, [1 1]);
            app.DimTable = uitable(tg, 'ColumnName', {'Dimension', 'Value (mm)', 'Meaning'}, ...
                'ColumnWidth', {170, 100, 'auto'}, 'RowName', {});

            t = uitab(app.Tabs, 'Title', 'Design steps');
            app.StepsGrid = uigridlayout(t, [1 3]); app.StepsGrid.ColumnWidth = {'1.3x', '1x', '1x'};
            app.StepsText = uitextarea(app.StepsGrid, 'Editable', 'off', 'FontName', 'Monospaced', 'FontSize', 11);
            app.AxK = uiaxes(app.StepsGrid); grid(app.AxK, 'on');
            app.AxQ = uiaxes(app.StepsGrid); grid(app.AxQ, 'on');

            t = uitab(app.Tabs, 'Title', 'Help');
            tg = uigridlayout(t, [1 1]);
            app.HelpText = uitextarea(tg, 'Editable', 'off', 'Value', FilterDesigner.helpText());

            app.Fig.AutoResizeChildren = 'off';
            app.Fig.SizeChangedFcn = @(~,~) app.arrange();
            app.arrange();
        end

        function arrange(app)
            % wide window: response | layout on top, tabs below
            % narrow window: response, layout, tabs stacked
            R = app.RightGrid; w = app.Fig.Position(3);
            wide = w >= 1250;
            if isequal(wide, app.Wide), return; end
            app.Wide = wide;
            if wide
                R.RowHeight = {'1.15x', '1x', 0};
                app.AxResp.Layout.Row = 1; app.AxResp.Layout.Column = 1;
                app.AxLay.Layout.Row  = 1; app.AxLay.Layout.Column  = 2;
                app.Tabs.Layout.Row   = 2; app.Tabs.Layout.Column   = [1 2];
            else
                R.RowHeight = {'1.3x', '0.6x', '1x'};
                app.AxResp.Layout.Row = 1; app.AxResp.Layout.Column = [1 2];
                app.AxLay.Layout.Row  = 2; app.AxLay.Layout.Column  = [1 2];
                app.Tabs.Layout.Row   = 3; app.Tabs.Layout.Column   = [1 2];
            end
        end

        % ------------------------------------------------------ callbacks --
        function onKindChanged(app)
            app.fillTopologies(); app.onTopoChanged();
        end

        function fillTopologies(app)
            Ts = app.All(strcmp({app.All.kind}, app.KindDD.Value));
            app.TopoDD.Items = {Ts.name}; app.TopoDD.ItemsData = {Ts.id};
        end

        function onTopoChanged(app)
            % load the topology's example spec into the UI; wait for Synthesise
            T = app.All(strcmp({app.All.id}, app.TopoDD.Value)); app.T = T;
            app.Blurb.Value = T.blurb;
            s = T.defaults; k = T.kind;
            bp = any(strcmp(k, {'BP', 'BS'}));
            set([app.FB app.FBLbl], 'Visible', bp);
            switch k
                case {'BP', 'BS'}
                    app.FALbl.Text = 'f1 (GHz)'; app.FBLbl.Text = 'f2 (GHz)';
                    app.FA.Value = s.f1/1e9; app.FB.Value = s.f2/1e9;
                    if strcmp(k, 'BS'), app.FALbl.Text = 'Stop f1 (GHz)'; app.FBLbl.Text = 'Stop f2 (GHz)'; end
                case {'LP', 'HP'}
                    app.FALbl.Text = 'fc (GHz)'; app.FA.Value = s.fc/1e9;
                case 'RES'
                    app.FALbl.Text = 'f0 (GHz)'; app.FA.Value = s.f0/1e9;
            end
            app.RespDD.Value = s.type; app.RippleEF.Value = s.ripple;
            app.RippleEF.Enable = T.hasOrder && strcmp(s.type, 'Chebyshev');
            app.OrderSP.Limits = T.orderLim; app.OrderSP.Value = s.n;
            app.OrderSP.Step = 1 + T.orderOdd;
            set([app.RespDD app.OrderSP app.FsEF app.AsEF app.SuggestBtn], 'Enable', T.hasOrder);
            app.FsEF.Value = s.fs/1e9; app.AsEF.Value = s.As;
            % topology-specific numbers
            delete(app.ParamGrid.Children); app.ParamEF = gobjects(0);
            np = numel(T.params);
            app.ParamGrid.RowHeight = repmat({24}, 1, np);
            for i = 1:np
                p = T.params(i);
                uilabel(app.ParamGrid, 'Text', p.label, 'Tooltip', p.tip);
                ef = uieditfield(app.ParamGrid, 'numeric', 'Value', p.default, 'Limits', p.lim, ...
                    'Tooltip', p.tip);
                if any(strcmp(p.field, app.INTPARAMS)), ef.RoundFractionalValues = 'on'; end
                app.ParamEF(i) = ef;
            end
            app.CalBtn.Enable = strcmp(T.em, 'section');
            if strcmp(T.em, 'section')
                app.CalBtn.Tooltip = 'Accurate MoM of a small section, then correct the circuit model.';
            else
                app.CalBtn.Tooltip = 'This design is small: use "EM full design" (it offers calibration).';
            end
            app.Cal = []; app.EM = [];
            app.clearResults();
        end

        function clearResults(app)
            % forget the previous design; nothing is shown until Synthesise
            app.D = []; app.DSynth = []; app.Info = [];
            delete(app.TuneGrid.Children); app.Sliders(:) = [];
            set([app.L21 app.L11 app.LEM21 app.LEM11 app.LIdeal21 app.LIdeal11], 'XData', NaN, 'YData', NaN);
            set([app.LEM21 app.LEM11 app.LIdeal21 app.LIdeal11], 'HandleVisibility', 'off');
            delete(findobj(app.AxResp, 'Tag', 'band'));
            title(app.AxResp, 'Set the specification, then press "Synthesise"', ...
                'FontSize', 10, 'FontWeight', 'normal');
            cla(app.AxLay); title(app.AxLay, '');
            text(app.AxLay, 0.5, 0.5, 'No design yet: press "Synthesise"', 'Units', 'normalized', ...
                'HorizontalAlignment', 'center', 'Color', [0.4 0.4 0.4]);
            app.DimTable.Data = {};
            app.StepsText.Value = {'Press "Synthesise" to see the design steps.'};
            cla(app.AxK); cla(app.AxQ);
        end

        function onSubChanged(app)
            s = app.SubList(app.SubDD.Value);
            app.HDD.Items = arrayfun(@(h) sprintf('%.3g mm', h*1e3), s.hList, 'UniformOutput', false);
            app.HDD.ItemsData = num2cell(s.hList);
            app.HDD.Value = s.hList(end);
            app.ErEF.Value = s.er; app.TandEF.Value = s.tand; app.CuEF.Value = s.t*1e6;
            app.SubNote.Text = s.note;
            custom = strcmp(s.name, 'Custom');
            app.HDD.Editable = matlab.lang.OnOffSwitchState(custom);
        end

        function sub = readSub(app)
            s = app.SubList(app.SubDD.Value);
            h = app.HDD.Value;
            if ischar(h) || isstring(h), h = str2double(regexprep(char(h), '[^\d.]', ''))*1e-3; end
            sub = struct('name', s.name, 'er', app.ErEF.Value, 'tand', app.TandEF.Value, ...
                'h', h, 't', app.CuEF.Value*1e-6, 'sigma', s.sigma);
        end

        function spec = readSpec(app)
            T = app.T; spec = T.defaults;
            spec.type = app.RespDD.Value; spec.ripple = app.RippleEF.Value;
            spec.minGap = app.MinGapEF.Value*1e-3;
            spec.fs = app.FsEF.Value*1e9; spec.As = app.AsEF.Value;
            switch T.kind
                case {'BP', 'BS'}
                    if app.FB.Value <= app.FA.Value, error('fd:spec', 'f2 must be above f1.'); end
                    spec.f1 = app.FA.Value*1e9; spec.f2 = app.FB.Value*1e9;
                case {'LP', 'HP'}, spec.fc = app.FA.Value*1e9;
                case 'RES',        spec.f0 = app.FA.Value*1e9;
            end
            if T.hasOrder
                n = round(app.OrderSP.Value);
                if T.orderOdd && ~mod(n, 2)
                    n = n + 1; if n > T.orderLim(2), n = n - 2; end
                    app.OrderSP.Value = n;
                    app.log('%s needs an odd order (symmetric, equal 50 Ω ends); using n = %d.', T.name, n);
                end
                spec.n = n;
            end
            for i = 1:numel(T.params), spec.(T.params(i).field) = app.ParamEF(i).Value; end
        end

        function suggestOrder(app)
            try
                fs = app.FsEF.Value*1e9; k = app.T.kind;
                switch k
                    case {'BP', 'BS'}
                        f1 = app.FA.Value*1e9; f2 = app.FB.Value*1e9; f0 = sqrt(f1*f2);
                        W = abs(fs/f0 - f0/fs); FBW = (f2 - f1)/f0;
                        if strcmp(k, 'BP'), Om = W/FBW; else, Om = FBW/max(W, eps); end
                    case 'LP', Om = fs/(app.FA.Value*1e9);
                    case 'HP', Om = (app.FA.Value*1e9)/fs;
                    otherwise, return
                end
                if abs(Om) <= 1
                    if strcmp(k, 'BS'), m = 'For a bandstop filter the frequency must lie inside the stop band (f1..f2).';
                    else, m = 'The frequency must lie outside the passband.'; end
                    error('fd:spec', m);
                end
                n = fd.minOrder(app.RespDD.Value, app.RippleEF.Value, Om, app.AsEF.Value);
                if app.T.orderOdd && ~mod(n, 2), n = n + 1; end
                n = min(max(n, app.T.orderLim(1)), app.T.orderLim(2));
                app.OrderSP.Value = n;
                app.log('Order needed for %.0f dB at %.3g GHz: n = %d (normalised Ω = %.2f).', ...
                    app.AsEF.Value, fs/1e9, n, abs(Om));
            catch e
                uialert(app.Fig, e.message, 'Order');
            end
        end

        % ------------------------------------------------------ actions ---
        function synthesise(app)
            if app.Busy, return; end
            dlg = uiprogressdlg(app.Fig, 'Title', 'Synthesis', 'Indeterminate', 'on', ...
                'Message', 'Computing dimensions (field-solving the coupled lines where needed)…');
            c = onCleanup(@() delete(dlg));
            try
                T = app.T;
                app.Spec = app.readSpec(); app.Sub = app.readSub();
                app.Cal = []; app.EM = [];
                [app.D, app.Info] = T.synth(app.Spec, app.Sub);
                app.F = T.fgrid(app.Spec, app.Info);
                app.Ideal = T.ideal(app.Spec, app.Info, app.F);
                app.DSynth = app.D;
                app.buildSliders(); app.refresh(true); app.showSteps();
                app.log('Synthesised %s.', app.describe());
                app.warnings();
            catch e
                msg = e.message;
                if ~startsWith(e.identifier, 'fd:')     % a raw MATLAB error: add context
                    msg = sprintf(['The %s design could not be computed for these inputs.\n\n' ...
                        'Usually one of the numbers is outside what this topology can do ' ...
                        '(a frequency too high or low for this board, or a width/gap that is too ' ...
                        'large or small). Try the example values again (re-select the topology), ' ...
                        'then change one number at a time.\n\nDetails: %s'], app.T.name, e.message);
                end
                app.log('Synthesis failed: %s', e.message);
                uialert(app.Fig, msg, 'Synthesis failed');
            end
        end

        function optimise(app)
            if isempty(app.D) || app.Busy, return; end
            if isempty(app.T.pack), app.log('Nothing to optimise for this topology.'); return; end
            dlg = uiprogressdlg(app.Fig, 'Title', 'Optimise', 'Indeterminate', 'on', ...
                'Message', 'Tuning dimensions to meet the target (circuit model)…');
            c = onCleanup(@() delete(dlg));
            try
                [app.D, rep] = fd.optimiseDesign(app.T, app.D, app.Sub, app.Spec, app.Info);
                app.syncSliders(); app.refresh(true);
                app.log('Optimised: mismatch %.3g -> %.3g%s.', rep.cost0, rep.cost, ...
                    ternary(isempty(app.Cal), '', ' (EM-calibrated model)'));
            catch e
                uialert(app.Fig, e.message, 'Optimisation failed');
            end
        end

        function resetDims(app)
            if isempty(app.DSynth), return; end
            app.D = app.DSynth;
            if ~isempty(app.Cal), app.D = fd.applyCal(app.D, app.Cal); end
            app.syncSliders(); app.refresh(true);
            app.log('Dimensions reset to the synthesis result.');
        end

        function emCalibrate(app)
            T = app.T;
            if ~strcmp(T.em, 'section') || isempty(app.D) || app.Busy, return; end
            lock = app.lockEM(app.CalBtn); %#ok<NASGU>
            d0 = app.D; if ~isempty(app.Cal), d0 = fd.applyCal(d0, [], T); end
            dlg = uiprogressdlg(app.Fig, 'Title', 'EM calibrate', 'Indeterminate', 'on', ...
                'Message', 'Preparing the EM section (mesh and memory estimate)…');
            cDlg = onCleanup(@() delete(dlg));
            [obj, dSec, f, info] = T.emSection(d0, app.Sub, app.Spec);
            delete(dlg);
            if ~info.ok
                uialert(app.Fig, sprintf(['The EM section needs %s of memory; the budget on this ' ...
                    'computer is %.1f GB. Try a thinner board.'], info.memStr, info.budgetGB), ...
                    'Not enough memory'); return
            end
            msg = sprintf(['Simulate a small section of the design with MoM (%d points, mesh %.2f mm, ' ...
                'memory %s)?\nThis typically takes 20-90 s per point.'], numel(f), info.edge*1e3, info.memStr);
            if ~strcmp(uiconfirm(app.Fig, msg, 'EM calibrate', 'Options', {'Run', 'Cancel'}), 'Run'), return; end
            sEM = app.runEM(obj, f, 'EM section');
            if isempty(sEM) || numel(sEM.Frequencies) < 4
                app.log('EM calibration cancelled.'); return
            end
            app.applyCalibration(dSec, sEM, 'section');
        end

        function applyCalibration(app, dSec, sEM, what)
            T = app.T;
            [cal, fit] = fd.calibrate(T, dSec, app.Sub, sEM);
            app.Cal = cal; app.D = fd.applyCal(app.D, cal);
            app.log('EM calibration (%s): %s (model error %.3f -> %.3f).', what, ...
                FilterDesigner.calString(cal), fit.rms0, fit.rms);
            app.showCalibration(dSec, sEM, cal);
            app.refresh(false);
            if ~isempty(T.pack) && strcmp(uiconfirm(app.Fig, ['The circuit model is now corrected ' ...
                    'to match EM. Re-optimise the design with the corrected model?'], 'Calibrated', ...
                    'Options', {'Optimise', 'Later'}), 'Optimise')
                b = app.Busy; app.Busy = false; app.optimise(); app.Busy = b;
            end
        end

        function emFull(app)
            if isempty(app.D) || app.Busy, return; end
            lock = app.lockEM(app.EMBtn); %#ok<NASGU>
            T = app.T;
            dlg = uiprogressdlg(app.Fig, 'Title', 'EM full design', 'Indeterminate', 'on', ...
                'Message', 'Preparing the EM model (mesh and memory estimate)… this can take a while.');
            cDlg = onCleanup(@() delete(dlg));
            obj = T.toolbox(app.D, app.Sub);
            if strcmp(T.id, 'hairpin'), obj.GroundPlaneWidth = app.D.La + 6*app.Sub.h; end
            fm = fd.topo.common.centre(T, app.Spec, app.Info);
            [obj, info] = fd.emPrepare(obj, app.Sub, fm);
            delete(dlg);
            coarse = false;
            if ~info.ok
                if ~app.AdvCB.Value
                    uialert(app.Fig, sprintf(['An accurate (converged-mesh) EM run of the whole ' ...
                        'design needs %s; the budget here is %.1f GB.\n\n%s' ...
                        'Or tick "Allow coarse-mesh EM" for a quick qualitative look ' ...
                        '(its frequency can be 5-10%% too high).'], info.memStr, info.budgetGB, ...
                        ternary(strcmp(T.em, 'section'), 'Use "EM calibrate" instead. ', '')), ...
                        'Too large for accurate EM');
                    return
                end
                obj = T.toolbox(app.D, app.Sub);   % default (coarse) mesh
                coarse = true; info.memStr = memoryEstimate(obj, fm);
            end
            f = fd.topo.common.emFreqs(T, app.Spec, app.Info, 'coarse');
            refine = strcmp(T.kind, 'RES') || strcmp(T.id, 'spurline');
            notch = app.isNotch();
            msg = sprintf(['Run MoM on the full design (%d points%s, %s mesh, memory %s)?\n\n' ...
                'This can take several minutes. The app is locked while it runs; ' ...
                'the progress window shows the time left and has a Cancel button.'], numel(f), ...
                ternary(refine, ' + 6 around the resonance', ''), ...
                ternary(coarse, 'COARSE default', sprintf('%.2f mm', info.edge*1e3)), info.memStr);
            if ~strcmp(uiconfirm(app.Fig, msg, 'EM full design', 'Options', {'Run', 'Cancel'}), 'Run'), return; end
            lbl = ternary(coarse, 'EM (coarse, qualitative)', 'EM');
            s = app.runEM(obj, f, lbl);
            if isempty(s), app.log('EM run cancelled.'); return; end
            fE = s.Frequencies(:).'; P = s.Parameters;
            if refine && numel(fE) == numel(f)
                fr = fd.topo.common.peakFreq(P, fE, notch);
                f2 = setdiff(fr*(1 + linspace(-0.04, 0.04, 7)), fE);
                s2 = app.runEM(obj, f2, [lbl ' - refining the resonance']);
                if ~isempty(s2)
                    [fE, i] = sort([fE, s2.Frequencies(:).']);
                    P = cat(3, P, s2.Parameters); P = P(:, :, i);
                end
            end
            app.EM = struct('f', fE, 'S', P, 'label', lbl);
            app.refresh(false);
            app.log('%s: %d points done.', lbl, numel(fE));
            if refine
                fe = fd.topo.common.peakFreq(P, fE, notch);
                fc = fd.topo.common.peakFreq(app.modelS(app.D, app.F), app.F, notch);
                app.log('Resonance: EM %.4f GHz, circuit model %.4f GHz (%+.1f %%).', fe/1e9, fc/1e9, 100*(fc/fe - 1));
            end
            if ~coarse && strcmp(T.em, 'full') && ~isempty(T.calSpec) && numel(fE) >= 5 && ...
                    strcmp(uiconfirm(app.Fig, ['Correct (calibrate) the circuit model so it matches ' ...
                    'this EM result?'], 'EM done', 'Options', {'Calibrate', 'No'}), 'Calibrate')
                d0 = app.D; if ~isempty(app.Cal), d0 = fd.applyCal(d0, [], T); end
                app.applyCalibration(d0, sparameters(P, fE, 50), 'full design');
            end
        end

        function s = runEM(app, obj, f, title_)
            was = app.Busy; app.Busy = true; c1 = onCleanup(@() app.setBusy(was));
            dlg = uiprogressdlg(app.Fig, 'Title', title_, 'Cancelable', 'on', ...
                'Message', 'Meshing and solving the first point…');
            c2 = onCleanup(@() delete(dlg));
            function stop = cb(k, n, tPer)
                dlg.Value = k/n;
                dlg.Message = sprintf('Point %d of %d done (%.0f s per point, ~%.1f min left)', ...
                    k, n, tPer, tPer*(n - k)/60);
                drawnow; stop = dlg.CancelRequested;
            end
            s = fd.emRun(obj, f, @cb);
        end

        function setBusy(app, b), app.Busy = b; end

        function c = lockEM(app, btn)
            % block a second click while an EM job is being prepared/run:
            % mark the app busy and grey out the action buttons until done
            app.Busy = true; txt = btn.Text; btn.Text = 'EM running…';
            btns = [app.SynthBtn app.OptBtn app.ResetBtn app.CalBtn app.EMBtn app.ExportBtn];
            en = get(btns, 'Enable'); set(btns, 'Enable', 'off'); drawnow;
            c = onCleanup(@() unlock());
            function unlock()
                app.Busy = false;
                if isvalid(btn), btn.Text = txt; end
                for k = 1:numel(btns), if isvalid(btns(k)), btns(k).Enable = en{k}; end, end
            end
        end

        % --------------------------------------------------------- plots --
        function refresh(app, redrawLayout)
            if isempty(app.D), return; end
            S = app.modelS(app.D, app.F);
            fG = app.F/1e9;
            if isempty(app.Ideal)
                set([app.LIdeal21 app.LIdeal11], 'XData', NaN, 'YData', NaN, 'HandleVisibility', 'off');
            else
                set(app.LIdeal21, 'XData', fG, 'YData', db(app.Ideal(1,:)), 'HandleVisibility', 'on');
                set(app.LIdeal11, 'XData', fG, 'YData', db(app.Ideal(2,:)), 'HandleVisibility', 'on');
            end
            set(app.L21, 'XData', fG, 'YData', db(squeeze(S(2,1,:))));
            set(app.L11, 'XData', fG, 'YData', db(squeeze(S(1,1,:))));
            if ~isempty(app.EM)
                set(app.LEM21, 'XData', app.EM.f/1e9, 'YData', db(squeeze(app.EM.S(2,1,:))), ...
                    'DisplayName', [app.EM.label ' |S21|'], 'HandleVisibility', 'on');
                set(app.LEM11, 'XData', app.EM.f/1e9, 'YData', db(squeeze(app.EM.S(1,1,:))), ...
                    'DisplayName', [app.EM.label ' |S11|'], 'HandleVisibility', 'on');
            else
                set([app.LEM21 app.LEM11], 'XData', NaN, 'YData', NaN, 'HandleVisibility', 'off');
            end
            ax = app.AxResp; ylim(ax, [-60 2]); xlim(ax, fG([1 end]));
            delete(findobj(ax, 'Tag', 'band'));
            band = app.bandGHz();
            if diff(band) > 0
                xr = xregion(ax, band(1), band(2), 'FaceColor', [0.3 0.7 0.3], 'FaceAlpha', 0.08, 'Tag', 'band');
            else
                xr = xline(ax, band(1), ':', 'Color', [0.2 0.6 0.2], 'LineWidth', 1.5, 'Tag', 'band');
            end
            xr.Annotation.LegendInformation.IconDisplayStyle = 'off';
            title(ax, app.metrics(S), 'FontSize', 10, 'FontWeight', 'normal');
            app.DimTable.Data = app.T.dims(app.D, app.Spec, app.Sub);
            if redrawLayout, app.drawLayout(); end
        end

        function b = bandGHz(app)
            s = app.Spec; fG = app.F([1 end])/1e9;
            switch app.T.kind
                case {'BP', 'BS'}, b = [s.f1 s.f2]/1e9;
                case 'LP', b = [fG(1) s.fc/1e9];
                case 'HP', b = [s.fc min(s.fc*s.fu, app.F(end))]/1e9;
                case 'RES', b = [s.f0 s.f0]/1e9;
            end
        end

        function n = isNotch(app)
            n = strcmp(app.T.id, 'spurline') || (strcmp(app.T.kind, 'RES') && ~strcmp(app.T.id, 'ring'));
        end

        function txt = metrics(app, S)
            s21 = db(squeeze(S(2,1,:))).'; s11 = db(squeeze(S(1,1,:))).'; f = app.F; s = app.Spec;
            calNote = ternary(isempty(app.Cal), '', ' · EM-calibrated model');
            switch app.T.kind
                case 'BP'
                    f0 = sqrt(s.f1*s.f2); in = f >= s.f1 & f <= s.f2;
                    [pk, ip] = max(s21);
                    [lo, hi] = around(s21 >= pk - 3, ip); fl = f(lo); fh = f(hi);
                    txt = {sprintf('IL %.2f dB at f0 · worst passband RL %.1f dB%s', ...
                              -interp1(f, s21, f0), -max(s11(in)), calNote);
                           sprintf('3 dB band %.3f–%.3f GHz · S21 peak at %.3f GHz', fl/1e9, fh/1e9, f(ip)/1e9)};
                case 'BS'
                    [mn, im] = min(s21);
                    st = f(s21 <= -3); txt3 = '-3 dB stop band not reached';
                    if ~isempty(st)
                        % contiguous -3 dB region around the deepest point
                        [lo, hi] = around(s21 <= -3, im);
                        txt3 = sprintf('-3 dB stop band %.3f–%.3f GHz', f(lo)/1e9, f(hi)/1e9);
                    end
                    f0 = sqrt(s.f1*s.f2); out = abs(f - f0) > max(1.5*(s.f2 - s.f1), 0.25*f0);
                    txt = {sprintf('Rejection %.1f dB at f0 · deepest %.1f dB at %.3f GHz%s', ...
                              -interp1(f, s21, f0), -mn, f(im)/1e9, calNote);
                           sprintf('%s · passband (away from f1–f2) worst RL %.1f dB', txt3, -max(s11(out)))};
                case 'LP'
                    in = f <= s.fc;
                    i3 = find(s21 < -3, 1); f3 = NaN; if ~isempty(i3), f3 = f(i3); end
                    a2 = -interp1(f, s21, min(2*s.fc, f(end)));
                    txt = {sprintf('Passband: worst IL %.2f dB · worst RL %.1f dB%s', -min(s21(in)), -max(s11(in)), calNote);
                           sprintf('-3 dB at %.3f GHz · %.1f dB rejection at 2 fc', f3/1e9, a2)};
                case 'HP'
                    in = f >= s.fc & f <= 0.9*s.fc*s.fu;   % usable band (see the warning)
                    i3 = find(s21 >= -3, 1); f3 = NaN; if ~isempty(i3), f3 = f(i3); end
                    a2 = -interp1(f, s21, s.fc/2);
                    txt = {sprintf('Passband fc–%.2g fc: worst IL %.2f dB · worst RL %.1f dB%s', 0.9*s.fu, ...
                              -min(s21(in)), -max(s11(in)), calNote);
                           sprintf('-3 dB at %.3f GHz · %.1f dB rejection at fc/2', f3/1e9, a2)};
                case 'RES'
                    notch = app.isNotch();
                    [fr, depth, QL] = fd.topo.common.peakFreq(S, f, notch);
                    if notch
                        txt = {sprintf('Notch at %.4f GHz (target %.4f, %+.2f %%)%s', fr/1e9, s.f0/1e9, ...
                                  100*(fr/s.f0 - 1), calNote);
                               sprintf('Depth %.1f dB · loaded Q (3 dB width of the dip) %.0f', -depth, QL)};
                    else
                        Qu = QL/(1 - 10^(depth/20));
                        txt = {sprintf('Peak at %.4f GHz (target %.4f, %+.2f %%)%s', fr/1e9, s.f0/1e9, ...
                                  100*(fr/s.f0 - 1), calNote);
                               sprintf('IL %.1f dB · loaded Q %.0f · unloaded Q ≈ %.0f', -depth, QL, Qu)};
                    end
            end
        end

        function drawLayout(app)
            ax = app.AxLay; cla(ax); hold(ax, 'on');
            try
                obj = app.T.toolbox(app.D, app.Sub);
                if isa(obj, 'pcbComponent'), pc = obj; else, pc = pcbComponent(obj); end
                w = warning('off', 'all'); cw = onCleanup(@() warning(w));
                vg = getShapeVertices(pc.Layers{end}); pg = polyshape(vg(:, 1:2)*1e3);
                vt = getShapeVertices(pc.Layers{1});   pt = polyshape(vt(:, 1:2)*1e3);
                plot(ax, pg, 'FaceColor', [0.80 0.88 0.72], 'FaceAlpha', 1, 'EdgeColor', [0.45 0.55 0.35]);
                plot(ax, pt, 'FaceColor', [0.85 0.55 0.20], 'FaceAlpha', 0.85, 'EdgeColor', [0.5 0.3 0.1]);
                if pg.NumHoles > 0   % etched ground features (CSRR): outline them on top
                    hp = holes(pg);
                    for k = 1:numel(hp)
                        plot(ax, hp(k), 'FaceColor', 'none', 'EdgeColor', [0.1 0.4 0.1], 'LineWidth', 1.2);
                    end
                end
                V = pc.ViaLocations;
                if ~isempty(V)
                    r = pc.ViaDiameter*1e3/2; th = linspace(0, 2*pi, 25);
                    for k = 1:size(V, 1)
                        fill(ax, V(k,1)*1e3 + r*cos(th), V(k,2)*1e3 + r*sin(th), [0.2 0.2 0.2], 'EdgeColor', 'none');
                    end
                end
                app.annotateLayout(ax);
                [bx, by] = boundingbox(pg);
                ttl = {'Top copper (orange), ground (green), vias (black); mm', ...
                    sprintf('board %.1f × %.1f mm, h = %.2f mm', diff(bx), diff(by), app.Sub.h*1e3)};
                if pg.NumHoles > 0, ttl{1} = 'Top line (orange), etched ground slots (outlined); mm'; end
                title(ax, ttl, 'FontSize', 10, 'FontWeight', 'normal');
            catch e
                text(ax, 0, 0, ['Layout not available: ' e.message], 'HorizontalAlignment', 'center');
            end
            axis(ax, 'equal'); axis(ax, 'tight'); hold(ax, 'off');
        end

        function annotateLayout(app, ax)
            d = app.D; fs = 8;
            switch app.T.id
                case 'hairpin'
                    pitch = d.slot + 2*d.W;
                    xs = cumsum([0, pitch + d.s]);            % left edge of each hairpin
                    xs = xs - (xs(end) + pitch)/2;
                    for i = 1:d.n - 1
                        xg = (xs(i) + pitch + xs(i+1))/2*1e3;
                        text(ax, xg, (d.La/2)*1e3 + 1.2, sprintf('s%d=%.2f', i, d.s(i)*1e3), ...
                            'HorizontalAlignment', 'center', 'FontSize', fs, 'Rotation', 90);
                    end
                    text(ax, xs(1)*1e3 - 1, 0, sprintf('La=%.2f', d.La*1e3), 'Rotation', 90, ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', fs);
                case 'sir'
                    x = -sum(d.len)/2;
                    for i = 1:d.n
                        text(ax, (x + d.len(i)/2)*1e3, ((mod(i,2)*d.WL + ~mod(i,2)*d.WH)/2)*1e3 + 1, ...
                            sprintf('%.2f', d.len(i)*1e3), 'HorizontalAlignment', 'center', 'FontSize', fs);
                        x = x + d.len(i);
                    end
                case 'srr'
                    if d.N < 2, return; end
                    aOut = d.a + 2*(d.sp + d.w); pitch = d.gp + aOut;
                    x1 = (-(d.N - 1)/2*pitch + aOut/2)*1e3;  % right edge of pair 1
                    x2 = x1 + d.gp*1e3;                       % left edge of pair 2
                    y = (d.W0/2 + d.gc + aOut)*1e3 + 1;
                    plot(ax, [x1 x2], [y y], 'k-', 'LineWidth', 0.8, 'Marker', '|', 'MarkerSize', 8);
                    text(ax, (x1 + x2)/2, y + 0.4, sprintf('gap %.2f', d.gp*1e3), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', fs);
                case 'csrr'
                    if ~isfield(d, 'N') || d.N < 2, return; end
                    aOut = d.a + 2*(d.sp + d.w); [~, ~, xc] = fd.csrrBoard(d);
                    x1 = (xc(1) + aOut/2)*1e3; x2 = (xc(2) - aOut/2)*1e3;
                    y = aOut/2*1e3 + 1;
                    plot(ax, [x1 x2], [y y], 'k-', 'LineWidth', 0.8, 'Marker', '|', 'MarkerSize', 8);
                    text(ax, (x1 + x2)/2, y + 0.4, sprintf('gap %.2f', d.gp*1e3), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', fs);
            end
        end

        function showCalibration(app, dSec, sEM, cal)
            f = linspace(sEM.Frequencies(1), sEM.Frequencies(end), 801);
            S0 = app.T.model(dSec, app.Sub, f);
            S1 = app.T.model(fd.applyCal(dSec, cal), app.Sub, f);
            fig = uifigure('Name', 'EM calibration of the circuit model', 'Position', [200 200 760 460]);
            ax = uiaxes(fig, 'Position', [20 20 720 420]); hold(ax, 'on'); grid(ax, 'on');
            plot(ax, sEM.Frequencies/1e9, db(squeeze(sEM.Parameters(2,1,:))), 'ko', 'MarkerFaceColor', 'k', 'DisplayName', 'EM |S21|');
            plot(ax, sEM.Frequencies/1e9, db(squeeze(sEM.Parameters(1,1,:))), 'ks', 'DisplayName', 'EM |S11|');
            plot(ax, f/1e9, db(squeeze(S0(2,1,:))), '--', 'Color', [0.6 0.6 0.6], 'DisplayName', 'Circuit before');
            plot(ax, f/1e9, db(squeeze(S1(2,1,:))), '-', 'Color', [0.1 0.35 0.75], 'LineWidth', 2, 'DisplayName', 'Circuit after (S21)');
            plot(ax, f/1e9, db(squeeze(S1(1,1,:))), '-', 'Color', [0.85 0.45 0.1], 'DisplayName', 'Circuit after (S11)');
            legend(ax, 'Location', 'southeast'); ylim(ax, [-50 1]); xlabel(ax, 'GHz'); ylabel(ax, 'dB');
            title(ax, ['Calibrated: ' FilterDesigner.calString(cal)], 'FontWeight', 'normal');
        end

        % ------------------------------------------------------- sliders --
        function buildSliders(app)
            delete(app.TuneGrid.Children); app.Sliders(:) = [];
            rows = app.T.tune(app.D, app.Spec, app.Sub);   % {label, field, idx, min, max, mirror}
            mm = 1e3;
            app.TuneGrid.RowHeight = repmat({28}, 1, size(rows, 1));
            for r = 1:size(rows, 1)
                lim = sort([rows{r, 4} rows{r, 5}])*mm;
                if diff(lim) <= 0, lim(2) = lim(1) + 1e-3; end
                v = min(max(app.D.(rows{r, 2})(rows{r, 3})*mm, lim(1)), lim(2));
                uilabel(app.TuneGrid, 'Text', rows{r, 1});
                sl = uislider(app.TuneGrid, 'Limits', lim, 'Value', v, 'MajorTicks', [], 'MinorTicks', []);
                ef = uieditfield(app.TuneGrid, 'numeric', 'Value', round(v, 3), ...
                    'Limits', lim, 'ValueDisplayFormat', '%.3f mm');
                k = numel(app.Sliders) + 1;
                app.Sliders(k) = struct('h', sl, 'ef', ef, 'name', rows{r, 2}, 'idx', rows{r, 3}, ...
                    'mirror', rows{r, 6});
                sl.ValueChangingFcn = @(~, e) app.onSlide(k, e.Value, false);
                sl.ValueChangedFcn  = @(~, e) app.onSlide(k, e.Value, true);
                ef.ValueChangedFcn  = @(~, e) app.onSlide(k, e.Value, true);
            end
        end

        function onSlide(app, k, v, final)
            s = app.Sliders(k); x = v/1e3;
            app.D.(s.name)(s.idx) = x;
            if s.mirror && app.SymCB.Value                          % mirror partner
                n = numel(app.D.(s.name)); j = n + 1 - s.idx;
                if j ~= s.idx, app.D.(s.name)(j) = x; end
            end
            app.syncSliders();
            app.refresh(final);
        end

        function syncSliders(app)
            for k = 1:numel(app.Sliders)
                s = app.Sliders(k); v = app.D.(s.name)(s.idx)*1e3;
                v = min(max(v, s.h.Limits(1)), s.h.Limits(2));
                s.h.Value = v; s.ef.Value = round(v, 3);
            end
        end

        % ---------------------------------------------------- tables/text --
        function showSteps(app)
            T = app.T;
            app.StepsText.Value = T.steps(app.DSynth, app.Info, app.Spec, app.Sub);
            if isempty(T.curves)
                cla(app.AxK); cla(app.AxQ); set([app.AxK app.AxQ], 'Visible', 'off');
                app.StepsGrid.ColumnWidth = {'1x', 0, 0};
            else
                set([app.AxK app.AxQ], 'Visible', 'on');
                app.StepsGrid.ColumnWidth = {'1.3x', '1x', '1x'};
                T.curves(app.AxK, app.AxQ, app.DSynth, app.Info);
            end
        end

        function warnings(app)
            w = app.T.warn(app.D, app.Info, app.Spec, app.Sub);
            for k = 1:numel(w), app.log('NOTE: %s', w{k}); end
        end

        % -------------------------------------------------------- export --
        function exportAll(app)
            if isempty(app.D), return; end
            folder = uigetdir(pwd, 'Choose a folder for the exported design');
            figure(app.Fig);
            if isequal(folder, 0), return; end
            base = fullfile(folder, sprintf('%s_%s', app.T.id, char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
            out = {};
            Tb = cell2table(app.DimTable.Data, 'VariableNames', {'Dimension', 'Value_mm', 'Meaning'});
            writetable(Tb, [base '_dimensions.csv']); out{end+1} = '_dimensions.csv';
            design = struct('topology', app.T.id, 'name', app.T.name, 'spec', app.Spec, ...
                'substrate', app.Sub, 'dims', app.D, 'synthesis', app.Info, 'calibration', app.Cal);
            save([base '_design.mat'], '-struct', 'design'); out{end+1} = '_design.mat';
            S = app.modelS(app.D, app.F);
            rfwrite(sparameters(S, app.F, 50), [base '_circuit.s2p']); out{end+1} = '_circuit.s2p';
            if ~isempty(app.EM)
                rfwrite(sparameters(app.EM.S, app.EM.f, 50), [base '_em.s2p']); out{end+1} = '_em.s2p';
            end
            exportgraphics(app.AxResp, [base '_response.png'], 'Resolution', 150); out{end+1} = '_response.png';
            exportgraphics(app.AxLay, [base '_layout.png'], 'Resolution', 200); out{end+1} = '_layout.png';
            try
                obj = app.T.toolbox(app.D, app.Sub);
                gdir = [base '_gerber']; mkdir(gdir);
                fd.writeGerber(obj, gdir, app.T.id); out{end+1} = '_gerber/';
            catch e
                app.log('Gerber export failed: %s', e.message);
            end
            app.log('Exported to %s: %s', folder, strjoin(out, ', '));
        end

        % --------------------------------------------------------- utils --
        function S = modelS(app, d, f)
            S = app.T.model(d, app.Sub, f);
        end

        function s = describe(app)
            sp = app.Spec; T = app.T;
            switch T.kind
                case {'BP', 'BS'}, b = sprintf('%.4g–%.4g GHz', sp.f1/1e9, sp.f2/1e9);
                case {'LP', 'HP'}, b = sprintf('fc = %.4g GHz', sp.fc/1e9);
                case 'RES',        b = sprintf('f0 = %.4g GHz', sp.f0/1e9);
            end
            if T.hasOrder, o = sprintf('order %d ', sp.n); else, o = ''; end
            s = sprintf('%s %s(%s) on %s %.2f mm', T.name, o, b, app.Sub.name, app.Sub.h*1e3);
        end

        function log(app, varargin)
            msg = sprintf(varargin{:});
            v = app.Status.Value; if ischar(v), v = {v}; end
            app.Status.Value = [{[char(datetime('now', 'Format', 'HH:mm:ss')) '  ' msg]}; v(:)];
        end
    end

    methods (Static, Access = private)
        function s = calString(cal)
            fn = fieldnames(cal); c = cell(1, numel(fn));
            for k = 1:numel(fn)
                v = cal.(fn{k});
                if abs(v) < 0.05 && v ~= 0, c{k} = sprintf('%s = %+.3f mm', fn{k}, v*1e3);
                else, c{k} = sprintf('%s = %.3f', fn{k}, v); end
            end
            s = strjoin(c, ', ');
        end

        function t = helpText()
            t = {
            'HOW TO USE'
            '1. Choose the RESPONSE (lowpass, highpass, bandpass, bandstop, resonator)'
            '   and a TOPOLOGY. The text under it says what the structure is.'
            '2. Type the specification. "Suggest order" finds the order that gives the'
            '   attenuation you need at a given frequency.'
            '3. Pick the board. FR4 is cheap but lossy; Rogers/PTFE are low loss.'
            '4. Press Synthesise. Read the "Design steps" tab: it shows every number,'
            '   from the prototype to the physical dimensions.'
            '5. In "Tune", move a slider and watch the response. Longer resonators'
            '   move the response DOWN in frequency; smaller gaps couple more strongly.'
            '6. "Optimise" tunes the dimensions to match the target (dashed curve, or'
            '   for resonators the requested f0).'
            '7. EM: "EM calibrate" simulates a small section with full-wave MoM and'
            '   corrects the fast circuit model; "EM full design" simulates everything'
            '   (small designs only) and can also calibrate. Then Optimise again.'
            '8. "Export" writes dimensions (CSV), S-parameters (.s2p), pictures and'
            '   Gerber files to send to any PCB fab.'
            ''
            'CURVES'
            '  dashed black  = ideal response (perfect synthesis, same resonator loss)'
            '  solid         = circuit model of YOUR dimensions (instant, approximate)'
            '  markers       = EM simulation (slow, accurate)'
            '  green band    = the specified passband / stop band (line = target f0)'
            ''
            'LIMITS OF THE CIRCUIT MODEL'
            '  It models lines, coupled lines, junctions, open ends, bends and vias,'
            '  but not every parasitic coupling, so far stopbands look deeper than'
            '  reality. Expect ~1-3 % frequency error for filters before EM'
            '  calibration, and ~5-15 % for SRR/CSRR (their formulas are approximate).'
            ''
            'EM NOTES'
            '  The RF PCB Toolbox default mesh is too coarse for filters (6-10 % error).'
            '  This app sets a converged mesh (edge ~ lambda_g/50) and checks memory'
            '  first. A big filter does not fit in a laptop - that is why calibration'
            '  uses a small section. EM runs take minutes: be patient, or Cancel.'
            };
        end
    end
end

% ===================================================================== utils
function y = db(x), y = 20*log10(abs(x) + 1e-15); end
function out = ternary(c, a, b), if c, out = a; else, out = b; end, end
function [lo, hi] = around(mask, i)
% first/last index of the run of true values in mask that contains i
lo = find(~mask(1:i), 1, 'last') + 1; if isempty(lo), lo = 1; end
hi = i - 1 + find(~mask(i:end), 1, 'first') - 1; if isempty(hi), hi = numel(mask); end
end
