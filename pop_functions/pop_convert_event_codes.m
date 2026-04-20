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

function [EEG, com] = pop_convert_event_codes(EEG)
% POP_CONVERT_EVENT_CODES - GUI for converting EEG.event.type format
%
% Allows the user to switch between different event marker formats for
% events that have already been labeled by EyeSort. The canonical CCRRLL
% code stored in eyesort_full_code is never modified.
%
% In single-dataset mode, operates on the EEG argument (or base workspace
% EEG). In batch mode (after pop_label_datasets has processed multiple
% datasets), operates on every *_processed.set file found in the batch
% output directory.
%
% Usage:
%   [EEG, com] = pop_convert_event_codes(EEG)

com = '';

% Detect whether we should run in batch mode by looking for an output
% directory left behind by pop_label_datasets.
batchDir = '';
try
    candidate = evalin('base', 'eyesort_batch_output_dir');
    if ischar(candidate) && ~isempty(candidate) && exist(candidate, 'dir')
        batchDir = candidate;
    end
catch
end

if isempty(batchDir)
    try
        candidate = evalin('base', 'eyesort_single_output_dir');
        if ischar(candidate) && ~isempty(candidate) && exist(candidate, 'dir')
            batchDir = candidate;
        end
    catch
    end
end

% Find labeled .set files in the batch directory (if any).
batchFiles = {};
if ~isempty(batchDir)
    listing = dir(fullfile(batchDir, '*_processed.set'));
    if isempty(listing)
        listing = dir(fullfile(batchDir, '*_labeled.set'));
    end
    for fi = 1:length(listing)
        batchFiles{end+1} = fullfile(listing(fi).folder, listing(fi).name); %#ok<AGROW>
    end
end

batchMode = ~isempty(batchFiles);

% Acquire a sample EEG: in batch mode, load just the first file (without
% touching the base workspace). In single mode, use the provided arg or
% pull from base.
sampleEEG = [];
if batchMode
    fprintf('Convert Event Codes: batch mode detected (%d dataset(s) in %s)\n', ...
        length(batchFiles), batchDir);
    try
        sampleEEG = pop_loadset(batchFiles{1});
    catch ME
        errordlg(sprintf('Failed to load %s: %s', batchFiles{1}, ME.message), ...
            'Convert Event Codes');
        return;
    end
else
    if nargin < 1 || isempty(EEG)
        try
            EEG = evalin('base', 'EEG'); %#ok<NASGU> used in nested on_apply
        catch
            errordlg('No EEG dataset available.', 'Convert Event Codes');
            return;
        end
    end
    sampleEEG = EEG;
end

if isempty(sampleEEG) || ~isfield(sampleEEG, 'event') || isempty(sampleEEG.event)
    errordlg('EEG dataset has no events.', 'Convert Event Codes');
    return;
end

if ~isfield(sampleEEG.event, 'eyesort_full_code')
    errordlg(['No labeled events found (eyesort_full_code field missing). ', ...
              'Please run EyeSort labeling first.'], 'Convert Event Codes');
    return;
end

formatLabels = { ...
    'Numeric code (CCRRLL) - ERPLAB compatible', ...
    'Condition and label description', ...
    'Condition, label, and fixated word', ...
    'Region text content', ...
    'Revert to original event codes'};
formatValues = {'numeric', 'description', 'description_word', 'region_content', 'original'};

currentFormat = 'numeric';
if isfield(sampleEEG, 'eyesort_event_format') && ischar(sampleEEG.eyesort_event_format)
    currentFormat = sampleEEG.eyesort_event_format;
end
currentIdx = find(strcmp(formatValues, currentFormat), 1);
if isempty(currentIdx), currentIdx = 1; end

previewEvent = [];
for i = 1:length(sampleEEG.event)
    if isfield(sampleEEG.event(i), 'eyesort_full_code') && ...
       ischar(sampleEEG.event(i).eyesort_full_code) && ~isempty(sampleEEG.event(i).eyesort_full_code)
        previewEvent = sampleEEG.event(i);
        break;
    end
end

