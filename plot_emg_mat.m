% PLOT_EMG_MAT  Plot every EMG channel for one trial (or the mean across a
% task's trials), reading directly from a session's .mat file.
%
% This is the .mat equivalent of plot_emg_csv.m. Prefer this version when
% you already have the .mat file for a session, since it skips the reshape
% step the CSV version needs -- the .mat file already stores one
% (numSamples x numChannels) array per trial inside the miDB struct.
%
% Expects the .mat file to contain a struct array (default name: "miDB")
% with one element per trial, and fields:
%   TrialID, TaskNumber, TrialNumber, RestTime, HoldTime,
%   EMG30k, EMG30kf, EMG1k, EMG1kf, MAVs
% Each EMG field is a [n_samples x n_channels] matrix for that trial.
% Channel names still come from the participant's metadata.json, since the
% .mat file itself only has channel numbers, not names.
%
% How to use this script: edit the Settings block below to point at your
% session and choose what to plot, then run the whole file.

clear; clc;

%% Settings ──────────────────────────────────────────────────────────────
% Which session to load.
MAT_PATH        = 'P1_S2_EMG.mat';
STRUCT_VAR      = 'miDB';            % name of the struct array inside the .mat file
CH_META_PATH    = 'P1_metadata.json';

% Which signal to plot. Use the *f versions for the filtered signal (see
% the dataset README for filter details), or the un-f versions for raw.
SIGNAL          = 'EMG1kf';             % 'EMG1k' | 'EMG1kf' | 'EMG30k' | 'EMG30kf'
FS              = 1000;                % sampling rate (Hz) for SIGNAL -- 1000 for *1k, 30000 for *30k

% What to plot. Only one of TRIAL_ID / TASK_NUMBER is used at a time,
% depending on PLOT_MEAN:
%   PLOT_MEAN = false -> TRIAL_ID is used   -> one specific trial, as recorded
%   PLOT_MEAN = true  -> TASK_NUMBER is used -> the average of every trial for that task
TRIAL_ID        = 6;
TASK_NUMBER     = 1;
PLOT_MEAN       = false;

%% Load metadata ─────────────────────────────────────────────────────────
% Channel names still come from JSON -- the .mat file has no names, only
% column positions, so this is the only place we need the metadata JSON.
ch_raw   = jsondecode(fileread(CH_META_PATH));
ch_nums  = [ch_raw.channelNumber];
ch_names = {ch_raw.channelName};
[~, idx] = sort(ch_nums);
ch_names = ch_names(idx);              % 1 x n_channels cell, ordered by channel number

%% Load EMG data ─────────────────────────────────────────────────────────
% Trial metadata is already embedded in the struct itself (unlike the CSV
% pipeline, which has to load it from a separate meta.json) -- we just pull
% it out into a table here for convenient lookup later in the script.
fprintf('Loading %s ...\n', MAT_PATH);
S      = load(MAT_PATH);
trials = S.(STRUCT_VAR);               % struct array, one element per trial
n_trials_total = numel(trials);

trial_ids  = [trials.TrialID]';
task_nums  = [trials.TaskNumber]';
trial_nums = [trials.TrialNumber]';
trial_meta = table(trial_ids, task_nums, trial_nums, ...
    'VariableNames', {'TrialID','TaskNumber','TrialNumber'});

n_ch = size(trials(1).(SIGNAL), 2);    % channels are columns: [n_samples x n_channels]

if numel(ch_names) ~= n_ch
    warning('Channel metadata has %d names but data has %d channels — using generic labels.', ...
        numel(ch_names), n_ch);
    ch_names = arrayfun(@(c) sprintf('Ch%d', c), 1:n_ch, 'UniformOutput', false);
end

fprintf('Loaded %d trials, %d channels, signal = %s.\n', n_trials_total, n_ch, SIGNAL);
fprintf('Trials   : %d | Tasks: %s\n', height(trial_meta), num2str(unique(task_nums)'));

%% Select data to plot ───────────────────────────────────────────────────
% This is the same branch as plot_emg_csv.m, but simpler: because every
% trial's SIGNAL array is already a fixed-length matrix (not a long-format
% table keyed by timestamp), averaging across trials is just stacking them
% along a 3rd dimension and taking the mean -- no need to align on a shared
% time vector the way the CSV version does.
if PLOT_MEAN
    match_idx = find(task_nums == TASK_NUMBER);
    n_trials  = numel(match_idx);
    if n_trials == 0
        error('No trials found for task %d.', TASK_NUMBER);
    end

    n_samples = size(trials(match_idx(1)).(SIGNAL), 2);
    stack     = zeros(n_ch, n_samples, n_trials);
    for k = 1:n_trials
        stack(:, :, k) = trials(match_idx(k)).(SIGNAL);
    end
    emg_mean  = mean(stack, 3);        % [n_channels x n_samples]

    plot_time = (0:n_samples-1)' / FS;
    plot_data = emg_mean;
    fig_title = sprintf('Mean %s — Task %d  (n=%d trials)', ...
        SIGNAL, TASK_NUMBER, n_trials);
else
    trial_idx = find(trial_ids == TRIAL_ID);
    if isempty(trial_idx)
        error('TrialID %d not found.', TRIAL_ID);
    end
    tr        = trials(trial_idx);
    n_samples = size(tr.(SIGNAL), 1);

    plot_time = (0:n_samples-1)' / FS;
    plot_data = tr.(SIGNAL);
    fig_title = sprintf('%s — Trial %d  (Task %d, Rep %d)', ...
        SIGNAL, TRIAL_ID, tr.TaskNumber, tr.TrialNumber);
end

fprintf('Plotting : %s\n', fig_title);

%% Plot ──────────────────────────────────────────────────────────────────
% One subplot per channel, stacked vertically so channel-to-channel timing
% differences are easy to compare by eye.
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
