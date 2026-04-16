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

function [EEG, com] = pop_inspect_regions(EEG)
    %% POP_INSPECT_REGIONS - GUI for validating parsed sentence regions
    %
    % Displays a scrollable table showing how each trial's sentence was parsed
    % into regions by Step 2 (Setup Interest Areas). Allows the user to verify
    % that region boundaries and text content are correct before proceeding
    % to labeling.
    %
    % Supports both single/multi-dataset mode (ALLEEG) and batch mode.
    % Also works with intermediate datasets that have already been processed.
    %
    % USAGE:
    %   [EEG, com] = pop_inspect_regions()
    %   [EEG, com] = pop_inspect_regions(EEG)
    %
    % INPUTS:
    %   EEG - (optional) EEGLAB EEG structure. If not provided, retrieves
    %         from the base workspace.
    %
    % OUTPUTS:
    %   EEG - Unchanged EEG structure (read-only operation)
    %   com - EEGLAB history command string

    com = '';

    if nargin < 1
        try
            EEG = evalin('base', 'EEG');
        catch
            EEG = eeg_emptyset;
        end
    end

    %% Determine mode and collect available datasets
    batch_mode = false;
    try
        batch_mode = evalin('base', 'eyesort_batch_mode');
    catch
    end

    datasetNames = {};
    datasetSources = {};  % file paths (batch) or ALLEEG indices

    if batch_mode
        batchFilePaths = evalin('base', 'eyesort_batch_file_paths');
        batchFilenames = evalin('base', 'eyesort_batch_filenames');

        for i = 1:length(batchFilePaths)
            if exist(batchFilePaths{i}, 'file')
                datasetNames{end+1} = batchFilenames{i}; %#ok<AGROW>
                datasetSources{end+1} = batchFilePaths{i}; %#ok<AGROW>
            end
        end

        if isempty(datasetNames)
            errordlg('No processed batch datasets found. Run Step 2 (Setup Interest Areas) first.', 'EyeSort');
            return;
        end
    else
        try
            ALLEEG = evalin('base', 'ALLEEG');
        catch
            errordlg('No datasets loaded. Use Step 1 to load datasets first.', 'EyeSort');
            return;
        end

        for i = 1:length(ALLEEG)
            if isfield(ALLEEG(i), 'eyesort_processed') && ALLEEG(i).eyesort_processed
                label = sprintf('%d: %s', i, ALLEEG(i).filename);
                datasetNames{end+1} = label; %#ok<AGROW>
                datasetSources{end+1} = i; %#ok<AGROW>
            end
        end

        if isempty(datasetNames)
            errordlg('No processed datasets found. Run Step 2 (Setup Interest Areas) first.', 'EyeSort');
            return;
        end
    end

    %% Dataset selection (skip if only one)
    if length(datasetNames) == 1
        selectedIdx = 1;
    else
        [selectedIdx, ok] = listdlg('ListString', datasetNames, ...
            'SelectionMode', 'single', 'Name', 'EyeSort - Select Dataset', ...
            'PromptString', 'Select a dataset to inspect:', ...
            'ListSize', [400, 300]);
        if ~ok, return; end
    end

    %% Load the selected dataset
    if batch_mode
        try
            inspectEEG = pop_loadset('filename', datasetSources{selectedIdx});
        catch ME
            errordlg(sprintf('Failed to load dataset: %s', ME.message), 'EyeSort');
            return;
        end
    else
        inspectEEG = ALLEEG(datasetSources{selectedIdx});
    end

    %% Validate and extract trial data
    if ~isfield(inspectEEG, 'eyesort_processed') || ~inspectEEG.eyesort_processed
        errordlg('Selected dataset has not been processed with Step 2.', 'EyeSort');
        return;
    end

    trialData = inspect_parsed_regions(inspectEEG);

    if isempty(trialData)
        errordlg('No trial data found in the selected dataset.', 'EyeSort');
        return;
    end

    %% Build and display the inspection GUI
    regionNames = inspectEEG.region_names;
    numRegions = length(regionNames);
    numTrials = length(trialData);

    % Each region gets two columns: text content and pixel boundaries
    numCols = 2 + numRegions * 2;
    tableData = cell(numTrials, numCols);
    for t = 1:numTrials
        tableData{t, 1} = trialData(t).condition;
        tableData{t, 2} = trialData(t).item;
        for r = 1:numRegions
            col_text = 2 + (r - 1) * 2 + 1;
            col_bounds = col_text + 1;
            tableData{t, col_text} = ['"' trialData(t).regions{r} '"'];
            tableData{t, col_bounds} = sprintf('[%g, %g]', ...
                trialData(t).boundaries(r, 1), trialData(t).boundaries(r, 2));
        end
    end

    % Build column headers: Region Name, then Region Name (px)
    colNames = {'Condition', 'Item'};
    for r = 1:numRegions
        colNames{end+1} = regionNames{r}; %#ok<AGROW>
        colNames{end+1} = [regionNames{r} ' (px)']; %#ok<AGROW>
    end

    % Determine figure size
    screenSize = get(0, 'ScreenSize');
    figWidth = min(1400, screenSize(3) * 0.8);
    figHeight = min(700, screenSize(4) * 0.7);
    figLeft = (screenSize(3) - figWidth) / 2;
    figBottom = (screenSize(4) - figHeight) / 2;

    datasetLabel = datasetNames{selectedIdx};

    fig = figure('Name', 'EyeSort - Inspect Parsed Regions', ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [figLeft, figBottom, figWidth, figHeight], ...
        'Resize', 'on');

    % Header info
    uicontrol('Parent', fig, 'Style', 'text', ...
        'String', sprintf('Dataset: %s   |   %d unique trials   |   %d regions', ...
            strrep(datasetLabel, '_', '\_'), numTrials, numRegions), ...
        'Units', 'normalized', 'Position', [0.02 0.93 0.96 0.05], ...
        'HorizontalAlignment', 'left', 'FontWeight', 'bold', 'FontSize', 11);

    % Column widths: narrow for Condition/Item/px, wider for text
    textColWidth = round((figWidth - 250 - numRegions * 110) / numRegions);
    textColWidth = max(textColWidth, 120);
    colWidths = {70, 50};
    for r = 1:numRegions
        colWidths{end+1} = textColWidth; %#ok<AGROW>
        colWidths{end+1} = 110; %#ok<AGROW>
    end

    % Region inspection table
    uitable('Parent', fig, 'Data', tableData, 'ColumnName', colNames, ...
        'Units', 'normalized', 'Position', [0.02 0.08 0.96 0.84], ...
        'ColumnEditable', false(1, numCols), ...
        'ColumnWidth', colWidths, ...
        'RowName', 'numbered');

    % Export button
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Export to File', ...
        'Units', 'normalized', 'Position', [0.02 0.01 0.15 0.05], ...
        'Callback', @(~,~) exportTable(tableData, colNames));

    % Close button
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Close', ...
        'Units', 'normalized', 'Position', [0.85 0.01 0.13 0.05], ...
        'Callback', @(~,~) close(fig));

    com = 'pop_inspect_regions();';
