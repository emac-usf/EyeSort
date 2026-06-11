% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

function summary = match_trigger_list(eventTypes, triggers)
%MATCH_TRIGGER_LIST Count event matches for user trigger inputs.

    if nargin < 2
        triggers = {};
    end
    if ~iscell(triggers)
        triggers = {triggers};
    end

    nTriggers = length(triggers);
    perTrigger = zeros(1, nTriggers);
    exactCounts = zeros(1, nTriggers);
    numericCounts = zeros(1, nTriggers);
    matchedEventMask = false(1, length(eventTypes));
    missingTriggers = {};

    for iTrig = 1:nTriggers
        trig = triggers{iTrig};
        for iEvt = 1:length(eventTypes)
            [matched, mode] = trigger_match(eventTypes{iEvt}, trig);
            if matched
                perTrigger(iTrig) = perTrigger(iTrig) + 1;
                matchedEventMask(iEvt) = true;
                if strcmp(mode, 'exact')
                    exactCounts(iTrig) = exactCounts(iTrig) + 1;
                elseif strcmp(mode, 'numeric')
                    numericCounts(iTrig) = numericCounts(iTrig) + 1;
                end
            end
        end
        if perTrigger(iTrig) == 0
            missingTriggers{end+1} = trigger_to_char(trig); %#ok<AGROW>
        end
    end

    summary = struct();
    summary.triggers = triggers;
    summary.perTrigger = perTrigger;
    summary.exactCounts = exactCounts;
    summary.numericCounts = numericCounts;
    summary.totalMatches = sum(matchedEventMask);
    summary.rawMatchCount = sum(perTrigger);
    summary.missingTriggers = missingTriggers;
    summary.matchedEventIndices = find(matchedEventMask);
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
