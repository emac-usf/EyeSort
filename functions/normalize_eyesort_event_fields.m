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
