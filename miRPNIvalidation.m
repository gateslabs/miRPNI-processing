function validations = miRPNIvalidation(miDB, moveset, json_filepath, win_ms)
% MIRPNIVALIDATION  Train and cross-validate 3 simple classifiers on one
% session's worth of miRPNI trials.
%
%   validations = miRPNIvalidation(miDB, moveset, json_filepath)
%   validations = miRPNIvalidation(miDB, moveset, json_filepath, win_ms)
%
% What this function does, in order:
%   1. Attaches a human-readable TaskName to every trial (from movements.json)
%   2. Restricts the data to one fixed set of movements ("moveset")
%   3. Extracts the MAV features from a 1-second window inside each trial's
%      cue period
%   4. Runs stratified k-fold cross-validation, training a Decision Tree,
%      k-NN, and LDA classifier on each fold
%   5. Reports per-model accuracy and plots confusion matrices
%
% This uses k-fold cross-validation rather than a single train/test split
% because a single session has very few trials per movement (at most 5),
% so one lucky/unlucky split would give a misleading accuracy estimate.
% (For validating across many sessions at once instead of one, see
% miRPNIvalidationALLTrials.m, which uses a single train/test split since
% pooling sessions gives enough samples for that to be reasonable.)
%
% Inputs:
%   miDB          - struct array, one element per trial, as loaded from a
%                   session's .mat file (must have TaskNumber, RestTime,
%                   MAVs fields at minimum)
%   moveset       - which fixed movement set to test:
%                     1 -> rest, fist, pinch, point   (TaskNumbers 1,7,8,9)
%                     2 -> rest, index, middle, ring flex (TaskNumbers 1,2,3,4)
%   json_filepath - path to movements.json (TaskNumber -> TaskName lookup)
%   win_ms        - (optional) MAV window width in ms, default 50 -- must
%                   match the window width MAVs was originally computed
%                   with, or the cue-window indices below will be wrong
%
% Output:
%   validations - struct containing the trained models, predictions,
%                 per-model accuracy, and the train/test split used

if nargin < 4, win_ms = 50; end

