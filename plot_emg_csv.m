% PLOT_EMG_CSV  Plot every EMG channel for one trial (or the mean across a
% task's trials), reading from a session's .csv export.
%
% This is the .csv equivalent of plot_emg_mat.m. Use this version when you
% only have the CSV + JSON exports for a session rather than the .mat file
% -- e.g. if you're working from the Zenodo tabular download rather than
% the MATLAB structs.
%
% Unlike the .mat version, the CSV is long-format: one row per timepoint
% per trial, not one array per trial. Most of this script's extra work
% (building a within-trial time column, merging in TaskNumber) exists to
% turn that long format back into something plottable.
%
% How to use this script: edit the Settings block below to point at your
% session and choose what to plot, then run the whole file.

clear; clc;

%% Settings ──────────────────────────────────────────────────────────────
% Which session to load.
DATA_PATH       = "sample_set/csv/P1_S12_EMG1kHz.csv";
CH_META_PATH    = "sample_set/meta/P1_metadata.json";
TRIAL_META_PATH = "sample_set/meta/P1_S12_meta.json";

FS              = 1000;   % sampling rate (Hz)

% What to plot. Only one of TRIAL_ID / TASK_NUMBER is used at a time,
% depending on PLOT_MEAN:
%   PLOT_MEAN = false -> TRIAL_ID is used    -> one specific trial, as recorded
%   PLOT_MEAN = true  -> TASK_NUMBER is used -> the average of every trial for that task
TRIAL_ID        = 10;
TASK_NUMBER     = 1;
PLOT_MEAN       = false;

%% Load metadata ─────────────────────────────────────────────────────────
% Channel names, ordered by channel number.
ch_unfilt    = jsondecode(fileread(CH_META_PATH));
ch_nums   = [ch_unfilt.channelNumber];
ch_names  = {ch_unfilt.channelName};
[~, idx]  = sort(ch_nums);
ch_names  = ch_names(idx);   % 1 x n_channels cell, ordered by channel number

% Trial-level metadata (one row per trial). Unlike the .mat version, this
% has to be loaded from a separate file, since the CSV itself only has
% per-timepoint rows and a TrialID to tie them together.
tr_unfilt     = jsondecode(fileread(TRIAL_META_PATH));
trial_ids  = [tr_unfilt.TrialID]';
task_nums  = [tr_unfilt.TaskNumber]';
trial_nums = [tr_unfilt.TrialNumber]';

trial_meta = table(trial_ids, task_nums, trial_nums, ...
    'VariableNames', {'TrialID','TaskNumber','TrialNumber'});

fprintf('Channels : %s\n', strjoin(ch_names, ', '));
fprintf('Trials   : %d | Tasks: %s\n', height(trial_meta), ...
    num2str(unique(task_nums)'));

%% Load EMG data ─────────────────────────────────────────────────────────
% The unfiltered CSV has one row per timepoint per trial. To make it plottable we
% need two things it doesn't already have: a within-trial time axis (so we
% know where each row falls in the trial, not just which trial it's from),
% and the TaskNumber for each row (so we can filter/average by task).
fprintf('Loading %s ...\n', DATA_PATH);
opts = detectImportOptions(DATA_PATH);
opts.VariableNamingRule = 'preserve';
T = readtable(DATA_PATH, opts);

emg_col_names = T.Properties.VariableNames(startsWith( ...
    T.Properties.VariableNames, 'EMG'));
n_ch = numel(emg_col_names);

% Within-trial time: restart the clock at 0 for every trial.
trials_col = T.TrialID;
time_s     = zeros(height(T), 1);
for tid = unique(trials_col)'
    mask = trials_col == tid;
    time_s(mask) = (0 : sum(mask)-1)' / FS;
end
T.time_s = time_s;

% Merge TaskNumber from trial_meta into every row of T that belongs to
% that trial, so each timepoint row knows which task it came from.
T.TaskNumber = nan(height(T), 1);
for i = 1:height(trial_meta)
    mask = T.TrialID == trial_meta.TrialID(i);
    T.TaskNumber(mask) = trial_meta.TaskNumber(i);
end

fprintf('Loaded %d rows, %d channels.\n', height(T), n_ch);

%% Select data to plot ───────────────────────────────────────────────────
if PLOT_MEAN
    % Averaging here is trickier than the .mat version: because this is a
    % long-format table, "the same timepoint across trials" means matching
    % rows on time_s, not just stacking fixed-length arrays. We do that
    % match explicitly, one time bin at a time.
    subset_mask = T.TaskNumber == TASK_NUMBER;
    subset      = T(subset_mask, :);
    n_trials    = numel(unique(subset.TrialID));

    time_axis = unique(subset.time_s);
    emg_mean  = zeros(numel(time_axis), n_ch);
    for ci = 1:n_ch
        col_data = subset.(emg_col_names{ci});
        for ti = 1:numel(time_axis)
            t_mask = subset.time_s == time_axis(ti);
            emg_mean(ti, ci) = mean(col_data(t_mask));
        end
    end
    plot_time = time_axis;
    plot_data = emg_mean;   % [samples x channels]
    fig_title = sprintf('Mean EMG — Task %d  (n=%d trials)', ...
        TASK_NUMBER, n_trials);
else
    row_mask   = T.TrialID == TRIAL_ID;
    subset     = T(row_mask, :);
    task_num   = subset.TaskNumber(1);
    tr_num     = trial_meta.TrialNumber(trial_meta.TrialID == TRIAL_ID);
    plot_time  = subset.time_s;
    plot_data  = table2array(subset(:, emg_col_names));  % [samples x channels]
    fig_title  = sprintf('EMG — Trial %d  (Task %d, Rep %d)', ...
        TRIAL_ID, task_num, tr_num);
end

fprintf('Plotting : %s\n', fig_title);

%% Plot ──────────────────────────────────────────────────────────────────
% One subplot per channel, stacked vertically -- same layout as
% plot_emg_mat.m, so figures from either pipeline look the same.
colors = lines(n_ch);

fig = figure('Name', fig_title, 'NumberTitle', 'off', ...
    'Position', [100 100 900 1100]);

n_rows = n_ch;
n_cols = 1;

for ci = 1:n_ch
    ax = subplot(n_rows, n_cols, ci);

    plot(plot_time, plot_data(:, ci), ...
        'Color', colors(ci, :), 'LineWidth', 0.6);
    hold on;

    title(ch_names{ci}, 'FontWeight', 'bold', 'FontSize', 10);
    % xlabel('Time (s)', 'FontSize', 8);
    % ylabel('Amplitude (µV)', 'FontSize', 8);
    xlim([0 max(plot_time)]);
    grid on;
    box off;
    set(ax, 'FontSize', 8, 'GridColor', [0.85 0.85 0.85]);
    hold off;
end

sgtitle(fig_title, 'FontSize', 13, 'FontWeight', 'bold');

%% Save (optional) ───────────────────────────────────────────────────────
% Uncomment to export the figure as a PNG instead of just viewing it.
% exportgraphics(fig, 'emg_channels.png', 'Resolution', 150);
% fprintf('Saved → emg_channels.png\n');
