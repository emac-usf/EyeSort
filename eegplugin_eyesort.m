% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

% Author: Brandon Snyder

function currvers = eegplugin_eyesort(fig, ~, ~)
% EEGPLUGIN_EYESORT - Register the EyeSort EEGLAB plugin menu and callbacks.

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %    EyeSort Plugin for EEGLAB:       %
    %        Main setup function          %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Call the default values script to intialize global variables
    eyesort_default_values;
    
    % Clear any lingering batch processing variables from previous sessions
    try
        evalin('base', 'clear eyesort_batch_file_paths eyesort_batch_filenames eyesort_batch_output_dir eyesort_batch_mode');
    catch
        % Variables might not exist, which is fine
    end
    
    % Return plugin name and version in EEGLAB's standard parsable format.
    currvers = ['EyeSort' eyesortver];
    
    % Ensure minimum arguments are met
    if nargin < 3
        error('eegplugin_eyesort requires 3 arguments');
    end

    % Add the to the MATLAB path
    p = which('eegplugin_eyesort', '-all');
    
    % Ensures no duplicates
    if length(p) > 1
        warning('EyeSort:MultiplePaths', ...
                'Multiple EyeSort folders found. Using the first one: %s', p{1});
    end
    
    p = p{1};
    idx = strfind(p, 'eegplugin_eyesort.m');
    
    if ~isempty(idx)
        p = p(1:idx - 1); % Extract the folder path
        addpath(p);
        addpath(fullfile(p, 'pop_functions'));
        addpath(fullfile(p, 'functions'));
    
    else
        error('Failed to locate the EyeSort plugin path.');
    end

   % Check if the EyeSort menu already exists
    menuEEGLAB = findobj(fig, 'tag', 'EEGLAB'); % Find EEGLAB main menu
    
    existingMenu = findobj(menuEEGLAB, 'tag', 'EyeSort'); % Check for existing EyeSort menu

    %% Initializes EyeSort to the EEGLAB menu
    if isempty(existingMenu)
        % Create main menu with try-catch for better error handling
        try
            submenu = uimenu(menuEEGLAB, 'Label', 'EyeSort', 'tag', 'EyeSort', ...
                             'separator', 'on', 'Callback', @(~,~) update_eyesort_menu_state(), ...
                             'userdata', 'study:on;erpset:on');
            
            % Store version number in a more accessible way
            setappdata(submenu, 'EyeSortVersion', eyesortver);
            
            % Add version as first item in the dropdown menu
            uimenu(submenu, 'label', ['         EyeSort v' eyesortver], ...
                   'separator', 'on');
            
            % Store main submenu handle for menu state updates
            setappdata(0, 'EyeSort_MainMenu', submenu);
            
            % Add error checking for callbacks
            uimenu(submenu, 'label', '1. Load EEG Dataset(s)', 'separator', 'on', ...
                   'userdata', 'study:on;erpset:on', ...
                   'callback', @(src,event) try_callback(@pop_load_datasets, src, event));
            
            % Improve menu structure with error handling
            loadInterestAreasMenu = uimenu(submenu, 'Label', '2. Setup Interest Areas', ...
                'separator', 'off', 'Tag', 'EyeSort_LoadIA', 'enable', 'off', ...
                'userdata', 'startup:off;study:on;erpset:on');
            
            uimenu(loadInterestAreasMenu, 'Label', 'Text-Based Sentence Contents and Interest Areas', ...
                'Tag', 'EyeSort_TextIA', 'enable', 'off', ...
                'userdata', 'startup:off;study:on;erpset:on', ...
                'callback', @(src,event) try_callback(@pop_load_text_ia, src, event));

            uimenu(loadInterestAreasMenu, 'Label', 'Inspect Parsed Regions', ...
                'Tag', 'EyeSort_InspectRegions', 'enable', 'off', ...
                'userdata', 'startup:off;study:on;erpset:on', ...
                'callback', @(src,event) try_callback(@pop_inspect_regions, src, event));
            
            % Import columns from IA text file into EEG events
            uimenu(submenu, 'label', '3. Import IA Columns to Events', 'separator', 'off', ...
                'userdata', 'startup:off;study:on;erpset:on', ...
                'callback', @(src,event) try_callback(@pop_import_ia_columns, src, event));

            % Eye-tracking event labeling
            uimenu(submenu, 'label', '4. Eye-Tracking Event Labeling', 'separator', 'off', ...
                'userdata', 'startup:off;study:on;erpset:on', ...
                'callback', @(src,event) try_callback(@pop_label_datasets, src, event));
            
            % Add the new BDF generator menu item
            uimenu(submenu, 'label', 'Generate BINLISTER BDF File', 'separator', 'on', ...
                'userdata', 'study:on;erpset:on', ...
                'callback', @(src,event) try_callback(@pop_generate_bdf, src, event));
            
            uimenu(submenu, 'label', 'Modify Event Code Format', 'separator', 'off', ...
                'userdata', 'startup:off;study:on;erpset:on', ...
                'callback', @(src,event) try_callback(@pop_convert_event_codes, src, event));
            
            historyScriptsMenu = uimenu(submenu, 'Label', 'History Scripts', ...
                'separator', 'on', 'Tag', 'EyeSort_HistoryScripts', ...
                'userdata', 'study:on;erpset:on');

            uimenu(historyScriptsMenu, 'Label', 'Save processing history script', ...
                'Tag', 'EyeSort_SaveSessionHistory', ...
                'userdata', 'study:on;erpset:on', ...
                'callback', @(src,event) try_callback(@save_eyesort_processing_script, src, event));
            
            uimenu(submenu, 'label', 'Help', 'separator', 'on', ...
                   'userdata', 'study:on;erpset:on', ...
                   'callback', @(src,event) try_callback(@help_button, src, event));

        catch ME
            error('EyeSort:MenuCreation', 'Failed to create EyeSort menu: %s', ME.message);
        end
    else
        warning('EyeSort:ExistingMenu', 'EyeSort menu already exists. Skipping creation.');
    end
