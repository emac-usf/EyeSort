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
