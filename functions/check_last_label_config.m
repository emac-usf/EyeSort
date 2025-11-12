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

function exists = check_last_label_config()
% CHECK_LAST_LABEL_CONFIG - Check if last label configuration exists
%
% Usage:
%   exists = check_last_filter_config()
%
% Outputs:
%   exists - True if 'last_filter_config.mat' exists, false otherwise

plugin_dir = fileparts(fileparts(mfilename('fullpath')));
exists = exist(fullfile(plugin_dir, 'last_label_config.mat'), 'file') == 2;
end 