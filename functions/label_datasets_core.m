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

function [labeledEEG, com, chosenConflictResolution] = label_datasets_core(EEG, varargin)
% LABEL_DATASETS_CORE - Core labeling function for EEG datasets
%
% Usage:
%   Method 1 - Using config file:
%   [labeledEEG, com] = label_datasets_core(EEG, configFilePath)
%   [labeledEEG, com] = label_datasets_core(EEG, 'config_file', configFilePath)
%
%   Method 2 - Using individual parameters:
%   [labeledEEG, com] = label_datasets_core(EEG, 'param', value, ...)
%
% Required Input:
%   EEG - EEGLAB dataset structure
%
% For config file method:
%   configFilePath - Path to .m config file containing label parameters
%
% For individual parameters method (name-value pairs):
%   'timeLockedRegions'    - Cell array of region names to label on
%   'passOptions'          - Array of pass type options (1=any, 2=first, 3=second, 4=third+)
%   'prevRegions'          - Cell array of previous region names
%   'nextRegions'          - Cell array of next region names  
%   'fixationOptions'      - Array of fixation type options (1=any, 2=first, 3=single, 4=second, 5=subsequent, 6=last)
%   'saccadeInOptions'     - Array of saccade in direction options (1=any, 2=forward, 3=backward)
%   'saccadeOutOptions'    - Array of saccade out direction options (1=any, 2=forward, 3=backward)
%   'conditions'           - Array of condition numbers to include
%   'items'                - Array of item numbers to include
%   'labelCount'          - Label number (auto-incremented if not provided)
%
% Outputs:
%   labeledEEG - Labeled EEG dataset
%   com         - Command string for EEGLAB history

% Initialize output
com = '';
chosenConflictResolution = '';

% Check if first argument is a config file
if ~isempty(varargin) && ischar(varargin{1}) && (endsWith(varargin{1}, '.m') || endsWith(varargin{1}, '.mat')) && exist(varargin{1}, 'file')
    % Config file method
    config_file = varargin{1};
    config = load_eyesort_config(config_file);
    
    % Extract parameters from config
    timeLockedRegions = get_config_value(config, 'timeLockedRegions', []);
    % Map GUI field name to expected parameter name
    if isempty(timeLockedRegions)
        timeLockedRegions = get_config_value(config, 'selectedRegions', []);
    end
    
    % Check if labeling is enabled AFTER field mapping
    if isempty(timeLockedRegions)
        % No labeling requested
        labeledEEG = EEG;
        com = '';
        fprintf('No time_locked_regions specified in config - skipping labeling\n');
        return;
    end
    
    passOptions = get_config_value(config, 'passOptions', 1);
    % Map GUI pass fields to passOptions array
    if isempty(passOptions) || passOptions == 1
        passArray = [];
        if get_config_value(config, 'passFirstPass', 0), passArray(end+1) = 2; end
        if get_config_value(config, 'passSecondPass', 0), passArray(end+1) = 3; end
        if get_config_value(config, 'passThirdBeyond', 0), passArray(end+1) = 4; end
        if ~isempty(passArray), passOptions = passArray; end
    end
    
    prevRegions = get_config_value(config, 'prevRegions', {});
    if isempty(prevRegions)
        prevRegions = get_config_value(config, 'selectedPrevRegions', {});
    end
    
    nextRegions = get_config_value(config, 'nextRegions', {});
    if isempty(nextRegions)
        nextRegions = get_config_value(config, 'selectedNextRegions', {});
    end
    
    fixationOptions = get_config_value(config, 'fixationOptions', 1);
    % Map GUI fixation fields to fixationOptions array  
    if isempty(fixationOptions) || fixationOptions == 1
        fixArray = [];
        if get_config_value(config, 'fixFirstInRegion', 0), fixArray(end+1) = 2; end
        if get_config_value(config, 'fixSingleFixation', 0), fixArray(end+1) = 3; end
        if get_config_value(config, 'fixSecondMulti', 0), fixArray(end+1) = 4; end
        if get_config_value(config, 'fixAllSubsequent', 0), fixArray(end+1) = 5; end
        if get_config_value(config, 'fixLastInRegion', 0), fixArray(end+1) = 6; end
        if ~isempty(fixArray), fixationOptions = fixArray; end
    end
    
    saccadeInOptions = get_config_value(config, 'saccadeInOptions', 1);
    % Map GUI saccade in fields
    if isempty(saccadeInOptions) || saccadeInOptions == 1
        saccInArray = [];
        if get_config_value(config, 'saccadeInForward', 0), saccInArray(end+1) = 2; end
        if get_config_value(config, 'saccadeInBackward', 0), saccInArray(end+1) = 3; end
        if ~isempty(saccInArray), saccadeInOptions = saccInArray; end
    end
    
    saccadeOutOptions = get_config_value(config, 'saccadeOutOptions', 1);
    % Map GUI saccade out fields  
    if isempty(saccadeOutOptions) || saccadeOutOptions == 1
        saccOutArray = [];
        if get_config_value(config, 'saccadeOutForward', 0), saccOutArray(end+1) = 2; end
        if get_config_value(config, 'saccadeOutBackward', 0), saccOutArray(end+1) = 3; end
        if ~isempty(saccOutArray), saccadeOutOptions = saccOutArray; end
    end
    
    conditions = get_config_value(config, 'conditions', []);
    items = get_config_value(config, 'items', []);
    labelCount = get_config_value(config, 'labelCount', []);
    labelDescription = get_config_value(config, 'labelDescription', '');
    conflictResolution = get_config_value(config, 'conflictResolution', 'ask');
    showRegionMap = get_config_value(config, 'showRegionMap', true);
    eventFormat = get_config_value(config, 'eventFormat', 'numeric');
    
else
    % Individual parameters method (original)
    p = inputParser;
    addRequired(p, 'EEG', @isstruct);
    addParameter(p, 'timeLockedRegions', {}, @iscell);
    addParameter(p, 'passOptions', 1, @isnumeric);
    addParameter(p, 'prevRegions', {}, @iscell);
    addParameter(p, 'nextRegions', {}, @iscell);
    addParameter(p, 'fixationOptions', 1, @isnumeric);
    addParameter(p, 'saccadeInOptions', 1, @isnumeric);
    addParameter(p, 'saccadeOutOptions', 1, @isnumeric);
    addParameter(p, 'conditions', [], @isnumeric);
    addParameter(p, 'items', [], @isnumeric);
    addParameter(p, 'labelCount', [], @isnumeric);
    addParameter(p, 'labelDescription', '', @ischar);
    addParameter(p, 'conflictResolution', 'ask', @ischar);
    addParameter(p, 'showRegionMap', true, @islogical);
    addParameter(p, 'eventFormat', 'numeric', @ischar);
    
    parse(p, EEG, varargin{:});
    
    % Extract parsed parameters
    timeLockedRegions = p.Results.timeLockedRegions;
    passOptions = p.Results.passOptions;
    prevRegions = p.Results.prevRegions;
    nextRegions = p.Results.nextRegions;
    fixationOptions = p.Results.fixationOptions;
    saccadeInOptions = p.Results.saccadeInOptions;
    saccadeOutOptions = p.Results.saccadeOutOptions;
    conditions = p.Results.conditions;
    items = p.Results.items;
    labelCount = p.Results.labelCount;
    labelDescription = p.Results.labelDescription;
    conflictResolution = p.Results.conflictResolution;
    showRegionMap = p.Results.showRegionMap;
    eventFormat = p.Results.eventFormat;
