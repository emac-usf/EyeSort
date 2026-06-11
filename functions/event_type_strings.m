% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

function eventTypes = event_type_strings(EEG)
%EVENT_TYPE_STRINGS Return EEG.event.type values as a cellstr.

    eventTypes = {};

    if isempty(EEG) || ~isfield(EEG, 'event') || isempty(EEG.event) || ~isfield(EEG.event, 'type')
        return;
    end

    eventTypes = cell(1, length(EEG.event));
    for iEvt = 1:length(EEG.event)
        eventTypes{iEvt} = value_to_char(EEG.event(iEvt).type);
    end
end
