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

function [EEG, com] = pop_generate_bdf(EEG)
% POP_GENERATE_BDF - GUI wrapper for generate_bdf_file function
%
% Usage:
%   >> [EEG, com] = pop_generate_bdf(EEG);
%
% Inputs:
%   EEG   - EEGLAB EEG structure (optional, not used for memory-efficient processing)
%
% Outputs:
%   EEG   - Same as input EEG (unchanged)
%   com   - Command string for EEGLAB history
%
% This function presents a GUI to create a BINLISTER Bin Descriptor File (BDF)
% from labeled events in processed datasets. The function will automatically
% find processed datasets from the output directory specified during dataset loading.
%
% See also: generate_bdf_file, pop_label_datasets

    % Initialize output
    com = '';
    
    % Get EEG from workspace if not provided (for EEGLAB compatibility)
    if nargin < 1 || isempty(EEG)
        try
            EEG = evalin('base', 'EEG');
        catch
            % No EEG in workspace, create empty one for return value
            EEG = [];
        end
    end
    
    % No validation needed - generate_bdf_file will handle finding datasets from:
    % 1. Output directory variables (batch/single mode)
    % 2. Workspace EEG/ALLEEG (if available)
    % 3. User prompt for directory (fallback)
    
    % Create the figure for the GUI
    hFig = figure('Name','Generate BINLISTER BDF File', ...
                  'NumberTitle','off', ...
                  'MenuBar','none', ...
                  'ToolBar','none', ...
                  'Color',[0.94 0.94 0.94], ...
                  'Resize', 'off', ...
                  'Position', [300 300 450 250]);
    
    % Define the UI controls
    uicontrol('Style', 'text', ...
              'String', 'Generate BINLISTER Bin Descriptor File', ...
              'FontSize', 14, ...
              'FontWeight', 'bold', ...
              'Position', [20 200 410 30], ...
              'BackgroundColor', [0.94 0.94 0.94], ...
              'ForegroundColor', [0 0 0]);
          
    % Description text
    uicontrol('Style', 'text', ...
              'String', ['This will analyze the 6-digit label codes in your processed/labeled datasets ' ...
                         'and create a BINLISTER compatible bin descriptor file (BDF).' char(10) char(10) ...
                         'The function will automatically find your processed datasets from the ' ...
                         'output directory you selected earlier.' char(10) char(10) ...
                         'The BDF can be used with BINLISTER for further analysis.'], ...
              'Position', [20 80 410 110], ...
              'HorizontalAlignment', 'left', ...
              'BackgroundColor', [0.94 0.94 0.94], ...
              'ForegroundColor', [0 0 0]);
    
    % Buttons
    uicontrol('Style', 'pushbutton', ...
              'String', 'Cancel', ...
              'Position', [80 20 100 40], ...
              'Callback', @cancelCallback);
          
    uicontrol('Style', 'pushbutton', ...
              'String', 'Generate BDF', ...
              'Position', [220 20 130 40], ...
              'Callback', @generateCallback);
    
    % Wait for user interaction
    uiwait(hFig);
    
    % Callback functions
    function cancelCallback(~, ~)
        close(hFig);
    end
    
    function generateCallback(~, ~)
        try
            % Close the dialog first
            close(hFig);
            
            % Generate BDF file - let it auto-detect datasets from workspace
            % This allows it to find ALLEEG if available, or fall back to EEG
            % The function will handle its own file dialog
            generate_bdf_file();
            
            % Create command string for history
            com = sprintf('EEG = pop_generate_bdf(EEG);');
            
            % Show success message
            msgbox('BDF file created successfully!', 'Success');
            
        catch ME
            % Error handling
            errordlg(['Error generating BDF file: ' ME.message], 'Error');
        end
    end
end 