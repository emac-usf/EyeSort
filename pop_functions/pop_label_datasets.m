% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.

% Author: Brandon Snyder


function [EEG, com] = pop_label_datasets(EEG)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %    LABEL DATASETS GUI      %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Initialize output
    com = '';
    
    % Queue state: labels are collected here before being applied all at once
    pending_labels = {};           % cell array of config structs
    saved_conflict_resolution = ''; % '' = ask each time, 'yes'/'no' = remembered choice
    
    % Check if we're in batch mode first
    batch_mode = false;
    batchFilePaths = {};
    batchFilenames = {};
    outputDir = '';
    
    % Track current label number for batch processing
    current_batch_label_count = 0;
    
    try
        batch_mode = evalin('base', 'eyesort_batch_mode');
        if batch_mode
            batchFilePaths = evalin('base', 'eyesort_batch_file_paths');
            batchFilenames = evalin('base', 'eyesort_batch_filenames');
            outputDir = evalin('base', 'eyesort_batch_output_dir');
            fprintf('Batch mode detected: %d datasets ready for labeling\n', length(batchFilePaths));
            
        end
    catch
        % Not in batch mode, continue with single dataset
        current_batch_label_count = 0;
    end
    
    % If no EEG input, try to get it from base workspace
    if nargin < 1
        try
            if batch_mode
                EEG = pop_loadset('filename', batchFilePaths{1}); % Load first dataset as reference
            
            else
                EEG = evalin('base', 'EEG');
                fprintf('Retrieved EEG from EEGLAB base workspace.\n');
            end
        catch ME
            error('Failed to retrieve EEG dataset from base workspace: %s', ME.message);
        end
    end
    
    % Initialize variables that will be used throughout the function
    regionNames = {};
    
    % Validate input
    if isempty(EEG)
        error('pop_label_datasets requires a non-empty EEG dataset');
    end
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        errordlg('EEG data does not contain any events.', 'Error');
        return;
    end
    if ~isfield(EEG.event(1), 'regionBoundaries')
        errordlg('EEG data is not properly processed with region information. Please process with the Text Interest Areas function first.', 'Error');
        return;
    end
    if ~isfield(EEG, 'eyesort_label_count')
        % Initialize label count to 0, so first label will be 01
        EEG.eyesort_label_count = 0;
    end
    
    % Get event type field names from EEG structure - these must exist
    if ~isfield(EEG, 'eyesort_field_names')
        errordlg('EEG data does not contain field name information. Please process with the Text Interest Areas function first.', 'Error');
        return;
    end
    
    % Note: EEG event validation occurs in the core labeling function
    
    % Extract region names, maintaining user-specified order
    if isfield(EEG, 'region_names') && ~isempty(EEG.region_names)
        % If the dataset has explicitly defined region order, use it
        fprintf('Using region_names field from EEG structure for ordered regions\n');
        regionNames = EEG.region_names;
        if ischar(regionNames)
            regionNames = {regionNames}; % Convert to cell array if it's a string
        end
    else
        % Otherwise extract from events but preserve order of first appearance
        fprintf('No region_names field found, extracting from events and preserving order\n');
        seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
        if isfield(EEG.event, 'current_region')
            for kk = 1:length(EEG.event)
                if isfield(EEG.event(kk), 'current_region') && ~isempty(EEG.event(kk).current_region)
                    regionName = EEG.event(kk).current_region;
                    % Only add each region once, preserving order of first appearance
                    if ~isKey(seen, regionName)
                        seen(regionName) = true;
                        regionNames{end+1} = regionName;
                    end
                end
            end
        end
    end
    
    if isempty(regionNames)
        regionNames = {'No regions found'};
    end
    
    % Print regions in order for verification
    fprintf('\nRegions in order (as will be displayed in listbox):\n');
    for m = 1:length(regionNames)
        fprintf('%d. %s\n', m, regionNames{m});
    end
    
    % In batch mode, go directly to GUI - user can load last config if desired
    if batch_mode
        fprintf('Batch mode: %d datasets ready. Use "Load Last Label Config" to reuse previous settings.\n', length(batchFilePaths));
    end

    % Let supergui create and size the figure automatically
    
    % Define the options to be used for checkboxes
    passTypeOptions = {'First pass only', 'Second pass only', 'Third pass and beyond'};
    fixationTypeOptions = {'Single Fixation', 'First of Multiple', 'Second of Multiple', 'All subsequent fixations', 'Last in Region'};
    saccadeInDirectionOptions = {'Forward only', 'Backward only'};
    saccadeOutDirectionOptions = {'Forward only', 'Backward only'};
    
    % Create parts of the layout for non-region sections
    % geomhoriz and geomvert are built in parallel (one entry per GUI row).
    % geomvert controls relative row heights; the label-queue listbox gets 4x height.
    geomhoriz = { ...
        1, ...                % Configuration management
        [1 1 1], ...            % Load config, Load last config buttons
        [0.5 1], ...          % Label Description label + edit box (consolidated)
        1, ...                % Time-Locked Region title (description folded in)
    };
    geomvert = [1, 1, 1, 1];
    
    uilist = { ...
        {'Style','text','String','Configuration Management:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','pushbutton','String','Load Label Configuration','callback', @load_label_config_callback}, ...
        {'Style','pushbutton','String','Load Previous Label Configuration','callback', @load_last_label_config_callback}, ...
        {}, ...   % spacer
        ...
        {'Style','text','String','Label Description (used in BDF generation):', 'FontWeight', 'bold'}, ...
        {'Style','edit','String','','tag','edtLabelDescription','ForegroundColor',[0 0 0]}, ...
        ...
        {'Style','text','String','Time-Locked Region: (main region of interest for all label criteria)', 'FontWeight', 'bold'}, ...
    };
    
    % Add dynamically generated checkboxes for regions
    numRegions = length(regionNames);
    regionCheckboxTags = cell(1, numRegions);
    
    % Each row will have 5 regions max (or fewer for the last row)
    regionsPerRow = 5;
    numRows = ceil(numRegions / regionsPerRow);
    
    for row = 1:numRows
        % Add geometry for this row
        columnsInRow = min(regionsPerRow, numRegions - (row-1)*regionsPerRow);
        rowGeom = zeros(1, columnsInRow);
        for col = 1:columnsInRow
            rowGeom(col) = 1/columnsInRow;
        end
        geomhoriz{end+1} = rowGeom;
        geomvert(end+1) = 1;
        
        % Add checkboxes for this row
        for col = 1:columnsInRow
            regionIdx = (row-1)*regionsPerRow + col;
            tag = sprintf('chkRegion%d', regionIdx);
            regionCheckboxTags{regionIdx} = tag;
            uilist{end+1} = {'Style','checkbox','String', regionNames{regionIdx}, 'tag', tag};
        end
    end
    
    % Create arrays for previous and next region checkboxes
    prevRegionCheckboxTags = cell(1, numRegions);
    nextRegionCheckboxTags = cell(1, numRegions);
    
    % Continue with the rest of the UI
    additionalGeomHoriz = { ...
        1, ...                        % Pass Type title (description folded in)
        [0.33 0.33 0.34], ...         % Pass type checkboxes
        1 ...                         % Previous Region title (description folded in)
    };
    additionalGeomVert = [1, 1, 1];
    
    additionalUIList = { ...
        {'Style','text','String','Pass Type: (first, second, or third+ pass through the time-locked region)', 'FontWeight', 'bold'}, ...
        ...
        {'Style','checkbox','String', passTypeOptions{1}, 'tag','chkPass1'}, ...
        {'Style','checkbox','String', passTypeOptions{2}, 'tag','chkPass2'}, ...
        {'Style','checkbox','String', passTypeOptions{3}, 'tag','chkPass3'}, ...
        ...
        {'Style','text','String','Previous Region: (region visited immediately before the time-locked region)', 'FontWeight', 'bold'}, ...
    };
    
    % Add Previous Region checkboxes with similar logic
    for row = 1:numRows
        % Add geometry for this row
        columnsInRow = min(regionsPerRow, numRegions - (row-1)*regionsPerRow);
        rowGeom = zeros(1, columnsInRow);
        for col = 1:columnsInRow
            rowGeom(col) = 1/columnsInRow;
        end
        additionalGeomHoriz{end+1} = rowGeom;
        additionalGeomVert(end+1) = 1;
        
        % Add checkboxes for this row
        for col = 1:columnsInRow
            regionIdx = (row-1)*regionsPerRow + col;
            tag = sprintf('chkPrevRegion%d', regionIdx);
            prevRegionCheckboxTags{regionIdx} = tag;
            additionalUIList{end+1} = {'Style','checkbox','String', regionNames{regionIdx}, 'tag', tag};
        end
    end
    
    % Add Next Region title (description folded in) after Previous Region checkboxes
    additionalGeomHoriz{end+1} = 1;
    additionalGeomVert(end+1) = 1;
    additionalUIList{end+1} = {'Style','text','String','Next Region: (region visited immediately after the time-locked region)', 'FontWeight', 'bold'};
    
    % Add Next Region checkboxes with similar logic
    for row = 1:numRows
        % Add geometry for this row
        columnsInRow = min(regionsPerRow, numRegions - (row-1)*regionsPerRow);
        rowGeom = zeros(1, columnsInRow);
        for col = 1:columnsInRow
            rowGeom(col) = 1/columnsInRow;
        end
        additionalGeomHoriz{end+1} = rowGeom;
        additionalGeomVert(end+1) = 1;
        
        % Add checkboxes for this row
        for col = 1:columnsInRow
            regionIdx = (row-1)*regionsPerRow + col;
            tag = sprintf('chkNextRegion%d', regionIdx);
            nextRegionCheckboxTags{regionIdx} = tag;
            additionalUIList{end+1} = {'Style','checkbox','String', regionNames{regionIdx}, 'tag', tag};
        end
    end
    
    % Add the rest of the UI controls, including the label queue panel
    additionalGeomHoriz = [additionalGeomHoriz, { ...
        1, ...                       % Fixation Type title (description folded in)
        [0.2 0.2 0.2 0.2 0.2], ...   % Fixation type checkboxes
        1, ...                       % Saccade Direction title (description folded in)
        [0.33 0.33 0.33], ...        % Saccade In label and checkboxes
        [0.33 0.33 0.33], ...        % Saccade Out label and checkboxes
        1, ...                       % Label Queue section title
        1, ...                       % Listbox (tall row via geomvert)
        [0.45 0.55], ...             % Remove Selected button + spacer
        1, ...                       % Spacer row
        [1 0.2 1 1 1] ...            % Save Config | spacer | Cancel | Add Label to Queue | Apply All & Finish
    }];
    % geomvert for the 10 rows above: listbox row gets height 4
    additionalGeomVert = [additionalGeomVert, 1, 1, 1, 1, 1, 1, 4, 1, 1, 1];
    
    additionalUIList = [additionalUIList, { ...
        {'Style','text','String','Fixation Type: (single, first-of-multiple, second, all subsequent, or last in region)', 'FontWeight', 'bold'}, ...
        ...
        {'Style','checkbox','String', fixationTypeOptions{1}, 'tag','chkFixType1'}, ...
        {'Style','checkbox','String', fixationTypeOptions{2}, 'tag','chkFixType2'}, ...
        {'Style','checkbox','String', fixationTypeOptions{3}, 'tag','chkFixType3'}, ...
        {'Style','checkbox','String', fixationTypeOptions{4}, 'tag','chkFixType4'}, ...
        {'Style','checkbox','String', fixationTypeOptions{5}, 'tag','chkFixType5'}, ...
        ...
        {'Style','text','String','Saccade Direction: (into / out-of the time-locked region)', 'FontWeight', 'bold'}, ...
        ...
        {'Style','text','String','Saccade In:'}, ...
        {'Style','checkbox','String', saccadeInDirectionOptions{1}, 'tag','chkSaccadeIn1'}, ...
        {'Style','checkbox','String', saccadeInDirectionOptions{2}, 'tag','chkSaccadeIn2'}, ...
        ...
        {'Style','text','String','Saccade Out:'}, ...
        {'Style','checkbox','String', saccadeOutDirectionOptions{1}, 'tag','chkSaccadeOut1'}, ...
        {'Style','checkbox','String', saccadeOutDirectionOptions{2}, 'tag','chkSaccadeOut2'}, ...
        {'Style','text','String','Label Queue (configure labels above, then add them here):', 'FontWeight', 'bold'}, ...
        {'Style','listbox','String',{'(no labels queued)'},'tag','lstPendingLabels','Min',0,'Max',1}, ...
        {'Style','pushbutton','String','Remove Selected Label','callback', @remove_selected_label}, ...
        {}, ...   % spacer beside Remove button
        ...
        {}, ...   % spacer row
        ...
        {'Style', 'pushbutton', 'String', 'Save Label Configuration', 'callback', @save_label_config_callback}, ...
        {}, ...   % spacer between Save and Cancel
        {'Style', 'pushbutton', 'String', 'Cancel', 'callback', @cancel_button}, ...
        {'Style', 'pushbutton', 'String', 'Add Label to Queue', 'callback', @add_label_to_queue}, ...
        {'Style', 'pushbutton', 'String', 'Apply All & Finish', 'callback', @apply_all_and_finish} ...
    }];
    
    % Combine all parts
    geomhoriz = [geomhoriz, additionalGeomHoriz];
    geomvert  = [geomvert,  additionalGeomVert];
    uilist = [uilist, additionalUIList];
    
    % Create the GUI using supergui (let it create and size the figure)
    [~, ~, ~, hFig] = supergui('geomhoriz', geomhoriz, 'geomvert', geomvert, 'uilist', uilist, 'title', 'Eye-Tracking Event Labeling');
    
    % Bring window to front
    figure(gcf);
    
    % *** Modification: Pause execution until user interaction is complete ***
    uiwait(gcf);  % This will pause the function until uiresume is called

    % Callback for the Cancel button
    function cancel_button(~,~)
        com = '';
        uiresume(gcf);
        fprintf('User cancelled the labeling process.\n');
        close(gcf);
    end

    % -----------------------------------------------------------------------
    % NEW: Add Label to Queue
    % Validates the form, collects the config, appends it to pending_labels,
    % refreshes the queue listbox, and resets the form — no labeling happens yet.
    % -----------------------------------------------------------------------
    function add_label_to_queue(~,~)
        % Validate region selection
        regionSelected = false;
        for ii = 1:length(regionCheckboxTags)
            if get(findobj('tag', regionCheckboxTags{ii}), 'Value') == 1
                regionSelected = true;
                break;
            end
        end
        if ~regionSelected
            errordlg('Please select at least one time-locked region before adding to the queue.', 'Region Required');
            return;
        end
        
        % Validate label description
        labelDescription = get(findobj('tag','edtLabelDescription'), 'String');
        if iscell(labelDescription), labelDescription = labelDescription{1}; end
        if isempty(strtrim(labelDescription))
            errordlg('Please enter a Label Description before adding to the queue.', 'Description Required');
            return;
        end
        
        % Collect config from form
        label_config = collect_label_gui_settings();
        if isempty(label_config), return; end
        
        % Append to queue and refresh display
        pending_labels{end+1} = label_config;
        update_queue_display();
        
        % Reset form for the next label
        reset_gui_for_next_label();
        
        fprintf('Label %d added to queue: "%s"\n', length(pending_labels), label_config.labelDescription);
    end

    % -----------------------------------------------------------------------
    % NEW: Apply All & Finish
    % Applies every label in pending_labels sequentially, then closes the GUI.
    % -----------------------------------------------------------------------
    function apply_all_and_finish(~,~)
        if isempty(pending_labels)
            errordlg(['No labels in queue. Use "Add Label to Queue" to configure and ' ...
                      'queue at least one label before applying.'], 'Empty Queue');
            return;
        end
        
        try
            if batch_mode
                apply_all_labels_batch();
            else
                apply_all_labels_single();
            end
        catch ME
            errordlg(['Error applying labels: ' ME.message], 'Error');
        end
    end

    % Save label configuration / queue callback
    function save_label_config_callback(~,~)
        % If there are queued labels, offer to save the whole queue or just current form
        if ~isempty(pending_labels)
            choice = questdlg('What would you like to save?', 'Save Configuration', ...
                'Save Full Queue', 'Save Current Form Only', 'Save Full Queue');
            figure(gcf);
            if isempty(choice), return; end
            if strcmp(choice, 'Save Full Queue')
                to_save = pending_labels;
            else
                to_save = collect_label_gui_settings();
                if isempty(to_save), return; end
            end
        else
            to_save = collect_label_gui_settings();
            if isempty(to_save), return; end
        end
        
        [filename, filepath] = uiputfile('*.mat', 'Save Label Configuration', 'my_label_config.mat');
        figure(gcf);
        if isequal(filename, 0), return; end
        
        full_filename = fullfile(filepath, filename);
        try
            save_label_config(to_save, full_filename);
            if iscell(to_save)
                msgbox(sprintf('Label queue (%d label(s)) saved to:\n%s', length(to_save), full_filename), 'Save Complete', 'help');
            else
                msgbox(sprintf('Label configuration saved to:\n%s', full_filename), 'Save Complete', 'help');
            end
            figure(gcf);
        catch ME
            errordlg(['Error saving: ' ME.message], 'Save Error');
            figure(gcf);
        end
    end

    % Load label configuration / queue callback
    function load_label_config_callback(~,~)
        try
            result = load_label_config(); % Shows file dialog
            figure(gcf);
            if isempty(result), return; end
            handle_loaded_config(result);
        catch ME
            errordlg(['Error loading configuration: ' ME.message], 'Load Error');
            figure(gcf);
        end
    end

    % Load last label configuration / queue callback
    function load_last_label_config_callback(~,~)
        try
            % Try the queue file first, then fall back to single config
            plugin_dir = fileparts(fileparts(mfilename('fullpath')));
            queue_file = fullfile(plugin_dir, 'cache', 'last_label_queue.mat');
            
            if exist(queue_file, 'file')
                result = load_label_config(queue_file);
                figure(gcf);
            elseif check_last_label_config()
                result = load_label_config('last_label_config.mat');
                figure(gcf);
            else
                msgbox('No previous configuration found. Save a configuration or queue first.', 'No Previous Config', 'warn');
                figure(gcf);
                return;
            end
            
            if isempty(result), return; end
            handle_loaded_config(result);
        catch ME
            errordlg(['Error loading previous configuration: ' ME.message], 'Load Error');
            figure(gcf);
        end
    end

    % Shared helper: apply a loaded config (single struct or queue cell array) to the GUI
    function handle_loaded_config(result)
        if iscell(result)
            % Queue — restore all labels to pending_labels and refresh display
            pending_labels = result;
            update_queue_display();
            msgbox(sprintf('Label queue loaded! %d label(s) added to the queue.\n\nClick "Apply All & Finish" to run them.', ...
                length(pending_labels)), 'Load Complete', 'help');
        else
            % Single config — populate the form
            apply_label_config_to_gui(result);
            msgbox('Label configuration loaded into the form.', 'Load Complete', 'help');
        end
        figure(gcf);
    end

    % Collect current label GUI settings
    function config = collect_label_gui_settings()
        config = struct();
        
        try
            % Region selections
            config.selectedRegions = {};
            for ii = 1:length(regionCheckboxTags)
                if get(findobj('tag', regionCheckboxTags{ii}), 'Value') == 1
                    config.selectedRegions{end+1} = regionNames{ii};
                end
            end
            
            % Pass type selections
            config.passFirstPass = get(findobj('tag','chkPass1'), 'Value');
            config.passSecondPass = get(findobj('tag','chkPass2'), 'Value');
            config.passThirdBeyond = get(findobj('tag','chkPass3'), 'Value');
            
            % Previous region selections
            config.selectedPrevRegions = {};
            for ii = 1:length(prevRegionCheckboxTags)
                if get(findobj('tag', prevRegionCheckboxTags{ii}), 'Value') == 1
                    config.selectedPrevRegions{end+1} = regionNames{ii};
                end
            end
            
            % Next region selections
            config.selectedNextRegions = {};
            for ii = 1:length(nextRegionCheckboxTags)
                if get(findobj('tag', nextRegionCheckboxTags{ii}), 'Value') == 1
                    config.selectedNextRegions{end+1} = regionNames{ii};
                end
            end
            
            % Fixation type selections
            config.fixSingleFixation = get(findobj('tag','chkFixType1'), 'Value');
            config.fixFirstOfMultiple = get(findobj('tag','chkFixType2'), 'Value');
            config.fixSecondMultiple = get(findobj('tag','chkFixType3'), 'Value');
            config.fixAllSubsequent = get(findobj('tag','chkFixType4'), 'Value');
            config.fixLastInRegion = get(findobj('tag','chkFixType5'), 'Value');
            
            % Saccade direction selections
            config.saccadeInForward = get(findobj('tag','chkSaccadeIn1'), 'Value');
            config.saccadeInBackward = get(findobj('tag','chkSaccadeIn2'), 'Value');
            config.saccadeOutForward = get(findobj('tag','chkSaccadeOut1'), 'Value');
            config.saccadeOutBackward = get(findobj('tag','chkSaccadeOut2'), 'Value');
            
            % Label description
            config.labelDescription = get(findobj('tag','edtLabelDescription'), 'String');
            if iscell(config.labelDescription)
                config.labelDescription = config.labelDescription{1};
            end
            config.labelDescription = strtrim(config.labelDescription); % Trim whitespace from user input
            
            % Store available regions for validation when loading
            config.availableRegions = regionNames;
            
        catch ME
            errordlg(['Error collecting label GUI settings: ' ME.message], 'Collection Error');
            config = [];
        end
    end

    % Apply label configuration to GUI
    function apply_label_config_to_gui(config)
        try
            % Validate that saved regions are compatible with current regions
            if isfield(config, 'availableRegions')
                saved_regions = config.availableRegions;
                if ~isequal(sort(saved_regions), sort(regionNames))
                    warning_msg = sprintf(['Warning: The saved configuration was created with different regions:\n\n'...
                        'Saved regions: %s\n\n'...
                        'Current regions: %s\n\n'...
                        'Region-specific selections may not match exactly.'], ...
                        strjoin(saved_regions, ', '), strjoin(regionNames, ', '));
                    msgbox(warning_msg, 'Region Mismatch Warning', 'warn');
                end
            end
            
            % Clear all current selections first
            % Region selections
            for i = 1:length(regionCheckboxTags)
                set(findobj('tag', regionCheckboxTags{i}), 'Value', 0);
            end
            for i = 1:length(prevRegionCheckboxTags)
                set(findobj('tag', prevRegionCheckboxTags{i}), 'Value', 0);
            end
            for i = 1:length(nextRegionCheckboxTags)
                set(findobj('tag', nextRegionCheckboxTags{i}), 'Value', 0);
            end
            
            % Apply region selections
            if isfield(config, 'selectedRegions')
                for i = 1:length(config.selectedRegions)
                    regionName = config.selectedRegions{i};
                    regionIdx = find(strcmpi(regionNames, regionName));
                    if ~isempty(regionIdx)
                        set(findobj('tag', regionCheckboxTags{regionIdx}), 'Value', 1);
                    end
                end
            end
            
            % Apply pass type selections
            if isfield(config, 'passFirstPass')
                set(findobj('tag','chkPass1'), 'Value', config.passFirstPass);
            end
            if isfield(config, 'passSecondPass')
                set(findobj('tag','chkPass2'), 'Value', config.passSecondPass);
            end
            if isfield(config, 'passThirdBeyond')
                set(findobj('tag','chkPass3'), 'Value', config.passThirdBeyond);
            end
            
            % Apply previous region selections
            if isfield(config, 'selectedPrevRegions')
                for i = 1:length(config.selectedPrevRegions)
                    regionName = config.selectedPrevRegions{i};
                    regionIdx = find(strcmpi(regionNames, regionName));
                    if ~isempty(regionIdx)
                        set(findobj('tag', prevRegionCheckboxTags{regionIdx}), 'Value', 1);
                    end
                end
            end
            
            % Apply next region selections
            if isfield(config, 'selectedNextRegions')
                for i = 1:length(config.selectedNextRegions)
                    regionName = config.selectedNextRegions{i};
                    regionIdx = find(strcmpi(regionNames, regionName));
                    if ~isempty(regionIdx)
                        set(findobj('tag', nextRegionCheckboxTags{regionIdx}), 'Value', 1);
                    end
                end
            end
            
            % Apply fixation options
            if isfield(config, 'fixSingleFixation')
                set(findobj('tag','chkFixType1'), 'Value', config.fixSingleFixation);
            end
            if isfield(config, 'fixFirstOfMultiple')
                set(findobj('tag','chkFixType2'), 'Value', config.fixFirstOfMultiple);
            end
            if isfield(config, 'fixSecondMultiple')
                set(findobj('tag','chkFixType3'), 'Value', config.fixSecondMultiple);
            end
            if isfield(config, 'fixAllSubsequent')
                set(findobj('tag','chkFixType4'), 'Value', config.fixAllSubsequent);
            end
            if isfield(config, 'fixLastInRegion')
                set(findobj('tag','chkFixType5'), 'Value', config.fixLastInRegion);
            end
            
            % Apply saccade direction selections
            if isfield(config, 'saccadeInForward')
                set(findobj('tag','chkSaccadeIn1'), 'Value', config.saccadeInForward);
            end
            if isfield(config, 'saccadeInBackward')
                set(findobj('tag','chkSaccadeIn2'), 'Value', config.saccadeInBackward);
            end
            if isfield(config, 'saccadeOutForward')
                set(findobj('tag','chkSaccadeOut1'), 'Value', config.saccadeOutForward);
            end
            if isfield(config, 'saccadeOutBackward')
                set(findobj('tag','chkSaccadeOut2'), 'Value', config.saccadeOutBackward);
            end
            
            % Apply label description
            if isfield(config, 'labelDescription')
                set(findobj('tag','edtLabelDescription'), 'String', config.labelDescription);
            end
            
        catch ME
            errordlg(['Error applying label configuration to GUI: ' ME.message], 'Apply Error');
        end
    end

    % -----------------------------------------------------------------------
    % Remove the selected label from the queue
    % -----------------------------------------------------------------------
    function remove_selected_label(~,~)
        lb = findobj('tag', 'lstPendingLabels');
        if isempty(lb) || isempty(pending_labels), return; end
        idx = get(lb, 'Value');
        if idx >= 1 && idx <= length(pending_labels)
            removed = pending_labels{idx}.labelDescription;
            pending_labels(idx) = [];
            update_queue_display();
            fprintf('Removed label %d ("%s") from queue. %d label(s) remaining.\n', ...
                idx, removed, length(pending_labels));
        end
    end

    % -----------------------------------------------------------------------
    % Refresh the queue listbox to reflect current pending_labels
    % -----------------------------------------------------------------------
    function update_queue_display()
        lb = findobj('tag', 'lstPendingLabels');
        if isempty(lb), return; end
        if isempty(pending_labels)
            set(lb, 'String', {'(no labels queued)'}, 'Value', 1);
        else
            items = cell(1, length(pending_labels));
            for i = 1:length(pending_labels)
                items{i} = format_label_for_display(pending_labels{i}, i);
            end
            curVal = get(lb, 'Value');
            set(lb, 'String', items, 'Value', min(curVal, length(pending_labels)));
        end
    end

    % Format a queued label config as a readable string for the listbox
    function str = format_label_for_display(cfg, idx)
        desc = '(no description)';
        if isfield(cfg, 'labelDescription') && ~isempty(strtrim(cfg.labelDescription))
            desc = cfg.labelDescription;
        end
        regions = '(none)';
        if isfield(cfg, 'selectedRegions') && ~isempty(cfg.selectedRegions)
            regions = strjoin(cfg.selectedRegions, ', ');
        end
        str = sprintf('[%d] %s  —  Region(s): %s', idx, desc, regions);
    end

    % -----------------------------------------------------------------------
    % Apply all queued labels to a single dataset, then close
    % -----------------------------------------------------------------------
    function apply_all_labels_single()
        nLabels = length(pending_labels);
        matched_counts = zeros(1, nLabels);
        
        h = waitbar(0, 'Applying labels...', 'Name', 'Eye-Tracking Event Labeling');
        try
            for qi = 1:nLabels
                desc = '';
                if isfield(pending_labels{qi}, 'labelDescription')
                    desc = pending_labels{qi}.labelDescription;
                end
                waitbar(qi / nLabels, h, sprintf('Applying label %d of %d: %s', qi, nLabels, desc));
                label_params = convert_config_to_params_gui(pending_labels{qi});
                if ~isempty(saved_conflict_resolution)
                    label_params = [label_params, {'conflictResolution', saved_conflict_resolution}];
                end
                [EEG, label_com, chosen] = label_datasets_core(EEG, label_params{:});
                com = label_com;
                if ~isempty(chosen)
                    saved_conflict_resolution = chosen;
                end
                matched_counts(qi) = EEG.eyesort_last_label_matched_count;
                assignin('base', 'EEG', EEG);
            end
        catch ME
            delete(h);
            rethrow(ME);
        end
        delete(h);
        
        % Auto-save the queue so it can be reloaded next session
        try
            save_label_config(pending_labels, 'last_label_queue.mat');
        catch
            fprintf('Note: Could not auto-save label queue.\n');
        end
        
        % Auto-save labeled dataset if output directory is configured
        try
            outputDir_single = evalin('base', 'eyesort_single_output_dir');
            if ~isempty(outputDir_single)
                if isfield(EEG, 'filename') && ~isempty(EEG.filename)
                    [~, name, ~] = fileparts(EEG.filename);
                else
                    name = 'dataset';
                end
                output_path = fullfile(outputDir_single, [name '_labeled.set']);
                pop_saveset(EEG, 'filename', output_path, 'savemode', 'twofiles');
                fprintf('Auto-saved labeled dataset to: %s\n', output_path);

                % Write per-full_description CSV summary
                if isfield(EEG, 'event') && isfield(EEG.event, 'bdf_full_description')
                    session_idx = 1;
                    while exist(fullfile(outputDir_single, sprintf('eyesort_labeling_summary_%03d.csv', session_idx)), 'file')
                        session_idx = session_idx + 1;
                    end
                    csv_path = fullfile(outputDir_single, sprintf('eyesort_labeling_summary_%03d.csv', session_idx));
                    allFD = {EEG.event.bdf_full_description};
                    allFD = allFD(~cellfun(@isempty, allFD));
                    uniqueFD = unique(allFD);
                    fid = fopen(csv_path, 'w');
                    if fid ~= -1
                        fprintf(fid, 'Dataset,FullDescription,TrialCount\n');
                        for ui = 1:length(uniqueFD)
                            fprintf(fid, '%s,%s,%d\n', name, uniqueFD{ui}, sum(strcmp(allFD, uniqueFD{ui})));
                        end
                        fclose(fid);
                        append_grand_totals(csv_path);
                        fprintf('Summary saved to: %s\n', csv_path);
                    end
                end
            end
        catch
            % No output dir set — skip silently
        end
        
        % Build a per-label summary for the completion message
        summaryLines = cell(1, nLabels);
        for qi = 1:nLabels
            desc = '';
            if isfield(pending_labels{qi}, 'labelDescription')
                desc = pending_labels{qi}.labelDescription;
            end
            if matched_counts(qi) > 0
                summaryLines{qi} = sprintf('  Label %02d (%s): %d event(s) matched', qi, desc, matched_counts(qi));
            else
                summaryLines{qi} = sprintf('  Label %02d (%s): WARNING — 0 events matched', qi, desc);
            end
        end

        % Build breakdown by bdf_full_description (label + condition)
        fdLines = {};
        if isfield(EEG, 'event') && isfield(EEG.event, 'bdf_full_description')
            allFD = {EEG.event.bdf_full_description};
            allFD = allFD(~cellfun(@isempty, allFD));
            uniqueFD = unique(allFD);
            for ui = 1:length(uniqueFD)
                fdLines{end+1} = sprintf('  %-40s : %d trial(s)', uniqueFD{ui}, sum(strcmp(allFD, uniqueFD{ui})));
            end
        end
        fdStr = '';
        if ~isempty(fdLines)
            fdStr = sprintf('\n\nTrials by label+condition:\n%s', strjoin(fdLines, '\n'));
        end

        summaryStr = sprintf(['Labeling complete!\n\n%d label(s) applied:\n%s%s\n\n' ...
            'Events have been labeled with 6-digit codes (CCRRLL).\n' ...
            'CC = condition, RR = region, LL = label'], ...
            nLabels, strjoin(summaryLines, '\n'), fdStr);
        hMsg = msgbox(summaryStr, 'Labeling Complete', 'help');
        waitfor(hMsg);
        
        uiresume(gcf);
        close(gcf);
    end

    % Helper function to reset GUI for next label
    function reset_gui_for_next_label()
        % Reset the time-locked region selection for the next label
        for i = 1:length(regionCheckboxTags)
            set(findobj('tag', regionCheckboxTags{i}), 'Value', 0);
        end
        
        % Reset the previous region checkboxes
        for i = 1:length(prevRegionCheckboxTags)
            set(findobj('tag', prevRegionCheckboxTags{i}), 'Value', 0);
        end
        
        % Reset the next region checkboxes
        for i = 1:length(nextRegionCheckboxTags)
            set(findobj('tag', nextRegionCheckboxTags{i}), 'Value', 0);
        end
        
        % Reset pass type checkboxes
        for i = 1:3
            set(findobj('tag', sprintf('chkPass%d', i)), 'Value', 0);
        end

        % Reset fixation type checkboxes
        for i = 1:5
            set(findobj('tag', sprintf('chkFixType%d', i)), 'Value', 0);
        end

        % Reset saccade direction checkboxes
        for i = 1:2
            set(findobj('tag', sprintf('chkSaccadeIn%d', i)), 'Value', 0);
            set(findobj('tag', sprintf('chkSaccadeOut%d', i)), 'Value', 0);
        end

        % Reset the label description
        set(findobj('tag','edtLabelDescription'), 'String', '');
    end

    % -----------------------------------------------------------------------
    % Apply all queued labels to all batch datasets, then close
    % -----------------------------------------------------------------------
    function apply_all_labels_batch()
        % Determine the starting label count from the first dataset
        if current_batch_label_count == 0
            first_ds = pop_loadset('filename', batchFilePaths{1});
            if isfield(first_ds, 'eyesort_label_count') && ~isempty(first_ds.eyesort_label_count)
                current_batch_label_count = first_ds.eyesort_label_count;
            end
            clear first_ds;
        end
        
        % Generate a unique summary filename for this session
        session_idx = 1;
        while exist(fullfile(outputDir, sprintf('eyesort_labeling_summary_%03d.csv', session_idx)), 'file')
            session_idx = session_idx + 1;
        end
        session_summary_file = fullfile(outputDir, sprintf('eyesort_labeling_summary_%03d.csv', session_idx));
        
        % Apply each queued label to all datasets in sequence.
        % saved_conflict_resolution threads the user's "remember" choice across
        % all labels and all datasets so the conflict dialog never repeats.
        all_rows = {};
        for qi = 1:length(pending_labels)
            current_batch_label_count = current_batch_label_count + 1;
            [~, ~, saved_conflict_resolution, label_rows] = batch_apply_labels_with_count( ...
                batchFilePaths, batchFilenames, outputDir, ...
                pending_labels{qi}, current_batch_label_count, saved_conflict_resolution);
            all_rows = [all_rows, label_rows];
        end

        % Write CSV sorted by dataset name
        if ~isempty(all_rows)
            ds_names = cellfun(@(r) strtok(r, ','), all_rows, 'UniformOutput', false);
            [~, sort_idx] = sort(ds_names);
            fid = fopen(session_summary_file, 'w');
            if fid ~= -1
                fprintf(fid, 'Dataset,FullDescription,TrialCount\n');
                for r = sort_idx
                    fprintf(fid, '%s\n', all_rows{r});
                end
                fclose(fid);
            end
        end
        append_grand_totals(session_summary_file);

        % Auto-save the queue for next session
        try
            save_label_config(pending_labels, 'last_label_queue.mat');
        catch
            fprintf('Note: Could not auto-save label queue.\n');
        end
        
        % Clean up and close
        cleanup_temp_files(batchFilePaths);
        evalin('base', 'clear eyesort_batch_file_paths eyesort_batch_filenames eyesort_batch_mode');
        
        com = sprintf('EEG = pop_label_datasets(EEG); %% Batch labeling completed with %d labels applied', current_batch_label_count);
        
        total_events_msg = sprintf(['Batch labeling complete!\n\n%d dataset(s) processed with %d label(s) applied.\n\n' ...
            'All datasets are ready for BDF generation.'], length(batchFilePaths), current_batch_label_count);
        h_msg = msgbox(total_events_msg, 'Batch Complete');
        waitfor(h_msg);
        
        current_batch_label_count = 0;
        uiresume(gcf);
        close(gcf);
    end

    % Batch apply a single label config to all datasets (called in a loop by apply_all_labels_batch)
    function [processed_count, com, resolvedConflictResolution, label_rows] = batch_apply_labels_with_count(filePaths, fileNames, outputDir, config, labelNum, conflictResolution)
        if nargin < 6, conflictResolution = ''; end
        processed_count = 0;
        label_rows = {};
        com = '';
        resolvedConflictResolution = conflictResolution;
        
        % Create a progress bar
        h = waitbar(0, sprintf('Applying label %02d to batch datasets...', labelNum), 'Name', 'Batch Processing');
        
        try
            for i = 1:length(filePaths)
                waitbar(i/length(filePaths), h, sprintf('Processing %d of %d: %s (Label %02d)', i, length(filePaths), strrep(fileNames{i}, '_', ' '), labelNum));
                
                try
                    % Generate clean filename once at the start
                    [~, fileName, ~] = fileparts(filePaths{i});
                    % Remove common processing suffixes and temp indicators
                    cleanFileName = regexprep(fileName, '(_temp|_textia|_processed|_labeled)+', '');
                    cleanFileName = regexprep(cleanFileName, '_+', '_');
                    cleanFileName = regexprep(cleanFileName, '^_|_$', '');
                    
                    % For label 1 load from original path; subsequent labels from output dir
                    if labelNum == 1
                        tempEEG = pop_loadset('filename', filePaths{i});
                    else
                        previous_file = fullfile(outputDir, [cleanFileName '_processed.set']);
                        if exist(previous_file, 'file')
                            tempEEG = pop_loadset('filename', previous_file);
                        else
                            warning('Previous labeled file not found: %s, using original', previous_file);
                            tempEEG = pop_loadset('filename', filePaths{i});
                        end
                    end
                    
                    % Preserve existing label count
                    if ~isfield(tempEEG, 'eyesort_label_count')
                        tempEEG.eyesort_label_count = labelNum - 1;
                    end
                    
                    % Verify dataset has required fields for labeling
                    if ~isfield(tempEEG, 'eyesort_field_names') || isempty(tempEEG.eyesort_field_names)
                        warning('Dataset %s missing eyesort_field_names - may not be properly processed', cleanFileName);
                        continue;
                    end
                    
                    % Convert configuration to parameters, include conflict resolution if set
                    label_params = convert_config_to_params_gui(config);
                    if ~isempty(conflictResolution)
                        label_params = [label_params, {'conflictResolution', conflictResolution}];
                    end
                    
                    % Snapshot existing descriptions before applying this label
                    preFD = {};
                    if isfield(tempEEG, 'event') && isfield(tempEEG.event, 'bdf_full_description')
                        preFD = {tempEEG.event.bdf_full_description};
                    end

                    % Apply the label; capture any "remember" conflict choice so it
                    % propagates to subsequent files in this batch run.
                    [labeledEEG, ~, newResolution] = label_datasets_core(tempEEG, label_params{:});
                    if ~isempty(newResolution)
                        resolvedConflictResolution = newResolution;
                        conflictResolution = newResolution;
                    end
                    
                    % Save with consistent clean name
                    output_path = fullfile(outputDir, [cleanFileName '_processed.set']);
                    pop_saveset(labeledEEG, 'filename', output_path, 'savemode', 'twofiles');

                    % Accumulate only NEWLY labeled events (exclude pre-existing descriptions)
                    if isfield(labeledEEG, 'event') && isfield(labeledEEG.event, 'bdf_full_description')
                        postFD = {labeledEEG.event.bdf_full_description};
                        newlyFD = {};
                        for ei = 1:length(postFD)
                            pre = '';
                            if ei <= length(preFD), pre = preFD{ei}; end
                            if ~isempty(postFD{ei}) && ~strcmp(postFD{ei}, pre)
                                newlyFD{end+1} = postFD{ei};
                            end
                        end
                        for ufd = unique(newlyFD)
                            label_rows{end+1} = sprintf('%s,%s,%d', cleanFileName, ufd{1}, sum(strcmp(newlyFD, ufd{1})));
                        end
                    end

                    clear tempEEG labeledEEG;
                    try; pack; catch; end
                    
                    processed_count = processed_count + 1;
                    fprintf('Processed %d/%d: %s with label %02d\n', processed_count, length(filePaths), cleanFileName, labelNum);
                    
                catch ME
                    warning('Failed to process dataset %s: %s', filePaths{i}, ME.message);
                end
            end
            
            delete(h);
            com = sprintf('EEG = pop_label_datasets(EEG); %% Applied label %02d to %d datasets', labelNum, processed_count);
            
            
        catch ME
            if exist('h', 'var') && ishandle(h)
                delete(h);
            end
            error('Error in batch processing: %s', ME.message);
        end
    end

    % Convert GUI configuration to parameters for core function
    function label_params = convert_config_to_params_gui(config)
        label_params = {};
        
        % Time-locked regions
        if isfield(config, 'selectedRegions') && ~isempty(config.selectedRegions)
            label_params{end+1} = 'timeLockedRegions';
            label_params{end+1} = config.selectedRegions;
        end
        
        % Pass options
        passOptions = [];
        if isfield(config, 'passFirstPass') && config.passFirstPass
            passOptions(end+1) = 2;
        end
        if isfield(config, 'passSecondPass') && config.passSecondPass
            passOptions(end+1) = 3;
        end
        if isfield(config, 'passThirdBeyond') && config.passThirdBeyond
            passOptions(end+1) = 4;
        end
        if isempty(passOptions)
            passOptions = 1;
        end
        label_params{end+1} = 'passOptions';
        label_params{end+1} = passOptions;
        
        % Previous regions
        if isfield(config, 'selectedPrevRegions') && ~isempty(config.selectedPrevRegions)
            label_params{end+1} = 'prevRegions';
            label_params{end+1} = config.selectedPrevRegions;
        end
        
        % Next regions
        if isfield(config, 'selectedNextRegions') && ~isempty(config.selectedNextRegions)
            label_params{end+1} = 'nextRegions';
            label_params{end+1} = config.selectedNextRegions;
        end
        
        % Fixation options
        fixationOptions = [];
        if isfield(config, 'fixSingleFixation') && config.fixSingleFixation
            fixationOptions(end+1) = 1;
        end
        if isfield(config, 'fixFirstOfMultiple') && config.fixFirstOfMultiple
            fixationOptions(end+1) = 2;
        end
        if isfield(config, 'fixSecondMultiple') && config.fixSecondMultiple
            fixationOptions(end+1) = 3;
        end
        if isfield(config, 'fixAllSubsequent') && config.fixAllSubsequent
            fixationOptions(end+1) = 4;
        end
        if isfield(config, 'fixLastInRegion') && config.fixLastInRegion
            fixationOptions(end+1) = 5;
        end
        if isempty(fixationOptions)
            fixationOptions = 0; % Default to "any fixation"
        end
        label_params{end+1} = 'fixationOptions';
        label_params{end+1} = fixationOptions;
        
        % Saccade in options
        saccadeInOptions = [];
        if isfield(config, 'saccadeInForward') && config.saccadeInForward
            saccadeInOptions(end+1) = 2;
        end
        if isfield(config, 'saccadeInBackward') && config.saccadeInBackward
            saccadeInOptions(end+1) = 3;
        end
        if isempty(saccadeInOptions)
            saccadeInOptions = 1;
        end
        label_params{end+1} = 'saccadeInOptions';
        label_params{end+1} = saccadeInOptions;
        
        % Saccade out options
        saccadeOutOptions = [];
        if isfield(config, 'saccadeOutForward') && config.saccadeOutForward
            saccadeOutOptions(end+1) = 2;
        end
        if isfield(config, 'saccadeOutBackward') && config.saccadeOutBackward
            saccadeOutOptions(end+1) = 3;
        end
        if isempty(saccadeOutOptions)
            saccadeOutOptions = 1;
        end
        label_params{end+1} = 'saccadeOutOptions';
        label_params{end+1} = saccadeOutOptions;
        
        % Add conditions and items - these should be empty for batch processing
        % to allow each dataset to determine its own conditions/items
        label_params{end+1} = 'conditions';
        label_params{end+1} = [];
        label_params{end+1} = 'items';
        label_params{end+1} = [];
        
        % Add label description
        if isfield(config, 'labelDescription') && ~isempty(config.labelDescription)
            label_params{end+1} = 'labelDescription';
            label_params{end+1} = config.labelDescription;
        end
    end

    % Append grand-total rows (sum across all datasets) to an existing CSV
    function append_grand_totals(csv_path)
        fid = fopen(csv_path, 'r');
        if fid == -1, return; end
        header = fgetl(fid);
        rows = {};
        while ~feof(fid)
            line = strtrim(fgetl(fid));
            if ~isempty(line), rows{end+1} = line; end
        end
        fclose(fid);
        if isempty(rows), return; end

        fdMap = containers.Map('KeyType','char','ValueType','double');
        for ri = 1:length(rows)
            parts = strsplit(rows{ri}, ',');
            if length(parts) >= 3
                key = strjoin(parts(2:end-1), ',');
                val = str2double(parts{end});
                if isKey(fdMap, key)
                    fdMap(key) = fdMap(key) + val;
                else
                    fdMap(key) = val;
                end
            end
        end

        fid = fopen(csv_path, 'a');
        if fid == -1, return; end
        for k = keys(fdMap)
            fprintf(fid, 'TOTAL,%s,%d\n', k{1}, fdMap(k{1}));
        end
        fclose(fid);
    end

end