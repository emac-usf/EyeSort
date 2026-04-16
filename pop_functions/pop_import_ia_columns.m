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

function [EEG, com] = pop_import_ia_columns(EEG)
    %% POP_IMPORT_IA_COLUMNS - GUI for importing interest area text file columns into EEG events
    %
    % Allows the user to select columns from their interest area text file
    % and import them as new fields into EEG.event. Columns already used by
    % EyeSort processing (condition, item, and region columns) are excluded
    % from the selection list.
    %
    % The mapping uses condition_number x item_number from EEG.event to match
    % rows in the text file, so Step 2 must have been run first.
    %
    % Supports both single/multi-dataset mode (ALLEEG) and batch mode.
    % Works with intermediate datasets that have already been processed.
    %
    % USAGE:
    %   [EEG, com] = pop_import_ia_columns()
    %   [EEG, com] = pop_import_ia_columns(EEG)
    %
    % INPUTS:
    %   EEG - (optional) EEGLAB EEG structure
    %
    % OUTPUTS:
    %   EEG - Modified EEG structure(s) with imported columns
    %   com - EEGLAB history command string

    com = '';

    if nargin < 1
        try
            EEG = evalin('base', 'EEG');
        catch
            EEG = eeg_emptyset;
        end
    end

    %% Detect batch mode
    batch_mode = false;
    batchFilePaths = {};
    batchFilenames = {};
    try
        batch_mode = evalin('base', 'eyesort_batch_mode');
        if batch_mode
            batchFilePaths = evalin('base', 'eyesort_batch_file_paths');
            batchFilenames = evalin('base', 'eyesort_batch_filenames');
        end
    catch
    end

    %% Validate that at least one processed dataset exists
    hasProcessed = false;
    if batch_mode
        for k = 1:length(batchFilePaths)
            if exist(batchFilePaths{k}, 'file')
                hasProcessed = true;
                break;
            end
        end
    else
        try
            ALLEEG = evalin('base', 'ALLEEG');
            for k = 1:length(ALLEEG)
                if isfield(ALLEEG(k), 'eyesort_processed') && ALLEEG(k).eyesort_processed
                    hasProcessed = true;
                    break;
                end
            end
        catch
        end
    end

    if ~hasProcessed
        errordlg('No processed datasets found. Run Step 2 (Setup Interest Areas) first.', 'EyeSort');
        return;
    end

    %% Load config from Step 2 cache (required)
    cachedTxtFile = '';
    cachedCondCol = '';
    cachedItemCol = '';
    cachedRegionNames = {};

    % Get region names from current EEG
    if batch_mode
        try
            tempEEG = pop_loadset('filename', batchFilePaths{1});
            if isfield(tempEEG, 'region_names')
                cachedRegionNames = tempEEG.region_names;
            end
            clear tempEEG;
        catch
        end
    else
        if isfield(EEG, 'region_names')
            cachedRegionNames = EEG.region_names;
        end
    end

    plugin_dir = fileparts(fileparts(mfilename('fullpath')));
    configPath = fullfile(plugin_dir, 'cache', 'last_text_ia_config.mat');
    if ~exist(configPath, 'file')
        errordlg('No Step 2 configuration found. Run Step 2 (Setup Interest Areas) first.', 'EyeSort');
        return;
    end

    try
        loaded = load(configPath);
        if isfield(loaded, 'config')
            cfg = loaded.config;
            if isfield(cfg, 'txtFileList')
                if iscell(cfg.txtFileList)
                    cachedTxtFile = cfg.txtFileList{1};
                else
                    cachedTxtFile = cfg.txtFileList;
                end
            end
            if isfield(cfg, 'conditionColName')
                cachedCondCol = cfg.conditionColName;
            end
            if isfield(cfg, 'itemColName')
                cachedItemCol = cfg.itemColName;
            end
            if isfield(cfg, 'regionNames') && isempty(cachedRegionNames)
                if ischar(cfg.regionNames)
                    cachedRegionNames = strtrim(strsplit(cfg.regionNames, ','));
                else
                    cachedRegionNames = cfg.regionNames;
                end
            end
        end
    catch ME
        errordlg(sprintf('Failed to load Step 2 configuration: %s', ME.message), 'EyeSort');
        return;
    end

    if isempty(cachedCondCol) || isempty(cachedItemCol)
        errordlg('Step 2 configuration is missing condition or item column names. Re-run Step 2.', 'EyeSort');
        return;
    end

    %% Build GUI
    screenSize = get(0, 'ScreenSize');
    figWidth = 600;
    figHeight = 420;
    figLeft = (screenSize(3) - figWidth) / 2;
    figBottom = (screenSize(4) - figHeight) / 2;

    fig = figure('Name', 'EyeSort - Import IA Columns to Events', ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [figLeft, figBottom, figWidth, figHeight], ...
        'Resize', 'off', 'WindowStyle', 'modal');

    yPos = figHeight - 40;

    % --- File path (read-only, from Step 2 config) ---
    uicontrol(fig, 'Style', 'text', 'String', 'Interest Area Text File:', ...
        'Position', [15, yPos, 200, 20], 'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    yPos = yPos - 28;
    hFilePath = uicontrol(fig, 'Style', 'edit', 'String', cachedTxtFile, ...
        'Position', [15, yPos, 470, 25], 'HorizontalAlignment', 'left', 'Tag', 'filePath');
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Browse', ...
        'Position', [495, yPos, 90, 25], 'Callback', @browseFile);

    % --- Condition column (read-only label from Step 2) ---
    yPos = yPos - 25;
    uicontrol(fig, 'Style', 'text', 'String', 'Condition Column:', ...
        'Position', [15, yPos, 150, 20], 'HorizontalAlignment', 'left');
    uicontrol(fig, 'Style', 'text', 'String', cachedCondCol, ...
        'Position', [170, yPos, 250, 20], 'HorizontalAlignment', 'left', 'FontWeight', 'bold');

    % --- Item column (read-only label from Step 2) ---
    yPos = yPos - 25;
    uicontrol(fig, 'Style', 'text', 'String', 'Item Column:', ...
        'Position', [15, yPos, 150, 20], 'HorizontalAlignment', 'left');
    uicontrol(fig, 'Style', 'text', 'String', cachedItemCol, ...
        'Position', [170, yPos, 250, 20], 'HorizontalAlignment', 'left', 'FontWeight', 'bold');

    % --- Available columns for import ---
    yPos = yPos - 30;
    uicontrol(fig, 'Style', 'text', 'String', 'Select columns to import (Ctrl/Cmd+click for multiple):', ...
        'Position', [15, yPos, 570, 20], 'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    yPos = yPos - 200;
    hColList = uicontrol(fig, 'Style', 'listbox', 'String', {'(loading...)'}, ...
        'Position', [15, yPos, 570, 200], 'Max', 100, 'Min', 0, 'Tag', 'colList');

    % --- Confirm / Cancel ---
    yPos = yPos - 40;
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Cancel', ...
        'Position', [figWidth - 200, yPos, 85, 30], 'Callback', @(~,~) close(fig));
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Confirm', ...
        'Position', [figWidth - 100, yPos, 85, 30], 'FontWeight', 'bold', ...
        'Callback', @confirmImport);

    % Store state in figure appdata
    setappdata(fig, 'allColumns', {});
    setappdata(fig, 'regionNames', cachedRegionNames);
    setappdata(fig, 'batch_mode', batch_mode);
    setappdata(fig, 'batchFilePaths', batchFilePaths);
    setappdata(fig, 'batchFilenames', batchFilenames);

    % Auto-load columns from the file
    filePath = strtrim(get(hFilePath, 'String'));
    if ~isempty(filePath) && exist(filePath, 'file')
        loadColumnsFromFile(fig, filePath);
    end

    % Wait for GUI to close
    uiwait(fig);

    % Return updated EEG from base workspace
    if ~batch_mode
        try
            EEG = evalin('base', 'EEG');
        catch
        end
    end
    com = 'pop_import_ia_columns();';

    %% --- Nested callback functions ---

    function browseFile(~, ~)
        [fname, fpath] = uigetfile({'*.txt', 'Text Files (*.txt)'; '*.*', 'All Files'}, ...
            'Select Interest Area Text File');
        if isequal(fname, 0), return; end
        fullPath = fullfile(fpath, fname);
        set(hFilePath, 'String', fullPath);
        loadColumnsFromFile(fig, fullPath);
    end

    function loadColumnsFromFile(figHandle, fPath)
        try
            opts = detectImportOptions(fPath, 'Delimiter', '\t');
            opts.VariableNamingRule = 'preserve';
            allCols = opts.VariableNames;
        catch ME
            errordlg(sprintf('Failed to read file: %s', ME.message), 'EyeSort');
            return;
        end

        setappdata(figHandle, 'allColumns', allCols);
        updateAvailableColumns(figHandle);
    end

    function updateAvailableColumns(figHandle)
        allCols = getappdata(figHandle, 'allColumns');
        regionNms = getappdata(figHandle, 'regionNames');

        if isempty(allCols), return; end

        excludeCols = {cachedCondCol, cachedItemCol};
        for r = 1:length(regionNms)
            excludeCols{end+1} = regionNms{r}; %#ok<AGROW>
        end

        availCols = {};
        for c = 1:length(allCols)
            excluded = false;
            for e = 1:length(excludeCols)
                if strcmpi(allCols{c}, excludeCols{e})
                    excluded = true;
                    break;
                end
            end
            if ~excluded
                availCols{end+1} = allCols{c}; %#ok<AGROW>
            end
        end

        if isempty(availCols)
            availCols = {'(no additional columns available)'};
        end

        set(hColList, 'String', availCols, 'Value', []);
    end

    function confirmImport(~, ~)
        allCols = getappdata(fig, 'allColumns');
        if isempty(allCols)
            errordlg('No columns loaded. Check that the file path is valid.', 'EyeSort');
            return;
        end

        importFilePath = strtrim(get(hFilePath, 'String'));

        colListStr = get(hColList, 'String');
        colListVal = get(hColList, 'Value');

        if isempty(colListVal) || (length(colListStr) == 1 && strcmp(colListStr{1}, '(no additional columns available)'))
            errordlg('Please select at least one column to import.', 'EyeSort');
            return;
        end

        selectedCols = colListStr(colListVal);

        isBatch = getappdata(fig, 'batch_mode');
        bPaths = getappdata(fig, 'batchFilePaths');
        bNames = getappdata(fig, 'batchFilenames');

        close(fig);

        if isBatch
            importBatch(importFilePath, cachedCondCol, cachedItemCol, selectedCols, bPaths, bNames);
        else
            importALLEEG(importFilePath, cachedCondCol, cachedItemCol, selectedCols);
        end
    end

    function importALLEEG(filePath, condColName, itemColName, selectedCols)
        try
            localALLEEG = evalin('base', 'ALLEEG');
        catch
            errordlg('No datasets found in workspace.', 'EyeSort');
            return;
        end

        modifiedCount = 0;
        for i = 1:length(localALLEEG)
            if isfield(localALLEEG(i), 'eyesort_processed') && localALLEEG(i).eyesort_processed
                try
                    localALLEEG(i) = import_ia_columns(localALLEEG(i), filePath, condColName, itemColName, selectedCols);
                    modifiedCount = modifiedCount + 1;
                catch ME
                    warning('Failed to import columns for dataset %d (%s): %s', ...
                        i, localALLEEG(i).filename, ME.message);
                end
            end
        end

        % Update base workspace
        assignin('base', 'ALLEEG', localALLEEG);
        assignin('base', 'EEG', localALLEEG(end));
        try
            eeglab('redraw');
        catch
        end

        msgbox(sprintf('Successfully imported %d column(s) into %d dataset(s).', ...
            length(selectedCols), modifiedCount), 'EyeSort - Import Complete');
    end

    function importBatch(filePath, condColName, itemColName, selectedCols, bPaths, bNames)
        h = waitbar(0, 'Importing columns into batch datasets...', 'Name', 'EyeSort - Import');
        successCount = 0;

        for i = 1:length(bPaths)
            waitbar(i / length(bPaths), h, sprintf('Processing %d of %d: %s', ...
                i, length(bPaths), strrep(bNames{i}, '_', ' ')));

            if ~exist(bPaths{i}, 'file')
                warning('File not found, skipping: %s', bPaths{i});
                continue;
            end

            try
                batchEEG = pop_loadset('filename', bPaths{i});

                if ~isfield(batchEEG, 'eyesort_processed') || ~batchEEG.eyesort_processed
                    warning('Dataset not processed, skipping: %s', bNames{i});
                    continue;
                end

                batchEEG = import_ia_columns(batchEEG, filePath, condColName, itemColName, selectedCols);

                % Save back to the same path
                pop_saveset(batchEEG, 'filename', bPaths{i}, 'savemode', 'twofiles');
                successCount = successCount + 1;

                clear batchEEG;
            catch ME
                warning('Failed to process %s: %s', bNames{i}, ME.message);
            end
        end

        delete(h);
        msgbox(sprintf('Successfully imported %d column(s) into %d of %d batch dataset(s).', ...
            length(selectedCols), successCount, length(bPaths)), 'EyeSort - Import Complete');
    end
end
