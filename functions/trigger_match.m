% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

% Author: Brandon Snyder

function [isMatch, matchMode] = trigger_match(eventTrigger, configTrigger)
% TRIGGER_MATCH Match user trigger input against an EEG event code.
%
% Matching is intentionally format-open: exact text (ignoring spaces) is
% preferred, and numeric-only user inputs may match the numeric portion of
% any event code. EyeSort does not assume or add an "S" prefix.

    eventNorm = strrep(strtrim(value_to_char(eventTrigger)), ' ', '');
    configNorm = strrep(strtrim(value_to_char(configTrigger)), ' ', '');

    isMatch = false;
    matchMode = 'none';

    if isempty(eventNorm) || isempty(configNorm)
        return;
    end

    if strcmp(eventNorm, configNorm)
        isMatch = true;
        matchMode = 'exact';
        return;
    end

    configIsNumberOnly = ~isempty(regexp(configNorm, '^\d+$', 'once'));
    if configIsNumberOnly
        eventNum = regexp(eventNorm, '\d+', 'match', 'once');
        configNum = regexp(configNorm, '\d+', 'match', 'once');
        if ~isempty(eventNum) && ~isempty(configNum) && strcmp(eventNum, configNum)
            isMatch = true;
            matchMode = 'numeric';
        end
    end
end
