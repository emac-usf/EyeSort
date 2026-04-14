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

function EEG = trial_labeling(EEG, startCode, endCode, conditionTriggers, itemTriggers, ...
                            fixationType, fixationXField, saccadeType, saccadeStartXField, saccadeEndXField, ...
                            sentenceStartCode, sentenceEndCode)
    
    % Verify inputs
    if nargin < 12
        error('trial_labeling: Not enough input arguments. All field names and sentence codes must be specified.');
    end
    
    % No default values - all field names are required
    
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        error('trial_labeling: EEG.event is empty or missing.');
    end

    % Check if sentence codes are provided (optional feature)
    useSentenceCodes = ~isempty(sentenceStartCode) && ~isempty(sentenceEndCode) && ...
                       ~strcmp(strtrim(sentenceStartCode), '') && ~strcmp(strtrim(sentenceEndCode), '');


    
    % Print verification of inputs
    fprintf('Start code: %s\n', startCode);
    fprintf('End code: %s\n', endCode);
    fprintf('Condition triggers: %s\n', strjoin(conditionTriggers, ', '));
    fprintf('Item triggers: %s\n', strjoin(itemTriggers, ', '));
    fprintf('Fixation event type: %s, X position field: %s\n', fixationType, fixationXField);
    fprintf('Saccade event type: %s, Start X field: %s, End X field: %s\n', saccadeType, saccadeStartXField, saccadeEndXField);
    
    if useSentenceCodes
        fprintf('Sentence start code: %s, Sentence end code: %s\n', sentenceStartCode, sentenceEndCode);
    else
        fprintf('Sentence codes not provided - processing all events within trials\n');
    end
    
    % Initialize trial tracking variables
    % Trial tracking level
    currentTrial = 0;
    currentItem = [];
    currentCond = [];
    sentenceActive = ~useSentenceCodes;  % If no sentence codes, always active within trials

    % For tracking regression status and fixations in the last region:
    % inEndRegion is true once we enter the last region.
    % Store indices of fixations (in EEG.event) that occur in the last region.
    trialRegressionMap = containers.Map('KeyType', 'double', 'ValueType', 'logical');
    inEndRegion = false;
    endRegionFixations = [];  
    endRegionFixationCount = 0;  % number of fixations stored in last region

    % - Word and region tracking maps
    % These track visited words/regions and count fixations for first-pass detection
    visitedWords = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    wordFixationCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
    visitedRegions = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    regionFixationCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
    previousWord = '';
    maxVisitedRegionNum = 0;        % running max visited region number for O(1) later-region check
    maxVisitedWordInRegion = containers.Map('KeyType', 'double', 'ValueType', 'double');

    % Per-region pass tracking and fixation counts within passes
    currentPassFixationCounts = containers.Map('KeyType', 'char', 'ValueType', 'double'); % Tracks fixation count in current pass
    regionPassMap = containers.Map('KeyType', 'char', 'ValueType', 'double');  % Tracks pass number per region independently
    lastRegionVisited = '';  % Tracks the actual last region visited (different from previousRegion which tracks the previous fixation)

    % Initialize new fields for all events
    [EEG.event.current_region] = deal('');
    [EEG.event.previous_fixation_region] = deal('');  % previous region
    [EEG.event.next_fixation_region] = deal('');      % tracks next fixation event in the following region
    [EEG.event.last_region_visited] = deal('');       % tracks the actual last region visited (different from previousRegion which tracks the previous fixation)
    [EEG.event.next_region_visited] = deal('');       % tracks the next different region that will be visited after this fixation
    [EEG.event.region_pass_number] = deal(0);         % which pass through this region (1st, 2nd, etc.)
    [EEG.event.fixation_in_pass] = deal(0);           % which fixation in the current pass (1st, 2nd, etc.)
    [EEG.event.is_last_in_pass] = deal(false);        % pre-computed flag for last fixation in pass
    [EEG.event.current_word] = deal('');
    [EEG.event.previous_word] = deal('');
    [EEG.event.is_first_pass_region] = deal(false);
    [EEG.event.is_first_pass_word] = deal(false);
    [EEG.event.is_regression_trial] = deal(false);
    [EEG.event.is_region_regression] = deal(false);
    [EEG.event.is_word_regression] = deal(false);
    [EEG.event.total_fixations_in_word] = deal(0);
    [EEG.event.total_fixations_in_region] = deal(0);
    [EEG.event.trial_number] = deal(0);
    [EEG.event.item_number] = deal(0);
    [EEG.event.condition_number] = deal(0);

    % Count events for verification
    numFixations = 0;
    numWithBoundaries = 0;
    numProcessed = 0;

    % Add this flag at the initialization section (around line 20)
    hasRegressionBeenFound = containers.Map('KeyType', 'double', 'ValueType', 'logical');

    % Precompute static trigger metadata (computed once, reused every event iteration)
    conditionTriggersNoSpace = cellfun(@(x) strrep(x, ' ', ''), conditionTriggers, 'UniformOutput', false);
    itemTriggersNoSpace      = cellfun(@(x) strrep(x, ' ', ''), itemTriggers,      'UniformOutput', false);
    startCodeNoSpace = strrep(startCode, ' ', '');
    endCodeNoSpace   = strrep(endCode,   ' ', '');
    % Precompute numeric parts of condition/item triggers for O(1) per-event matching
    condIsNumOnly  = cellfun(@(t) ~isempty(regexp(t, '^\d+$', 'once')), conditionTriggersNoSpace);
    condConfigNums = cellfun(@(t) regexp(t, '\d+', 'match', 'once'),    conditionTriggersNoSpace, 'UniformOutput', false);
    itemIsNumOnly  = cellfun(@(t) ~isempty(regexp(t, '^\d+$', 'once')), itemTriggersNoSpace);
    itemConfigNums = cellfun(@(t) regexp(t, '\d+', 'match', 'once'),    itemTriggersNoSpace,      'UniformOutput', false);
    if useSentenceCodes
        sentenceStartNoSpace = strrep(sentenceStartCode, ' ', '');
        sentenceEndNoSpace   = strrep(sentenceEndCode,   ' ', '');
    else
        sentenceStartNoSpace = '';
        sentenceEndNoSpace   = '';
    end

    % Event processing loop
    for iEvt = 1:length(EEG.event)
        eventType = EEG.event(iEvt).type;
        if isnumeric(eventType)
            eventType = num2str(eventType);
        end

        % Remove spaces from event type; extract numeric part once for trigger matching
        eventTypeNoSpace = strrep(eventType, ' ', '');
        eventNum = regexp(eventTypeNoSpace, '\d+', 'match', 'once');

        %%%%%%%%%%%%%%%   
        % Trial start %
        %%%%%%%%%%%%%%% 
        % This section is responsible for resetting the trial-level tracking variables
        if flexibleTriggerMatch(eventTypeNoSpace, startCodeNoSpace)
            currentTrial = currentTrial + 1;
            hasRegressionBeenFound(currentTrial) = false;  % Initialize flag for new trial
            % Reset word and region tracking for new trial
            visitedWords          = containers.Map('KeyType', 'char',   'ValueType', 'logical');
            wordFixationCounts    = containers.Map('KeyType', 'char',   'ValueType', 'double');
            visitedRegions        = containers.Map('KeyType', 'char',   'ValueType', 'logical');
            regionFixationCounts  = containers.Map('KeyType', 'char',   'ValueType', 'double');
            maxVisitedRegionNum   = 0;
            maxVisitedWordInRegion = containers.Map('KeyType', 'double', 'ValueType', 'double');
            % Reset pass tracking variables
            currentPassFixationCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
            regionPassMap             = containers.Map('KeyType', 'char', 'ValueType', 'double');
            lastRegionVisited = '';
            previousWord = '';
            sentenceActive = ~useSentenceCodes;  % Reset sentence state for new trial
            % Also, clear any last region storage from previous trial:
            inEndRegion = false;
            endRegionFixations = [];
            endRegionFixationCount = 0;
            fprintf('Starting trial %d\n', currentTrial);

        %%%%%%%%%%%%%%   
        % Trial end  %
        %%%%%%%%%%%%%% 
        % Check for trial end
        elseif flexibleTriggerMatch(eventType, endCode)
            % Reset tracking at the end of the trial
            inEndRegion = false;
            endRegionFixationCount = 0;
            endRegionFixations = [];

            % Reset trial-level item and condition numbers
            currentItem = [];
            currentCond = [];
            sentenceActive = ~useSentenceCodes;

        % Check for condition trigger (vectorized: exact match OR numeric part match)
        elseif any(strcmp(eventTypeNoSpace, conditionTriggersNoSpace)) || ...
               (~isempty(eventNum) && any(condIsNumOnly & strcmp(eventNum, condConfigNums)))
            currentCond = str2double(eventNum);
            EEG.event(iEvt).condition_number = currentCond;

        % Check for item trigger (vectorized: exact match OR numeric part match)
        elseif any(strcmp(eventTypeNoSpace, itemTriggersNoSpace)) || ...
               (~isempty(eventNum) && any(itemIsNumOnly & strcmp(eventNum, itemConfigNums)))
            currentItem = str2double(eventNum);
            EEG.event(iEvt).item_number = currentItem;

        % Check for sentence start/end codes
        elseif useSentenceCodes
            if flexibleTriggerMatch(eventTypeNoSpace, sentenceStartNoSpace)
                sentenceActive = true;
            elseif flexibleTriggerMatch(eventTypeNoSpace, sentenceEndNoSpace)
                sentenceActive = false;
            end
        end
        
        % Process fixation events
        if startsWith(eventType, fixationType) && sentenceActive
            numFixations = numFixations + 1;

            if isfield(EEG.event(iEvt), 'word_boundaries')
                numWithBoundaries = numWithBoundaries + 1;

                if ~isempty(currentItem) && ~isempty(currentCond)
                    numProcessed = numProcessed + 1;
                    currentWord = determine_word_region(EEG.event(iEvt), fixationXField);
                    
                    if ~isempty(currentWord)
                        % Update word-related fields
                        EEG.event(iEvt).current_word = currentWord;
                        EEG.event(iEvt).previous_word = previousWord;
                        
                        % Update word fixation counts
                        if ~isKey(wordFixationCounts, currentWord)
                            wordFixationCounts(currentWord) = 1;
                        else
                            wordFixationCounts(currentWord) = wordFixationCounts(currentWord) + 1;
                        end
                        
                        % Parse current word into region and word number
                        [curr_region, curr_word_num] = parse_word_region(currentWord);
                        
                        % Update first-pass word information
                        % A word is only first-pass if:
                        % 1. This is the first visit to this word AND
                        % 2. We haven't visited any words with a higher number in the same region
                        regionKey = num2str(curr_region);

                        % Check if any higher-numbered region has already been visited
                        hasVisitedLaterRegion = (maxVisitedRegionNum > curr_region);

                        % Only proceed with word-level checks if no later region was visited
                        isFirstPassPossible = ~hasVisitedLaterRegion;
                        if isFirstPassPossible
                            % Then check if this specific word hasn't been visited
                            isFirstVisitToWord = ~isKey(visitedWords, currentWord);
                            
                            % Check if any later word in the same region was visited
                            hasVisitedLaterWord = false;
                            if isFirstVisitToWord
                                hasVisitedLaterWord = isKey(maxVisitedWordInRegion, curr_region) && ...
                                                      maxVisitedWordInRegion(curr_region) > curr_word_num;
                            end
                            
                            % Only mark as first pass if all conditions are met
                            EEG.event(iEvt).is_first_pass_word = isFirstVisitToWord && ~hasVisitedLaterWord;
                        else
                            % If a later region was already visited, this can't be first-pass
                            EEG.event(iEvt).is_first_pass_word = false;
                        end

                        visitedWords(currentWord) = true;
                        if ~isKey(maxVisitedWordInRegion, curr_region) || curr_word_num > maxVisitedWordInRegion(curr_region)
                            maxVisitedWordInRegion(curr_region) = curr_word_num;
                        end

                        % Get region name from the event's region fields
                        regionName = EEG.event(iEvt).(sprintf('region%d_name', curr_region));
                        
                        % Update region-related fields
                        EEG.event(iEvt).current_region = regionName;
                        
                        % Update region fixation counts (using region number as key)
                        if ~isKey(regionFixationCounts, regionKey)
                            regionFixationCounts(regionKey) = 1;
                        else
                            regionFixationCounts(regionKey) = regionFixationCounts(regionKey) + 1;
                        end
                        
                        % ======= REGRESSION DETECTION AND PASS TRACKING =======
                        % Detect regressions for regression fields
                        if ~isempty(previousWord)
                            [prev_region, prev_word_num] = parse_word_region(previousWord);
                            isRegression = (curr_region < prev_region);
                            
                            % Set regression fields
                            EEG.event(iEvt).is_region_regression = isRegression;
                            if curr_region == prev_region
                                EEG.event(iEvt).is_word_regression = (curr_word_num < prev_word_num);
                            else
                                EEG.event(iEvt).is_word_regression = false;
                            end
                            
                            % Mark trial as regression trial if ANY region regression occurs
                            if isRegression && ~hasRegressionBeenFound(currentTrial)
                                hasRegressionBeenFound(currentTrial) = true;
                                trialRegressionMap(currentTrial) = true;
                            end
                        end
                        
                        % Per-region pass tracking: increment pass count when entering a region
                        % Each region tracks its own pass number independently
                        if isempty(lastRegionVisited) || ~strcmpi(regionName, lastRegionVisited)
                            % Entering this region (either first time or returning)
                            if isKey(regionPassMap, regionName)
                                % Returning to this region - increment its pass counter
                                regionPassMap(regionName) = regionPassMap(regionName) + 1;
                            else
                                % First visit: a skip (later region already visited) counts as
                                % pass 1, so the first actual fixation starts at pass 2.
                                % Uses the same hasVisitedLaterRegion already computed above;
                                % skip-based pass inflation only applies on first entry.
                                regionPassMap(regionName) = 1 + hasVisitedLaterRegion;
                            end
                            % Reset fixation counter for this new pass
                            currentPassFixationCounts(regionName) = 1;
                            lastRegionVisited = regionName;
                        else
                            % Continuing in same region, same pass - increment fixation counter
                            currentPassFixationCounts(regionName) = currentPassFixationCounts(regionName) + 1;
                        end
                        
                        % Set pass number and fixation count for this fixation
                        EEG.event(iEvt).region_pass_number = regionPassMap(regionName);
                        EEG.event(iEvt).fixation_in_pass = currentPassFixationCounts(regionName);
                        % ======= END REGION PASS TRACKING LOGIC =======
                        
                        % is_first_pass_region rules (both must hold):
                        %   1. Region must not have already been visited
                        %   2. No fixations in any further regions
                        % hasVisitedLaterRegion is already computed above and has not
                        % changed since (visitedRegions is not modified until line below).
                        isFirstVisit = ~isKey(visitedRegions, regionKey);
                        EEG.event(iEvt).is_first_pass_region = isFirstVisit && ~hasVisitedLaterRegion;
                        visitedRegions(regionKey) = true;
                        if curr_region > maxVisitedRegionNum
                            maxVisitedRegionNum = curr_region;
                        end

                        % Store fixation counts
                        EEG.event(iEvt).total_fixations_in_word = wordFixationCounts(currentWord);
                        EEG.event(iEvt).total_fixations_in_region = regionFixationCounts(regionKey);
                        

                        
                        % Store trial metadata ONLY if event has proper region assignment
                        if ~isempty(EEG.event(iEvt).current_region) && ~strcmpi(EEG.event(iEvt).current_region, '')
                            EEG.event(iEvt).trial_number = currentTrial;
                            EEG.event(iEvt).item_number = currentItem;
                            EEG.event(iEvt).condition_number = currentCond;
                        end

                        %% ======= Track ENDING region regression information =======
                        % Get the last region name from user input
                        lastRegionName = '';
                        if isfield(EEG, 'region_names') && ~isempty(EEG.region_names)
                            lastRegionName = EEG.region_names{end};
                        end
                        
                        if ~isempty(lastRegionName) && strcmpi(EEG.event(iEvt).current_region, lastRegionName)
                            % We are in the last region: add this fixation to our storage.
                            if ~inEndRegion
                                inEndRegion = true;
                                endRegionFixationCount = 0;
                                endRegionFixations = [];
                            end
                            endRegionFixationCount = endRegionFixationCount + 1;
                            endRegionFixations(endRegionFixationCount) = iEvt;
                            
                            % Check if this fixation shows a word-level regression:
                            % Compare current fixation's word number with the previous fixation's word number
                            if ~isempty(EEG.event(iEvt).previous_word) && ~hasRegressionBeenFound(currentTrial)
                                [~, curr_word_num] = parse_word_region(EEG.event(iEvt).current_word);
                                [~, prev_word_num] = parse_word_region(EEG.event(iEvt).previous_word);
                                if curr_word_num < prev_word_num
                                    % Word-level regression detected in the last region.
                                    hasRegressionBeenFound(currentTrial) = true;
                                    trialRegressionMap(currentTrial) = true;
                                end
                            end
                        else
                            % The current fixation is not in last region.
                            % If we were collecting last-region fixations and no regression was yet flagged,
                            % then a regression out of the last region has occurred.
                            if inEndRegion && ~hasRegressionBeenFound(currentTrial)
                                hasRegressionBeenFound(currentTrial) = true;
                                trialRegressionMap(currentTrial) = true;
                                
                                % Clear the last-region storage.
                                inEndRegion = false;
                                endRegionFixationCount = 0;
                                endRegionFixations = [];
                            end
                        end
                        %% ======= End of LAST region regression tracking =======

                        % Now update the previous trackers AFTER handling the last region behavior.
                        previousWord = currentWord;
                    end
                    
                    % Handle fixations outside word boundaries - clear end region tracking
                    % to prevent false regression detection on next valid fixation
                    if isempty(currentWord) && inEndRegion
                        inEndRegion = false;
                        endRegionFixationCount = 0;
                        endRegionFixations = [];
                    end
                end
            end
        end
    end
    
    % Mark all events in regression trials (vectorized)
    fprintf('Marking all events in regression trials...\n');
    if ~isempty(trialRegressionMap)
        allTrialNums = [EEG.event.trial_number];
        regrTrialNums = cell2mat(keys(trialRegressionMap));
        regrMask = ismember(allTrialNums, regrTrialNums);
        [EEG.event(regrMask).is_regression_trial] = deal(true);
    end
    fprintf('Done marking regression trials.\n');

    % Precompute trial-to-fixation-index lookup (single O(E) pass, reused by all trial loops)
    allTrialNums_ev = [EEG.event.trial_number];
    isFixMask = strncmp({EEG.event.type}, fixationType, length(fixationType));
    maxTrialNum = max(allTrialNums_ev);
    trialFixationsCache = cell(maxTrialNum, 1);
    fixEventIndices = find(isFixMask & allTrialNums_ev > 0);
    fixTrialNums_cache = allTrialNums_ev(fixEventIndices);
    for fi = 1:length(fixEventIndices)
        t = fixTrialNums_cache(fi);
        trialFixationsCache{t}(end+1) = fixEventIndices(fi);
    end

    % Single pass per trial: compute region tracking fields and is_last_in_pass together
    fprintf('Computing region tracking and pass fields...\n');
    for iTrial = 1:maxTrialNum
        trialFixations = trialFixationsCache{iTrial};
        numFixations = length(trialFixations);

        if numFixations == 0
            continue;
        end

        % Pre-extract all regions for this trial to avoid repeated struct field access
        regions = cell(numFixations, 1);
        for i = 1:numFixations
            regions{i} = EEG.event(trialFixations(i)).current_region;
        end

        % Build run structure: compress consecutive same-region fixations into runs.
        % Allows O(R) next/last-region lookup per fixation instead of O(F) scan.
        runRegions = {};
        fixToRun = zeros(numFixations, 1);
        curRun = 0;
        prevRunRegion = [];
        for iR = 1:numFixations
            if curRun == 0 || ~strcmpi(regions{iR}, prevRunRegion)
                curRun = curRun + 1;
                runRegions{curRun} = regions{iR};
                prevRunRegion = regions{iR};
            end
            fixToRun(iR) = curRun;
        end
        numRuns = curRun;

        % Compute all fields in one loop over fixations
        for iFixIdx = 1:numFixations
            iEvt = trialFixations(iFixIdx);
            currentRegion = regions{iFixIdx};
            ri = fixToRun(iFixIdx);

            % previous_fixation_region: immediate previous fixation's region
            if iFixIdx > 1
                EEG.event(iEvt).previous_fixation_region = regions{iFixIdx-1};
            else
                EEG.event(iEvt).previous_fixation_region = '';
            end

            % next_fixation_region: immediate next fixation's region
            if iFixIdx < numFixations
                EEG.event(iEvt).next_fixation_region = regions{iFixIdx+1};
            else
                EEG.event(iEvt).next_fixation_region = '';
            end

            % next_region_visited: scan runs forward (O(R) instead of O(F))
            nextDifferentRegion = '';
            for rNext = ri+1:numRuns
                if ~isempty(runRegions{rNext}) && ~strcmpi(runRegions{rNext}, currentRegion)
                    nextDifferentRegion = runRegions{rNext};
                    break;
                end
            end
            EEG.event(iEvt).next_region_visited = nextDifferentRegion;

            % last_region_visited: scan runs backward (O(R) instead of O(F))
            lastDifferentRegion = '';
            for rPrev = ri-1:-1:1
                if ~isempty(runRegions{rPrev}) && ~strcmpi(runRegions{rPrev}, currentRegion)
                    lastDifferentRegion = runRegions{rPrev};
                    break;
                end
            end
            EEG.event(iEvt).last_region_visited = lastDifferentRegion;

            % is_last_in_pass: true if next fixation is in a different region or no next fixation
            if iFixIdx < numFixations
                EEG.event(iEvt).is_last_in_pass = ~strcmpi(currentRegion, regions{iFixIdx+1});
            else
                EEG.event(iEvt).is_last_in_pass = true;
            end
        end
    end
    fprintf('Done computing region tracking and pass fields.\n');
