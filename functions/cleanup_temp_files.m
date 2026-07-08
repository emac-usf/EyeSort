% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

% Author: Brandon Snyder

function cleanup_temp_files(batchFilePaths)
% CLEANUP_TEMP_FILES - Clean up temporary files created during processing
%
% Usage:
%   cleanup_temp_files(batchFilePaths)
%
% Inputs:
%   batchFilePaths - Cell array of file paths to clean up

batch_label_utils('cleanup', batchFilePaths);
end 