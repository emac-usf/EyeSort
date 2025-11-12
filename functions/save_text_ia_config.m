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

function save_text_ia_config(config, filename)
    % SAVE_TEXT_IA_CONFIG - Save Text IA configuration to file
    % 
    % Input:
    %   config - struct containing all Text IA parameters
    %   filename - optional filename (if not provided, uses default)
    
    if nargin < 2 || isempty(filename)
        % Use default filename with timestamp
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        filename = sprintf('eyesort_text_ia_config_%s.mat', timestamp);
    end
    
    % Ensure .mat extension
    if ~endsWith(filename, '.mat')
        filename = [filename '.mat'];
    end
    
    % Add metadata
    config.saved_date = datestr(now);
    config.eyesort_version = 'EyeSort 2025.0.0';
    config.config_type = 'text_ia';
    
    try
        % For last config, save only to plugin root directory
        plugin_dir = fileparts(fileparts(mfilename('fullpath')));
        if strcmp(filename, 'last_text_ia_config.mat')
            save(fullfile(plugin_dir, filename), 'config');
        else
            save(filename, 'config');
            fprintf('Text IA configuration saved to: %s\n', filename);
            
            % Also save as "last_text_ia_config.mat" for quick access in plugin root
            save(fullfile(plugin_dir, 'last_text_ia_config.mat'), 'config');
        end
        
        % Return success (filename is already displayed in fprintf)
        return;
    catch ME
        error('Failed to save Text IA configuration: %s', ME.message);
    end
end 