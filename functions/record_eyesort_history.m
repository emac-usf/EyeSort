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

function EEG = record_eyesort_history(com, EEG)
    % Record an EyeSort command in EEGLAB session and dataset history.

    if nargin < 1 || isempty(com)
        if nargin < 2
            EEG = [];
        end
        return;
    end

    if isstring(com)
        com = char(com);
    end

    if ~ischar(com) || isempty(strtrim(com))
        if nargin < 2
            EEG = [];
        end
        return;
    end

    if nargin < 2
        try
            EEG = evalin('base', 'EEG');
        catch
            EEG = [];
        end
    end

    try
        if ~isempty(EEG) && isstruct(EEG)
            EEG = eegh(com, EEG);
            assignin('base', 'EEG', EEG);
            sync_current_alleeg(EEG);
        else
            eegh(com);
        end
    catch ME
        warning('EyeSort:HistoryRecord', 'Failed to record EyeSort history: %s', ME.message);
    end
end

function sync_current_alleeg(EEG)
    if numel(EEG) ~= 1
        return;
    end

    try
        ALLEEG = evalin('base', 'ALLEEG');
        CURRENTSET = evalin('base', 'CURRENTSET');
        if ~isempty(ALLEEG) && ~isempty(CURRENTSET) && CURRENTSET >= 1 && CURRENTSET <= numel(ALLEEG)
            ALLEEG(CURRENTSET) = EEG;
            assignin('base', 'ALLEEG', ALLEEG);
        end
    catch
        % ALLEEG/CURRENTSET are optional for batch workflows.
    end
end
