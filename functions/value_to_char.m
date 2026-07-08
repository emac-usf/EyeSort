% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

% Author: Brandon Snyder

function out = value_to_char(value)
%VALUE_TO_CHAR Convert scalar event/config values to char safely.

    if iscell(value)
        if isempty(value)
            out = '';
            return;
        end
        value = value{1};
    end

    if isnumeric(value)
        if isempty(value)
            out = '';
        else
            out = num2str(value);
        end
    elseif ischar(value)
        out = value;
    elseif isstring(value)
        if isscalar(value)
            out = char(value);
        else
            out = char(strjoin(value, ','));
        end
    else
        try
            out = char(value);
        catch
            out = '';
        end
    end
end
