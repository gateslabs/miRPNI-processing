# miRPNI-processing

Exploratory scripts for loading and visualizing data from the **miRPNI dataset**: a dataset of intramuscular electromyography from Regenerative Peripheral Nerve Interfaces (RPNIs) and residual muscles [1].

This repo is a set of starter notebooks and MATLAB scripts meant to get miRPNI users from the raw dataset files on Zenodo (`.mat` or `.csv` + metadata JSONs) to a usable per-trial table, some plots, and a simple movement classifier. 

> A small sample dataset (`sample_set/`) will be added to this repo separately. This README assumes you have that sample data — see [Getting the sample data](#getting-the-sample-data) below for the exact folder layout the scripts expect.

[1] Nwokeabia, C. et al. *miRPNI: A dataset of intramuscular electromyography from Regenerative Peripheral Nerve Interfaces and residual muscles.* Zenodo (2026). https://doi.org/10.5281/ZENODO.21268334

---

## Contents

| File | Language | What it does |
|---|---|---|
| `mirpni.yaml` | conda | Environment spec with all Python dependencies |
| `mat_to_dataframe.ipynb` | Python | Loads a `.mat` session file into a tidy per-trial `pandas` DataFrame |
| `csv_to_dataframe.ipynb` | Python | Loads a `.csv` + metadata-JSON session export into the same per-trial DataFrame shape |
| `plot_emg.ipynb` | Python | Plots a single trial (or the mean across trials for a task) using the CSV pipeline |
| `plot_emg_mat.m` | MATLAB | Same single-trial / mean-across-task plot, reading directly from a `.mat` file |
| `plot_emg_csv.m` | MATLAB | Same plot, reading from a `.csv` + metadata JSONs |
| `miRPNIvalidation.m` | MATLAB | Stratified k-fold movement classification (decision tree, k-NN, LDA) on MAV features for a single session |
| `miRPNIvalidationALLTrials.m` | MATLAB | Same classification pipeline, but concatenates multiple session `.mat` files first |

There is no top-level driver script — each notebook/script is a standalone starting point you edit and run directly (see the `Settings` cell/section at the top of each one).

---

## Requirements

### Python

All notebooks use the same conda environment, defined in `mirpni.yaml`:

- Python (via conda-forge). Code in this repo has been tested using version 3.14.7. 
- `numpy`, `pandas`, `scipy`
- `h5py`, `mat73` (for reading MATLAB v7.3 `.mat` files)
- `matplotlib`
- `ipykernel` (to run the notebooks in Jupyter/VS Code)

Create and activate the environment with [conda](https://docs.conda.io/) or [mamba](https://mamba.readthedocs.io/):

```bash
git clone https://github.com/gateslabs/miRPNI-processing.git
cd miRPNI-processing

conda env create -f mirpni.yaml
conda activate mirpni
```

Then launch Jupyter (or open the `.ipynb` files in VS Code / another notebook client) from inside the repo:

```bash
jupyter lab
```

### MATLAB

The `.m` scripts were written in MATLAB (R2025b) and use:

- `readtable` / `detectImportOptions` (Data Import)
- `jsondecode` (built-in JSON support)
- Statistics and Machine Learning Toolbox — required only for `miRPNIvalidation.m` / `miRPNIvalidationALLTrials.m` (`cvpartition`, `fitctree`, `fitcknn`, `fitcdiscr`, `confusionchart`)

No MATLAB package manager setup is needed — just open the `.m` files in MATLAB with the repo folder on your path (`Add to Path` or `cd` into the repo).

---

## Getting the sample data

The scripts expect a `sample_set/` folder at the repo root (it's git-ignored, so you add it locally — it isn't tracked in this repo). Once the sample dataset is published alongside this repo, download/unzip it so the layout looks like this:

```
miRPNI-processing/
├── sample_set/
│   ├── movements.json  # TaskNumber->TaskName, shared across all sessions
│   ├── mat/
│   │   └── P1_S12_EMG.mat # one session, v7.3 struct array ("miDB")
│   ├── csv/
│   │   └── P1_S12_EMG1kHz.csv  # same session as a long-format CSV
│   └── meta/
│       ├── P1_S12_meta.json    # per-trial metadata for that session
│       └── P1_metadata.json    # per-channel metadata for that participant
├── mat_to_dataframe.ipynb
├── ...
```

File naming follows `P<participant>_S<session>_...`, so a different sample file will simply have a different `P#_S#` prefix — update the path constants at the top of each script/notebook accordingly (see below).

The sample data ships as a zip (e.g. `sample_set.zip`). Unzip it at the repo root so it produces the `sample_set/` folder shown above.

---

## Data model

Both loading pipelines (`.mat` and `.csv`) converge on the same shape: **one row per trial**, with the following fields:

| Field | Meaning |
|---|---|
| `TrialID` | Unique ID for the trial within the session |
| `TaskNumber` | Numeric movement code (joined against `movements.json` to get `TaskName`) |
| `TaskName` | Human-readable movement name, e.g. "rest", "fist", "pinch", "point" |
| `TrialNumber` | Repetition number of that movement within the session |
| `RestTime` / `HoldTime` | Timing (ms) of the rest and hold/movement periods within the trial |
| `EMG1k` | `(numSamples × numChannels)` array — 1 kHz EMG for the trial |
| `EMG1kf` | Filtered version of `EMG1k` |
| `EMG30k` / `EMG30kf` | Raw/filtered 30 kHz EMG (present in the `.mat` files; dropped by `miRPNIvalidationALLTrials.m` before concatenating sessions) |
| `MAVs` | Mean absolute value features per time window (used by the validation scripts) |

Channel names (e.g. `FDPI`, `FCR`, `Ulnar RPNI`, `Median RPNI`, `EDC`, `EPL`, `FDPS`, `FPL`) come from the participant's `P#_metadata.json`, ordered by `channelNumber` — they are **not** stored in the `.mat`/`.csv` data itself.

---

## Quickstart: Python notebooks

Pick **one** of the two loading pipelines depending on which sample file(s) you have (`.mat` or `.csv`) — both produce an equivalent `trial_meta` DataFrame.

### 1. Build a per-trial DataFrame

- **From a `.mat` file** — open `mat_to_dataframe.ipynb`, update `MAT_PATH` (defaults to `sample_set/mat/P1_S12_EMG.mat`) and `TASKS_PATH` if needed, then run all cells. Note the `TRANSPOSE` flag partway through: it's `False` by default, but check the printed shape from the sanity-check cell — if `EMG1k` prints as `(numChannels, numSamples)` instead of `(numSamples, numChannels)`, flip it to `True`.
- **From a `.csv` export** — open `csv_to_dataframe.ipynb`, update `CSV_PATH`, `META_PATH`, `CHANNELS_PATH`, and `TASKS_PATH` at the top, then run all cells.

Either way you end up with a `trial_meta` DataFrame where each row is a trial and `EMG1k` holds the full `(numSamples, numChannels)` array for that trial.

### 2. Plot EMG

Open `plot_emg.ipynb`. It rebuilds `trial_meta` from the CSV pipeline internally, so just update the path constants at the top (`DATA_PATH`, `TRIAL_META_PATH`, `CH_META_PATH`, `TASKS_PATH`) to match your sample files, then choose what to plot:

- `PLOT_MEAN = False` + `TRIAL_ID = <id>` → plots every channel for one trial
- `PLOT_MEAN = True` + `TASK_NUMBER = <n>` → plots the across-trial mean for a given movement

Run all cells; the final cell renders the figure inline.

---

## Quickstart: MATLAB scripts

### Plotting

- `plot_emg_csv.m` — edit `DATA_PATH`, `CH_META_PATH`, `TRIAL_META_PATH` at the top to point at your sample files, set `TRIAL_ID`/`MOVEMENT_NUMBER`/`PLOT_MEAN`, then run the script. It produces a stacked grid of subplots, one per channel.
- `plot_emg_mat.m` — same idea, but reads straight from the session `.mat` file (`MAT_PATH`, expects a struct array named `miDB` by default — change `STRUCT_VAR` if your file uses a different variable name). You can also choose which signal to plot via `SIGNAL` (`'EMG1k'`, `'EMG1kf'`, `'EMG30k'`, or `'EMG30kf'`) and set `FS` to match (1000 Hz for the `*1k*` signals, 30000 Hz for `*30k*`).

Both scripts have a commented-out `exportgraphics(...)` line at the bottom if you want to save the figure as a PNG instead of just viewing it.

### Movement classification

These two scripts train simple decoders (decision tree, k-NN, LDA) on MAV features to classify movement from EMG, using stratified k-fold cross-validation (the dataset has few trials per movement, so plain train/test splits aren't reliable).

- **`miRPNIvalidation.m`** — single session.
  ```matlab
  load('sample_set/mat/P1_S12_EMG.mat'); % loads a struct array called miDB
  results = miRPNIvalidation(miDB, 1, 'sample_set/movements.json');
  ```
  - `moveset` selects which four movements to classify: `1` = rest/fist/pinch/point, `2` = rest + first three grasps.
  - `win_ms` (optional, default `50`) is the MAV window size in ms.
  - Returns a `struct` with trained models, predictions, per-model accuracy, and pops up a figure with three confusion matrices (one per model).

- **`miRPNIvalidationALLTrials.m`** — same pipeline across multiple session files, concatenated first.
  ```matlab
  matFiles = {'sample_set/mat/P1_S12_EMG.mat'};  % add more session files as you get them
  results = miRPNIvalidationALLTrials(matFiles, 1, 'sample_set/movements.json');
  ```
  It calls `load(fname)` on each file directly (rather than taking a path argument like `plot_emg_mat.m`), so run it from a working directory where those relative paths resolve, or use full paths in `matFiles`. `EMG30k`/`EMG30kf` are dropped before concatenation to keep things light.

---

## Notes / gotchas

- **Array orientation**: MATLAB v7.3 (`.mat`) files loaded via `mat73`/`scipy.io` can come back transposed depending on how they were saved. Always check the printed shape in the sanity-check cell of `mat_to_dataframe.ipynb` before trusting downstream results, and flip `TRANSPOSE` if needed.
- **Paths are hardcoded for the sample data**: every script/notebook has its file paths set as plain constants near the top (`MAT_PATH`, `CSV_PATH`, `DATA_PATH`, etc.), pointing at `sample_set/...` by default. Update them to point at wherever your copy of the real dataset lives — there's no config file or CLI args.
- **`movements.json` is shared**: it's the one metadata file that isn't per-session — it maps `TaskNumber` → `TaskName` for the whole dataset.

---

## Citation

If you use this code or the miRPNI dataset, please cite:

> Nwokeabia, C. et al. miRPNI: A dataset of intramuscular electromyography from Regenerative Peripheral Nerve Interfaces and residual muscles. Zenodo (2026). https://doi.org/10.5281/ZENODO.21268334

## License

MIT — see [`LICENSE`](./LICENSE).