previewStrings = cell(1, length(formatValues));
for fi = 1:length(formatValues)
    previewStrings{fi} = build_preview(previewEvent, formatValues{fi});
end

% Build mode description first so we can size the dialog to fit it.
if batchMode
    modeStr = sprintf('Batch mode: will rewrite event types in %d dataset file(s) in:\n%s', ...
        length(batchFiles), batchDir);
    modeRowH = 50;
else
    modeStr = ['Single dataset mode: will rewrite EEG.event.type for the current dataset. ', ...
               'The internal CCRRLL code (eyesort_full_code) is always preserved.'];
    modeRowH = 60;
end

% Layout constants
pad        = 15;
dlgW       = 560;
titleH     = 28;
modeGapTop = 6;
popupH     = 28;
popupGap   = 12;
labelH     = 22;
previewH   = 44;
btnH       = 32;
btnRowH    = btnH + 25;

dlgH = pad + titleH + modeGapTop + modeRowH + popupGap + popupH + ...
       popupGap + labelH + 4 + previewH + btnRowH + pad;

screenSize = get(0, 'ScreenSize');
dlgX = (screenSize(3) - dlgW) / 2;
dlgY = (screenSize(4) - dlgH) / 2;

hDlg = figure('Name', 'Modify Event Marker Format', ...
    'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
    'Resize', 'off', 'Position', [dlgX dlgY dlgW dlgH], ...
    'WindowStyle', 'modal', 'CloseRequestFcn', @on_cancel);

y = dlgH - pad - titleH;
uicontrol(hDlg, 'Style', 'text', ...
    'String', 'Select Event Marker Format:', ...
    'FontWeight', 'bold', 'FontSize', 11, ...
    'Position', [pad y dlgW-2*pad titleH], ...
    'HorizontalAlignment', 'left');

y = y - modeGapTop - modeRowH;
uicontrol(hDlg, 'Style', 'text', ...
    'String', modeStr, ...
    'FontSize', 9, ...
    'Position', [pad y dlgW-2*pad modeRowH], ...
    'HorizontalAlignment', 'left');

y = y - popupGap - popupH;
hPopup = uicontrol(hDlg, 'Style', 'popupmenu', ...
    'String', formatLabels, 'Value', currentIdx, ...
    'FontSize', 10, ...
    'Position', [pad y dlgW-2*pad popupH], ...
    'Callback', @on_format_change);

y = y - popupGap - labelH;
uicontrol(hDlg, 'Style', 'text', ...
    'String', 'Preview (first labeled event):', ...
    'FontWeight', 'bold', 'FontSize', 10, ...
    'Position', [pad y dlgW-2*pad labelH], ...
    'HorizontalAlignment', 'left');

y = y - 4 - previewH;
hPreview = uicontrol(hDlg, 'Style', 'text', ...
    'String', previewStrings{currentIdx}, ...
    'FontSize', 10, 'ForegroundColor', [0.1 0.3 0.6], ...
    'Position', [pad y dlgW-2*pad previewH], ...
    'HorizontalAlignment', 'left');

btnW = 120;
btnY = pad;
uicontrol(hDlg, 'Style', 'pushbutton', 'String', 'Apply', ...
    'FontSize', 10, 'Position', [dlgW/2 - btnW - 10 btnY btnW btnH], ...
    'Callback', @on_apply);
uicontrol(hDlg, 'Style', 'pushbutton', 'String', 'Cancel', ...
    'FontSize', 10, 'Position', [dlgW/2 + 10 btnY btnW btnH], ...
    'Callback', @on_cancel);

