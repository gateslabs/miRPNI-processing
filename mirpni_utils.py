"""Shared helpers used by more than one miRPNI notebook.

This module is deliberately limited to "plumbing" -- code that exists to
paper over a loading quirk or interop gotcha, not code that's meant to
teach a concept. If you're looking for the CSV-reshape walkthrough or the
plotting functions themselves, those stay inline in csv_to_dataframe.ipynb
and plot_emg.ipynb on purpose: the whole point of those notebooks is to
show that logic, not hide it behind an import.

Keeping the plumbing here instead of copy-pasted into every notebook is
the point of *this* file: if the channel-lookup or CSV-reshape logic only
exists in one place, it can't drift into two different implementations
the way it did before.
"""

import numpy as np
import pandas as pd
import scipy.io as sio
import mat73


def load_channel_map(ch_meta_path, n_ch_expected=None):
    """Load a participant's channel metadata as {rawColumnIndex: channelName}.

    Returns a plain dict keyed by the 1-indexed raw column position in the
    EMG data (matching EMG1k_1, EMG1k_2, ... in the CSVs and column 1, 2, ...
    in the .mat arrays) -- NOT a name list built by sorting and hoping the
    result lines up positionally with the data. Looking up by the actual
    column index removes the failure mode where a sort silently produces
    the wrong order (e.g. if channelNumber was stored as a JSON string and
    got sorted lexicographically instead of numerically).

    Raises ValueError if channelNumber isn't a clean contiguous 1..n range,
    since that's the one assumption this whole approach depends on -- better
    to fail loudly here than silently mislabel channels downstream.
    """
    channels = pd.read_json(ch_meta_path)

    # Force numeric regardless of whether the JSON stored channelNumber as a
    # bare number or a quoted string -- this is the fix for the sort bug.
    channels['channelNumber'] = pd.to_numeric(channels['channelNumber'])

    ch_map = dict(zip(channels['channelNumber'], channels['channelName']))

    n_ch = n_ch_expected if n_ch_expected is not None else len(ch_map)
    expected = list(range(1, n_ch + 1))
    if sorted(ch_map.keys()) != expected:
        raise ValueError(
            f"channelNumber values {sorted(ch_map.keys())} are not a "
            f"contiguous 1..{n_ch} range -- can't safely map them to raw "
            f"EMG column positions. Check {ch_meta_path}."
        )

    return ch_map


def ordered_channel_names(ch_meta_path, n_ch):
    """Convenience wrapper: return channel names as a plain list, ordered
    to match raw EMG column position 1..n_ch (list index 0 = column 1)."""
    ch_map = load_channel_map(ch_meta_path, n_ch_expected=n_ch)
    return [ch_map[i] for i in range(1, n_ch + 1)]


def load_mat_any(path):
    """Load a .mat file regardless of version: try the HDF5-based v7.3
    reader first, fall back to scipy for older-format files.

    This exists purely to hide the mat73/scipy split -- it's not meant to
    teach anything, which is why it lives here rather than inline in
    mat_to_dataframe.ipynb.
    """
    try:
        mat = mat73.loadmat(path)
    except TypeError:
        mat = sio.loadmat(path, simplify_cells=True)
    return mat


def to_scalar(x):
    """Unwrap a 1-element numpy array (as MATLAB scalars come back) into a
    plain Python scalar."""
    x = np.asarray(x)
    return x.item() if x.size == 1 else x


def build_trial_meta_from_csv(csv_path, meta_path, tasks_path):
    """Build the trial-level DataFrame from a session's CSV + metadata JSON.

    This is the shared implementation of the reshape walkthrough taught
    step-by-step in csv_to_dataframe.ipynb -- see that notebook if you want
    to understand *how* this works. It's centralized here because
    plot_emg.ipynb needs the exact same result and previously duplicated
    this logic verbatim, which is exactly the kind of two-copies-that-can-
    diverge risk this whole cleanup is about.
    """
    trial_meta = pd.read_json(meta_path)

    emg_raw = pd.read_csv(csv_path)
    channel_cols = [c for c in emg_raw.columns if c.startswith('EMG1k_')]
    emg_arrays = {
        tid: group[channel_cols].to_numpy()
        for tid, group in emg_raw.groupby('TrialID')
    }
    trial_meta['EMG1k'] = trial_meta['TrialID'].map(emg_arrays)

    tasks = pd.read_json(tasks_path)
    tasks['TaskNumber'] = tasks['TaskNumber'].astype(int)
    trial_meta['TaskNumber'] = trial_meta['TaskNumber'].astype(int)
    trial_meta = trial_meta.merge(tasks[['TaskNumber', 'TaskName']], on='TaskNumber', how='left')

    return trial_meta, len(channel_cols)
