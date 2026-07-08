% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

% Author: Brandon Snyder

function EEG = normalize_eyesort_event_fields(EEG)
% NORMALIZE_EYESORT_EVENT_FIELDS Keep EyeSort event metadata type-stable.

    if ~isfield(EEG, 'event') || isempty(EEG.event)
        return;
    end

    fields = { ...
        'original_type', ...
        'eyesort_condition_code', ...
        'eyesort_region_code', ...
        'eyesort_label_code', ...
        'eyesort_full_code'};

    for iField = 1:length(fields)
        fieldName = fields{iField};

        if ~isfield(EEG.event, fieldName)
            [EEG.event.(fieldName)] = deal('');
            continue;
        end

        for iEvent = 1:length(EEG.event)
            EEG.event(iEvent).(fieldName) = value_to_char(EEG.event(iEvent).(fieldName));
        end
    end
end
