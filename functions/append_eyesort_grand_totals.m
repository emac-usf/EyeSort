% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

function append_eyesort_grand_totals(csvPath)
% APPEND_EYESORT_GRAND_TOTALS Append TOTAL rows to an EyeSort summary CSV.

fid = fopen(csvPath, 'r');
if fid == -1
    return;
end
fgetl(fid);
rows = {};
while ~feof(fid)
    line = strtrim(fgetl(fid));
    if ~isempty(line)
        rows{end+1} = line; %#ok<AGROW>
    end
end
fclose(fid);

if isempty(rows)
    return;
end

fdMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
for rowIdx = 1:numel(rows)
    parts = strsplit(rows{rowIdx}, ',');
    if numel(parts) >= 3
        key = strjoin(parts(2:end-1), ',');
        val = str2double(parts{end});
        if isKey(fdMap, key)
            fdMap(key) = fdMap(key) + val;
        else
            fdMap(key) = val;
        end
    end
end

fid = fopen(csvPath, 'a');
if fid == -1
    return;
end
for keyCell = keys(fdMap)
    fprintf(fid, 'TOTAL,%s,%d\n', keyCell{1}, fdMap(keyCell{1}));
end
fclose(fid);
end
