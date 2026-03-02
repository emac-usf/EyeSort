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

function save_label_config(config, filename)
% SAVE_LABEL_CONFIG - Save label configuration or queue to file
%
% Usage:
%   save_label_config(config, filename)
%
% Inputs:
%   config   - Label configuration structure (single) OR cell array of configs (queue)
%   filename - Output filename (optional, defaults to 'last_label_config.mat')
%
% If config is a cell array, it is saved as a 'label_queue' variable so that
% load_label_config can distinguish queues from single configs.

if nargin < 2
    filename = 'last_label_config.mat';
end

% Resolve special filenames to the plugin cache directory
plugin_dir = fileparts(fileparts(mfilename('fullpath')));
cache_dir = fullfile(plugin_dir, 'cache');
is_named_file = ismember(filename, {'last_label_config.mat', 'last_label_queue.mat'});
if is_named_file
    if ~exist(cache_dir, 'dir')
        mkdir(cache_dir);
    end
    filename = fullfile(cache_dir, filename);
end

try
    if iscell(config)
        % Save as a queue (cell array of config structs)
        label_queue = config; 
        save(filename, 'label_queue');
    else
        % Save as a single config struct (existing behaviour)
        save(filename, 'config');
    end
    if ~is_named_file
        fprintf('Label configuration saved to: %s\n', filename);
    end
catch ME
    error('Failed to save label configuration: %s', ME.message);
end
end