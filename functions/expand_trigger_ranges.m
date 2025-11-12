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

function expandedTriggers = expand_trigger_ranges(triggerInput)
%EXPAND_TRIGGER_RANGES - Expand trigger ranges like "S1:S112" into individual triggers
%
% This function handles the complex logic of expanding trigger ranges while
% maintaining backward compatibility. It's the only duplication worth centralizing.
%
% INPUT: 
%   triggerInput - String like "S1:S112", "S1, S2, S5:S10", or cell array
%
% OUTPUT:
%   expandedTriggers - Cell array of individual trigger strings
%
% EXAMPLES:
%   expand_trigger_ranges('S1:S5') → {'S1', 'S2', 'S3', 'S4', 'S5'}
%   expand_trigger_ranges('S1, S3, S5:S7') → {'S1', 'S3', 'S5', 'S6', 'S7'}

    % Handle cell array input (already expanded)
    if iscell(triggerInput)
        expandedTriggers = triggerInput;
        return;
    end
    
    % Handle empty or non-string input
    if isempty(triggerInput)
        expandedTriggers = {};
        return;
    end
    
    % Convert to string if needed
    triggerStr = char(triggerInput);
    
    % Split by commas and process each part
    triggerParts = strtrim(strsplit(triggerStr, ','));
    expandedTriggers = {};
    
    for i = 1:length(triggerParts)
        currentPart = triggerParts{i};
        
        % Check if this part contains a range (e.g., "S1:S112")
        if contains(currentPart, ':')
            rangeParts = strsplit(currentPart, ':');
            if length(rangeParts) == 2
                % Extract the numeric parts from the range
                startStr = rangeParts{1};
                endStr = rangeParts{2};
                
                % Extract the prefix (e.g., "S") and the numbers
                startPrefix = regexp(startStr, '^[^0-9]*', 'match', 'once');
                if isempty(startPrefix), startPrefix = ''; end
                
                startNum = str2double(regexp(startStr, '[0-9]+', 'match', 'once'));
                endNum = str2double(regexp(endStr, '[0-9]+', 'match', 'once'));
                
                % Validate the range
                if isnan(startNum) || isnan(endNum) || startNum > endNum
                    warning('Invalid trigger range: %s. Keeping as-is.', currentPart);
                    expandedTriggers{end+1} = currentPart;
                    continue;
                end
                
                % Generate all items in the range
                for j = startNum:endNum
                    expandedTriggers{end+1} = sprintf('%s%d', startPrefix, j);
                end
                
                fprintf('Expanded range %s to %d triggers\n', currentPart, endNum-startNum+1);
            else
                % Invalid range format, keep as-is
                expandedTriggers{end+1} = currentPart;
            end
        else
            % Not a range, add as is
            expandedTriggers{end+1} = currentPart;
        end
    end
end 