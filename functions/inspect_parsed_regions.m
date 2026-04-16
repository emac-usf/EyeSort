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

function trialData = inspect_parsed_regions(EEG)
    %% INSPECT_PARSED_REGIONS - Extract unique trial region data from a processed EEG dataset
    %
    % Scans EEG.event to collect each unique condition x item trial and its
    % parsed region text and pixel boundaries. Uses the raw region text
    % (regionN_text) stored during Step 2 so the inspection matches exactly
    % what EyeSort uses for boundary calculations.
    %
    % USAGE:
    %   trialData = inspect_parsed_regions(EEG)
    %
    % INPUTS:
    %   EEG - EEGLAB EEG structure that has been processed with compute_text_based_ia
    %         (i.e., EEG.eyesort_processed == true)
    %
    % OUTPUTS:
    %   trialData - Struct array with fields:
    %       .condition   - Condition number for this trial
    %       .item        - Item number for this trial
    %       .regions     - 1 x numRegions cell array of region text strings
    %       .boundaries  - numRegions x 2 matrix of [start, end] pixel boundaries

    if ~isfield(EEG, 'eyesort_processed') || ~EEG.eyesort_processed
        error('inspect_parsed_regions:NotProcessed', ...
            'Dataset has not been processed with EyeSort Step 2 (Setup Interest Areas).');
    end

    if ~isfield(EEG, 'region_names') || isempty(EEG.region_names)
        error('inspect_parsed_regions:NoRegions', ...
            'No region names found in dataset. Run Step 2 first.');
    end

    numRegions = length(EEG.region_names);

    % Prefer raw text fields; fall back to reconstructed words for older datasets
    hasRawText = isfield(EEG.event, 'region1_text');
    if hasRawText
        textFields = arrayfun(@(r) sprintf('region%d_text', r), 1:numRegions, 'UniformOutput', false);
    else
        textFields = arrayfun(@(r) sprintf('region%d_words', r), 1:numRegions, 'UniformOutput', false);
    end
    startFields = arrayfun(@(r) sprintf('region%d_start', r), 1:numRegions, 'UniformOutput', false);
    endFields   = arrayfun(@(r) sprintf('region%d_end',   r), 1:numRegions, 'UniformOutput', false);

    seenKeys = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    trialData = struct('condition', {}, 'item', {}, 'regions', {}, 'boundaries', {});

    for iEvt = 1:length(EEG.event)
        evt = EEG.event(iEvt);

        cond = evt.condition_number;
        item = evt.item_number;

        if isequal(cond, 0) || isequal(item, 0) || isempty(cond) || isempty(item)
            continue;
        end

        key = sprintf('%d_%d', cond, item);
        if seenKeys.isKey(key)
            continue;
        end
        seenKeys(key) = true;

        regionTexts = cell(1, numRegions);
        bounds = zeros(numRegions, 2);

        for r = 1:numRegions
            % Region text
            if isfield(evt, textFields{r})
                val = evt.(textFields{r});
                if hasRawText
                    if ischar(val)
                        regionTexts{r} = val;
                    else
                        regionTexts{r} = '';
                    end
                else
                    if iscell(val)
                        regionTexts{r} = strtrim(strjoin(val, ''));
                    elseif ischar(val)
                        regionTexts{r} = strtrim(val);
                    else
                        regionTexts{r} = '';
                    end
                end
            else
                regionTexts{r} = '';
            end

            % Pixel boundaries
            if isfield(evt, startFields{r})
                bounds(r, 1) = evt.(startFields{r});
            end
            if isfield(evt, endFields{r})
                bounds(r, 2) = evt.(endFields{r});
            end
        end

        trialData(end+1) = struct('condition', cond, 'item', item, ...
            'regions', {regionTexts}, 'boundaries', bounds); %#ok<AGROW>
    end

    % Sort by condition, then item
    if length(trialData) > 1
        [~, sortIdx] = sortrows([[trialData.condition]', [trialData.item]']);
        trialData = trialData(sortIdx);
    end
end
