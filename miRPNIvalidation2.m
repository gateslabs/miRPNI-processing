function validationz = miRPNIvalidation2(miDB, movements, moveset, win_ms)

if nargin < 4, win_ms = 50; end
%this one uses stratified k-fold cross-validation instead cause the dataset
%has pretty few samples to work with (at most 5 per movement)

%generate list of tasknames from task numbers
for i = 1:numel(miDB)
    nomcondition = find(movements(:,2) == string(miDB(i).TaskNumber));
    nomresult = movements(nomcondition,1);
    miDB(i).TaskName = nomresult;
end

% get final counts for movements
taskcats = categorical([miDB.TaskNumber]);
validationz.taskcounts = countlabels(taskcats);
disp('total movements in data structure');
disp(validationz.taskcounts)

% what movement set do you want to test?
% filter out data to only contain these movements:
if moveset == 1
    keymovements = ['1', '7', '8', '9']'; % rest, fist, pinch, point
elseif moveset == 2
    keymovements = ['1', '2', '3', '4']'; %running this model because there are some seesssions that dont have grasps above
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
% --- Cue timing (edit to match your protocol) ---
    %we want to start about a second into the nominal movement time to
    %ensure that actual movement movement is being done here. so, we'll add
    %the equivalent of an extra second to account for that.

    cue_start_s = (miDB(i).RestTime + 1000)/1000; %for s 
    cue_end_s   = (miDB(i).RestTime + 2000)/1000; %for s 
    
    % Convert to MAV window indices
    cue_start_win = floor(cue_start_s / (win_ms/1000)) + 1;  % +1 for 1-based indexing
    cue_end_win   = floor(cue_end_s   / (win_ms/1000));
   
    
    % Extract MAV only within the cue window
    miDB(i).MAV_cue = miDB(i).MAVs(cue_start_win : cue_end_win,:);   % [n_cue_windows x 1]
    miDB(i).MAV_collapse = mean(miDB(i).MAV_cue,1); %averaging MAVs across channels for a single vector
   
end

% =========================================================================
% Step 2: Format Data for fitc* commands (Revised for compatibility)
% =========================================================================
disp('Step 2: Extracting and formatting data...');

numTrials = length(miDB);
X = []; % Predictor matrix (Features)
Y = {}; % Response cell array (Labels) - Changed to cell array

for i = 1:numTrials
    % Extract the MAV features for this trial
    %currentFeatures = miDB(i).MAVz; 
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
end

disp(['Data formatted! Total samples: ', num2str(size(X,1)), ', Features: ', num2str(size(X,2))]);


% =========================================================================
% Step 3: Stratified K-Fold Cross-Validation (replaces randperm split)
% =========================================================================
disp('Step 3: Setting up stratified k-fold cross-validation...');

k = 4; % number of folds — reduce to 3 if dataset is very small
cv = cvpartition(categorical(Y), 'KFold', k, 'Stratify', true);

% Preallocate accumulator arrays for predictions and ground truth
allTrue  = {};
predTree_all = {};
predKNN_all  = {};
predLDA_all  = {};

% =========================================================================
% Steps 4 & 5: Train and Predict across each fold
% =========================================================================
disp('Step 4/5: Training and predicting across folds...');

for fold = 1:k
    fprintf(' - Fold %d of %d\n', fold, k);

    trainIdx = training(cv, fold);
    testIdx  = test(cv, fold);

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
validationz.mdlTree = mdlTree;
validationz.mdlKNN  = mdlKNN;
validationz.mdlLDA  = mdlLDA;

validationz.X_train = X_train;  validationz.Y_train = Y_train;
validationz.X_test  = X_test;   validationz.Y_test  = Y_test;
validationz.predTree = predTree_all;
validationz.predKNN  = predKNN_all;
validationz.predLDA  = predLDA_all;

% =========================================================================
% Step 5a: Accuracy across all folds
% =========================================================================
accTree = round(sum(cellfun(@strcmp, allTrue, predTree_all)) / numel(allTrue) * 100, 2);
accKNN  = round(sum(cellfun(@strcmp, allTrue, predKNN_all))  / numel(allTrue) * 100, 2);
accLDA  = round(sum(cellfun(@strcmp, allTrue, predLDA_all))  / numel(allTrue) * 100, 2);

% =========================================================================
% Step 6: Confusion Matrices (unchanged, just uses allTrue now)
% =========================================================================
disp('Step 6: Generating Confusion Matrices...');

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
validationz.accuracies = [accTree, accKNN, accLDA];
validationz.modelNames = {'Decision Tree', 'k-NN', 'LDA'};
disp('accuracies');
disp(validationz.modelNames);
disp(validationz.accuracies);
disp('storing and exporting data');

end