end

% Validate input EEG structure
if isempty(EEG)
    error('label_datasets_core requires a non-empty EEG dataset');
end
if ~isfield(EEG, 'event') || isempty(EEG.event)
    error('EEG data does not contain any events.');
end
if ~isfield(EEG.event(1), 'regionBoundaries')
    error('EEG data is not properly processed with region information. Please process with the Text Interest Areas function first.');
end
if ~isfield(EEG, 'eyesort_field_names')
    error('EEG data does not contain field name information. Please process with the Text Interest Areas function first.');
end

% Initialize label count if missing or empty (e.g. saved as [] by a prior run)
if ~isfield(EEG, 'eyesort_label_count') || isempty(EEG.eyesort_label_count)
    EEG.eyesort_label_count = 0;
end

if isempty(labelCount)
    EEG.eyesort_label_count = EEG.eyesort_label_count + 1;
    labelCount = EEG.eyesort_label_count;
end

% Get event type field names from EEG structure
fixationType = EEG.eyesort_field_names.fixationType;
fixationXField = EEG.eyesort_field_names.fixationXField;
saccadeType = EEG.eyesort_field_names.saccadeType;
saccadeStartXField = EEG.eyesort_field_names.saccadeStartXField;
saccadeEndXField = EEG.eyesort_field_names.saccadeEndXField;

% Read RTL reading direction flag (stored during text IA processing)
rtl = isfield(EEG.eyesort_field_names, 'rtl') && EEG.eyesort_field_names.rtl;

% Extract conditions and items if not provided
if isempty(conditions) && isfield(EEG.event, 'condition_number')
    raw = {EEG.event.condition_number};
    nonempty = ~cellfun(@isempty, raw);
    condVals = zeros(1, length(raw));
    condVals(nonempty) = cell2mat(raw(nonempty));
    conditions = unique(condVals(condVals > 0));
end

if isempty(items) && isfield(EEG.event, 'item_number')
    raw = {EEG.event.item_number};
    nonempty = ~cellfun(@isempty, raw);
    itemVals = zeros(1, length(raw));
    itemVals(nonempty) = cell2mat(raw(nonempty));
    items = unique(itemVals(itemVals > 0));
end

% Validate that at least one time-locked region is specified
if isempty(timeLockedRegions)
    error('At least one time-locked region must be specified for labeling');
end

% Ensure timeLockedRegions is a cell array
if ischar(timeLockedRegions)
    timeLockedRegions = {timeLockedRegions};
elseif ~iscell(timeLockedRegions)
    error('timeLockedRegions must be a cell array of strings or a single string');
end

% Apply the labeling
try
    [labeledEEG, chosenConflictResolution] = label_dataset_internal(EEG, conditions, items, timeLockedRegions, ...
                                            passOptions, prevRegions, nextRegions, ...
                                            fixationOptions, saccadeInOptions, saccadeOutOptions, labelCount, ...
                                            fixationType, fixationXField, saccadeType, ...
                                            saccadeStartXField, saccadeEndXField, labelDescription, rtl, conflictResolution, showRegionMap, eventFormat);
    
    % Store the event format used for labeling
    labeledEEG.eyesort_event_format = eventFormat;

    % Update label count and descriptions
    labeledEEG.eyesort_label_count = labelCount;
    if ~isfield(labeledEEG, 'eyesort_label_descriptions')
        labeledEEG.eyesort_label_descriptions = {};
    end
    
    % Build label description structure
    labelDesc = struct();
    labelDesc.label_number = labelCount;
    labelDesc.label_code = sprintf('%02d', labelCount);
    labelDesc.regions = timeLockedRegions;
    labelDesc.pass_options = passOptions;
    labelDesc.prev_regions = prevRegions;
    labelDesc.next_regions = nextRegions;
    labelDesc.fixation_options = fixationOptions;
    labelDesc.saccade_in_options = saccadeInOptions;
    labelDesc.saccade_out_options = saccadeOutOptions;
    labelDesc.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    labeledEEG.eyesort_label_descriptions{end+1} = labelDesc;
    
    % Generate command string
    if iscell(timeLockedRegions)
        % Create cell array string representation manually for compatibility
        if length(timeLockedRegions) == 1
            regionStr = sprintf('{''%s''}', timeLockedRegions{1});
        else
            regionStr = sprintf('{''%s''}', strjoin(timeLockedRegions, ''', '''));
        end
    else
        regionStr = mat2str(timeLockedRegions);
    end
    com = sprintf('EEG = label_datasets_core(EEG, ''timeLockedRegions'', %s, ''labelCount'', %d);', ...
                regionStr, labelCount);
    
catch ME
    % Provide more detailed error information
    if contains(ME.message, 'mat2str') || contains(ME.message, 'Input matrix must be')
        error('Error in command string generation. This may be due to incompatible data types in label parameters. Original error: %s', ME.message);
    else
        error('Error applying label: %s', ME.message);
    end
end

end

