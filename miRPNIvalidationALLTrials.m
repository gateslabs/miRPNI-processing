function validationALL = miRPNIvalidationALLTrials(matfiles, set, json_filepath, win_ms, seed)
% MIRPNIVALIDATIONALLTRIALS  Train and validate 3 classifiers pooling
% trials across multiple sessions (rather than a single session).
%
%   validationALL = miRPNIvalidationALLTrials(matfiles, set, json_filepath)
%   validationALL = miRPNIvalidationALLTrials(matfiles, set, json_filepath, win_ms, seed)
%
% What this function does, in order:
%   1. Loads each session's .mat file in turn, attaches TaskName, and
%      restricts each one to a fixed movement set
%   2. Extracts a single MAV feature vector per trial from the cue window
%   3. Pools every session's trials together into one large dataset
%   4. Splits that pooled dataset into a single 80/20 train/test split
%   5. Trains a Decision Tree, k-NN, and LDA classifier and reports accuracy
%
% This uses a single train/test split rather than k-fold cross-validation
% (contrast with miRPNIvalidation.m, which uses k-fold on one session) --
% pooling many sessions gives enough trials that one split is a reasonable
% estimate, and it's much faster than k-fold over a large pooled dataset.
%
% Inputs:
%   matfiles      - cell array of .mat filenames to pool, e.g.
%                     {'P1_S1_EMG.mat', 'P1_S2_EMG.mat', ..., 'P1_S12_EMG.mat'}
%                   or
%                     {'P3_S1_EMG.mat', ..., 'P3_S9_EMG.mat'}
%                   All files must be from the same participant if you want
%                   a single-participant model; mixing participants pools
%                   across them instead.
%   set           - which fixed movement set to test:
%                     1 -> rest, fist, pinch, point       (TaskNumbers 1,7,8,9)
%                     2 -> rest, index, middle, ring flex  (TaskNumbers 1,2,3,4)
%   json_filepath - path to movements.json (TaskNumber -> TaskName lookup)
%   win_ms        - (optional) MAV window width in ms, default 50 -- must
%                   match the window width MAVs was originally computed with
%   seed          - (optional) RNG seed for the train/test split, default 1
%
% Output:
%   validationALL - struct containing the trained models, predictions,
%                   per-model accuracy, and the train/test split used

if nargin < 4, win_ms = 50; end
if nargin < 5, seed = 1; end
rng(seed);

largeDB = struct([]); %empty dataset to add to.

