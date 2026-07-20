## EyeSort

EyeSort toolbox is a free, open-source software for behavior-contingent
labeling of synchronized EEG and eye-tracking events in reading experiments.
It is built as an EEGLAB plugin and builds on the
[EEGLAB Toolbox](https://sccn.ucsd.edu/eeglab/) event and dataset framework.

EyeSort operates between synchronization and analysis: once fixation and
saccade events are already in `EEG.event`, it maps those events onto
text-defined interest areas, applies region and behavior-based labels, and
writes traceable event markers that can feed ERPLAB/BINLISTER workflows, FRP
analyses, or deconvolution models.

We **highly** recommend all new users to read through the user manual to
understand both toolbox functionality and workflow. The README is a short
overview only; the manual covers installation, input preparation, GUI steps,
scripting, quality control, and troubleshooting.

## Documentation And Downloads

- [Latest releases](../../releases)
- [User Manual (PDF)](https://github.com/emac-usf/EyeSort/releases/latest/download/EyeSort_Manual.pdf)
- [Compatible sample datasets + IA file](https://github.com/emac-usf/EyeSort/releases/latest/download/EyeSort_Compatible_Files.zip)

Source code for the plugin is attached automatically by GitHub. Install by
placing the `EyeSort` folder in your EEGLAB `plugins` directory, then launch
EEGLAB and confirm the **EyeSort** menu is present.

**Before using your own data:** work through the manual and sample files first.

## Scope

EyeSort does not preprocess EEG, clean eye-tracker data, correct artifacts, or
synchronize modalities. Those steps must be finished upstream. It assumes
fixation and saccade events are already present in `EEG.event`.

EyeSort outputs can be used in downstream analyses including ERPLAB/BINLISTER
ERP workflows and model-based approaches such as deconvolution.

## Requirements

- MATLAB with [EEGLAB](https://sccn.ucsd.edu/eeglab/) installed and working.
- EyeSort copied into the EEGLAB `plugins` directory.
- EEGLAB `.set` datasets with synchronized fixation and saccade events in
  `EEG.event`.
- A tab-delimited interest-area text file with one row per stimulus/trial,
  condition and item trigger columns, and one column per named text region.

EyeSort defaults match common EYE-EEG synchronized field names, but these are
customizable in the GUI:

- Fixation event type: `R_fixation`
- Fixation X-position field: `fix_avgpos_x`
- Saccade event type: `R_saccade`
- Saccade X-position fields: `sac_startpos_x`, `sac_endpos_x`

## Installation

1. Copy the `EyeSort` folder into the EEGLAB `plugins` directory.
2. Start MATLAB and launch EEGLAB with `eeglab`.
3. Verify that the `EyeSort` menu appears in the EEGLAB toolbar.

If MATLAB reports multiple EyeSort folders on the path, remove duplicate copies
or confirm that the first folder found is the intended version.

## Quick Workflow

The EyeSort menu is organized as a guided sequence:

1. `EyeSort > 1. Load EEG Dataset(s)`
2. `EyeSort > 2a. Setup Interest Areas > Text-Based Sentence Contents and Interest Areas`
3. `EyeSort > 2b. Setup Interest Areas > Inspect Parsed Regions` (optional)
4. `EyeSort > 3. Import IA Columns to Events` (optional)
5. `EyeSort > 4. Eye-Tracking Event Labeling`
6. `EyeSort > Generate BINLISTER BDF File` (optional)
7. `EyeSort > Modify Event Code Format` (optional)
8. `EyeSort > History Scripts > Save processing history script` (optional)

For scripted reruns without the GUI, export a processing script from the
`History Scripts` menu after completing a representative EyeSort workflow.
Single-dataset and batch steps also record evaluable `pop_*` commands for the
current dataset in EEGLAB history (`eegh` and `EEG.history`). Use the exported
processing script to replay an entire multi-file batch.

## Outputs

EyeSort writes traceable metadata to the EEG dataset and event structures. Common
outputs include:

- Optional intermediate datasets: `*_eyesort_ia.set`
- Processed/labeled datasets: `*_processed.set`
- BINLISTER BDF files, typically `eyesort_bins.txt`
- Labeling summary CSV files when label descriptions are available
- Exported processing scripts and sidecar configuration files

Important event-level fields include `original_type`, `eyesort_full_code`,
`eyesort_condition_code`, `eyesort_region_code`, `eyesort_label_code`,
`bdf_full_description`, `current_region`, `current_word`, and behavioral-context
fields such as pass number, previous region, and next region.

## Help And Support

- Use `EyeSort > Help` for an in-EEGLAB workflow summary.
- Use the user manual for tutorials and detailed troubleshooting.
- Open an [issue](https://github.com/emac-usf/EyeSort/issues) on the repository to report bugs.

Contact:

- Sara Milligan: smilliga@usf.edu
- Brandon Snyder: snyderb96@gmail.com
- Elizabeth Schotter: eschotter@usf.edu

## License

EyeSort is distributed under the GPL-3.0-or-later license. See `LICENSE`.

## Citation

Citation information will be added when available.
