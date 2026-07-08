% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

function message = format_diagnostics(diagnostics, titleText)
% FORMAT_DIAGNOSTICS Convert diagnostic structs into readable text.

    if nargin < 2 || isempty(titleText)
        titleText = 'EyeSort input diagnostics';
    end

    if isempty(diagnostics)
        message = '';
        return;
    end

    lines = {titleText, ''};
    for i = 1:length(diagnostics)
        diag = diagnostics(i);
        severity = upper(diag.severity);
        lines{end+1} = sprintf('%s: %s', severity, diag.inputName); %#ok<AGROW>
        if isfield(diag, 'userValue') && ~isempty(diag.userValue)
            lines{end+1} = sprintf('Input: %s', diag.userValue); %#ok<AGROW>
        end
        lines{end+1} = diag.message; %#ok<AGROW>
        if isfield(diag, 'suggestion') && ~isempty(diag.suggestion)
            lines{end+1} = sprintf('Suggested fix: %s', diag.suggestion); %#ok<AGROW>
        end
        lines{end+1} = ''; %#ok<AGROW>
    end

    message = strjoin(lines, sprintf('\n'));
end
