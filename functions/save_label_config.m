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
% SAVE_LABEL_CONFIG - Save label configuration to file
%
% Usage:
%   save_label_config(config, filename)
%
% Inputs:
%   config   - Label configuration structure
%   filename - Output filename (optional, defaults to 'last_label_config.mat')

if nargin < 2
    filename = 'last_label_config.mat';
end

% For last_label_config.mat, save to plugin root directory
plugin_dir = fileparts(fileparts(mfilename('fullpath')));
is_last_config = strcmp(filename, 'last_label_config.mat');
if is_last_config
    filename = fullfile(plugin_dir, filename);
end

try
    save(filename, 'config');
    if ~is_last_config
        fprintf('Label configuration saved to: %s\n', filename);
    end
catch ME
    error('Failed to save label configuration: %s', ME.message);
end
end 