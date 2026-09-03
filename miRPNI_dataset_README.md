**A dataset of intramuscular electromyography from Regenerative Peripheral Nerve Interfaces (RPNIs) and residual muscles**

Date: 2026-09-02
DOI: https://doi.org/10.5281/ZENODO.21268334

> This document describes the **data** only. For code to load, plot, and classify this data, see the companion GitHub repository: [gateslabs/miRPNI-processing](https://github.com/gateslabs/miRPNI-processing). That repo's own README covers environment setup and usage.

---

## Dataset contacts
Chinwendu Nwokeabia [cnwoke@umich.edu]

Cynthia Chestek [cchestek@umich.edu]

Deanna Gates [gatesd@umich.edu]

## Funding

Research reported in this publication was supported by the National Institute of Neurological Disorders and Stroke of the National Institutes of Health under Award Numbers R01NS105132 and T32NS115724.

## License

This dataset is licensed under **CC BY-NC-SA 4.0**.

## Ethical approvals

Approval of all ethical and experimental procedures and protocols was granted by the University of Michigan's Medical School IRB (IRB-MED) under Application No. HUM00124839, and performed in line with the Declaration of Helsinki. This study is also registered on clinicaltrials.gov under NCT03260400.

## Conflicts of interest

P. Cederna and A. Vaskov are employed in leadership roles and hold equity in Blue Arbor Technologies, Inc., a company that makes prosthetic control systems. P. Cederna and C. Chestek are inventors of patents US10314725 and US10779963 related to this work. This intellectual property is held by the University of Michigan and has been optioned by Blue Arbor Technologies, Inc. These interests have been reviewed and are managed by the University of Michigan in accordance with its Conflict of Interest policy.

---

## Overview

Data were collected from four people with transradial limb loss who had regenerative peripheral nerve interfaces (RPNIs) created on their median, ulnar, and/or radial nerves. Up to 12 bipolar electrodes (Synapse Biomedical, Oberlin, OH, USA) were placed in RPNIs and residual muscles (see [Channel maps](#channel-maps) below).

Data were collected monthly while participants were enrolled in the study (up to 6.5 years to date). The dataset includes data from up to twelve sessions per participant (42 total) across the study period. During each session, participants mirrored a series of hand gestures displayed on a computer screen with their phantom limb, while intramuscular EMG (imEMG) was recorded at 30 kHz using a neural processor (Cerebus, Blackrock Microsystems, Salt Lake City, UT, USA). Each movement was repeated up to 5 times.

Data were collected between June 2018 and May 2024 at the University of Michigan, Ann Arbor, MI, United States. A more detailed description of the data collection methods is available in [1].

---

## File organization

There are up to twelve evenly spaced sessions per participant (42 files total). Session files follow the naming convention:

```
<ParticipantID>_<SessionNumber>_EMG.mat
```

For example, Participant 1's data for session 8 is `P1_S8_EMG.mat`.

Data were originally sampled at 30 kHz but downsampled to 1 kHz for most sessions to save space. The 30 kHz data is retained for each participant's last three available sessions:

- Sessions 7, 8, 9 for P1 and P2
- Sessions 10, 11, 12 for P3 and P4

Each `.mat` file can be paired with the corresponding session's per-trial metadata file (`P#_S#_meta.json`) via the shared `TrialID` field, and with the participant's channel metadata (`P#_metadata.json`). A single `movements.json` file (shared across the whole dataset) maps `TaskNumber` to movement name.

---

## Data structure

Each `.mat` file contains a single struct variable named **`miDB`**, with one element per trial.

### Trial-level fields

| Field name | Description |
|---|---|
| `TrialID` | Identification number for an individual trial in a recording session. Used to map EMG data to metadata in the session's corresponding metadata files. |
| `TaskNumber` | Code for the specific movement completed during a given trial. The corresponding movement name is listed in `movements.json`. |
| `TrialNumber` | Repetition number for the movement completed during a given trial. |
| `RestTime` | Time in the trial (ms) before movement was cued. |
| `HoldTime` | Time in the trial (ms) during which movement was cued/expected. |


### Raw signal fields

| Field name | Description |
|---|---|
| `EMG30k` | Raw imEMG sampled at 30,000 Hz. Present only for each participant's last three sessions (see above). |
| `EMG1k` | Raw imEMG downsampled to 1,000 Hz. |

### Processed signal fields

Raw EMG was band-pass filtered (4th-order Butterworth, 100–499 Hz passband) and notch-filtered to remove 60 Hz line noise and its harmonics (60, 120, 180, 240, 300, 360, 420, 480 Hz). This filtered signal populates:

| Field name | Description |
|---|---|
| `EMG30kf` | Filtered imEMG at 30,000 Hz. Present only for each participant's last three sessions. |
| `EMG1kf` | Filtered imEMG at 1,000 Hz. |
| `MAVs` | Mean absolute value, computed on the 30 kHz filtered data over fixed-width time windows (50 ms by default). |

All EMG-related fields (`EMG30k(f)`, `EMG1k(f)`, `MAVs`) are matrices where each **column** is a channel/muscle and each **row** is a frame of data.

### Movement labels

A string array, `movements`, lists the names and corresponding codes (`TaskNumber`) for every movement available across the dataset. This is also provided as `movements.json`.

---

## Channel maps

EMG channel names for each participant are listed, in channel order, in that participant's `P#_metadata.json` file, and reproduced here:

| Channel Number | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **P1** | EPL | EDC | FPL | FDPI | Med | Uln1 | Uln2 | FCR | | | | |
| **P2** | FDPI | FCR | Uln | Med | EDC | EPL | FDPS | FPL | | | | |
| **P3** | EDC | EPL | Sup | Rad | Pro | Med2 | Med4 | FDPS | FDPI | FPL | Med3 | Med1 |
| **P4** | EPL | Sup | EDC | ECRL | FCR | Pro | FDPI | FPL | Med2 | Med1 | Uln2 | Uln1 |

**Abbreviations:** FDPI = flexor digitorum profundus, index finger; FCR = flexor carpi radialis; Uln(1,2) = Ulnar RPNI (1,2); Med(1–4) = Median RPNI (1–4); EDC = extensor digitorum communis; EPL = extensor pollicis longus; FDPS = flexor digitorum profundus, small finger; FPL = flexor pollicis longus; Sup = supinator; ECRL = extensor carpi radialis longus; Pro = pronator; Rad = Radial RPNI.

---

## Companion flat-file exports

In addition to the `.mat` files, the `miDB` structs have been exported as flat, comma separated files for use outside MATLAB:

- **`P#_S#_MAVs.csv`** — MAVs for all channels across every available trial, including a `WindowStartTime` column (seconds) denoting the start of each 50 ms window.
- **`P#_S#_EMG1kHz.csv`** — the 1 kHz EMG data for all channels across every available trial, including a `MovementCue` logical column derived from `RestTime`/`HoldTime`.

Both flat files can be joined back to a session's metadata (`P#_S#_meta.json`) via the shared `TrialID` field.

---

## References

[1] Vu, P. P., Vaskov, A. K., Lee, C., Jillala, R. R., Wallace, D. M., Davis, A. J., ... & Cederna, P. S. (2023). Long-term upper-extremity prosthetic control using regenerative peripheral nerve interfaces and implanted EMG electrodes. *Journal of Neural Engineering, 20*(2), 026039.

[2] Nwokeabia, C. et al. (2026). miRPNI: A dataset of intramuscular electromyography from Regenerative Peripheral Nerve Interfaces and residual muscles. Zenodo. https://doi.org/10.5281/ZENODO.21268334

---

## Data intial processing code
The following excerpts of MATLAB code illustrate important data processing steps taken before data validation. For code related to data validaiton and classification, visit the companion GitHub repository: [gateslabs/miRPNI-processing](https://github.com/gateslabs/miRPNI-processing).

#### Filtering 30kHz data:
  ```matlab
numsamp = 30000; %starting out with 30k data

%100-500 Hz bandpass filter
[b(1,:), a(1,:)] = butter(2, [100, 500]/15e3, 'bandpass');

%notch filter at 60Hz and harmonics
[d(1,:), c(1,:)] = butter(2, [59, 61]/15e3, 'stop');
[d(2,:), c(2,:)] = butter(2, [119, 121]/15e3, 'stop');
[d(3,:), c(3,:)] = butter(2, [179, 181]/15e3, 'stop');
[d(4,:), c(4,:)] = butter(2, [239, 241]/15e3, 'stop');
[d(5,:), c(5,:)] = butter(2, [299, 301]/15e3, 'stop');
[d(6,:), c(6,:)] = butter(2, [359, 361]/15e3, 'stop');
[d(7,:), c(7,:)] = butter(2, [419, 421]/15e3, 'stop');
[d(8,:), c(8,:)] = butter(2, [479, 481]/15e3, 'stop');

disp('filtering 30 khz data')
for i = 1:length(miDB)
    disp(['filtering for task i = ', num2str(i)])
    disp('bandpass: 100-500 hz')
    miDB(i).EMG30kf = filter(b(1,:), a(1,:),  miDB(i).EMG30k);

    disp('notch filter at 60 hz and harmonics')
    for j = 1:8
        miDB(i).EMG30kf = filter(d(j,:), c(j,:), miDB(i).EMG30kf);
    end
end
  ```
#### Downsampling 30 kHz data:
```matlab
disp('downsampling 30k data')
for i = 1:length(miDB)
    disp(['downsampling for task i = ', num2str(i)])
    % using resample to downsample the data to ensure antialiasing
    miDB(i).EMG1kf = resample(miDB(i).EMG30kf, 1, 30); %downsampling down all channel columns
    miDB(i).EMG1k = resample(miDB(i).EMG30k, 1, 30); %downsampling raw data, too
end
```
#### Calculating MAVs from 30 kHz EMG data:
```matlab
for i = 1:numel(inDB)
        emg_filt = inDB(i).EMG30kf; %grabbing 30k data: should be [numsamps x numchans]
        n_windows = floor(size(emg_filt, 1) / win_samples);  % = 160 windows (default)
        emg_trimmed = emg_filt(1 : n_windows * win_samples, :);
        
        numchans = size(emg_filt,2);
        % Reshape and compute MAV: [n_windows x numchans]
        emg_reshaped = reshape(emg_trimmed, win_samples, n_windows, numchans);  % [1500 x 160 x 8]
        MAV = squeeze(mean(abs(emg_reshaped), 1));
        
        inDB(i).MAVs = MAV;

        outDB = inDB;
end
```
#### (Optional): calculating movement onset time based on MAVs
```matlab
for i = 1:length(inDB)
      cue_start_s = inDB(i).RestTime/1000; %cue appears at {RestTime} s into the trial
      cue_end_s   = (inDB(i).RestTime + inDB(i).HoldTime)/1000; %movement expected to be complete by          end of {HoldTime}
    
        % Convert to MAV window indices
        cue_start_win = floor(cue_start_s / (win_ms/1000)) + 1;  % +1 for 1-based indexing
        cue_end_win   = floor(cue_end_s   / (win_ms/1000));
    
        MAV = inDB(i).MAVs; %grabbing respective MAV matrix
        MAV_sum = sum(MAV,2); %summing MAVs across channels for a single vector
    
        % Extract MAV only within the cue window
        MAV_cue = MAV_sum(cue_start_win : cue_end_win, :);   % [n_cue_windows x 1]


        % Baseline still comes from the pre-cue period
        baseline_wins = cue_start_win - 1;   % all windows before the cue
        baseline_MAV  = MAV_sum(1 : baseline_wins);

        min_thresh = 2 * std(baseline_MAV);  % scaled to pre-cue noise floor
    
if isnan(min_thresh), min_thresh = 0; end %in case there is no rest time

        % Change-point detection restricted to cue window
        ipt_cue = findchangepts(MAV_cue, ...
                  'Statistic',    'mean', ...
                  'MinThreshold', min_thresh);

        if ~isempty(ipt_cue)
        % Map local index back to full-trial index
        onset_window = cue_start_win + ipt_cue(1) - 1;
        onset_time_s = (onset_window - 1) * (win_ms / 1000);
        fprintf('Onset at window %d → %.3f s\n', onset_window, onset_time_s);
        else
        fprintf('No onset detected in cue window.\n');
        onset_window = NaN;
        onset_time_s = NaN;
        end

        inDB(i).onset_idx = onset_window;

    end
```




