## EyeSort

EyeSort is a free, open-source EEGLAB plugin for adding behavior-contingent
event labels to synchronized EEG and eye-movement datasets from reading studies.
It is designed for the stage after fixation and saccade events have already
been synchronized into `EEG.event`, but before ERP averaging, FRP analysis,
BINLISTER binning, or deconvolution modeling.

EyeSort maps fixations to text-defined regions, labels fixation events by
behavioral context, preserves traceability in the EEGLAB event structure, and
supports both interactive GUI workflows and reusable MATLAB scripts.

If you are new to EyeSort, we strongly recommend reading the user manual before
using the plugin on your own data. The README is intentionally brief; the manual
contains the full tutorials, screenshots, quality-control guidance, and
troubleshooting details.

## EyeSort v0.6

This release provides the current EEGLAB menu workflow:

- Load one or more synchronized EEGLAB `.set` datasets.
- Map text-based interest areas to fixation and saccade events.
- Inspect parsed regions before labeling.
- Optionally import additional interest-area file columns into `EEG.event`.
- Queue and apply behavior-contingent fixation labels.
- Generate BINLISTER-compatible BDF files for ERPLAB.
- Modify labeled event marker formats while preserving canonical EyeSort codes.
- Export MATLAB history scripts for GUI-free reruns.

## Documentation And Downloads

- [Latest releases](../../releases)
- [User Manual (PDF)](https://github.com/emac-usf/EyeSort/releases/latest/download/EyeSort_Manual.pdf)
- [Sample datasets and interest-area file](https://github.com/emac-usf/EyeSort/releases/latest/download/EyeSort_compatible_files.zip)

The user manual is the authoritative guide for installation, input preparation,
step-by-step GUI use, scripted reproducibility, quality control, and
troubleshooting.

## Scope

EyeSort does not perform raw EEG preprocessing, eye-tracker preprocessing,
artifact correction, or EEG/eye-tracking synchronization. It assumes those
upstream steps have already produced fixation and saccade events in `EEG.event`.

EyeSort outputs can be used in downstream analyses including ERPLAB/BINLISTER
ERP workflows and model-based approaches such as deconvolution.

## Requirements

- MATLAB with EEGLAB installed and working.
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
3. `EyeSort > 2b. Setup Interest Areas > Inspect Parsed Regions`
4. `EyeSort > 3. Import IA Columns to Events` (optional)
5. `EyeSort > 4. Eye-Tracking Event Labeling`
6. `EyeSort > Generate BINLISTER BDF File` (optional)
7. `EyeSort > Modify Event Code Format` (optional)
8. `EyeSort > History Scripts > Save processing history script` (optional)

For scripted reruns without the GUI, export a processing script from the
`History Scripts` menu after completing a representative EyeSort workflow.

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
- Open an issue on the repository to report bugs.

Contact:

- Sara Milligan: smilliga@usf.edu
- Brandon Snyder: snyderb96@gmail.com
- Elizabeth Schotter: eschotter@usf.edu

## License

EyeSort is distributed under the GPL-3.0-or-later license. See `LICENSE`.

## Citation

Citation information will be added when available.
