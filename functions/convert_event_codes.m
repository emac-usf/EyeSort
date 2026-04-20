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

function EEG = convert_event_codes(EEG, eventFormat)
% CONVERT_EVENT_CODES - Convert EEG.event.type to a different format
%
% Rewrites EEG.event.type for all labeled events (those with a non-empty
% eyesort_full_code) using one of the supported format options. The
% canonical CCRRLL code in eyesort_full_code is never modified.
%
% Usage:
%   EEG = convert_event_codes(EEG, eventFormat)
%
% Inputs:
%   EEG         - EEGLAB dataset with labeled events
%   eventFormat - One of:
%       'numeric'          - 6-digit CCRRLL code (ERPLAB compatible)
%       'description'      - Condition + label description
%       'description_word' - Condition + label + fixated word
%       'region_content'   - Full text of the fixated region
%       'original'         - Restore original pre-EyeSort event codes
%
% Outputs:
%   EEG - Dataset with updated EEG.event.type values

if nargin < 2
    error('convert_event_codes requires an eventFormat argument.');
end

validFormats = {'numeric', 'description', 'description_word', 'region_content', 'original'};
if ~ismember(eventFormat, validFormats)
    error('Invalid eventFormat ''%s''. Must be one of: %s', eventFormat, strjoin(validFormats, ', '));
end

if ~isfield(EEG, 'event') || isempty(EEG.event)
    warning('EEG dataset has no events. Nothing to convert.');
    return;
end

if ~isfield(EEG.event, 'eyesort_full_code')
    warning('No eyesort_full_code field found. Dataset may not have been labeled yet.');
    return;
end

convertedCount = 0;

for i = 1:length(EEG.event)
    evt = EEG.event(i);

    if ~ischar(evt.eyesort_full_code) || isempty(evt.eyesort_full_code)
        continue;
    end

    switch eventFormat
        case 'numeric'
            EEG.event(i).type = evt.eyesort_full_code;

        case 'description'
            descType = '';
            if isfield(evt, 'bdf_full_description') && ~isempty(evt.bdf_full_description)
                descType = evt.bdf_full_description;
            end
            if ~isempty(descType)
                EEG.event(i).type = descType;
            else
                EEG.event(i).type = evt.eyesort_full_code;
            end

        case 'description_word'
            descType = '';
            if isfield(evt, 'bdf_full_description') && ~isempty(evt.bdf_full_description)
                descType = evt.bdf_full_description;
            end
            wordText = resolve_word_text(evt);
            if ~isempty(descType) && ~isempty(wordText)
                EEG.event(i).type = [descType ' ' wordText];
            elseif ~isempty(descType)
                EEG.event(i).type = descType;
            else
                EEG.event(i).type = evt.eyesort_full_code;
            end

        case 'region_content'
            regionText = resolve_region_text(evt);
            if ~isempty(regionText)
                EEG.event(i).type = regionText;
            else
                EEG.event(i).type = evt.eyesort_full_code;
            end

        case 'original'
            if isfield(evt, 'original_type') && ~isempty(evt.original_type)
                EEG.event(i).type = evt.original_type;
            end
    end

    convertedCount = convertedCount + 1;
end

EEG.eyesort_event_format = eventFormat;
fprintf('Converted %d event(s) to ''%s'' format.\n', convertedCount, eventFormat);

end

%% Helper: resolve the actual word string from current_word or current_word_text
function wordText = resolve_word_text(evt)
    wordText = '';
    if isfield(evt, 'current_word_text') && ischar(evt.current_word_text) && ~isempty(evt.current_word_text)
        wordText = evt.current_word_text;
        return;
    end
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
end

%% Helper: resolve the full text of the fixated region
function regionText = resolve_region_text(evt)
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
end
