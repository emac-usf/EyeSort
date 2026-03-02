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

function config = load_label_config(filename)
% LOAD_LABEL_CONFIG - Load label configuration or queue from file
%
% Usage:
%   config = load_label_config(filename)
%
% Inputs:
%   filename - Input filename (optional, will show file dialog if not provided)
%
% Outputs:
%   config - Label configuration structure (single config) OR cell array of
%            config structs (queue).  Callers should use iscell(config) to
%            distinguish the two cases.

if nargin < 1
    [filename, filepath] = uigetfile('*.mat', 'Load Label Configuration');
    if isequal(filename, 0)
        config = [];
        return;
    end
    filename = fullfile(filepath, filename);
elseif ismember(filename, {'last_label_config.mat', 'last_label_queue.mat'})
    % Resolve named files to the plugin cache directory
    plugin_dir = fileparts(fileparts(mfilename('fullpath')));
    filename = fullfile(plugin_dir, 'cache', filename);
end

try
    loaded = load(filename);
    if isfield(loaded, 'label_queue')
        % Queue format — return cell array of config structs
        config = loaded.label_queue;
        fprintf('Label queue (%d label(s)) loaded from: %s\n', length(config), filename);
    elseif isfield(loaded, 'config')
        % Single config format (backward compatible)
        config = loaded.config;
        fprintf('Label configuration loaded from: %s\n', filename);
    else
        error('Invalid configuration file format (expected ''config'' or ''label_queue'' variable).');
    end
catch ME
    error('Failed to load label configuration: %s', ME.message);
end
end