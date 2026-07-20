% SPDX-License-Identifier: GPL-3.0-or-later
% EyeSort - Region-aware eye-tracking event labeling for EEGLAB
% Copyright (C) 2025 Eye Movements & Cognition Lab (USF)
% Copyright (C) 2025 Brandon Snyder, Sara Milligan, Elizabeth Schotter

% Author: Brandon Snyder

function scriptPath = save_eyesort_session_script(varargin)
    % SAVE_EYESORT_SESSION_SCRIPT - Export a GUI-free EyeSort processing script.
    %
    % Captures the EyeSort pipeline settings recorded during GUI use (Steps 1–4)
    % and writes a standalone .m file that re-runs Text IA, optional column import,
    % label queue application, and optional BDF generation without opening GUIs.
    %
    % Generated scripts default to scanning inputDir for *.set files so users
    % can edit one directory path when reusing the pipeline for a new batch. The
    % exact Step 1 file list is also written as a commented fallback.
    %
    % Sidecar files (Text IA config, label queue, interest-area text files) are
    % copied next to the saved script so the bundle is portable.
    %
    % Inputs:
    %   scriptPathOut - optional full path for the output script; skips uiputfile
    %                   (used by automated tests). Legacy scope arguments are
    %                   accepted but ignored.
    %
    % Output:
    %   scriptPath   - path to the written script, or '' if the user cancelled
    %
    % See also: update_eyesort_session_state, record_eyesort_history

    scriptPathOut = parse_script_path_arg(varargin{:});

    % Recover pipeline settings from base workspace or cache, then validate.
    state = load_session_state();
    state = fill_state_from_workspace(state);
    validate_session_state(state);

    % Generated scripts use inputDir by default, but document the exact Step 1 files.
    inputDir = get_input_dir(state);
    inputFiles = get_input_files(state);

    % Resolve output path (dialog or caller-supplied path for tests).
    if ~isempty(scriptPathOut)
        scriptPath = char(scriptPathOut);
        [filepath, baseName, ext] = fileparts(scriptPath);
        if isempty(ext)
            ext = '.m';
        end
        if isempty(filepath)
            filepath = pwd;
        end
        scriptPath = fullfile(filepath, [baseName ext]);
    else
        defaultName = 'eyesort_processing_script.m';
        [filename, filepath] = uiputfile('*.m', 'Save EyeSort processing script', defaultName);
        if isequal(filename, 0)
            scriptPath = '';
            return;
        end
        scriptPath = fullfile(filepath, filename);
    end
    [~, baseName] = fileparts(scriptPath);

    % Bundle portable sidecars beside the script and rewrite Text IA paths.
    textConfigPath = copy_sidecar(state.textIAConfigPath, filepath, [baseName '_text_ia_config.mat']);
    localize_text_ia_files(textConfigPath, filepath, baseName);
    labelQueuePath = '';
    if isfield(state, 'labelQueueConfigPath') && ~isempty(state.labelQueueConfigPath) && exist(state.labelQueueConfigPath, 'file')
        labelQueuePath = copy_sidecar(state.labelQueueConfigPath, filepath, [baseName '_label_queue.mat']);
    end

    fid = fopen(scriptPath, 'w');
    if fid == -1
        error('Could not open script for writing: %s', scriptPath);
    end

    cleanupObj = onCleanup(@() fclose(fid));

    % --- Generated script: setup ---
    fprintf(fid, '%% EyeSort processing script generated on %s\n', datestr(now));
    fprintf(fid, '%% Re-runs the EyeSort pipeline without opening EyeSort GUIs.\n\n');
    fprintf(fid, 'clear EEG;\n\n');
    fprintf(fid, 'pluginDir = %s;\n', matlab_literal(plugin_root()));
    fprintf(fid, 'addpath(pluginDir);\n');
    fprintf(fid, 'addpath(fullfile(pluginDir, ''pop_functions''));\n');
    fprintf(fid, 'addpath(fullfile(pluginDir, ''functions''));\n\n');
    fprintf(fid, 'inputDir = %s; %% edit this path to process a different batch\n', matlab_literal(inputDir));
    fprintf(fid, 'datasetFiles = dir(fullfile(inputDir, ''*.set''));\n');
    fprintf(fid, 'inputFiles = arrayfun(@(f) fullfile(f.folder, f.name), datasetFiles, ''UniformOutput'', false);\n');
    fprintf(fid, 'if isempty(inputFiles)\n');
    fprintf(fid, '    error(''No .set files found in inputDir: %%s'', inputDir);\n');
    fprintf(fid, 'end\n\n');
    fprintf(fid, '%% Files selected in EyeSort Step 1.\n');
    fprintf(fid, '%% To process only this original selection, comment out the inputDir scan above\n');
    fprintf(fid, '%% and uncomment the inputFiles block below.\n');
    write_commented_cellstr_assignment(fid, 'inputFiles', inputFiles);
    fprintf(fid, '\n');
    fprintf(fid, 'outputDir = %s;\n', matlab_literal(get_output_dir(state, filepath)));
    fprintf(fid, 'textIAConfig = %s;\n', matlab_literal(textConfigPath));
    fprintf(fid, 'labelQueueConfig = %s;\n', matlab_literal(labelQueuePath));
    write_cellstr_assignment(fid, 'importColumns', get_import_columns(state));
    fprintf(fid, 'conflictResolution = %s; %% change to ''no'' if you prefer to keep existing labels\n', ...
        matlab_literal(get_conflict_resolution(state)));
    fprintf(fid, 'generateBDF = %s; %% set false to skip BINLISTER BDF generation\n', logical_literal(should_generate_bdf(state, labelQueuePath)));
    fprintf(fid, 'generateSummary = true; %% set false to skip the labeling summary CSV\n');
    fprintf(fid, 'bdfOutputFile = fullfile(outputDir, ''eyesort_bins.txt'');\n');
    fprintf(fid, 'summaryOutputFile = next_available_eyesort_summary_file(outputDir);\n\n');

    % --- Generated script: per-dataset pipeline loop ---
    fprintf(fid, 'if ~exist(outputDir, ''dir'')\n');
    fprintf(fid, '    mkdir(outputDir);\n');
    fprintf(fid, 'end\n\n');
    fprintf(fid, 'textCfg = load_text_ia_config(textIAConfig);\n');
    fprintf(fid, 'txtFilePath = textCfg.txtFileList;\n');
    fprintf(fid, 'if iscell(txtFilePath)\n');
    fprintf(fid, '    txtFilePath = txtFilePath{1};\n');
    fprintf(fid, 'end\n\n');
    fprintf(fid, 'summaryRows = {};\n\n');

    fprintf(fid, 'for fileIdx = 1:numel(inputFiles)\n');
    fprintf(fid, '    inputFile = inputFiles{fileIdx};\n');
    fprintf(fid, '    [~, datasetName] = fileparts(inputFile);\n');
    fprintf(fid, '    fprintf(''\\n=== EyeSort script %%d/%%d: %%s ===\\n'', fileIdx, numel(inputFiles), datasetName);\n\n');
    fprintf(fid, '    EEG = pop_loadset(''filename'', inputFile);\n');
    fprintf(fid, '    EEG = compute_text_based_ia(EEG, textIAConfig, ''reportMode'', ''command'');\n\n');
    fprintf(fid, '    if ~isempty(importColumns)\n');
    fprintf(fid, '        EEG = import_ia_columns(EEG, txtFilePath, textCfg.conditionColName, textCfg.itemColName, importColumns, ''command'');\n');
    fprintf(fid, '    end\n\n');
    fprintf(fid, '    if ~isempty(labelQueueConfig) && exist(labelQueueConfig, ''file'')\n');
    fprintf(fid, '        labelQueue = load_label_config(labelQueueConfig);\n');
    fprintf(fid, '        if ~iscell(labelQueue)\n');
    fprintf(fid, '            labelQueue = {labelQueue};\n');
    fprintf(fid, '        end\n');
    fprintf(fid, '        startLabelCount = 0;\n');
    fprintf(fid, '        if isfield(EEG, ''eyesort_label_count'') && ~isempty(EEG.eyesort_label_count) && EEG.eyesort_label_count >= 0\n');
    fprintf(fid, '            startLabelCount = EEG.eyesort_label_count;\n');
    fprintf(fid, '        end\n');
    fprintf(fid, '        for labelIdx = 1:numel(labelQueue)\n');
    fprintf(fid, '            labelParams = convert_config_to_params(labelQueue{labelIdx});\n');
    fprintf(fid, '            preFD = {};\n');
    fprintf(fid, '            if generateSummary && isfield(EEG, ''event'') && isfield(EEG.event, ''bdf_full_description'')\n');
    fprintf(fid, '                preFD = {EEG.event.bdf_full_description};\n');
    fprintf(fid, '            end\n');
    fprintf(fid, '            [EEG, ~] = label_datasets_core(EEG, labelParams{:}, ...\n');
    fprintf(fid, '                ''labelCount'', startLabelCount + labelIdx, ...\n');
    fprintf(fid, '                ''conflictResolution'', conflictResolution, ...\n');
    fprintf(fid, '                ''showRegionMap'', false);\n');
    fprintf(fid, '            if generateSummary && isfield(EEG, ''event'') && isfield(EEG.event, ''bdf_full_description'')\n');
    fprintf(fid, '                postFD = {EEG.event.bdf_full_description};\n');
    fprintf(fid, '                preExpanded = repmat({''''}, size(postFD));\n');
    fprintf(fid, '                nPre = min(numel(preFD), numel(postFD));\n');
    fprintf(fid, '                if nPre > 0\n');
    fprintf(fid, '                    preExpanded(1:nPre) = preFD(1:nPre);\n');
    fprintf(fid, '                end\n');
    fprintf(fid, '                isNew = ~cellfun(@isempty, postFD) & ~strcmp(postFD, preExpanded);\n');
    fprintf(fid, '                newlyFD = postFD(isNew);\n');
    fprintf(fid, '                uniqueNewFD = unique(newlyFD);\n');
    fprintf(fid, '                for summaryIdx = 1:numel(uniqueNewFD)\n');
    fprintf(fid, '                    summaryRows{end+1} = sprintf(''%%s,%%s,%%d'', datasetName, uniqueNewFD{summaryIdx}, sum(strcmp(newlyFD, uniqueNewFD{summaryIdx}))); %%#ok<SAGROW>\n');
    fprintf(fid, '                end\n');
    fprintf(fid, '            end\n');
    fprintf(fid, '        end\n');
    fprintf(fid, '    end\n\n');
    fprintf(fid, '    outputPath = fullfile(outputDir, [datasetName ''_processed.set'']);\n');
    fprintf(fid, '    pop_saveset(EEG, ''filename'', outputPath, ''savemode'', ''twofiles'');\n');
    fprintf(fid, '    fprintf(''Saved: %%s\\n'', outputPath);\n');
    fprintf(fid, 'end\n\n');

    % --- Generated script: optional labeling summary CSV ---
    fprintf(fid, 'if generateSummary\n');
    fprintf(fid, '    if isempty(summaryRows)\n');
    fprintf(fid, '        fprintf(''\\nNo labeling summary rows were generated.\\n'');\n');
    fprintf(fid, '    else\n');
    fprintf(fid, '        dsNames = cellfun(@(row) strtok(row, '',''), summaryRows, ''UniformOutput'', false);\n');
    fprintf(fid, '        [~, sortIdx] = sort(dsNames);\n');
    fprintf(fid, '        fidSummary = fopen(summaryOutputFile, ''w'');\n');
    fprintf(fid, '        if fidSummary == -1\n');
    fprintf(fid, '            error(''Could not open summary file for writing: %%s'', summaryOutputFile);\n');
    fprintf(fid, '        end\n');
    fprintf(fid, '        fprintf(fidSummary, ''Dataset,FullDescription,TrialCount\\n'');\n');
    fprintf(fid, '        for rowIdx = sortIdx\n');
    fprintf(fid, '            fprintf(fidSummary, ''%%s\\n'', summaryRows{rowIdx});\n');
    fprintf(fid, '        end\n');
    fprintf(fid, '        fclose(fidSummary);\n');
    fprintf(fid, '        append_eyesort_grand_totals(summaryOutputFile);\n');
    fprintf(fid, '        fprintf(''\\nLabeling summary saved: %%s\\n'', summaryOutputFile);\n');
    fprintf(fid, '    end\n');
    fprintf(fid, 'end\n\n');

    % --- Generated script: batch BDF from processed output directory ---
    fprintf(fid, 'if generateBDF\n');
    fprintf(fid, '    fprintf(''\\nGenerating BINLISTER BDF file...\\n'');\n');
    fprintf(fid, '    generate_bdf_file(outputDir, bdfOutputFile);\n');
    fprintf(fid, 'end\n\n');
    fprintf(fid, 'fprintf(''\\nEyeSort script complete.\\n'');\n');

    clear cleanupObj;
    if isempty(scriptPathOut)
        msgbox(sprintf('EyeSort script saved to:\n%s', scriptPath), 'EyeSort - Script Saved', 'help');
    end
end

function scriptPathOut = parse_script_path_arg(varargin)
    % Preserve old test-call shapes while removing user-facing scope choices.
    scriptPathOut = '';
    if nargin < 1
        return;
    end
    firstArg = varargin{1};
    if ischar(firstArg) || isstring(firstArg)
        firstArgText = lower(char(firstArg));
        if strcmp(firstArgText, 'session') || strcmp(firstArgText, 'dataset')
            if nargin >= 2
                scriptPathOut = varargin{2};
            end
            return;
        end
    end
    scriptPathOut = firstArg;
end

function state = load_session_state()
    % Prefer live base-workspace state; fall back to cached .mat from last session.
    try
        state = evalin('base', 'eyesort_session_state');
        if isstruct(state)
            return;
        end
    catch
    end

    statePath = fullfile(plugin_root(), 'cache', 'last_session_state.mat');
    if exist(statePath, 'file')
        loaded = load(statePath);
        if isfield(loaded, 'state') && isstruct(loaded.state)
            state = loaded.state;
            return;
        end
    end

    state = struct();
end

function state = fill_state_from_workspace(state)
    % Backfill missing fields from EEG in base and default cache sidecar paths.
    if ~isfield(state, 'inputFiles') || isempty(state.inputFiles)
        try
            EEG = evalin('base', 'EEG');
            if isfield(EEG, 'filename') && ~isempty(EEG.filename)
                state.inputFiles = {fullfile(EEG.filepath, EEG.filename)};
                state.inputDir = EEG.filepath;
            end
        catch
        end
    end
    if (~isfield(state, 'inputDir') || isempty(state.inputDir)) && isfield(state, 'inputFiles') && ~isempty(state.inputFiles)
        state.inputDir = common_parent_directory(state.inputFiles);
    end

    if ~isfield(state, 'textIAConfigPath') || isempty(state.textIAConfigPath)
        candidate = fullfile(plugin_root(), 'cache', 'last_text_ia_config.mat');
        if exist(candidate, 'file')
            state.textIAConfigPath = candidate;
        end
    end

    if ~isfield(state, 'labelQueueConfigPath') || isempty(state.labelQueueConfigPath)
        candidate = fullfile(plugin_root(), 'cache', 'last_label_queue.mat');
        if exist(candidate, 'file')
            state.labelQueueConfigPath = candidate;
        end
    end
end

function inputDir = get_input_dir(state)
    % Return explicit inputDir, or infer a shared parent when all files match.
    if isfield(state, 'inputDir') && ~isempty(state.inputDir)
        inputDir = state.inputDir;
        return;
    end
    if isfield(state, 'inputFiles') && ~isempty(state.inputFiles)
        inputDir = common_parent_directory(state.inputFiles);
        return;
    end
    inputDir = '';
end

function validate_session_state(state)
    % Require Step 1 datasets and Step 2 Text IA config before script export.
    if ~isfield(state, 'inputFiles') || isempty(state.inputFiles)
        error('No EyeSort input dataset paths were captured. Run Step 1 before saving a script.');
    end
    inputDir = get_input_dir(state);
    if isempty(inputDir)
        error('No input dataset directory was captured. Run Step 1 before saving a processing script.');
    end
    if ~exist(inputDir, 'dir')
        error('Captured input dataset directory does not exist: %s', inputDir);
    end
    if ~isfield(state, 'textIAConfigPath') || isempty(state.textIAConfigPath) || ~exist(state.textIAConfigPath, 'file')
        error('No Step 2 Text IA configuration was found. Run Step 2 before saving a script.');
    end
end

function inputFiles = get_input_files(state)
    % Exact Step 1 file list, used as a commented reproducibility fallback.
    inputFiles = state.inputFiles;
    if ischar(inputFiles) || isstring(inputFiles)
        inputFiles = cellstr(inputFiles);
    end
end

function parentDir = common_parent_directory(inputFiles)
    % Return the shared directory when all paths agree; otherwise the grandparent.
    if ischar(inputFiles) || isstring(inputFiles)
        inputFiles = cellstr(inputFiles);
    end
    parentDir = '';
    if isempty(inputFiles)
        return;
    end
    [parentDir, ~, ~] = fileparts(inputFiles{1});
    for idx = 2:numel(inputFiles)
        [candidateDir, ~, ~] = fileparts(inputFiles{idx});
        if ~strcmp(parentDir, candidateDir)
            % Mixed directories: fall back to parent of the first file's folder.
            parentDir = fileparts(parentDir);
            return;
        end
    end
end

function outputDir = get_output_dir(state, fallbackDir)
    % Use Step 1 output directory when recorded; otherwise the script folder.
    if isfield(state, 'outputDir') && ~isempty(state.outputDir)
        outputDir = state.outputDir;
    else
        outputDir = fallbackDir;
    end
end

function importColumns = get_import_columns(state)
    % Step 3 column import list; empty when import was not run in this session.
    if isfield(state, 'importColumns') && ~isempty(state.importColumns)
        importColumns = state.importColumns;
    else
        importColumns = {};
    end
end

function conflictResolution = get_conflict_resolution(state)
    % Label conflict policy from Step 4; default replaces existing labels.
    if isfield(state, 'conflictResolution') && ~isempty(state.conflictResolution)
        conflictResolution = state.conflictResolution;
    else
        conflictResolution = 'yes';
    end
end

function generateBDF = should_generate_bdf(state, labelQueuePath)
    % Honor explicit Step 5 flag; otherwise enable BDF when a label queue exists.
    if isfield(state, 'generateBDF') && ~isempty(state.generateBDF)
        generateBDF = logical(state.generateBDF);
    else
        generateBDF = ~isempty(labelQueuePath);
    end
end

function sidecarPath = copy_sidecar(sourcePath, targetDir, targetName)
    % Copy a config .mat beside the script; skip copy when already in place.
    if ~exist(sourcePath, 'file')
        error('Required sidecar file not found: %s', sourcePath);
    end
    sidecarPath = fullfile(targetDir, targetName);
    if ~strcmp(sourcePath, sidecarPath)
        [copyOk, copyMsg] = copyfile(sourcePath, sidecarPath);
        if ~copyOk
            error('Could not copy sidecar file "%s" to "%s": %s', sourcePath, sidecarPath, copyMsg);
        end
    end
end

function localize_text_ia_files(textConfigPath, targetDir, scriptBaseName)
    % Copy interest-area text files next to the script and update config paths.
    loaded = load(textConfigPath);
    if ~isfield(loaded, 'config') || ~isfield(loaded.config, 'txtFileList')
        return;
    end

    config = loaded.config;
    txtFiles = config.txtFileList;
    wasCell = iscell(txtFiles);
    if isstring(txtFiles)
        txtFiles = cellstr(txtFiles);
        wasCell = true;
    end
    if ~wasCell
        txtFiles = {txtFiles};
    end
    if isempty(txtFiles)
        error('Text IA configuration does not contain any interest area text files.');
    end

    copiedFiles = txtFiles;
    for idx = 1:numel(txtFiles)
        sourcePath = txtFiles{idx};
        if isstring(sourcePath)
            sourcePath = char(sourcePath);
        end
        if ~ischar(sourcePath) || isempty(sourcePath)
            error('Text IA configuration contains an invalid interest area text file path at index %d.', idx);
        end
        if ~exist(sourcePath, 'file')
            error('Interest area text file not found while saving EyeSort script: %s', sourcePath);
        end
        [~, sourceName, sourceExt] = fileparts(sourcePath);
        % Single file: scriptBaseName_interest_areas.ext; multiple: indexed names.
        if numel(txtFiles) == 1
            targetName = sprintf('%s_interest_areas%s', scriptBaseName, sourceExt);
        else
            targetName = sprintf('%s_interest_areas_%02d_%s%s', scriptBaseName, idx, sourceName, sourceExt);
        end
        targetPath = fullfile(targetDir, targetName);
        if ~strcmp(sourcePath, targetPath)
            [copyOk, copyMsg] = copyfile(sourcePath, targetPath);
            if ~copyOk
                error('Could not copy interest area text file "%s" to "%s": %s', ...
                    sourcePath, targetPath, copyMsg);
            end
        end
        copiedFiles{idx} = targetPath;
    end

    % Persist rewritten paths so load_text_ia_config resolves local copies.
    if wasCell
        config.txtFileList = copiedFiles;
    else
        config.txtFileList = copiedFiles{1};
    end
    save(textConfigPath, 'config');
end

function write_cellstr_assignment(fid, varName, values)
    % Emit a multi-line cellstr assignment with safely quoted string literals.
    if ischar(values) || isstring(values)
        values = cellstr(values);
    end
    if isempty(values)
        fprintf(fid, '%s = {};\n', varName);
        return;
    end
    fprintf(fid, '%s = { ...\n', varName);
    for idx = 1:numel(values)
        fprintf(fid, '    %s', matlab_literal(values{idx}));
        if idx < numel(values)
            fprintf(fid, '; ...\n');
        else
            fprintf(fid, '\n');
        end
    end
    fprintf(fid, '};\n');
end

function write_commented_cellstr_assignment(fid, varName, values)
    % Emit a commented cellstr assignment users can uncomment for exact replay.
    if ischar(values) || isstring(values)
        values = cellstr(values);
    end
    fprintf(fid, '%% %s = { ...\n', varName);
    for idx = 1:numel(values)
        fprintf(fid, '%%     %s', matlab_literal(values{idx}));
        if idx < numel(values)
            fprintf(fid, '; ...\n');
        else
            fprintf(fid, '\n');
        end
    end
    fprintf(fid, '%% };\n');
end

function literal = matlab_literal(value)
    % Quote a char/string for insertion into generated MATLAB source code.
    if isstring(value)
        value = char(value);
    end
    value = strrep(value, '''', '''''');
    literal = ['''' value ''''];
end

function literal = logical_literal(value)
    % Render a logical as lowercase 'true'/'false' for generated scripts.
    if value
        literal = 'true';
    else
        literal = 'false';
    end
end

function root = plugin_root()
    % EyeSort plugin root (parent of functions/).
    root = fileparts(fileparts(mfilename('fullpath')));
end