function [labeledEEG, chosenConflictResolution] = label_dataset_internal(EEG, conditions, items, timeLockedRegions, ...
                                                passOptions, prevRegions, nextRegions, ...
                                                fixationOptions, saccadeInOptions, ...
                                                saccadeOutOptions, labelCount, ...
                                                fixationType, fixationXField, saccadeType, ...
                                                saccadeStartXField, saccadeEndXField, labelDescription, rtl, conflictResolution, showRegionMap, eventFormat)
    % Optimized internal labeling implementation with O(n) complexity
    
    % Initialize conflict resolution output
    chosenConflictResolution = '';
    
    % Default showRegionMap to true if not provided
    if nargin < 20 || isempty(showRegionMap)
        showRegionMap = true;
    end
    
    % Default conflict resolution to 'ask' if not provided
    if nargin < 19 || isempty(conflictResolution)
        conflictResolution = 'ask';
    end
    
    % Create a copy of the EEG structure
    labeledEEG = EEG;
    
    % Create a tracking count for matched events
    matchedEventCount = 0;
    
    % Ensure label count is at least 1 for 1-indexed label codes
    if labelCount < 1
        labelCount = 1;
    end
    
    % Pre-compute the label code (always 2 digits, 01-99)
    labelCode = sprintf('%02d', labelCount);
    
    % Create region code mapping - map region names to 2-digit codes
    regionCodeMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    
    % Get the unique region names from the EEG events
    if isfield(EEG, 'region_names') && ~isempty(EEG.region_names)
        regionList = EEG.region_names;
        if ischar(regionList)
            regionList = {regionList};
        end
    else
        % Extract region names safely, handling empty/missing fields
        if isfield(EEG.event, 'current_region')
            allReg = {EEG.event.current_region};
            valid  = cellfun(@(x) ischar(x) && ~isempty(x), allReg);
            regionList = unique(allReg(valid));
        else
            regionList = {};
        end
    end
    
    % Map each region to a 2-digit code
    for kk = 1:length(regionList)
        if ~isempty(regionList{kk}) && ischar(regionList{kk})
            regionCodeMap(regionList{kk}) = sprintf('%02d', kk);
        end
    end
    
    % Print the region code mapping only once per label queue (controlled by caller)
    if showRegionMap
        fprintf('\n============ REGION CODE MAPPING ============\n');
        if ~isempty(regionCodeMap) && regionCodeMap.Count > 0
            for kk = 1:length(regionList)
                if ~isempty(regionList{kk}) && ischar(regionList{kk}) && isKey(regionCodeMap, regionList{kk})
                    fprintf('  Region "%s" = Code %s\n', regionList{kk}, regionCodeMap(regionList{kk}));
                end
            end
        else
            fprintf('  No regions found to map\n');
        end
        fprintf('=============================================\n\n');
    end
    
    % Track events with conflicting codes
    conflictingEvents = {};
    
    % ========== PERFORMANCE OPTIMIZATION: PRE-COMPUTE ALL INDICES ==========
    if showRegionMap
        fprintf('Pre-computing event indices for optimized labeling...\n');
    end
    
    % Pre-extract all event fields using bulk struct-array access (C-speed)
    nEvents = length(EEG.event);
    eventTypes        = {EEG.event.type}';
    trialNumbers      = zeros(nEvents, 1);
    regionPassNumbers = zeros(nEvents, 1);
    fixationInPass    = zeros(nEvents, 1);
    conditionNumbers  = zeros(nEvents, 1);
    itemNumbers       = zeros(nEvents, 1);

    if isfield(EEG.event, 'original_type')
        originalTypes = {EEG.event.original_type}';
        originalTypes(cellfun(@isempty, originalTypes)) = {''};
    else
        originalTypes = repmat({''}, nEvents, 1);
    end

    if isfield(EEG.event, 'current_region')
        currentRegions = {EEG.event.current_region}';
        currentRegions(cellfun(@(x) ~ischar(x), currentRegions)) = {''};
    else
        currentRegions = repmat({''}, nEvents, 1);
    end

    if isfield(EEG.event, 'last_region_visited')
        lastRegionVisited = {EEG.event.last_region_visited}';
        lastRegionVisited(cellfun(@isempty, lastRegionVisited)) = {''};
    else
        lastRegionVisited = repmat({''}, nEvents, 1);
    end

    if isfield(EEG.event, 'trial_number')
        raw = {EEG.event.trial_number};
        nonempty = ~cellfun(@isempty, raw);
        trialNumbers(nonempty) = cell2mat(raw(nonempty));
    end
    if isfield(EEG.event, 'region_pass_number')
        raw = {EEG.event.region_pass_number};
        nonempty = ~cellfun(@isempty, raw);
        regionPassNumbers(nonempty) = cell2mat(raw(nonempty));
    end
    if isfield(EEG.event, 'fixation_in_pass')
        raw = {EEG.event.fixation_in_pass};
        nonempty = ~cellfun(@isempty, raw);
        fixationInPass(nonempty) = cell2mat(raw(nonempty));
    end
    if isfield(EEG.event, 'condition_number')
        raw = {EEG.event.condition_number};
        nonempty = ~cellfun(@isempty, raw);
        conditionNumbers(nonempty) = cell2mat(raw(nonempty));
    end
    if isfield(EEG.event, 'item_number')
        raw = {EEG.event.item_number};
        nonempty = ~cellfun(@isempty, raw);
        itemNumbers(nonempty) = cell2mat(raw(nonempty));
    end

    % Identify fixation events using vectorized string comparison
    fixLen     = length(fixationType);
    isFixation = strncmp(eventTypes, fixationType, fixLen) | ...
                 strncmp(originalTypes, fixationType, fixLen);
    % Third condition: already-coded fixations have a 6-char CCRRLL type
    % and the eyesort_full_code field (struct field is array-wide once set)
    if isfield(EEG.event, 'eyesort_full_code')
        isCharType = cellfun(@ischar, eventTypes);
        typeLengths = cellfun(@numel, eventTypes);
        isFixation = isFixation | (isCharType & typeLengths == 6);
    end

    % Get fixation indices
    fixationIndices = find(isFixation);

    % Extract next region visited field for all events
    if isfield(EEG.event, 'next_region_visited')
        nextRegionVisited = {EEG.event.next_region_visited}';
        nextRegionVisited(cellfun(@isempty, nextRegionVisited)) = {''};
    else
        nextRegionVisited = repmat({''}, nEvents, 1);
    end
    
    % Pre-compute fixation group counts and max fixation-in-pass per (trial/region/pass) key.
    % Storing only two scalars per group instead of a growing index array eliminates
    % the repeated copy-on-write allocations of the old end+1 pattern.
    groupCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
    groupMaxFIP = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for i = 1:length(fixationIndices)
        idx = fixationIndices(i);
        if trialNumbers(idx) == 0 || isempty(currentRegions{idx}) || regionPassNumbers(idx) == 0
            continue;
        end
        key = sprintf('%d_%s_%d', trialNumbers(idx), currentRegions{idx}, regionPassNumbers(idx));
        if isKey(groupCounts, key)
            groupCounts(key) = groupCounts(key) + 1;
            groupMaxFIP(key) = max(groupMaxFIP(key), fixationInPass(idx));
        else
            groupCounts(key) = 1;
            groupMaxFIP(key) = fixationInPass(idx);
        end
    end
    
    % Pre-compute saccade relationships
    saccadeIndices = find(strcmp(eventTypes, saccadeType));
    prevSaccadeMap = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    nextSaccadeMap = containers.Map('KeyType', 'int32', 'ValueType', 'any');

    % Precompute trial-boundary lookups in two O(F) passes so the saccade map
    % loop never needs inner scans over fixationIndices.
    % prevValidTrialArr(i) = last non-zero trial number seen strictly before position i.
    % nextValidTrialArr(i) = next non-zero trial number seen strictly after position i.
    nFix = length(fixationIndices);
    prevValidTrialArr = zeros(nFix, 1);
    nextValidTrialArr = zeros(nFix, 1);
    lastSeen = 0;
    for k = 1:nFix
        prevValidTrialArr(k) = lastSeen;
        if trialNumbers(fixationIndices(k)) > 0
            lastSeen = trialNumbers(fixationIndices(k));
        end
    end
    lastSeen = 0;
    for k = nFix:-1:1
        nextValidTrialArr(k) = lastSeen;
        if trialNumbers(fixationIndices(k)) > 0
            lastSeen = trialNumbers(fixationIndices(k));
        end
    end

    for i = 1:nFix
        idx = fixationIndices(i);

        % Find previous saccade: vectorized find on sorted saccadeIndices
        jj = find(saccadeIndices < idx, 1, 'last');
        if ~isempty(jj)
            prevSaccade = saccadeIndices(jj);
            % Only accept if within the same trial.
            % Skip over adjacent fixations with trial_number=0 (in-trial but unassigned
            % to a region) to find the nearest fixation with a valid trial number.
            withinTrial = true;
            if trialNumbers(idx) > 0
                if prevValidTrialArr(i) ~= trialNumbers(idx)
                    withinTrial = false;
                end
            end
            if withinTrial
                prevSaccadeMap(idx) = prevSaccade;
            end
        end

        % Find next saccade: vectorized find on sorted saccadeIndices
        jj = find(saccadeIndices > idx, 1, 'first');
        if ~isempty(jj)
            nextSaccade = saccadeIndices(jj);
            % Only accept if within the same trial.
            % Skip over adjacent fixations with trial_number=0 (in-trial but unassigned
            % to a region) to find the nearest fixation with a valid trial number.
            withinTrial = true;
            if trialNumbers(idx) > 0
                if nextValidTrialArr(i) ~= trialNumbers(idx)
                    withinTrial = false;
                end
            end
            if withinTrial
                nextSaccadeMap(idx) = nextSaccade;
            end
        end
    end
    
    if showRegionMap
        fprintf('Pre-computation complete. Processing %d fixation events...\n', length(fixationIndices));
    end
    
    % ========== OPTIMIZED LABELING LOOP ==========
    bdf_fields_initialized = false;  % Flag to track BDF field initialization
    % Cache for matlab.lang.makeValidName results — the set of unique (cond,item)
    % pairs is small, but the call fires once per matched event without caching.
    validKeyCache = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for i = 1:length(fixationIndices)
        mm = fixationIndices(i);
        evt = EEG.event(mm);
        
        % Check basic labels first (fastest)
        % Check if this is a fixation event or a previously coded fixation event
        if ~isFixation(mm)
            continue;
        end
        
        % Check for condition and item labels (vectorized) - MUST match if specified
        if ~isempty(conditions)
            if conditionNumbers(mm) <= 0 || ~any(conditionNumbers(mm) == conditions)
                continue;
            end
        end
        
        if ~isempty(items)
            if itemNumbers(mm) <= 0 || ~any(itemNumbers(mm) == items)
                continue;
            end
        end
        
        % Time-locked region label (vectorized) - MUST have valid region if specified
        if ~isempty(timeLockedRegions)
            if isempty(currentRegions{mm}) || ~any(strcmpi(currentRegions{mm}, timeLockedRegions))
                continue;
            end
        end
        
        % Pass index labeling (optimized)
        passesPassIndex = false;
        if isscalar(passOptions)
            if passOptions == 1
                passesPassIndex = true;
            elseif passOptions == 2
                passesPassIndex = (regionPassNumbers(mm) == 1);
            elseif passOptions == 3
                passesPassIndex = (regionPassNumbers(mm) == 2);
            elseif passOptions == 4
                passesPassIndex = (regionPassNumbers(mm) >= 3);
            else
                passesPassIndex = true;
            end
        else
            if isempty(passOptions) || any(passOptions == 1)
                passesPassIndex = true;
            else
                for opt = passOptions
                    if opt == 2 && regionPassNumbers(mm) == 1
                        passesPassIndex = true;
                        break;
                    elseif opt == 3 && regionPassNumbers(mm) == 2
                        passesPassIndex = true;
                        break;
                    elseif opt == 4 && regionPassNumbers(mm) >= 3
                        passesPassIndex = true;
                        break;
                    end
                end
            end
        end
        
        if ~passesPassIndex
            continue;
        end
        
        % Previous region labeling (optimized)
        if ~isempty(prevRegions)
            if isempty(lastRegionVisited{mm}) || ~any(strcmpi(lastRegionVisited{mm}, prevRegions))
                continue;
            end
        end
        
        % Next region labeling (using pre-computed field)
        if ~isempty(nextRegions)
            if isempty(nextRegionVisited{mm}) || ~any(strcmpi(nextRegionVisited{mm}, nextRegions))
                continue;
            end
        end
        
        % Fixation type labeling (uses groupCounts / groupMaxFIP scalar maps)
        passesFixationType = false;
        if isscalar(fixationOptions)
            if fixationOptions == 0
                passesFixationType = true;
            elseif fixationOptions == 1
                % Single fixation - using next_fixation_region for efficiency
                if isfield(EEG.event(mm), 'next_fixation_region') && fixationInPass(mm) == 1
                    nextFixRegion = EEG.event(mm).next_fixation_region;
                    passesFixationType = isempty(nextFixRegion) || ~strcmpi(currentRegions{mm}, nextFixRegion);
                else
                    % Fallback to group-based check
                    if trialNumbers(mm) > 0 && ~isempty(currentRegions{mm}) && regionPassNumbers(mm) > 0
                        key = sprintf('%d_%s_%d', trialNumbers(mm), currentRegions{mm}, regionPassNumbers(mm));
                        if isKey(groupCounts, key)
                            passesFixationType = (groupCounts(key) == 1);
                        end
                    end
                end
            elseif fixationOptions == 2
                % First of multiple
                if trialNumbers(mm) > 0 && ~isempty(currentRegions{mm}) && regionPassNumbers(mm) > 0
                    key = sprintf('%d_%s_%d', trialNumbers(mm), currentRegions{mm}, regionPassNumbers(mm));
                    if isKey(groupCounts, key)
                        passesFixationType = (fixationInPass(mm) == 1 && groupCounts(key) > 1);
                    end
                end
            elseif fixationOptions == 3
                passesFixationType = (fixationInPass(mm) == 2);
            elseif fixationOptions == 4
                passesFixationType = (fixationInPass(mm) > 2);
            elseif fixationOptions == 5
                % Last in region (using pre-computed field)
                if isfield(EEG.event(mm), 'is_last_in_pass')
                    passesFixationType = EEG.event(mm).is_last_in_pass;
                else
                    % Fallback to group-based check
                    if trialNumbers(mm) > 0 && ~isempty(currentRegions{mm}) && regionPassNumbers(mm) > 0
                        key = sprintf('%d_%s_%d', trialNumbers(mm), currentRegions{mm}, regionPassNumbers(mm));
                        if isKey(groupCounts, key)
                            passesFixationType = (fixationInPass(mm) == groupMaxFIP(key));
                        end
                    end
                end
            else
                passesFixationType = true;
            end
        else
            if isempty(fixationOptions) || any(fixationOptions == 0)
                passesFixationType = true;
            else
                for opt = fixationOptions
                    if opt == 1
                        % Single fixation - using next_fixation_region for efficiency
                        if isfield(EEG.event(mm), 'next_fixation_region') && fixationInPass(mm) == 1
                            nextFixRegion = EEG.event(mm).next_fixation_region;
                            if isempty(nextFixRegion) || ~strcmpi(currentRegions{mm}, nextFixRegion)
                                passesFixationType = true;
                                break;
                            end
                        elseif trialNumbers(mm) > 0 && ~isempty(currentRegions{mm}) && regionPassNumbers(mm) > 0
                            % Fallback to group-based check
                            key = sprintf('%d_%s_%d', trialNumbers(mm), currentRegions{mm}, regionPassNumbers(mm));
                            if isKey(groupCounts, key) && groupCounts(key) == 1
                                passesFixationType = true;
                                break;
                            end
                        end
                    elseif opt == 2 && trialNumbers(mm) > 0 && ~isempty(currentRegions{mm}) && regionPassNumbers(mm) > 0
                        key = sprintf('%d_%s_%d', trialNumbers(mm), currentRegions{mm}, regionPassNumbers(mm));
                        if isKey(groupCounts, key) && fixationInPass(mm) == 1 && groupCounts(key) > 1
                            passesFixationType = true;
                            break;
                        end
                    elseif opt == 3 && fixationInPass(mm) == 2
                        passesFixationType = true;
                        break;
                    elseif opt == 4 && fixationInPass(mm) > 2
                        passesFixationType = true;
                        break;
                    elseif opt == 5
                        % Last in region (using pre-computed field)
                        if isfield(EEG.event(mm), 'is_last_in_pass') && EEG.event(mm).is_last_in_pass
                            passesFixationType = true;
                            break;
                        elseif trialNumbers(mm) > 0 && ~isempty(currentRegions{mm}) && regionPassNumbers(mm) > 0
                            % Fallback to group-based check
                            key = sprintf('%d_%s_%d', trialNumbers(mm), currentRegions{mm}, regionPassNumbers(mm));
                            if isKey(groupCounts, key) && fixationInPass(mm) == groupMaxFIP(key)
                                passesFixationType = true;
                                break;
                            end
                        end
                    end
                end
            end
        end
        
        if ~passesFixationType
            continue;
        end
        
        % Saccade in direction labeling (optimized with pre-computed map)
        passesSaccadeInDirection = false;
        if isscalar(saccadeInOptions)
            if saccadeInOptions == 1
                passesSaccadeInDirection = true;
            else
                if isKey(prevSaccadeMap, mm)
                    prevSaccadeIdx = prevSaccadeMap(mm);
                    xChange = EEG.event(prevSaccadeIdx).(saccadeEndXField) - EEG.event(prevSaccadeIdx).(saccadeStartXField);
                    isForward = (xChange > 0) ~= rtl;
                    
                    if saccadeInOptions == 2
                        passesSaccadeInDirection = isForward && abs(xChange) > 5;
                    elseif saccadeInOptions == 3
                        passesSaccadeInDirection = ~isForward && abs(xChange) > 5;
                    elseif saccadeInOptions == 4
                        passesSaccadeInDirection = abs(xChange) > 5;
                    end
                                 else
                     if saccadeInOptions == 4
                         passesSaccadeInDirection = true;
                     else
                         passesSaccadeInDirection = false;
                     end
                 end
            end
        else
            if isempty(saccadeInOptions) || any(saccadeInOptions == 1)
                passesSaccadeInDirection = true;
            else
                if isKey(prevSaccadeMap, mm)
                    prevSaccadeIdx = prevSaccadeMap(mm);
                    xChange = EEG.event(prevSaccadeIdx).(saccadeEndXField) - EEG.event(prevSaccadeIdx).(saccadeStartXField);
                    isForward = (xChange > 0) ~= rtl;
                    
                    if abs(xChange) > 5
                        for opt = saccadeInOptions
                            if opt == 2 && isForward
                                passesSaccadeInDirection = true;
                                break;
                            elseif opt == 3 && ~isForward
                                passesSaccadeInDirection = true;
                                break;
                            elseif opt == 4
                                passesSaccadeInDirection = true;
                                break;
                            end
                        end
                    end
                end
            end
        end
        
        if ~passesSaccadeInDirection
            continue;
        end
        
        % Saccade out direction labeling (optimized with pre-computed map)
        passesSaccadeOutDirection = false;
        if isscalar(saccadeOutOptions)
            if saccadeOutOptions == 1
                passesSaccadeOutDirection = true;
            else
                if isKey(nextSaccadeMap, mm)
                    nextSaccadeIdx = nextSaccadeMap(mm);
                    xChange = EEG.event(nextSaccadeIdx).(saccadeEndXField) - EEG.event(nextSaccadeIdx).(saccadeStartXField);
                    isForward = (xChange > 0) ~= rtl;
                    
                    if saccadeOutOptions == 2
                        passesSaccadeOutDirection = isForward && abs(xChange) > 10;
                    elseif saccadeOutOptions == 3
                        passesSaccadeOutDirection = ~isForward && abs(xChange) > 10;
                    elseif saccadeOutOptions == 4
                        passesSaccadeOutDirection = abs(xChange) > 10;
                    end
                                 else
                     if saccadeOutOptions > 1 && saccadeOutOptions < 4
                         passesSaccadeOutDirection = false;
                     else
                         passesSaccadeOutDirection = true;
                     end
                 end
            end
        else
            if isempty(saccadeOutOptions) || any(saccadeOutOptions == 1)
                passesSaccadeOutDirection = true;
            else
                if isKey(nextSaccadeMap, mm)
                    nextSaccadeIdx = nextSaccadeMap(mm);
                    xChange = EEG.event(nextSaccadeIdx).(saccadeEndXField) - EEG.event(nextSaccadeIdx).(saccadeStartXField);
                    isForward = (xChange > 0) ~= rtl;
                    
                    if abs(xChange) > 10
                        for opt = saccadeOutOptions
                            if opt == 2 && isForward
                                passesSaccadeOutDirection = true;
                                break;
                            elseif opt == 3 && ~isForward
                                passesSaccadeOutDirection = true;
                                break;
                            elseif opt == 4
                                passesSaccadeOutDirection = true;
                                break;
                            end
                        end
                    end
                end
            end
        end
        
        if ~passesSaccadeOutDirection
            continue;
        end
        
        % If we reach here, the event passes all labels
        matchedEventCount = matchedEventCount + 1;
        
        % Generate the 6-digit event code
        condStr = '';
        if conditionNumbers(mm) > 0
            condStr = sprintf('%02d', mod(conditionNumbers(mm), 100));
        else
            condStr = '00';
        end
        
        regionStr = '';
        if ~isempty(currentRegions{mm}) && isKey(regionCodeMap, currentRegions{mm})
            regionStr = regionCodeMap(currentRegions{mm});
        else
            regionStr = '00';
        end
        
        labelStr = labelCode;
        newType = sprintf('%s%s%s', condStr, regionStr, labelStr);
        
        % Store the original type if this is the first time we're coding this event.
        % Also check isempty because MATLAB auto-populates the field as [] on all
        % other struct-array elements whenever any element first receives the field.
        if ~isfield(evt, 'original_type') || isempty(evt.original_type)
            labeledEEG.event(mm).original_type = evt.type;
        end
        
        % Check for existing code in the event
        if isfield(evt, 'eyesort_full_code') && ~isempty(evt.eyesort_full_code)
            existingDesc = '';
            if isfield(evt, 'bdf_label_description')
                existingDesc = evt.bdf_label_description;
            end
            conflictingEvents{end+1} = struct(...
                'event_index', mm, ...
                'existing_code', evt.eyesort_full_code, ...
                'existing_desc', existingDesc, ...
                'new_code', newType, ...
                'new_desc', labelDescription, ...
                'condition', conditionNumbers(mm), ...
                'region', currentRegions{mm});
            continue; % Skip this event instead of overwriting
        end
        
        % Always store the canonical CCRRLL code and sub-codes
        labeledEEG.event(mm).eyesort_condition_code = condStr;
        labeledEEG.event(mm).eyesort_region_code = regionStr;
        labeledEEG.event(mm).eyesort_label_code = labelStr;
        labeledEEG.event(mm).eyesort_full_code = newType;
        
        % Initialize BDF description fields for ALL events (only once, after eyesort fields)
        if ~bdf_fields_initialized
            if ~isfield(labeledEEG.event, 'bdf_condition_description')
                fprintf('Initializing BDF description fields for all events...\n');
                [labeledEEG.event.bdf_condition_description] = deal('');
                [labeledEEG.event.bdf_label_description] = deal('');
                [labeledEEG.event.bdf_full_description] = deal('');
            end
            if ~isfield(labeledEEG.event, 'current_word_text')
                [labeledEEG.event.current_word_text] = deal('');
            end
            bdf_fields_initialized = true;
        end
        
        % Resolve the actual word text from the positional current_word index
        wordText = '';
        if isfield(evt, 'current_word') && ischar(evt.current_word) && ~isempty(evt.current_word)
            try
                [regionNum, wordNum] = parse_word_region(evt.current_word);
                wordsField = sprintf('region%d_words', regionNum);
                if isfield(evt, wordsField) && ~isempty(evt.(wordsField))
                    words = evt.(wordsField);
                    if iscell(words) && wordNum <= length(words)
                        wordText = strtrim(words{wordNum});
                    end
                end
            catch
            end
        end
        labeledEEG.event(mm).current_word_text = wordText;
        
        % Resolve condition description (needed for BDF fields and text formats)
        conditionDesc = '';
        if isfield(labeledEEG, 'eyesort_condition_descriptions') && ...
           isfield(labeledEEG, 'eyesort_condition_lookup') && ...
           conditionNumbers(mm) > 0 && itemNumbers(mm) > 0
            key = sprintf('%d_%d', conditionNumbers(mm), itemNumbers(mm));
            if isKey(validKeyCache, key)
                validKey = validKeyCache(key);
            else
                validKey = matlab.lang.makeValidName(['k_' key]);
                validKeyCache(key) = validKey;
            end
            condStruct = labeledEEG.eyesort_condition_descriptions;
            if isfield(condStruct, validKey)
                conditionNum = condStruct.(validKey);
                if isKey(labeledEEG.eyesort_condition_lookup, num2str(conditionNum))
                    conditionDesc = labeledEEG.eyesort_condition_lookup(num2str(conditionNum));
                end
            end
        end
        if isempty(conditionDesc), conditionDesc = ''; end
        
        % Store BDF description fields (only when labelDescription is provided)
        if ~isempty(labelDescription)
            labeledEEG.event(mm).bdf_condition_description = char(conditionDesc);
            labeledEEG.event(mm).bdf_label_description = char(labelDescription);
            
            if isempty(conditionDesc) && isempty(labelDescription)
                labeledEEG.event(mm).bdf_full_description = '';
            elseif isempty(conditionDesc)
                labeledEEG.event(mm).bdf_full_description = char(labelDescription);
            elseif isempty(labelDescription)
                labeledEEG.event(mm).bdf_full_description = char(conditionDesc);
            else
                labeledEEG.event(mm).bdf_full_description = [char(conditionDesc) ' ' char(labelDescription)];
            end
        end
        
        % Set EEG.event.type based on the chosen eventFormat
        switch eventFormat
            case 'numeric'
                labeledEEG.event(mm).type = newType;
            case 'description'
                descType = build_description_type(conditionDesc, labelDescription);
                if isempty(descType)
                    labeledEEG.event(mm).type = newType;
                else
                    labeledEEG.event(mm).type = descType;
                end
            case 'description_word'
                descType = build_description_type(conditionDesc, labelDescription);
                if isempty(descType)
                    labeledEEG.event(mm).type = newType;
                elseif ~isempty(wordText)
                    labeledEEG.event(mm).type = [descType ' ' wordText];
                else
                    labeledEEG.event(mm).type = descType;
                end
            case 'region_content'
                regionText = '';
                if isfield(evt, 'current_word') && ischar(evt.current_word) && ~isempty(evt.current_word)
                    try
                        [regionNum, ~] = parse_word_region(evt.current_word);
                        textField = sprintf('region%d_text', regionNum);
                        if isfield(evt, textField) && ischar(evt.(textField)) && ~isempty(evt.(textField))
                            regionText = strtrim(evt.(textField));
                        end
                    catch
                    end
                end
                if ~isempty(regionText)
                    labeledEEG.event(mm).type = regionText;
                else
                    labeledEEG.event(mm).type = newType;
                end
            case 'original'
                % Do not overwrite type; leave it as original_type
            otherwise
                labeledEEG.event(mm).type = newType;
        end
    end
    
    % Handle conflicting events if any were found
    if ~isempty(conflictingEvents)
        if matchedEventCount > 0
            conflictPercentage = (length(conflictingEvents) / matchedEventCount) * 100;
        else
            conflictPercentage = 100;
        end
        
        fprintf('Warning: Found %d events with conflicting codes (%.1f%% of matched events).\n', ...
                length(conflictingEvents), conflictPercentage);
        fprintf('These events match multiple label criteria.\n');
        
        % Ask user whether to replace existing codes (or use saved choice)
        if strcmp(conflictResolution, 'yes')
            choice = 'Yes';
        elseif strcmp(conflictResolution, 'no')
            choice = 'No';
        else
            datasetName = '';
            if isfield(EEG, 'setname') && ~isempty(EEG.setname)
                datasetName = EEG.setname;
            elseif isfield(EEG, 'filename') && ~isempty(EEG.filename)
                [~, datasetName] = fileparts(EEG.filename);
            end
            [choice, rememberAll] = show_conflict_dialog(conflictingEvents, datasetName);
            if rememberAll
                chosenConflictResolution = lower(choice);
            end
        end
        
        if strcmp(choice, 'Yes')
            % Replace existing codes
            fprintf('Replacing existing codes with new labels...\n');
            for i = 1:length(conflictingEvents)
                evt_idx = conflictingEvents{i}.event_index;
                new_code = conflictingEvents{i}.new_code;
                
                % Always update the canonical CCRRLL code
                labeledEEG.event(evt_idx).eyesort_full_code = new_code;
                labeledEEG.event(evt_idx).eyesort_condition_code = new_code(1:2);
                labeledEEG.event(evt_idx).eyesort_region_code = new_code(3:4);
                labeledEEG.event(evt_idx).eyesort_label_code = new_code(5:6);
                
                % Update BDF descriptions with current label description
                conditionDesc = '';
                if ~isempty(labelDescription)
                    if isfield(labeledEEG.event(evt_idx), 'bdf_condition_description')
                        conditionDesc = labeledEEG.event(evt_idx).bdf_condition_description;
                    end
                    
                    labeledEEG.event(evt_idx).bdf_label_description = char(labelDescription);
                    if isempty(conditionDesc)
                        labeledEEG.event(evt_idx).bdf_full_description = char(labelDescription);
                    else
                        labeledEEG.event(evt_idx).bdf_full_description = [char(conditionDesc) ' ' char(labelDescription)];
                    end
                end
                
                % Resolve word text for conflict events
                cEvt = labeledEEG.event(evt_idx);
                cWordText = '';
                if isfield(cEvt, 'current_word') && ischar(cEvt.current_word) && ~isempty(cEvt.current_word)
                    try
                        [rn, wn] = parse_word_region(cEvt.current_word);
                        wf = sprintf('region%d_words', rn);
                        if isfield(cEvt, wf) && ~isempty(cEvt.(wf))
                            ws = cEvt.(wf);
                            if iscell(ws) && wn <= length(ws)
                                cWordText = strtrim(ws{wn});
                            end
                        end
                    catch
                    end
                end
                labeledEEG.event(evt_idx).current_word_text = cWordText;
                
                % Set type based on eventFormat
                switch eventFormat
                    case 'numeric'
                        labeledEEG.event(evt_idx).type = new_code;
                    case 'description'
                        descType = build_description_type(conditionDesc, labelDescription);
                        if isempty(descType)
                            labeledEEG.event(evt_idx).type = new_code;
                        else
                            labeledEEG.event(evt_idx).type = descType;
                        end
                    case 'description_word'
                        descType = build_description_type(conditionDesc, labelDescription);
                        if isempty(descType)
                            labeledEEG.event(evt_idx).type = new_code;
                        elseif ~isempty(cWordText)
                            labeledEEG.event(evt_idx).type = [descType ' ' cWordText];
                        else
                            labeledEEG.event(evt_idx).type = descType;
                        end
                    case 'region_content'
                        regionText = '';
                        if isfield(cEvt, 'current_word') && ischar(cEvt.current_word) && ~isempty(cEvt.current_word)
                            try
                                [rn2, ~] = parse_word_region(cEvt.current_word);
                                tf = sprintf('region%d_text', rn2);
                                if isfield(cEvt, tf) && ischar(cEvt.(tf)) && ~isempty(cEvt.(tf))
                                    regionText = strtrim(cEvt.(tf));
                                end
                            catch
                            end
                        end
                        if ~isempty(regionText)
                            labeledEEG.event(evt_idx).type = regionText;
                        else
                            labeledEEG.event(evt_idx).type = new_code;
                        end
                    case 'original'
                        % Leave type unchanged
                    otherwise
                        labeledEEG.event(evt_idx).type = new_code;
                end
            end
            fprintf('Replaced %d conflicting labels.\n', length(conflictingEvents));
        else
            fprintf('Keeping existing codes. Skipped %d conflicting events.\n', length(conflictingEvents));
        end
    end
    
    % Store the number of matched events for reference
    labeledEEG.eyesort_last_label_matched_count = matchedEventCount;
    
    % Display results
    fprintf('Label code for this batch: %s\n', labelCode);
    if matchedEventCount == 0
        fprintf('Warning: No events matched your label criteria!\n');
    else
        fprintf('Label applied successfully! Identified %d events matching label criteria.\n', matchedEventCount);
    end
    
