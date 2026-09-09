**A dataset of intramuscular electromyography from Regenerative Peripheral Nerve Interfaces (RPNIs) and residual muscles**

Date: 2026-09-02

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
or 
```
<ParticipantID>_<SessionNumber>_<DataCategory>.csv
```

For example, Participant 1's data for session 8 is `P1_S8_EMG.mat`. Participant 2's MAVs for session 12 are availale in `P2_S12_MAVS.csv`.

Data were originally sampled at 30 kHz but downsampled to 1 kHz for most sessions to save space. The 30 kHz data is retained for each participant's last three available sessions in their respective `.mat` files:

- Sessions 7, 8, 9 for P1 and P2
- Sessions 10, 11, 12 for P3 and P4

Each `.mat` file can be paired with the corresponding session's per-trial metadata file (`P#_S#_meta.json`) via the shared `TrialID` field, and with the participant's channel metadata (`P#_metadata.json`). A single `movements.json` file (shared across the whole dataset) maps `TaskNumber` to movement name.

---

## Data structure
### Complete EMG data exports (`.mat`)
EMG data (unfiltered and filtered) are available in 1000 Hz via `.csv` files, while unfiltered and filtered data at 1000 Hz and 30000 Hz is available in `.mat` files.

 Each `.mat` file contains a single struct variable named **`miDB`**, with one element per trial.

### Trial-level fields

| Field name | Description |
|---|---|
| `TrialID` | Identification number for an individual trial in a recording session. Used to map EMG data to metadata in the session's corresponding metadata files. |
| `TaskNumber` | Code for the specific movement (individual finger movement, wrist movment, or functional grasp) completed during a given trial. The corresponding movement name is listed in `movements.json`. |
| `TrialNumber` | Repetition number for the hand gesture completed during a given trial (i.e. 1-5).|
| `RestTime` | Time in the trial (ms) where no movement was cued. |
| `HoldTime` | Time in the trial (ms) where the movement was cued.|


### Raw signal fields

| Field name | Description |
|---|---|
| `EMG30k` | Raw imEMG sampled at 30,000 Hz. Present only for each participant's last three sessions and only in `.mat` form (see above). |
| `EMG1k` |imEMG downsampled to 1,000 Hz using the `resample` function in MATLAB.|

### Processed signal fields

30kHz and 1kHz EMG data were band-pass filtered (4th-order Butterworth, 100–499 Hz passband) and notch-filtered to remove 60 Hz line noise and its harmonics (60, 120, 180, 240, 300, 360, 420, 480 Hz). This filtered signal populates:

| Field name | Description |
|---|---|
| `EMG30k_filt` | The 30 kHz data after the specified band-pass and notch filters were applied. Present only for each participant's last three sessions and only available in `.mat` form. |
| `EMG1k_filt` | The 1 kHz resampled signal after the specified band-pass and notch filters were applied. |
| `MAVs` | Mean absolute value, computed on the 30 kHz filtered data over fixed-width time windows (50 ms). |

All EMG-related fields (`EMG30k(_filt)`, `EMG1k(_filt)`) are matrices where each column is an EMG channel for a residual muscle or RPNI and each row is a frame of data. For the `MAVs` field, each column is an EMG channel for a residual muscle or RPNI, but each row is the calculated mean absolute value over each nonoverlapping window.

### Companion flat-file exports (`.csv`)

In addition to the `.mat` files, some fields in the `miDB` structs `EMG1k`, `EMG1k_filt`, `MAVs` have been exported as flat, comma separated files for use outside MATLAB:

- **`P#_S#_MAVs.csv`** — MAVs for all channels as seen in corresponding `.mat` file across every available trial, including a `WindowStartTime` column (seconds) denoting the start of each 50 ms window.
- **`P#_S#_EMG1kHz.csv`** — the *raw* 1 kHz EMG data for all channels across every available trial, including a `MovementCue` logical column derived from `RestTime`/`HoldTime`.
- **`P#_S#_EMG1kHz_filt.csv`** — the 1 kHz *filtered* EMG data for all channels across every available trial, including a `MovementCue` logical column derived from `RestTime`/`HoldTime`

All flat files can be joined back to a session's metadata (`P#_S#_meta.json`) via the shared `TrialID` field.