end

function exportTable(tableData, colNames)
    [fname, fpath] = uiputfile({'*.csv', 'CSV File (*.csv)'; '*.txt', 'Tab-Delimited (*.txt)'}, ...
        'Export Parsed Regions');
    if isequal(fname, 0), return; end
    fullPath = fullfile(fpath, fname);

    fid = fopen(fullPath, 'w');
    if fid == -1
        errordlg('Could not open file for writing.', 'EyeSort');
        return;
    end

    % Determine delimiter from extension
    [~, ~, ext] = fileparts(fname);
    if strcmpi(ext, '.txt')
        delim = '\t';
    else
        delim = ',';
    end

    % Header
    fprintf(fid, ['%s' delim], colNames{1:end-1});
    fprintf(fid, '%s\n', colNames{end});

    % Rows
    isCSV = strcmp(delim, ',');
    for row = 1:size(tableData, 1)
        for col = 1:size(tableData, 2)
            val = tableData{row, col};
            if isnumeric(val)
                fprintf(fid, '%g', val);
            elseif isCSV
                escaped = strrep(val, '"', '""');
                fprintf(fid, '"%s"', escaped);
            else
                fprintf(fid, '%s', val);
            end
            if col < size(tableData, 2)
                fprintf(fid, delim);
            end
        end
        fprintf(fid, '\n');
    end

    fclose(fid);
    msgbox(sprintf('Exported to: %s', fullPath), 'EyeSort - Export Complete');
end
