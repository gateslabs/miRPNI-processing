% Plots all EMG channels from a given session using a .mat file
% Expects the .mat file to contain a struct array (default name: "subset")
% with one element per trial, and fields:
%   TrialID, TaskNumber, TrialNumber, RestTime, HoldTime,
%   EMG30k, EMG30kf, EMG1k, EMG1kf, MAVs
% Each EMG field is a [n_samples x n_channels] matrix for that trial.
% Channel names still come from participant's metadata.json.
% Produces a grid of subplots

clear; clc;

%% Settings ──────────────────────────────────────────────────────────────
MAT_PATH        = 'sample_set/mat/P1_S12_EMG.mat';
STRUCT_VAR      = 'miDB';            % name of the struct array inside the .mat file
CH_META_PATH    = 'sample_set/meta/P1_metadata.json';

SIGNAL          = 'EMG1kf';             % which field to plot: 'EMG1k' | 'EMG1kf' | 'EMG30k' | 'EMG30kf'
FS              = 1000;                % sampling rate (Hz) for the chosen SIGNAL (1000 for *1k, 30000 for *30k)

TRIAL_ID        = 6;                   % which trial to plot (ignored when PLOT_MEAN = true)
MOVEMENT_NUMBER = 1;                   % movement to average (used when PLOT_MEAN = true)
PLOT_MEAN       = false;               % false = single trial | true = mean across movement trials

%% Load metadata ─────────────────────────────────────────────────────────
% Channel names (still comes from JSON; the .mat file itself has no names)
ch_raw   = jsondecode(fileread(CH_META_PATH));
ch_nums  = [ch_raw.channelNumber];
ch_names = {ch_raw.channelName};
[~, idx] = sort(ch_nums);
ch_names = ch_names(idx);              % 1 x n_channels cell, ordered by channel number

%% Load EMG data ─────────────────────────────────────────────────────────
fprintf('Loading %s ...\n', MAT_PATH);
S      = load(MAT_PATH);
trials = S.(STRUCT_VAR);               % struct array, one element per trial
n_trials_total = numel(trials);

% Trial metadata is already embedded in the struct - build a lookup table
% just like trial_meta was built from TRIAL_META_PATH before
trial_ids  = [trials.TrialID]';
move_nums  = [trials.TaskNumber]';
trial_nums = [trials.TrialNumber]';
trial_meta = table(trial_ids, move_nums, trial_nums, ...
    'VariableNames', {'TrialID','TaskNumber','TrialNumber'});

n_ch = size(trials(1).(SIGNAL), 2);    % channels are columns: [n_samples x n_channels]

if numel(ch_names) ~= n_ch
    warning('Channel metadata has %d names but data has %d channels — using generic labels.', ...
        numel(ch_names), n_ch);
    ch_names = arrayfun(@(c) sprintf('Ch%d', c), 1:n_ch, 'UniformOutput', false);
end

fprintf('Loaded %d trials, %d channels, signal = %s.\n', n_trials_total, n_ch, SIGNAL);
fprintf('Trials   : %d | Movements: %s\n', height(trial_meta), num2str(unique(move_nums)'));

%% Select data to plot ───────────────────────────────────────────────────
if PLOT_MEAN
    match_idx = find(move_nums == MOVEMENT_NUMBER);
    n_trials  = numel(match_idx);
    if n_trials == 0
        error('No trials found for movement %d.', MOVEMENT_NUMBER);
    end

    % All trials for a given signal are the same fixed length, so we can
    % just stack them along a 3rd dimension and average - no need to
    % align on a shared time vector like the CSV version had to.
    n_samples = size(trials(match_idx(1)).(SIGNAL), 2);
    stack     = zeros(n_ch, n_samples, n_trials);
    for k = 1:n_trials
        stack(:, :, k) = trials(match_idx(k)).(SIGNAL);
    end
    emg_mean  = mean(stack, 3);        % [n_channels x n_samples]

    plot_time = (0:n_samples-1)' / FS;
    plot_data = emg_mean;             
    fig_title = sprintf('Mean %s — Movement %d  (n=%d trials)', ...
        SIGNAL, MOVEMENT_NUMBER, n_trials);
else
    trial_idx = find(trial_ids == TRIAL_ID);
    if isempty(trial_idx)
        error('TrialID %d not found.', TRIAL_ID);
    end
    tr        = trials(trial_idx);
    n_samples = size(tr.(SIGNAL), 1);

    plot_time = (0:n_samples-1)' / FS;
    plot_data = tr.(SIGNAL);         
    fig_title = sprintf('%s — Trial %d  (Movement %d, Rep %d)', ...
        SIGNAL, TRIAL_ID, tr.TaskNumber, tr.TrialNumber);
end

fprintf('Plotting : %s\n', fig_title);

%% Plot ──────────────────────────────────────────────────────────────────
% Color palette (one per channel)
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
% exportgraphics(fig, 'emg_channels.png', 'Resolution', 150);
% fprintf('Saved → emg_channels.png\n');
