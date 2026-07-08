% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

function summary = match_trigger_list(eventTypes, triggers, eventNorm, eventNum)
%MATCH_TRIGGER_LIST Count event matches for user trigger inputs.

    if nargin < 2
        triggers = {};
    end
    if ~iscell(triggers)
        triggers = {triggers};
    end
    if nargin < 3 || isempty(eventNorm) || nargin < 4 || isempty(eventNum)
        [eventNorm, eventNum] = precompute_event_features(eventTypes);
    end

    nTriggers = length(triggers);
    perTrigger = zeros(1, nTriggers);
    exactCounts = zeros(1, nTriggers);
    numericCounts = zeros(1, nTriggers);
    missingTriggers = {};
    triggerNorms = cell(1, nTriggers);
    triggerNums = cell(1, nTriggers);
    triggerIsNumberOnly = false(1, nTriggers);
    [exactCountMap, numericCountMap] = build_count_maps(eventNorm, eventNum);

    for iTrig = 1:nTriggers
        trig = triggers{iTrig};
        triggerNorms{iTrig} = normalize_trigger_value(trig);
        if isempty(triggerNorms{iTrig})
            continue;
        end

        exactCounts(iTrig) = lookup_count(exactCountMap, triggerNorms{iTrig});
        triggerIsNumberOnly(iTrig) = ~isempty(regexp(triggerNorms{iTrig}, '^\d+$', 'once'));
        if triggerIsNumberOnly(iTrig)
            triggerNums{iTrig} = regexp(triggerNorms{iTrig}, '\d+', 'match', 'once');
            numericCounts(iTrig) = lookup_count(numericCountMap, triggerNums{iTrig}) - exactCounts(iTrig);
            numericCounts(iTrig) = max(numericCounts(iTrig), 0);
        end

        perTrigger(iTrig) = exactCounts(iTrig) + numericCounts(iTrig);
        if perTrigger(iTrig) == 0
            missingTriggers{end+1} = trigger_to_char(trig); %#ok<AGROW>
        end
    end

    matchedEventMask = build_matched_event_mask(eventNorm, eventNum, triggerNorms, triggerNums, triggerIsNumberOnly);

    summary = struct();
    summary.triggers = triggers;
    summary.perTrigger = perTrigger;
    summary.exactCounts = exactCounts;
    summary.numericCounts = numericCounts;
    summary.totalMatches = sum(matchedEventMask);
    summary.rawMatchCount = sum(perTrigger);
    summary.missingTriggers = missingTriggers;
    summary.matchedEventIndices = find(matchedEventMask);
    summary.numericMatchedEventCount = sum(matchedEventMask & ~cellfun('isempty', eventNum));
end

function [eventNorm, eventNum] = precompute_event_features(eventTypes)
    eventNorm = cell(1, length(eventTypes));
    eventNum = cell(1, length(eventTypes));
    for iEvt = 1:length(eventTypes)
        eventNorm{iEvt} = normalize_trigger_value(eventTypes{iEvt});
        eventNum{iEvt} = regexp(eventNorm{iEvt}, '\d+', 'match', 'once');
        if isempty(eventNum{iEvt})
            eventNum{iEvt} = '';
        end
    end
end

function [exactCountMap, numericCountMap] = build_count_maps(eventNorm, eventNum)
    exactCountMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
    numericCountMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for iEvt = 1:length(eventNorm)
        exactCountMap = increment_count(exactCountMap, eventNorm{iEvt});
        numericCountMap = increment_count(numericCountMap, eventNum{iEvt});
    end
end

function countMap = increment_count(countMap, key)
    if isempty(key)
        return;
    end
    if isKey(countMap, key)
        countMap(key) = countMap(key) + 1;
    else
        countMap(key) = 1;
    end
end

function count = lookup_count(countMap, key)
    count = 0;
    if isempty(key)
        return;
    end
    if isKey(countMap, key)
        count = countMap(key);
    end
end

function matchedEventMask = build_matched_event_mask(eventNorm, eventNum, triggerNorms, triggerNums, triggerIsNumberOnly)
    matchedEventMask = false(1, length(eventNorm));

    exactTriggerMask = ~cellfun('isempty', triggerNorms);
    if any(exactTriggerMask)
        matchedEventMask = matchedEventMask | ismember(eventNorm, unique(triggerNorms(exactTriggerMask)));
    end

    numericTriggerMask = triggerIsNumberOnly & ~cellfun('isempty', triggerNums);
    if any(numericTriggerMask)
        matchedEventMask = matchedEventMask | ismember(eventNum, unique(triggerNums(numericTriggerMask)));
    end
end

function out = normalize_trigger_value(value)
    out = strrep(strtrim(value_to_char(value)), ' ', '');
end

function out = trigger_to_char(value)
    if iscell(value)
        if isempty(value)
            out = '';
        else
            out = trigger_to_char(value{1});
        end
    elseif isnumeric(value)
        out = num2str(value);
    elseif ischar(value)
        out = value;
    elseif isstring(value)
        out = char(value);
    else
        try
            out = char(value);
        catch
            out = '';
        end
    end
end
