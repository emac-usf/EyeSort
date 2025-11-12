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

function help_button()
    % Function to display help information for EyeSort
    % Called when the user clicks the "Help" button in the EyeSort menu
    
    % Find the plugin directory
    pluginDir = fileparts(which('eegplugin_eyesort'));
    
    % Path to help file
    helpFile = fullfile(pluginDir, 'help.txt');
    
    % Check if help file exists
    if ~exist(helpFile, 'file')
        errordlg('Help file not found. Please check your installation.', 'EyeSort Help Error');
        return;
    end
    
    % Read the contents of the help file
    try
        fid = fopen(helpFile, 'r');
        if fid == -1
            errordlg('Could not open help file.', 'EyeSort Help Error');
            return;
        end
        
        helpContent = textscan(fid, '%s', 'Delimiter', '\n');
        helpContent = helpContent{1};
        fclose(fid);
        
        % Convert cell array of lines to a single string
        helpText = '';
        for i = 1:length(helpContent)
            helpText = [helpText, helpContent{i}, char(10)]; % char(10) is newline
        end
        
        % Create a figure for the help window
        hFig = figure('Name', 'EyeSort Help', ...
               'NumberTitle', 'off', ...
               'MenuBar', 'none', ...
               'ToolBar', 'none', ...
               'Position', [300, 300, 600, 400], ...
               'Color', [0.95, 0.95, 0.95]);
        
        % Create text area with help content
        uicontrol('Parent', hFig, ...
                 'Style', 'edit', ...
                 'String', helpText, ...
                 'Position', [20, 60, 560, 320], ...
                 'Max', 2, ... % Make it multiline
                 'Min', 0, ...
                 'HorizontalAlignment', 'left', ...
                 'Enable', 'inactive', ... % Make it read-only but selectable
                 'BackgroundColor', [1, 1, 1]);
        
        % Add a close button
        uicontrol('Parent', hFig, ...
                 'Style', 'pushbutton', ...
                 'String', 'Close', ...
                 'Position', [250, 20, 100, 30], ...
                 'Callback', @(~,~) close(hFig));
                 
    catch ME
        errordlg(['Error displaying help: ' ME.message], 'EyeSort Help Error');
    end
end 