end

% No-output wrapper so try_callback does not treat the script path as history.
function save_eyesort_processing_script()
    save_eyesort_session_script();
end

% Helper function for safer callback execution
function try_callback(callback_fn, ~, ~)
    try
        com = '';
        EEG = [];
        outputCount = nargout(callback_fn);
        if outputCount >= 2
            [EEG, com] = callback_fn();
        elseif outputCount == 1
            output = callback_fn();
            if ischar(output) || isstring(output)
                com = output;
            else
                EEG = output;
            end
        else
            callback_fn();
        end
        EEG = get_current_eyesort_eeg(EEG);
        if ~isempty(com)
            EEG = record_eyesort_history(com, EEG);
        end
        refresh_eyesort_eeglab_state(EEG);
        % Update menu state after successful operations (especially dataset loading)
        update_eyesort_menu_state();
    catch ME
        errordlg(sprintf('Error in EyeSort operation: %s', ME.message), 'EyeSort Error');
        rethrow(ME);
    end
end

function EEG = get_current_eyesort_eeg(EEG)
    try
        baseEEG = evalin('base', 'EEG');
        if ~isempty(baseEEG) && isstruct(baseEEG)
            EEG = baseEEG;
        end
    catch
        % Use the callback output if the base workspace is not available.
    end
end

