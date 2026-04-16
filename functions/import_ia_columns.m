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

function EEG = import_ia_columns(EEG, txtFilePath, condColName, itemColName, selectedColumns)
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
    for iRow = 1:height(data)
        cond = data.(condColName)(iRow);
        item = data.(itemColName)(iRow);
        if iscell(cond), cond = cond{1}; end
        if iscell(item), item = item{1}; end
        if ischar(cond), cond = str2double(cond); end
        if ischar(item), item = str2double(item); end
        key = sprintf('%d_%d', cond, item);
        rowMap(key) = iRow;
    end

    %% Initialize new event fields
    safeFieldNames = cell(size(selectedColumns));
    for c = 1:length(selectedColumns)
        safeFieldNames{c} = matlab.lang.makeValidName(selectedColumns{c});
        [EEG.event.(safeFieldNames{c})] = deal([]);
    end

    %% Assign column values to matching events
    assignedEvents = 0;
    for iEvt = 1:length(EEG.event)
        cond = EEG.event(iEvt).condition_number;
        item = EEG.event(iEvt).item_number;

        if isequal(cond, 0) || isequal(item, 0) || isempty(cond) || isempty(item)
            continue;
        end

        key = sprintf('%d_%d', cond, item);
        if ~rowMap.isKey(key)
            continue;
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

    fprintf('Imported %d column(s) into %d event(s).\n', length(selectedColumns), assignedEvents);
end