end

%% Helper function: load_eyesort_config
function config = load_eyesort_config(configPath)
    % LOAD_EYESORT_CONFIG - Load configuration from MATLAB script or MAT file
    %
    % INPUTS:
    %   configPath - Path to .m config file or .mat file
    %
    % OUTPUTS:
    %   config - Struct containing all variables from config file
    
    if ~exist(configPath, 'file')
        error('Configuration file not found: %s', configPath);
    end
    
    [~, ~, ext] = fileparts(configPath);
    if strcmp(ext, '.mat')
        % Load MAT file
        try
            loaded_data = load(configPath);
            % Check if config is nested inside a 'config' field
            if isfield(loaded_data, 'config')
                config = loaded_data.config;
            else
                config = loaded_data;
            end
        catch ME
            error('Error loading MAT config file %s: %s', configPath, ME.message);
        end
    elseif strcmp(ext, '.m')
        % Run M file script
        try
            % Run the config file and capture variables
            run(configPath);
            
            % Capture all variables from workspace
            config = struct();
            vars = whos;
            for i = 1:length(vars)
                if ~strcmp(vars(i).name, 'config') && ~strcmp(vars(i).name, 'configPath')
                    config.(vars(i).name) = eval(vars(i).name);
                end
            end
        catch ME
            error('Error loading M config file %s: %s', configPath, ME.message);
        end
    else
        error('Config file must be a .m or .mat file: %s', configPath);
    end
