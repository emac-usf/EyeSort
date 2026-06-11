% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

function hasErrors = report_diagnostics(diagnostics, titleText, mode)
%REPORT_DIAGNOSTICS Show or throw formatted diagnostics.
%
% mode:
%   'dialog'  - errordlg/warndlg for GUI entry points
%   'command' - error/warning for batch and core functions

    if nargin < 2 || isempty(titleText)
        titleText = 'EyeSort input diagnostics';
    end
    if nargin < 3 || isempty(mode)
        mode = 'command';
    end

    hasErrors = false;
    if isempty(diagnostics)
        return;
    end

    severities = {diagnostics.severity};
    hasErrors = any(strcmpi(severities, 'error'));
    msg = format_diagnostics(diagnostics, titleText);

    if strcmpi(mode, 'dialog')
        if hasErrors
            errordlg(msg, titleText);
        else
            warndlg(msg, titleText);
        end
    else
        if hasErrors
            error('EyeSort:InputDiagnostics', '%s', msg);
        else
            warning('EyeSort:InputDiagnostics', '%s', msg);
        end
    end
end
