% SPDX-License-Identifier: GPL-3.0-or-later
function h = eyesort_waitbar(varargin)
% EYESORT_WAITBAR Waitbar with literal text (no TeX).
%   Filenames like ES02_processed.set contain underscores; MATLAB's default
%   TeX interpreter treats "_" as subscript, which misrenders waitbar text.
%
%   Usage matches waitbar:
%     h = eyesort_waitbar(x, msg, 'Name', name)
%     eyesort_waitbar(x, h, msg)

    h = waitbar(varargin{:});
    disable_tex(h);
end

function disable_tex(h)
    if ~ishandle(h)
        return;
    end
    try
        txt = findall(h, 'Type', 'text');
        if ~isempty(txt)
            set(txt, 'Interpreter', 'none');
        end
    catch
    end
end
