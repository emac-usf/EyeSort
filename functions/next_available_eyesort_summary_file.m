% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

function summaryPath = next_available_eyesort_summary_file(outputDir)
% NEXT_AVAILABLE_EYESORT_SUMMARY_FILE Return the next unused summary CSV path.

sessionIdx = 1;
summaryPath = fullfile(outputDir, sprintf('eyesort_labeling_summary_%03d.csv', sessionIdx));
while exist(summaryPath, 'file')
    sessionIdx = sessionIdx + 1;
    summaryPath = fullfile(outputDir, sprintf('eyesort_labeling_summary_%03d.csv', sessionIdx));
end
end
