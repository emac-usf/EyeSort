% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

% Author: Brandon Snyder

function has_last_config = check_last_text_ia_config()
    % CHECK_LAST_TEXT_IA_CONFIG - Check if last Text IA config exists
    plugin_dir = fileparts(fileparts(mfilename('fullpath')));
has_last_config = exist(fullfile(plugin_dir, 'cache', 'last_text_ia_config.mat'), 'file') == 2;
end 