function EEG = refresh_eyesort_eeglab_state(EEG)
    try
        EEG = get_current_eyesort_eeg(EEG);

        if ~isempty(EEG) && isstruct(EEG) && isscalar(EEG)
            try
                ALLEEG = evalin('base', 'ALLEEG');
                CURRENTSET = evalin('base', 'CURRENTSET');
            catch
                ALLEEG = [];
                CURRENTSET = 0;
            end

            if isempty(ALLEEG) || isempty(CURRENTSET) || ...
                    CURRENTSET < 1 || CURRENTSET > numel(ALLEEG)
                [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);
            else
                [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
            end

            assignin('base', 'ALLEEG', ALLEEG);
            assignin('base', 'EEG', EEG);
            assignin('base', 'CURRENTSET', CURRENTSET);
        elseif ~isempty(EEG) && isstruct(EEG)
            assignin('base', 'EEG', EEG);
        end

        try
            eeglab('redraw');
        catch
            % Redraw is best-effort; command-line workflows may not have a GUI.
        end
    catch ME
        warning('EyeSort:RefreshState', 'Failed to refresh EEGLAB state: %s', ME.message);
    end
end

% Function to update EyeSort menu state based on loaded datasets
function update_eyesort_menu_state()
    try
        % Get the main menu handle
        mainMenu = getappdata(0, 'EyeSort_MainMenu');
        if isempty(mainMenu) || ~ishandle(mainMenu)
            return;
        end
        
        % Find the Load Interest Areas menu
        loadIAMenu = findobj(mainMenu, 'Tag', 'EyeSort_LoadIA');
        if isempty(loadIAMenu)
            return;
        end
        
        % Check if datasets are loaded (either in ALLEEG or batch mode)
        hasDatasets = false;
        
        % First check for batch mode
        try
            batchMode = evalin('base', 'eyesort_batch_mode');
            batchFilePaths = evalin('base', 'eyesort_batch_file_paths');
            if ~isempty(batchMode) && batchMode && ~isempty(batchFilePaths) && length(batchFilePaths) >= 1
                hasDatasets = true;
            end
        catch
            % Batch mode variables don't exist, continue to check ALLEEG
        end
        
        % If not in batch mode, check ALLEEG for individual datasets
        if ~hasDatasets
            try
                ALLEEG = evalin('base', 'ALLEEG');
                if ~isempty(ALLEEG) && length(ALLEEG) >= 1
                    % Check if at least one dataset has actual data AND filename
                    for i = 1:length(ALLEEG)
                        if ~isempty(ALLEEG(i)) && isstruct(ALLEEG(i)) && ...
                           isfield(ALLEEG(i), 'data') && ~isempty(ALLEEG(i).data) && ...
                           isfield(ALLEEG(i), 'nbchan') && ALLEEG(i).nbchan > 0 && ...
                           isfield(ALLEEG(i), 'filename') && ~isempty(ALLEEG(i).filename) && ...
                           ~strcmp(ALLEEG(i).filename, '')
                            hasDatasets = true;
                            break;
                        end
                    end
                end
            catch
                % ALLEEG doesn't exist or can't be accessed
                hasDatasets = false;
            end
        end
        
        % Enable/disable Load Interest Areas menu based on dataset state
        if hasDatasets
            set(loadIAMenu, 'enable', 'on');
            % Enable text IA submenu
            textIAMenu = findobj(mainMenu, 'Tag', 'EyeSort_TextIA');
            if ~isempty(textIAMenu), set(textIAMenu, 'enable', 'on'); end
        else
            set(loadIAMenu, 'enable', 'off');
            % Disable text IA submenu
            textIAMenu = findobj(mainMenu, 'Tag', 'EyeSort_TextIA');
            if ~isempty(textIAMenu), set(textIAMenu, 'enable', 'off'); end
        end
        
        % Enable Inspect Parsed Regions only after Step 2 has been run
        inspectMenu = findobj(mainMenu, 'Tag', 'EyeSort_InspectRegions');
        if ~isempty(inspectMenu)
            hasProcessed = false;
            try
                EEG = evalin('base', 'EEG');
                if isfield(EEG, 'eyesort_processed') && EEG.eyesort_processed
                    hasProcessed = true;
                end
            catch
            end
            if ~hasProcessed
                try
                    ALLEEG = evalin('base', 'ALLEEG');
                    for i = 1:length(ALLEEG)
                        if isfield(ALLEEG(i), 'eyesort_processed') && ALLEEG(i).eyesort_processed
                            hasProcessed = true;
                            break;
                        end
                    end
                catch
                end
            end
            if hasProcessed
                set(inspectMenu, 'enable', 'on');
            else
                set(inspectMenu, 'enable', 'off');
            end
        end
        
    catch ME
        % Silently handle errors to avoid disrupting the plugin
        warning('EyeSort:MenuUpdate', 'Failed to update menu state: %s', ME.message);
    end
end
