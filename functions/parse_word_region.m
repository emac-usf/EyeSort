% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

% Author: Brandon Snyder

function [major, minor] = parse_word_region(word_region)
% PARSE_WORD_REGION - Parse a word region identifier into region and word numbers
%
% Handles two formats:
%   "4.2"  -> region 4, word 2
%   "x1_1" -> region 1, word 1
%
% Usage:
%   [regionNum, wordNum] = parse_word_region(word_region)

if contains(word_region, '.')
    parts = split(word_region, '.');
    major = str2double(parts{1});
    minor = str2double(parts{2});
elseif contains(word_region, '_')
    parts = split(word_region, '_');
    region_part = regexprep(parts{1}, '^x', '');
    major = str2double(region_part);
    minor = str2double(parts{2});
else
    error('Unknown word region format: %s', word_region);
end

if isnan(major) || isnan(minor)
    error('Failed to parse word region: %s', word_region);
end

end