%% Step 1: Load and prep each session, then pool them together ───────────
% Each session goes through the same per-session prep as
% miRPNIvalidation.m (attach TaskName, restrict to the fixed movement set,
% extract the cue-window MAV feature), then gets concatenated onto
% largeDB. EMG30k(f) is dropped before concatenating purely to save
% memory -- it's not used by anything past this point.
for fileIdx = 1:numel(matfiles)
    fname = matfiles{fileIdx};
    fprintf('Processing %s ...\n', fname);

    load(fname);  % loads miDB from this session's .mat file

    movements = string(struct2cell(jsondecode(fileread(json_filepath)))'); %imports movement json as a struct, converts to cell array
    for i = 1:numel(miDB)
        nomcondition = find(movements(:,1) == string(miDB(i).TaskNumber));
        nomresult = movements(nomcondition,2);
        miDB(i).TaskName = nomresult;
    end

    % Drop the 30kHz fields before concatenating across sessions -- they're
    % not used for classification here and are large enough to matter once
    % you're pooling many sessions together.
    if isfield(miDB, "EMG30k")
        miDB = rmfield(miDB, "EMG30k");
    end
    if isfield(miDB, "EMG30kf")
        miDB = rmfield(miDB, "EMG30kf");
    end

    if set == 1
        keymovements = ['1', '7', '8', '9']'; % rest, fist, pinch, point
    elseif set == 2
        keymovements = ['1', '2', '3', '4']'; %rest, index, middle, ring flex
    else
        disp('choose a set');
    end

    taskNumbers = [miDB.TaskNumber];
    g = ismember(string(taskNumbers), keymovements);
    miDB = miDB(g);

    % Extract one MAV feature vector per trial from the same 1-second
    % cue window used in miRPNIvalidation.m: starting 1s after the nominal
    % cue (RestTime) to make sure movement has actually started.
    for i = 1:numel(miDB)
        cue_start_s = (miDB(i).RestTime + 1000)/1000; %HoldTime/1000; %for s     %4.0;   % e.g. cue appears at 2s into the trial
        cue_end_s   = (miDB(i).RestTime + 2000)/1000; %for s  % e.g. movement expected to be complete by 4s

        cue_start_win = floor(cue_start_s / (win_ms/1000)) + 1;  % +1 for 1-based indexing
        cue_end_win   = floor(cue_end_s   / (win_ms/1000));

        MAV = miDB(i).MAVs;
        miDB(i).MAV_cue = MAV(cue_start_win : cue_end_win,:);   % [n_cue_windows x n_channels]
        miDB(i).MAV_collapse = mean(miDB(i).MAV_cue,1); % average across the cue window -> one feature vector per trial

        % Track which session (file) each trial came from -- useful later
        % if you want to check whether errors cluster in particular sessions.
        miDB(i).SessionNumber = fileIdx;
    end

    largeDB = [largeDB, miDB];
end

%% Step 2: Assemble the pooled feature matrix ─────────────────────────────
% Unlike miRPNIvalidation.m, we use one feature vector per trial here
% (MAV_collapse) rather than one row per MAV window (MAV_cue) -- with many
% sessions pooled together there's already enough data, so per-trial
% granularity keeps X at a manageable size.
disp('Extracting and formatting data...');

numTrials = length(largeDB);
X = []; % Predictor matrix (Features)
Y = {}; % Response cell array (Labels)

for i = 1:numTrials
    currentFeatures = largeDB(i).MAV_collapse;

    if ischar(currentFeatures) || isstring(currentFeatures)
        continue; 
    end

    numSamples = size(currentFeatures, 1);
    currentLabel = {char(largeDB(i).TaskName)};

    X = [X; currentFeatures];
    Y = [Y; repmat(currentLabel, numSamples, 1)];
end

disp(['Data formatted! Total samples: ', num2str(size(X,1)), ', Features: ', num2str(size(X,2))]);

%% Step 3: Single stratified train/test split ─────────────────────────────
% A single 80/20 split (rather than k-fold, as in miRPNIvalidation.m) is
% reasonable here because pooling multiple sessions gives enough trials
% that one held-out set is a stable enough estimate, and it's much cheaper
% to compute than k-fold would be at this scale.
disp('Splitting data into train/test sets using randperm...');

numObservations = size(X, 1);
validationALL.numObservations = numObservations;

shuffledIdx = randperm(numObservations);

trainRatio = 0.8;
cv = cvpartition(categorical(Y), 'HoldOut', 1 - trainRatio, 'Stratify', true);

trainIdx = training(cv);
testIdx  = test(cv);

X_train = X(trainIdx, :);
Y_train = Y(trainIdx, :);
X_test  = X(testIdx, :);
Y_test  = Y(testIdx, :);

validationALL.X_train = X_train;
validationALL.Y_train = Y_train;
validationALL.X_test = X_test;
validationALL.Y_test = Y_test;

%% Step 4: Train classifiers ───────────────────────────────────────────────
% Same three simple, fast baseline classifiers as miRPNIvalidation.m so
% the two functions' results are comparable. LDA is used here instead of
% an SVM (fitcecoc) because SVM training time gets impractical once you're
% pooling hundreds of thousands of rows across many sessions.
disp('Training Classifiers...');

disp(' - Training Decision Tree (fitctree)...');
mdlTree = fitctree(X_train, Y_train);

disp(' - Training k-NN (fitcknn)...');
mdlKNN = fitcknn(X_train, Y_train, 'NumNeighbors', 5);

disp(' - Training LDA (fitcdiscr)...');
mdlLDA = fitcdiscr(X_train, Y_train);

validationALL.mdlTree = mdlTree;
validationALL.mdlKNN = mdlKNN;
validationALL.mdlLDA = mdlLDA;

disp('Making predictions on test data...');
predTree = predict(mdlTree, X_test);
predKNN  = predict(mdlKNN, X_test);
predLDA  = predict(mdlLDA, X_test);

validationALL.predTree = predTree;
validationALL.predKNN = predKNN;
validationALL.predLDA = predLDA;

%% Step 5: Accuracy and confusion matrices ────────────────────────────────
disp('Calculating overall accuracy...');
accTree = round(sum(cellfun(@strcmp, Y_test, predTree)) / length(Y_test) * 100, 2);
accKNN  = round(sum(cellfun(@strcmp, Y_test, predKNN)) / length(Y_test) * 100, 2);
accLDA  = round(sum(cellfun(@strcmp, Y_test, predLDA)) / length(Y_test) * 100, 2);

disp('Generating Confusion Matrices...');

mainFig = figure('WindowState', 'maximized', 'Name', 'Multi-Model Performance Comparison', 'NumberTitle', 'off');
tl = tiledlayout(mainFig, 1, 3);
tl.TileSpacing = 'compact';
tl.Padding = 'compact';

xlabel(tl, 'Predicted Class', 'FontSize', 14, 'FontWeight', 'bold');
ylabel(tl, 'True Class', 'FontSize', 14, 'FontWeight', 'bold');

nexttile(tl);
cmTree = confusionchart(Y_test, predTree, ...
    'Title', sprintf('Decision Tree\nDecoder accuracy: %.1f%%', accTree), ...
    'Normalization', 'row-normalized', ...
    'RowSummary', 'off', ...
    'ColumnSummary', 'off');
cmTree.FontSize = 10;

nexttile(tl);
cmKNN = confusionchart(Y_test, predKNN, ...
    'Title', sprintf('k-Nearest Neighbors\nDecoder accuracy: %.1f%%', accKNN), ...
    'Normalization', 'row-normalized', ...
    'RowSummary', 'off', ...
    'ColumnSummary', 'off');
cmKNN.FontSize = 10;

nexttile(tl);
cmLDA = confusionchart(Y_test, predLDA, ...
    'Title', sprintf('Linear Discriminant\nDecoder accuracy: %.1f%%', accLDA), ...
    'Normalization', 'row-normalized', ...
    'RowSummary', 'off', ...
    'ColumnSummary', 'off');
cmLDA.FontSize = 10;

disp('Done!');

validationALL.accuracies = [accTree, accKNN, accLDA];
validationALL.modelNames = {'Decision Tree', 'k-NN', 'LDA'};
disp('accuracies');
disp(validationALL.modelNames)
disp(validationALL.accuracies)

disp('storing and exporting data')

end