end

% Parses word region identifiers into region number and word number
% Handles two formats:
% - "4.2" -> region 4, word 2
% - "x1_1" -> region 1, word 1
function [major, minor] = parse_word_region(word_region)
    % Parses a word region string (e.g., "4.2" or "x1_1") into its major (region) and minor (word) parts.
    if contains(word_region, '.')
        parts = split(word_region, '.');
        major = str2double(parts{1});
        minor = str2double(parts{2});
    elseif contains(word_region, '_')
        parts = split(word_region, '_');
        % Remove 'x' from the first part if it exists
        region_part = regexprep(parts{1}, '^x', '');
        major = str2double(region_part);
        minor = str2double(parts{2});
    else
        error('Unknown word region format: %s', word_region);
    end
    
    if isnan(major) || isnan(minor)
        error('Failed to parse word region: %s', word_region);
    end
end


% Determines which word a fixation falls into based on x-coordinate
% Returns the word identifier or empty string if no match found
function currentWord = determine_word_region(event, fixationXField)
    currentWord = '';
    
    % Get x position - check all possible field names
    if isfield(event, fixationXField)
        x = event.(fixationXField);
    else
        fprintf('Warning: No position data found in event\n');
        return;
    end
    
    % Handle different data types for x position
    if ischar(x)
        % Handle coordinate string format "(X.XX, Y.YY)"
        numbers = regexp(x, '[-\d.]+', 'match');
        if ~isempty(numbers)
            x = str2double(numbers{1});
        else
            x = str2double(x);
        end
    elseif iscell(x)
        if ~isempty(x)
            if ischar(x{1})
                numbers = regexp(x{1}, '[-\d.]+', 'match');
                if ~isempty(numbers)
                    x = str2double(numbers{1});
                else
                    x = str2double(x{1});
                end
            else
                x = x{1};
            end
        else
            x = NaN;
        end
    end
    
    % Verify numeric conversion worked
    if isnan(x)
        fprintf('Warning: Could not convert x position to number\n');
        return;
    end
    
    % Check word boundaries
    if ~isfield(event, 'word_boundaries') || isempty(event.word_boundaries)
        return;
    end
    
    word_bounds = event.word_boundaries;
    field_names = fieldnames(word_bounds);
    
    % Loop through each field (word) in the word_bounds structure
    for i = 1:length(field_names)
        % Get the boundary coordinates for the current word
        bounds = word_bounds.(field_names{i});
        
        % Check if the fixation x-coordinate falls within this word's boundaries
        % bounds(1) is left edge, bounds(2) is right edge of word
        if x >= bounds(1) && x <= bounds(2)
            currentWord = field_names{i};
            break;
        end
    end
end

%% Helper function: flexibleTriggerMatch
function isMatch = flexibleTriggerMatch(eventTrigger, configTrigger)
    % FLEXIBLETRIGGERMATCH - Flexible trigger code matching
    % Handles cases where user enters "212" but data has "S212" or "R212"
    % BUT "R212" does NOT match "S212" - different prefixes must match exactly
    
    % First try exact match
    if strcmp(eventTrigger, configTrigger)
        isMatch = true;
        return;
    end
    
    % Check if config (user input) is just numbers (no letter prefix)
    configIsNumberOnly = ~isempty(regexp(configTrigger, '^\d+$', 'once'));
    
    if configIsNumberOnly
        % User entered just numbers, so match any prefix in event data
        eventNum = regexp(eventTrigger, '\d+', 'match', 'once');
        configNum = regexp(configTrigger, '\d+', 'match', 'once');
        isMatch = ~isempty(eventNum) && ~isempty(configNum) && strcmp(eventNum, configNum);
    else
        % User entered with prefix, must match exactly (already checked above)
        isMatch = false;
    end
end