end

%% Helper function: get_config_value
function value = get_config_value(config, field_name, default_value)
    % GET_CONFIG_VALUE - Get a value from config with default fallback
    %
    % INPUTS:
    %   config - Config struct
    %   field_name - Name of field to get
    %   default_value - Default value if field doesn't exist
    %
    % OUTPUTS:
    %   value - Field value or default
    
    if isfield(config, field_name) && ~isempty(config.(field_name))
        value = config.(field_name);
    else
        value = default_value;
    end
end

%% Helper function: show_conflict_dialog
function [choice, rememberAll] = show_conflict_dialog(conflictingEvents, datasetName)
    % SHOW_CONFLICT_DIALOG - Custom conflict resolution dialog with "remember" option
    %
    % Shows a modal dialog asking whether to replace conflicting labels,
    % with a checkbox allowing the user to apply their choice to all future conflicts.
    %
    % INPUTS:
    %   conflictingEvents - Cell array of conflict structs (event_index, existing_code, new_code, ...)
    %   datasetName       - (optional) Name of the dataset being processed
    %
    % OUTPUTS:
    %   choice     - 'Yes' to replace, 'No' to keep existing
    %   rememberAll - true if user checked "Apply to all future conflicts"
    
    if nargin < 2, datasetName = ''; end
    
    choice = 'No';
    rememberAll = false;
    nConflicts = length(conflictingEvents);
    
    % Hide waitbars so the modal dialog is front-most and fully interactable
    wbHandles = findobj(0, 'Tag', 'TMWWaitbar');
    set(wbHandles, 'Visible', 'off');
    restoreWb = onCleanup(@() set(wbHandles(ishandle(wbHandles)), 'Visible', 'on'));
    
    % Build a summary of unique existing→new code pairs (with descriptions)
    % Key = "existingCode|newCode"; value = {count, existingDesc, newDesc}
    pairMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for k = 1:nConflicts
        ce = conflictingEvents{k};
        key = sprintf('%s|%s', ce.existing_code, ce.new_code);
        if isKey(pairMap, key)
            entry = pairMap(key);
            entry{1} = entry{1} + 1;
            pairMap(key) = entry;
        else
            pairMap(key) = {1, ce.existing_desc, ce.new_desc};
        end
    end
    pairKeys = keys(pairMap);
    pairLines = '';
    for k = 1:length(pairKeys)
        parts = strsplit(pairKeys{k}, '|');
        entry  = pairMap(pairKeys{k});
        n      = entry{1};
        exDesc = entry{2};
        nwDesc = entry{3};
        if ~isempty(exDesc)
            exLabel = sprintf('%s (%s)', parts{1}, exDesc);
        else
            exLabel = parts{1};
        end
        if ~isempty(nwDesc)
            nwLabel = sprintf('%s (%s)', parts{2}, nwDesc);
        else
            nwLabel = parts{2};
        end
        if n > 1
            pairLines = [pairLines sprintf('  %s \x2192 %s  [%d events]\n', exLabel, nwLabel, n)]; %#ok<AGROW>
        else
            pairLines = [pairLines sprintf('  %s \x2192 %s\n', exLabel, nwLabel)]; %#ok<AGROW>
        end
    end
    
    dlgW = 560;
    nPairLines = length(pairKeys);
    % Height: ~20px per line (dataset name + header + pairs + footer) + wrapping buffer
    nMsgLines  = (~isempty(datasetName)) + 2 + nPairLines + 1;
    lineH      = 20;
    msgH       = nMsgLines * lineH + 30;  % +30 wrapping buffer

    btnH   = 38;
    btnY   = 15;
    chkY   = btnY + btnH + 8;
    msgY   = chkY + 30;
    dlgH   = msgY + msgH + 10;

    if ~isempty(datasetName)
        dlgTitle = sprintf('Conflicting Labels — %s', datasetName);
    else
        dlgTitle = 'Conflicting Labels Found';
    end
    hDlg = figure('Name', dlgTitle, 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'on', ...
        'WindowStyle', 'modal', 'Position', [0 0 dlgW dlgH], ...
        'CloseRequestFcn', @(~,~) set_and_close('No'));
    movegui(hDlg, 'center');
    
    if ~isempty(datasetName)
        headerStr = sprintf('Dataset: %s\n', datasetName);
    else
        headerStr = '';
    end
    msgStr = sprintf(['%sFound %d event(s) with conflicting labels (existing \x2192 new):\n%s\n' ...
        'Do you want to replace the existing labels with the new ones?'], ...
        headerStr, nConflicts, pairLines);
    
    uicontrol(hDlg, 'Style', 'text', 'String', msgStr, ...
        'Position', [15 msgY dlgW-30 msgH], 'HorizontalAlignment', 'left', ...
        'FontSize', 10);
    
    hChk = uicontrol(hDlg, 'Style', 'checkbox', ...
        'String', 'Apply this choice to all future conflicts in this run', ...
        'Position', [15 chkY dlgW-30 22], 'Value', 0, 'FontSize', 10);
    
    uicontrol(hDlg, 'Style', 'pushbutton', 'String', 'Yes, Replace', ...
        'Position', [dlgW/2 - 140 btnY 125 btnH], 'FontSize', 10, ...
        'Callback', @(~,~) set_and_close('Yes'));
    
    uicontrol(hDlg, 'Style', 'pushbutton', 'String', 'No, Keep Existing', ...
        'Position', [dlgW/2 + 15 btnY 125 btnH], 'FontSize', 10, ...
        'Callback', @(~,~) set_and_close('No'));
    
    uiwait(hDlg);
    
    function set_and_close(c)
        choice = c;
        if ishandle(hChk)
            rememberAll = get(hChk, 'Value') == 1;
        end
        if ishandle(hDlg)
            uiresume(hDlg);
            delete(hDlg);
        end
    end
end

%% Helper function: build_description_type
function descType = build_description_type(conditionDesc, labelDescription)
    conditionDesc = char(conditionDesc);
    labelDescription = char(labelDescription);
    if isempty(conditionDesc) && isempty(labelDescription)
        descType = '';
    elseif isempty(conditionDesc)
        descType = labelDescription;
    elseif isempty(labelDescription)
        descType = conditionDesc;
    else
        descType = [conditionDesc ' ' labelDescription];
    end
end