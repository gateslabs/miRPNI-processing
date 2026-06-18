% Plots all EMG channels from a given session
% Uses channel names from participant's metadata.json and trial info from
% the corresponding metadata file.
% Produces a grid of subplots with an optional vertical onset line.

clear; clc;

%% Settings ──────────────────────────────────────────────────────────────
DATA_PATH      = 'P2_S12_EMG1kHz.txt';
CH_META_PATH   = 'metadata.json';
TRIAL_META_PATH = 'P2_S12_meta.json';

FS             = 1000;   % sampling rate (Hz)
TRIAL_ID       = 53;      % which trial to plot (ignored when PLOT_MEAN = true)
MOVEMENT_NUMBER = 1;     % movement to average (used when PLOT_MEAN = true)
PLOT_MEAN      = false;  % false = single trial | true = mean across movement trials
SHOW_ONSET     = true;   % draw vertical dashed line at movement onset

%% Load metadata ─────────────────────────────────────────────────────────
% Channel names
ch_raw = jsondecode(fileread(CH_META_PATH));

% ch_raw is a struct array; sort by channelNumber
ch_nums   = [ch_raw.channelNumber];
ch_names  = {ch_raw.channelName};
[~, idx]  = sort(ch_nums);
ch_names  = ch_names(idx);   % 1xnumchans cell, ordered by channel number

% Trial metadata
tr_raw     = jsondecode(fileread(TRIAL_META_PATH));
trial_ids  = [tr_raw.trialID]';
move_nums  = [tr_raw.movementNumber]';
trial_nums = [tr_raw.trialNumber]';
onset_times = [tr_raw.onsetIDX]';

% Table for easy lookup
trial_meta = table(trial_ids, move_nums, trial_nums, onset_times, ...
    'VariableNames', {'trialID','movementNumber','trialNumber','onsetTime'});

fprintf('Channels : %s\n', strjoin(ch_names, ', '));
fprintf('Trials   : %d | Movements: %s\n', height(trial_meta), ...
    num2str(unique(move_nums)'));

%% Load EMG data ─────────────────────────────────────────────────────────
fprintf('Loading %s ...\n', DATA_PATH);
opts = detectImportOptions(DATA_PATH);
opts.VariableNamingRule = 'preserve';
T = readtable(DATA_PATH, opts);

% Identify EMG columns (columns 3-10, named EMG1k_1 … EMG1k_12)
emg_col_names = T.Properties.VariableNames(startsWith( ...
    T.Properties.VariableNames, 'EMG'));
n_ch = numel(emg_col_names);

% Add within-trial time
trials_col = T.trialID;
time_s     = zeros(height(T), 1);
for tid = unique(trials_col)'
    mask = trials_col == tid;
    time_s(mask) = (0 : sum(mask)-1)' / FS;
end
T.time_s = time_s;

% Merge movementNumber and onsetTime into T
T.movementNumber = nan(height(T), 1);
T.onsetTime      = nan(height(T), 1);
for i = 1:height(trial_meta)
    mask = T.trialID == trial_meta.trialID(i);
    T.movementNumber(mask) = trial_meta.movementNumber(i);
    T.onsetTime(mask)      = trial_meta.onsetTime(i);
end

fprintf('Loaded %d rows, %d channels.\n', height(T), n_ch);

%% Select data to plot ───────────────────────────────────────────────────
if PLOT_MEAN
    subset_mask = T.movementNumber == MOVEMENT_NUMBER;
    subset      = T(subset_mask, :);
    onset_time  = mean(subset.onsetTime, 'omitnan');
    n_trials    = numel(unique(subset.trialID));

    % Average each channel over trials at the same time point
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
    fig_title = sprintf('Mean EMG — Movement %d  (n=%d trials)', ...
        MOVEMENT_NUMBER, n_trials);
else
    row_mask   = T.trialID == TRIAL_ID;
    subset     = T(row_mask, :);
    onset_time = subset.onsetTime(1);
    mov_num    = subset.movementNumber(1);
    tr_num     = trial_meta.trialNumber(trial_meta.trialID == TRIAL_ID);
    plot_time  = subset.time_s;
    plot_data  = table2array(subset(:, emg_col_names));  % [samples x channels]
    fig_title  = sprintf('EMG — Trial %d  (Movement %d, Rep %d)', ...
        TRIAL_ID, mov_num, tr_num);
end

fprintf('Plotting : %s\n', fig_title);
fprintf('Onset    : %.3f s\n', onset_time);

%% 5. Plot ──────────────────────────────────────────────────────────────────
% Color palette (one per channel)
colors = lines(n_ch);

fig = figure('Name', fig_title, 'NumberTitle', 'off', ...
    'Position', [100 100 900 1100]);

n_rows = n_ch; %ceil(n_ch / 2);
n_cols = 1; %2;

for ci = 1:n_ch
    ax = subplot(n_rows, n_cols, ci);

    plot(plot_time, plot_data(:, ci), ...
        'Color', colors(ci, :), 'LineWidth', 0.6);
    hold on;

    % Onset line
    if SHOW_ONSET
        xline(onset_time, '--r', 'LineWidth', 0.9, 'Alpha', 0.8);
    end

    % title(ch_names{ci}, 'FontWeight', 'bold', 'FontSize', 10);
    % xlabel('Time (s)', 'FontSize', 8);
    % ylabel('Amplitude (µV)', 'FontSize', 8);
    xlim([0 max(plot_time)]);
    %ylim([-500 500]); %should be autoscaled at the moment
    xticks(0:2:8);
    grid on;
    box off;
    set(ax, 'FontSize', 8, 'GridColor', [0.85 0.85 0.85]);
    hold off;
end

sgtitle(fig_title, 'FontSize', 13, 'FontWeight', 'bold');

%% 6. Save (optional) ───────────────────────────────────────────────────────
% exportgraphics(fig, 'emg_channels.png', 'Resolution', 150);
% fprintf('Saved → emg_channels.png\n');
