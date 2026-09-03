function validations = miRPNIvalidation(miDB, moveset, json_filepath, win_ms)

if nargin < 4, win_ms = 50; end

%this function uses stratified k-fold cross-validation instead cause the dataset
%has pretty few samples to work with (at most 5 per movement)

%generate list of tasknames from movements.json
movements = string(struct2cell(jsondecode(fileread(json_filepath)))'); %imports movement json as a struct, converts to cell array
for i = 1:numel(miDB)
    nomcondition = find(movements(:,1) == string(miDB(i).TaskNumber));
    nomresult = movements(nomcondition,2);
    miDB(i).TaskName = nomresult;
end

% get final counts for movements
taskcats = categorical([miDB.TaskNumber]);
validations.taskcounts = countlabels(taskcats);
disp('total movements in data structure');
disp(validations.taskcounts)

% what movement set do you want to test?
% filter out data to only contain these movements:
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

%check to see if all unique moves are available. if not throw a flag for later analysis
if length(unique([miDB.TaskNumber])) ~= length(keymovements)
    error('heads up -- not all key movements available in this datset')
else
    disp('all key movments available in this dataset')
end

disp('movements available:')
disp([miDB.TaskNumber])

for i = 1:numel(miDB)
    % we want to start about a second into the nominal movement time to
    % ensure that actual movement movement is being done here. so, we'll add
    % the equivalent of an extra second to account for that.

    cue_start_s = (miDB(i).RestTime + 1000)/1000; %for s 
    cue_end_s   = (miDB(i).RestTime + 2000)/1000; %for s 
    
    % convert to MAV window indices
    cue_start_win = floor(cue_start_s / (win_ms/1000)) + 1;  % +1 for 1-based indexing
    cue_end_win   = floor(cue_end_s   / (win_ms/1000));
   
    
    % extract MAV only within the cue window
    miDB(i).MAV_cue = miDB(i).MAVs(cue_start_win : cue_end_win,:);   % [n_cue_windows x 1]
    miDB(i).MAV_collapse = mean(miDB(i).MAV_cue,1); %averaging MAVs across channels for a single vector
   
end


% Format Data for fitc* commands (Revised for compatibility)
disp('Extracting and formatting data...');

numTrials = length(miDB);

% track which trial each window-row came from
X = []; % Predictor matrix (Features)
Y = {}; % Response cell array (Labels) - Changed to cell array
trialID = [];   % trialID: one entry per window-row

for i = 1:numTrials
    % Extract the MAV features for this trial 
    currentFeatures = miDB(i).MAV_cue;

    % Check if MAVs is empty or invalid
    if ischar(currentFeatures) || isstring(currentFeatures)
        continue; 
    end

    numSamples = size(currentFeatures, 1);

    % Extract the label and force it into a cell array of characters
    currentLabel = {char(miDB(i).TaskName)}; %which should have been added ealier in this function

    % Append to our master X and Y arrays
    X = [X; currentFeatures];
    Y = [Y; repmat(currentLabel, numSamples, 1)];
    trialID = [trialID; repmat(i, numSamples, 1)];
end

disp(['Data formatted! Total samples: ', num2str(size(X,1)), ', Features: ', num2str(size(X,2))]);


% Stratified K-Fold Cross-Validation (partitioning trials)
disp('Step 3: Setting up stratified k-fold cross-validation...');
rng('default');  % seed for reproducibility

k = 4; % number of folds — reduce to 3 if dataset is very small
trialLabels = categorical(cellfun(@(t) char(t), {miDB.TaskName}, 'UniformOutput', false));
cv = cvpartition(trialLabels, 'KFold', k, 'Stratify', true);

% Preallocate accumulator arrays for predictions and ground truth
allTrue  = {};
predTree_all = {};
predKNN_all  = {};
predLDA_all  = {};


% Train and Predict across each fold
disp('Training and predicting across folds...');

for fold = 1:k
    fprintf(' - Fold %d of %d\n', fold, k);

    trainTrials = find(training(cv, fold));
    testTrials  = find(test(cv, fold));

    trainIdx = ismember(trialID, trainTrials);
    testIdx  = ismember(trialID, testTrials);


    X_train = X(trainIdx, :);  Y_train = Y(trainIdx, :);
    X_test  = X(testIdx,  :);  Y_test  = Y(testIdx,  :);

    % Train
    mdlTree = fitctree(X_train, Y_train);
    mdlKNN  = fitcknn(X_train, Y_train, 'NumNeighbors', 5);
    mdlLDA  = fitcdiscr(X_train, Y_train);

    % Predict and accumulate
    allTrue      = [allTrue;      Y_test];
    predTree_all = [predTree_all; predict(mdlTree, X_test)];
    predKNN_all  = [predKNN_all;  predict(mdlKNN,  X_test)];
    predLDA_all  = [predLDA_all;  predict(mdlLDA,  X_test)];
end

% Store the last fold's models for inspection if needed
validations.mdlTree = mdlTree;
validations.mdlKNN  = mdlKNN;
validations.mdlLDA  = mdlLDA;

validations.X_train = X_train;  validations.Y_train = Y_train;
validations.X_test  = X_test;   validations.Y_test  = Y_test;
validations.predTree = predTree_all;
validations.predKNN  = predKNN_all;
validations.predLDA  = predLDA_all;

% Accuracy across all folds

accTree = round(sum(cellfun(@strcmp, allTrue, predTree_all)) / numel(allTrue) * 100, 2);
accKNN  = round(sum(cellfun(@strcmp, allTrue, predKNN_all))  / numel(allTrue) * 100, 2);
accLDA  = round(sum(cellfun(@strcmp, allTrue, predLDA_all))  / numel(allTrue) * 100, 2);

% Confusion Matrices
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