### Movement labels
A string array, `movements`, lists the names and corresponding codes (`TaskNumber`) for every movement available across the dataset. This is provided as `movements.json`.

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



---

## References

[1] Vu, P. P., Vaskov, A. K., Lee, C., Jillala, R. R., Wallace, D. M., Davis, A. J., ... & Cederna, P. S. (2023). Long-term upper-extremity prosthetic control using regenerative peripheral nerve interfaces and implanted EMG electrodes. *Journal of Neural Engineering, 20*(2), 026039.

[2] Nwokeabia, C. et al. (2026). miRPNI: A dataset of intramuscular electromyography from Regenerative Peripheral Nerve Interfaces and residual muscles. Zenodo. https://doi.org/10.5281/zenodo.20739025

---

## Initial data processing code
The following excerpts of MATLAB code illustrate important data processing steps taken before data validation as outlined in the corresponding manuscript. For code related to data validation, classification, and visualization, visit the companion GitHub repository: [gateslabs/miRPNI-processing](https://github.com/gateslabs/miRPNI-processing).

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
    miDB(i).EMG30k_filt = filter(b(1,:), a(1,:),  miDB(i).EMG30k);

    disp('notch filter at 60 hz and harmonics')
    for j = 1:8
        miDB(i).EMG30k_filt = filter(d(j,:), c(j,:), miDB(i).EMG30k_filt);
    end
end
  ```
#### Downsampling 30 kHz data:
```matlab
disp('downsampling 30k data')
for i = 1:length(miDB)
    disp(['downsampling for task i = ', num2str(i)])
    % using resample to downsample the data to ensure antialiasing
    miDB(i).EMG1k_filt = resample(miDB(i).EMG30k_filt, 1, 30); %downsampling down all channel columns
    miDB(i).EMG1k = resample(miDB(i).EMG30k, 1, 30); %downsampling raw data, too
end
```
#### Calculating MAVs from 30 kHz EMG data:
```matlab
for i = 1:numel(inDB)
        emg_filt = inDB(i).EMG30k_filt; %grabbing 30k data: should be [numsamps x numchans]
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
#### Generate json files for session metadata using miDB fields
```matlab
% export metadata for user sessions
for session = 1:numSessions
    disp('loading emg data')
    load(strcat(savepath, "\mat\", pID, "_S", num2str(session), "_EMG.mat"))

    json_session = strcat(savepath, "\meta\", pID, "_S", num2str(session), "_meta.json");

    for i = 1:numel(miDB)
        j(i).TrialID = miDB(i).TrialID;
        j(i).TaskNumber = miDB(i).TaskNumber;
        j(i).TrialNumber = miDB(i).TrialNumber;
        j(i).RestTime = miDB(i).RestTime;
        j(i).HoldTime = miDB(i).HoldTime;

    end

    out = jsonencode(j, "PrettyPrint",true);

    disp('saving json')
    fid = fopen(json_session,'w');
    fprintf(fid,'%s',out);
    fclose(fid);
end
```

#### Convert and save miDB MATLAB structs as csv files
This code uses the custom script **`miDB2csv.m`**, which is available in this data repo.
```matlab
%% convert and save miDB as csv files: 1k, 1k_filt, mavs:(miDB2csv.m)
for session = 1:numSessions
    fprintf('session %d \n', session);
    disp('loading emg data')
    load(strcat(savepath, "\mat\", pID, "_S", num2str(session), "_EMG.mat"))
    idxx = size(miDB(1).EMG1k, 2);

    [MAVs, Data1k, Data1kf, D30, D30f] = miDB2csv(miDB, idxx);

    mavfp = strcat(savepath, "\csv\",pID, "_S", num2str(session), '_MAVS.csv'); 
    EMG1kfp = strcat(savepath, "\csv\",pID, "_S", num2str(session), '_EMG1kHz_filt.csv');
    EMG1k_filtfp = strcat(savepath, switch_name, "\csv\",switch_name, "_S", num2str(session), '_EMG1kHz_filt.csv');

    writematrix(MAVs,mavfp, 'Delimiter', 'comma'); 
    writematrix(Data1k,EMG1kfp, 'Delimiter', 'comma'); 
    writematrix(Data1kf,EMG1k_filtfp, 'Delimiter', 'comma');


end
```



