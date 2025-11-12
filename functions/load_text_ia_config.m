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

function [config, loaded_filename] = load_text_ia_config(filename)
    % LOAD_TEXT_IA_CONFIG - Load Text IA configuration from file
    %
    % Input:
    %   filename - optional filename (if not provided, uses file dialog)
    % Output:
    %   config - struct containing Text IA parameters
    %   loaded_filename - actual filename that was loaded (for tracking save status)
    
    if nargin < 1 || isempty(filename)
        % Show file dialog
        [fname, fpath] = uigetfile('*.mat', 'Select Text IA Configuration File');
        if isequal(fname, 0)
            config = [];
            loaded_filename = '';
            return; % User cancelled
        end
        filename = fullfile(fpath, fname);
    elseif strcmp(filename, 'last_text_ia_config.mat')
        % For last config, look in plugin root directory
        plugin_dir = fileparts(fileparts(mfilename('fullpath')));
        filename = fullfile(plugin_dir, filename);
    end
    
    try
        loaded = load(filename);
        if isfield(loaded, 'config') && isfield(loaded.config, 'config_type') && ...
           strcmp(loaded.config.config_type, 'text_ia')
            config = loaded.config;
            loaded_filename = filename;
            fprintf('Text IA configuration loaded from: %s\n', filename);
        else
            error('Invalid Text IA configuration file format');
        end
    catch ME
        error('Failed to load Text IA configuration: %s', ME.message);
    end
end 