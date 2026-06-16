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

function EEG = import_ia_columns(EEG, txtFilePath, condColName, itemColName, selectedColumns, reportMode)
    %% IMPORT_IA_COLUMNS - Import selected columns from an IA text file into EEG.event
    %
    % Maps rows from the interest area text file to EEG events using
    % condition_number x item_number matching, then copies the selected
    % column values into new EEG.event fields.
    %
    % USAGE:
    %   EEG = import_ia_columns(EEG, txtFilePath, condColName, itemColName, selectedColumns)
    %
    % INPUTS:
    %   EEG             - EEGLAB EEG structure (must have eyesort_processed == true)
    %   txtFilePath     - Path to the tab-delimited interest area text file
    %   condColName     - Name of the condition number column in the text file
    %   itemColName     - Name of the item number column in the text file
    %   selectedColumns - Cell array of column names to import
    %
    % OUTPUTS:
    %   EEG - Modified EEG structure with new event fields for each imported column.
    %         Field names are made MATLAB-safe via matlab.lang.makeValidName.
    %         Also sets EEG.eyesort_imported_columns with the list of imported columns.

    if nargin < 6 || isempty(reportMode)
        reportMode = 'command';
    end

    if ~isfield(EEG, 'eyesort_processed') || ~EEG.eyesort_processed
        error('import_ia_columns:NotProcessed', ...
            'Dataset has not been processed with EyeSort Step 2.');
    end

    if ~exist(txtFilePath, 'file')
        error('import_ia_columns:FileNotFound', 'File not found: %s', txtFilePath);
    end

    if isempty(selectedColumns)
        warning('import_ia_columns:NoColumns', 'No columns selected for import.');
        return;
    end

    %% Read the IA text file
    opts = detectImportOptions(txtFilePath, 'Delimiter', '\t');
    opts.VariableNamingRule = 'preserve';
    data = readtable(txtFilePath, opts);

    if ~ismember(condColName, data.Properties.VariableNames)
        error('import_ia_columns:CondColNotFound', ...
            'Condition column "%s" not found in IA file. Available columns: %s', ...
            condColName, strjoin(data.Properties.VariableNames, ', '));
    end
    if ~ismember(itemColName, data.Properties.VariableNames)
        error('import_ia_columns:ItemColNotFound', ...
            'Item column "%s" not found in IA file. Available columns: %s', ...
            itemColName, strjoin(data.Properties.VariableNames, ', '));
    end

    % Validate that all requested columns exist
    for c = 1:length(selectedColumns)
        if ~ismember(selectedColumns{c}, data.Properties.VariableNames)
            error('import_ia_columns:ColNotFound', ...
                'Column "%s" not found in file. Available: %s', ...
                selectedColumns{c}, strjoin(data.Properties.VariableNames, ', '));
        end
    end

    %% Build lookup: "condition_item" -> row index
    rowMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
    invalidRows = 0;
    for iRow = 1:height(data)
        cond = data.(condColName)(iRow);
        item = data.(itemColName)(iRow);
        cond = normalize_numeric_value(cond);
        item = normalize_numeric_value(item);
        if isempty(cond) || isempty(item) || isnan(cond) || isnan(item)
            invalidRows = invalidRows + 1;
            continue;
        end
        key = sprintf('%d_%d', cond, item);
        rowMap(key) = iRow;
    end

    if rowMap.Count == 0
        error('import_ia_columns:NoValidRows', ...
            'No valid condition/item rows were found in the IA file using columns "%s" and "%s".', ...
            condColName, itemColName);
    end

    %% Initialize new event fields
    safeFieldNames = cell(size(selectedColumns));
    for c = 1:length(selectedColumns)
        safeFieldNames{c} = matlab.lang.makeValidName(selectedColumns{c});
        [EEG.event.(safeFieldNames{c})] = deal([]);
    end

    %% Assign column values to matching events
    assignedEvents = 0;
    validEventKeys = 0;
    invalidEventKeys = 0;
    missingKeyMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
    matchedKeyMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for iEvt = 1:length(EEG.event)
        cond = normalize_numeric_value(EEG.event(iEvt).condition_number);
        item = normalize_numeric_value(EEG.event(iEvt).item_number);

        if isempty(cond) || isempty(item) || isnan(cond) || isnan(item) || isequal(cond, 0) || isequal(item, 0)
            invalidEventKeys = invalidEventKeys + 1;
            continue;
        end

        key = sprintf('%d_%d', cond, item);
        validEventKeys = validEventKeys + 1;
        if ~rowMap.isKey(key)
            if isKey(missingKeyMap, key)
                missingKeyMap(key) = missingKeyMap(key) + 1;
            else
                missingKeyMap(key) = 1;
            end
            continue;
        end
        if isKey(matchedKeyMap, key)
            matchedKeyMap(key) = matchedKeyMap(key) + 1;
        else
            matchedKeyMap(key) = 1;
        end

        rowIdx = rowMap(key);
        for c = 1:length(selectedColumns)
            val = data.(selectedColumns{c})(rowIdx);
            if iscell(val), val = val{1}; end
            EEG.event(iEvt).(safeFieldNames{c}) = val;
        end
        assignedEvents = assignedEvents + 1;
    end

    %% Store metadata about imported columns
    if isfield(EEG, 'eyesort_imported_columns')
        EEG.eyesort_imported_columns = unique([EEG.eyesort_imported_columns, selectedColumns]);
    else
        EEG.eyesort_imported_columns = selectedColumns;
    end

    importDiagnostics = struct();
    importDiagnostics.selected_columns = selectedColumns;
    importDiagnostics.valid_text_rows = rowMap.Count;
    importDiagnostics.invalid_text_rows = invalidRows;
    importDiagnostics.invalid_event_keys = invalidEventKeys;
    importDiagnostics.valid_event_keys = validEventKeys;
    importDiagnostics.assigned_events = assignedEvents;
    importDiagnostics.matched_keys = sort(matchedKeyMap.keys);
    importDiagnostics.missing_keys = sort(missingKeyMap.keys);
    importDiagnostics.unused_text_keys = setdiff(sort(rowMap.keys), importDiagnostics.matched_keys);
    EEG.eyesort_import_diagnostics = importDiagnostics;

    diagnostics = import_column_diagnostics(importDiagnostics, condColName, itemColName);
    report_diagnostics(diagnostics, 'EyeSort IA Column Import Diagnostics', reportMode);

    fprintf('Imported %d column(s) into %d event(s).\n', length(selectedColumns), assignedEvents);
end

function value = normalize_numeric_value(inputValue)
    if iscell(inputValue)
        if isempty(inputValue)
            value = NaN;
            return;
        end
        inputValue = inputValue{1};
    end
    if isnumeric(inputValue)
        if isempty(inputValue)
            value = NaN;
        else
            value = double(inputValue);
        end
    elseif ischar(inputValue)
        value = str2double(inputValue);
    elseif isstring(inputValue)
        value = str2double(char(inputValue));
    else
        try
            value = str2double(char(inputValue));
        catch
            value = NaN;
        end
    end
    if isempty(value)
        value = NaN;
    end
end
