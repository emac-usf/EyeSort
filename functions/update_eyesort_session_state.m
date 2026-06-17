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

function state = update_eyesort_session_state(varargin)
    % Persist enough EyeSort GUI state to generate a GUI-free session script.

    state = load_existing_state();

    if mod(nargin, 2) ~= 0
        error('update_eyesort_session_state requires name-value arguments.');
    end

    for idx = 1:2:nargin
        name = varargin{idx};
        value = varargin{idx + 1};
        if ~ischar(name) && ~isstring(name)
            error('Session state field names must be strings.');
        end
        state.(char(name)) = value;
    end

    state.updatedDate = datestr(now);

    cacheFile = session_state_file();
    cacheDir = fileparts(cacheFile);
    if ~exist(cacheDir, 'dir')
        mkdir(cacheDir);
    end
    save(cacheFile, 'state');
    assignin('base', 'eyesort_session_state', state);
end

function state = load_existing_state()
    try
        state = evalin('base', 'eyesort_session_state');
        if isstruct(state)
            return;
        end
    catch
    end

    cacheFile = session_state_file();
    if exist(cacheFile, 'file')
        loaded = load(cacheFile);
        if isfield(loaded, 'state') && isstruct(loaded.state)
            state = loaded.state;
            return;
        end
    end

    state = struct();
end

function cacheFile = session_state_file()
    pluginDir = fileparts(fileparts(mfilename('fullpath')));
    cacheFile = fullfile(pluginDir, 'cache', 'last_session_state.mat');
end
