% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

% Author: Brandon Snyder

function save_text_ia_config(config, filename)
    % SAVE_TEXT_IA_CONFIG - Save Text IA configuration to file
    % 
    % Input:
    %   config - struct containing all Text IA parameters
    %   filename - optional filename (if not provided, uses default)
    
    if nargin < 2 || isempty(filename)
        % Use default filename with timestamp
        timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        filename = sprintf('eyesort_text_ia_config_%s.mat', timestamp);
    end
    
    % Ensure .mat extension
    if ~endsWith(filename, '.mat')
        filename = [filename '.mat'];
    end
    
    % Add metadata
    eyesort_default_values;
    config.saved_date = char(datetime('now', 'Format', 'dd-MMM-yyyy HH:mm:ss'));
    config.eyesort_version = ['EyeSort ' eyesortver];
    config.config_type = 'text_ia';
    
    try
        plugin_dir = fileparts(fileparts(mfilename('fullpath')));
        cache_dir = fullfile(plugin_dir, 'cache');
        if ~exist(cache_dir, 'dir')
            mkdir(cache_dir);
        end
        if strcmp(filename, 'last_text_ia_config.mat')
            save(fullfile(cache_dir, filename), 'config');
        else
            save(filename, 'config');
            fprintf('Text IA configuration saved to: %s\n', filename);
            
            % Also save as "last_text_ia_config.mat" for quick access in cache directory
            save(fullfile(cache_dir, 'last_text_ia_config.mat'), 'config');
        end
        
        % Return success (filename is already displayed in fprintf)
        return;
    catch ME
        error('Failed to save Text IA configuration: %s', ME.message);
    end
end 