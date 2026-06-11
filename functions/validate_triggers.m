% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

function [diagnostics, summary] = validate_triggers(EEG, startCode, endCode, conditionTriggers, itemTriggers, sentenceStartCode, sentenceEndCode)
%VALIDATE_TRIGGERS Validate Step 2 trigger inputs against EEG events.

    if nargin < 6
        sentenceStartCode = '';
    end
    if nargin < 7
        sentenceEndCode = '';
    end

    diagnostics = empty_diagnostics();
    eventTypes = event_type_strings(EEG);

    summary = struct();
    summary.eventCount = length(eventTypes);
    summary.eventExamples = event_examples(eventTypes, 10);
    summary.start = match_trigger_list(eventTypes, {startCode});
    summary.end = match_trigger_list(eventTypes, {endCode});
    summary.condition = match_trigger_list(eventTypes, conditionTriggers);
    summary.item = match_trigger_list(eventTypes, itemTriggers);
    summary.sentenceStart = [];
    summary.sentenceEnd = [];

    if isempty(eventTypes)
        diagnostics(end+1) = make_diag('error', 'EEG events', 'EEG.event.type', '', ...
            'No EEG event types were available for validation.', ...
            'Load a dataset with events before running EyeSort Step 2.');
        return;
    end

    if summary.start.totalMatches == 0
        diagnostics(end+1) = make_diag('error', 'Start Trial Code', 'startCode', trigger_to_char(startCode), ...
            'No EEG events matched the start trial code. Trial boundaries cannot be detected.', ...
            sprintf('Use the exact start-trial event text from EEG.event.type. Examples: %s', strjoin(summary.eventExamples, ', ')));
    end

    if summary.end.totalMatches == 0
        diagnostics(end+1) = make_diag('error', 'End Trial Code', 'endCode', trigger_to_char(endCode), ...
            'No EEG events matched the end trial code. Trial boundaries cannot be detected.', ...
            sprintf('Use the exact end-trial event text from EEG.event.type. Examples: %s', strjoin(summary.eventExamples, ', ')));
    end

    if summary.condition.totalMatches == 0
        diagnostics(end+1) = make_diag('error', 'Condition Triggers', 'conditionTriggers', join_triggers(conditionTriggers), ...
            'No EEG events matched any condition trigger. Condition/item keys cannot be created.', ...
            sprintf('Check the condition trigger text, prefix, and numbers against EEG.event.type. Examples: %s', strjoin(summary.eventExamples, ', ')));
    elseif count_numeric_matched_events(eventTypes, conditionTriggers) == 0
        diagnostics(end+1) = make_diag('error', 'Condition Triggers', 'conditionTriggers', join_triggers(conditionTriggers), ...
            'Condition triggers matched EEG events, but no matched condition event contained a numeric value for the IA-file key.', ...
            'Use condition trigger events that include the numeric condition code used by the IA file, or update EyeSort before using nonnumeric condition keys.');
    elseif ~isempty(summary.condition.missingTriggers)
        diagnostics(end+1) = make_diag('warning', 'Condition Triggers', 'conditionTriggers', join_triggers(summary.condition.missingTriggers), ...
            'Some condition trigger inputs did not match this EEG dataset.', ...
            'Unmatched condition triggers will not contribute to interest-area assignment.');
    end

    if summary.item.totalMatches == 0
        diagnostics(end+1) = make_diag('error', 'Item Triggers', 'itemTriggers', join_triggers(itemTriggers), ...
            'No EEG events matched any item trigger. Condition/item keys cannot be created.', ...
            sprintf('Check the item trigger text, prefix, and numbers against EEG.event.type. Examples: %s', strjoin(summary.eventExamples, ', ')));
    elseif count_numeric_matched_events(eventTypes, itemTriggers) == 0
        diagnostics(end+1) = make_diag('error', 'Item Triggers', 'itemTriggers', join_triggers(itemTriggers), ...
            'Item triggers matched EEG events, but no matched item event contained a numeric value for the IA-file key.', ...
            'Use item trigger events that include the numeric item code used by the IA file, or update EyeSort before using nonnumeric item keys.');
    elseif ~isempty(summary.item.missingTriggers)
        diagnostics(end+1) = make_diag('warning', 'Item Triggers', 'itemTriggers', join_triggers(summary.item.missingTriggers), ...
            'Some item trigger inputs did not match this EEG dataset.', ...
            'Unmatched item triggers will not contribute to interest-area assignment.');
    end

    useSentenceCodes = ~isempty(strtrim(trigger_to_char(sentenceStartCode))) && ~isempty(strtrim(trigger_to_char(sentenceEndCode)));
    if useSentenceCodes
        summary.sentenceStart = match_trigger_list(eventTypes, {sentenceStartCode});
        summary.sentenceEnd = match_trigger_list(eventTypes, {sentenceEndCode});
        if summary.sentenceStart.totalMatches == 0
            diagnostics(end+1) = make_diag('error', 'Stimulus Start Code', 'sentenceStartCode', trigger_to_char(sentenceStartCode), ...
                'No EEG events matched the stimulus start code, so the requested eye-event time window cannot open.', ...
                sprintf('Use a stimulus/window start code present in EEG.event.type. Examples: %s', strjoin(summary.eventExamples, ', ')));
        end
        if summary.sentenceEnd.totalMatches == 0
            diagnostics(end+1) = make_diag('error', 'Stimulus End Code', 'sentenceEndCode', trigger_to_char(sentenceEndCode), ...
                'No EEG events matched the stimulus end code, so the requested eye-event time window cannot close.', ...
                sprintf('Use a stimulus/window end code present in EEG.event.type. Examples: %s', strjoin(summary.eventExamples, ', ')));
        end
    end
end

function count = count_numeric_matched_events(eventTypes, triggers)
    if ~iscell(triggers)
        triggers = {triggers};
    end
    count = 0;
    for iEvt = 1:length(eventTypes)
        for iTrig = 1:length(triggers)
            if trigger_match(eventTypes{iEvt}, triggers{iTrig}) && ...
                    ~isempty(regexp(strrep(eventTypes{iEvt}, ' ', ''), '\d+', 'once'))
                count = count + 1;
                break;
            end
        end
    end
end

function diagnostics = empty_diagnostics()
    diagnostics = struct('severity', {}, 'inputName', {}, 'fieldName', {}, ...
        'userValue', {}, 'message', {}, 'suggestion', {});
end

function diag = make_diag(severity, inputName, fieldName, userValue, message, suggestion)
    diag = struct('severity', severity, 'inputName', inputName, ...
        'fieldName', fieldName, 'userValue', userValue, ...
        'message', message, 'suggestion', suggestion);
end

function examples = event_examples(eventTypes, maxCount)
    examples = {};
    for i = 1:length(eventTypes)
        val = eventTypes{i};
        if isempty(val)
            continue;
        end
        if ~any(strcmp(examples, val))
            examples{end+1} = val; %#ok<AGROW>
        end
        if length(examples) >= maxCount
            break;
        end
    end
    if isempty(examples)
        examples = {'(none)'};
    end
end

function out = join_triggers(values)
    if isempty(values)
        out = '';
        return;
    end
    if ~iscell(values)
        values = {values};
    end
    parts = cell(1, length(values));
    for i = 1:length(values)
        parts{i} = trigger_to_char(values{i});
    end
    out = strjoin(parts, ', ');
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