%% Step 1: Attach task names ──────────────────────────────────────────────
% miDB only has numeric TaskNumber. movements.json is the dataset-wide
% TaskNumber -> TaskName lookup, so we attach TaskName here once up front
% and use it everywhere else in this function (the classifiers below
% predict TaskName, not TaskNumber, since it's what you actually want to
% read off a confusion matrix).
movements = string(struct2cell(jsondecode(fileread(json_filepath)))'); %imports movement json as a struct, converts to cell array
for i = 1:numel(miDB)
    nomcondition = find(movements(:,1) == string(miDB(i).TaskNumber));
    nomresult = movements(nomcondition,2);
    miDB(i).TaskName = nomresult;
end

% Report how many trials of each task are in this session before we
% filter anything out -- useful for spotting a session with too few
% trials of a given movement to be worth including.
taskcats = categorical([miDB.TaskNumber]);
validations.taskcounts = countlabels(taskcats);
disp('total movements in data structure');
disp(validations.taskcounts)

%% Step 2: Restrict to one fixed movement set ─────────────────────────────
% We fix which movements get compared (rather than using whatever's in the
% session) so that accuracy numbers are comparable across sessions and
% participants -- moveset 1 and 2 are the two combinations used throughout
% the manuscript.
if moveset == 1
    keymovements = ['1', '7', '8', '9']'; % rest, fist, pinch, point
elseif moveset == 2
    keymovements = ['1', '2', '3', '4']'; %rest, index, middle, ring flex
else
    disp('choose a set');
end

taskNumbers = [miDB.TaskNumber];
g = ismember(string(taskNumbers), keymovements);
miDB = miDB(g);

% If a session is missing one of the key movements entirely (e.g. a
% partial recording), that's a data problem worth stopping for rather than
% silently training on fewer classes than expected.
if length(unique([miDB.TaskNumber])) ~= length(keymovements)
    error('heads up -- not all key movements available in this datset')
else
    disp('all key movments available in this dataset')
end

disp('movements available:')
disp([miDB.TaskNumber])

%% Step 3: Extract MAV features from the cue window ───────────────────────
% We don't use the whole trial -- only a 1-second window starting 1 second
% after the nominal cue (RestTime), to make sure the participant has
% actually started the movement rather than still reacting to the cue.
% win_ms converts that time window into MAV row indices, since MAVs is
% already binned into win_ms-wide windows rather than raw samples.
for i = 1:numel(miDB)
    cue_start_s = (miDB(i).RestTime + 1000)/1000; %for s 
    cue_end_s   = (miDB(i).RestTime + 2000)/1000; %for s 
    
    cue_start_win = floor(cue_start_s / (win_ms/1000)) + 1;  % +1 for 1-based indexing
    cue_end_win   = floor(cue_end_s   / (win_ms/1000));
   
    miDB(i).MAV_cue = miDB(i).MAVs(cue_start_win : cue_end_win,:);   % [n_cue_windows x n_channels]
    miDB(i).MAV_collapse = mean(miDB(i).MAV_cue,1); % average across the cue window -> one feature vector per trial
end

%% Step 4: Assemble the feature matrix ────────────────────────────────────
% fitc* functions want a flat [n_samples x n_features] matrix X and a
% matching label list Y, not a struct array -- this loop flattens miDB
% into that shape. Note each trial contributes multiple rows to X (one per
% MAV window in its cue period, not just one row per trial), which is why
% we also track trialID here -- Step 5 needs it to make sure a fold split
% never puts windows from the same trial in both train and test.
disp('Extracting and formatting data...');

numTrials = length(miDB);

X = []; % Predictor matrix (Features)
Y = {}; % Response cell array (Labels)
trialID = [];   % which trial each row of X came from

for i = 1:numTrials
    currentFeatures = miDB(i).MAV_cue;

    if ischar(currentFeatures) || isstring(currentFeatures)
        continue; 
    end

    numSamples = size(currentFeatures, 1);
    currentLabel = {char(miDB(i).TaskName)};

    X = [X; currentFeatures];
    Y = [Y; repmat(currentLabel, numSamples, 1)];
    trialID = [trialID; repmat(i, numSamples, 1)];
end

disp(['Data formatted! Total samples: ', num2str(size(X,1)), ', Features: ', num2str(size(X,2))]);

%% Step 5: Stratified k-fold cross-validation ─────────────────────────────
% Stratified so each fold has a proportional mix of every task, not just
% whatever happened to shuffle in -- important given how few trials per
% task this dataset has. cvpartition splits are done on trialLabels (one
% per trial) rather than on X directly, so every window from the same
% trial always ends up in the same fold together.
disp('Step 3: Setting up stratified k-fold cross-validation...');
rng('default');  % seed for reproducibility

k = 4; % number of folds — reduce to 3 if dataset is very small
trialLabels = categorical(cellfun(@(t) char(t), {miDB.TaskName}, 'UniformOutput', false));
cv = cvpartition(trialLabels, 'KFold', k, 'Stratify', true);

allTrue  = {};
predTree_all = {};
predKNN_all  = {};
predLDA_all  = {};

disp('Training and predicting across folds...');

for fold = 1:k
    fprintf(' - Fold %d of %d\n', fold, k);

    trainTrials = find(training(cv, fold));
    testTrials  = find(test(cv, fold));

    trainIdx = ismember(trialID, trainTrials);
    testIdx  = ismember(trialID, testTrials);

    X_train = X(trainIdx, :);  Y_train = Y(trainIdx, :);
    X_test  = X(testIdx,  :);  Y_test  = Y(testIdx,  :);

    % Three simple, fast-to-train classifiers -- not meant to be
    % state-of-the-art, just a baseline sanity check that the features
    % separate the movements at all.
    mdlTree = fitctree(X_train, Y_train);
    mdlKNN  = fitcknn(X_train, Y_train, 'NumNeighbors', 5);
    mdlLDA  = fitcdiscr(X_train, Y_train);

    allTrue      = [allTrue;      Y_test];
    predTree_all = [predTree_all; predict(mdlTree, X_test)];
    predKNN_all  = [predKNN_all;  predict(mdlKNN,  X_test)];
    predLDA_all  = [predLDA_all;  predict(mdlLDA,  X_test)];
end

% Only the last fold's trained models are kept for inspection -- accuracy
% below is pooled across all folds' predictions, not just this last one.
validations.mdlTree = mdlTree;
validations.mdlKNN  = mdlKNN;
validations.mdlLDA  = mdlLDA;

validations.X_train = X_train;  validations.Y_train = Y_train;
validations.X_test  = X_test;   validations.Y_test  = Y_test;
validations.predTree = predTree_all;
validations.predKNN  = predKNN_all;
validations.predLDA  = predLDA_all;

%% Step 6: Accuracy and confusion matrices ────────────────────────────────
accTree = round(sum(cellfun(@strcmp, allTrue, predTree_all)) / numel(allTrue) * 100, 2);
accKNN  = round(sum(cellfun(@strcmp, allTrue, predKNN_all))  / numel(allTrue) * 100, 2);
accLDA  = round(sum(cellfun(@strcmp, allTrue, predLDA_all))  / numel(allTrue) * 100, 2);

disp('Generating Confusion Matrices...');

mainFig = figure('WindowState', 'maximized', 'Name', 'Multi-Model Performance Comparison', 'NumberTitle', 'off');
tl = tiledlayout(mainFig, 1, 3);
tl.TileSpacing = 'compact';
tl.Padding = 'compact';
xlabel(tl, 'Predicted Class', 'FontSize', 14, 'FontWeight', 'bold');
ylabel(tl, 'True Class',      'FontSize', 14, 'FontWeight', 'bold');

nexttile(tl);
cmTree = confusionchart(allTrue, predTree_all, ...
    'Title', sprintf('Decision Tree\nDecoder accuracy: %.1f%%', accTree), ...
    'Normalization', 'row-normalized', 'RowSummary', 'off', 'ColumnSummary', 'off');
cmTree.FontSize = 10;

nexttile(tl);
cmKNN = confusionchart(allTrue, predKNN_all, ...
    'Title', sprintf('k-Nearest Neighbors\nDecoder accuracy: %.1f%%', accKNN), ...
    'Normalization', 'row-normalized', 'RowSummary', 'off', 'ColumnSummary', 'off');
cmKNN.FontSize = 10;

nexttile(tl);
cmLDA = confusionchart(allTrue, predLDA_all, ...
    'Title', sprintf('Linear Discriminant\nDecoder accuracy: %.1f%%', accLDA), ...
    'Normalization', 'row-normalized', 'RowSummary', 'off', 'ColumnSummary', 'off');
cmLDA.FontSize = 10;

disp('Done!');
validations.accuracies = [accTree, accKNN, accLDA];
validations.modelNames = {'Decision Tree', 'k-NN', 'LDA'};
disp('accuracies');
disp(validations.modelNames);
disp(validations.accuracies);
disp('storing and exporting data');

end