uiwait(hDlg);

    function on_format_change(~, ~)
        idx = get(hPopup, 'Value');
        set(hPreview, 'String', previewStrings{idx});
    end

    function on_apply(~, ~)
        idx = get(hPopup, 'Value');
        selectedFormat = formatValues{idx};
        if ishandle(hDlg), delete(hDlg); end

        if batchMode
            apply_batch(batchFiles, selectedFormat);
            com = sprintf('%% pop_convert_event_codes batch: %d file(s) -> %s', ...
                length(batchFiles), selectedFormat);
            msgbox(sprintf('Converted %d dataset(s) to ''%s'' format.', ...
                length(batchFiles), selectedFormat), ...
                'Conversion Complete', 'help');
        else
            EEG = convert_event_codes(EEG, selectedFormat);
            com = sprintf('EEG = convert_event_codes(EEG, ''%s'');', selectedFormat);
            assignin('base', 'EEG', EEG);
            msgbox(sprintf('Event codes converted to ''%s'' format.', selectedFormat), ...
                'Conversion Complete', 'help');
        end
    end

    function on_cancel(~, ~)
        if ishandle(hDlg), delete(hDlg); end
    end
end

%% Apply conversion to a list of dataset files, saving each in place.
function apply_batch(files, fmt)
    nFiles = length(files);
    fprintf('Converting event codes in %d dataset(s) to format ''%s''...\n', nFiles, fmt);
    h = waitbar(0, 'Converting event codes...', 'Name', 'Convert Event Codes');
    cleanup = onCleanup(@() safe_delete(h));

    for i = 1:nFiles
        [folder, name, ext] = fileparts(files{i});
        fname = [name ext];
        try
            waitbar((i-1)/nFiles, h, sprintf('Loading %s...', fname));
            tmp = pop_loadset('filename', fname, 'filepath', folder);

            if ~isfield(tmp, 'event') || isempty(tmp.event) || ...
               ~isfield(tmp.event, 'eyesort_full_code')
                fprintf('  Skipping %s: not labeled by EyeSort.\n', fname);
                continue;
            end

            waitbar((i-0.5)/nFiles, h, sprintf('Converting %s...', fname));
            tmp = convert_event_codes(tmp, fmt);

            waitbar((i-0.25)/nFiles, h, sprintf('Saving %s...', fname));
            pop_saveset(tmp, 'filename', fname, 'filepath', folder, 'savemode', 'twofiles');
            fprintf('  Converted %d/%d: %s\n', i, nFiles, fname);
        catch ME
            warning('Failed to convert %s: %s', fname, ME.message);
        end
        clear tmp;
    end
    fprintf('Batch conversion complete.\n');
end

function safe_delete(h)
    if ishandle(h), delete(h); end
end

%% Build a human-readable preview string for the given format
function str = build_preview(evt, fmt)
    if isempty(evt)
        str = '(no labeled events to preview)';
        return;
    end
    switch fmt
        case 'numeric'
            str = evt.eyesort_full_code;
        case 'description'
            if isfield(evt, 'bdf_full_description') && ~isempty(evt.bdf_full_description)
                str = evt.bdf_full_description;
            else
                str = [evt.eyesort_full_code ' (no description available)'];
            end
        case 'description_word'
            desc = '';
            if isfield(evt, 'bdf_full_description') && ~isempty(evt.bdf_full_description)
                desc = evt.bdf_full_description;
            end
            word = '';
            if isfield(evt, 'current_word_text') && ~isempty(evt.current_word_text)
                word = evt.current_word_text;
            end
            if ~isempty(desc) && ~isempty(word)
                str = [desc ' ' word];
            elseif ~isempty(desc)
                str = desc;
            else
                str = [evt.eyesort_full_code ' (no description available)'];
            end
        case 'region_content'
            str = '';
            if isfield(evt, 'current_word') && ischar(evt.current_word) && ~isempty(evt.current_word)
                try
                    [regionNum, ~] = parse_word_region(evt.current_word);
                    textField = sprintf('region%d_text', regionNum);
                    if isfield(evt, textField) && ischar(evt.(textField)) && ~isempty(evt.(textField))
                        str = strtrim(evt.(textField));
                    end
                catch
                end
            end
            if isempty(str)
                str = [evt.eyesort_full_code ' (no region text available)'];
            end
        case 'original'
            if isfield(evt, 'original_type') && ~isempty(evt.original_type)
                str = evt.original_type;
            else
                str = '(original type not available)';
            end
    end
    str = ['type = ''' str ''''];
end
