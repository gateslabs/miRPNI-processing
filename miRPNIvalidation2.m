function validationz = miRPNIvalidation2(miDB, movements)

%this function uses stratified k-fold cross-validation instead cause the dataset
%is quite small when looking at it as is.

% be sure to run below to load file of interest before running this
% function
%load("path\to\miRPNI\P1\mat\P1_S1_EMG.mat")

%generate list of tasknames from task numbers
for i = 1:numel(miDB)
    nomcondition = find(movements(:,2) == string(miDB(i).TaskNumber));
    nomresult = movements(nomcondition,1);
    miDB(i).TaskName = nomresult;
end

% get final counts for movements
% this is to get final counts for each movement per participant cause i
% need final answers for reviews
taskcats = categorical([miDB.TaskNumber]);
validationz.taskcounts = countlabels(taskcats);
disp('total movements in data structure');
disp(validationz.taskcounts)

% filter out data to only contain these movements:
keymovements = ['1', '7', '8', '9']';
%keymovements = ['1', '2', '3', '4']'; %some sessions that dont have grasps
%above, so this is an alternative moveset to use

taskNumbers = [miDB.TaskNumber];

g = ismember(string(taskNumbers), keymovements);
miDB = miDB(g);

%check to see if all unique moves are available. if not throw a flag for later analysis

if length(unique([miDB.TaskNumber])) ~= length(keymovements)
    disp('heads up -- not all key movements available in this datset')
else
    disp('all key movments available in this dataset')
end

disp('movements available:')
disp([miDB.TaskNumber])


% grab only the MAVs relevant to movement (not based on movement onset atm)
for i = 1:numel(miDB)
    winStart = length(miDB(i).MAVs)-miDB(i).HoldTime+1; %this should ensure start of hold time regardless of rest time
    winEnd = winStart + 999; %1000ms window

    miDB(i).MAVz = miDB(i).MAVs([winStart:winEnd],:);

    % collapse into a 1xnumchans array for prediction
    miDB(i).MAVcollapse = mean(miDB(i).MAVz,1); % (averaged across timesteps)

end

%% Format Data for fitc* commands
disp('Extracting and formatting data...');

numTrials = length(miDB);
X = []; % Predictor matrix (Features)
Y = {}; % Response cell array (Labels) - Changed to cell array

for i = 1:numTrials
    % Extract the MAV features for this trial
    %currentFeatures = miDB(i).MAVz; 
    currentFeatures = miDB(i).MAVcollapse;

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


%% Stratified K-Fold Cross-Validation 

%k-fold was done because some session days had very few samples to work
%with

disp('Setting up stratified k-fold cross-validation...');

k = 3; % number of folds — reduce to 3 if dataset is very small
cv = cvpartition(categorical(Y), 'KFold', k, 'Stratify', true);

% Preallocate accumulator arrays for predictions and ground truth
allTrue  = {};
predTree_all = {};
predKNN_all  = {};
predLDA_all  = {};

%% Train and Predict across each fold
disp('Training and predicting across folds...');

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

% Accuracy across all folds

accTree = round(sum(cellfun(@strcmp, allTrue, predTree_all)) / numel(allTrue) * 100, 2);
accKNN  = round(sum(cellfun(@strcmp, allTrue, predKNN_all))  / numel(allTrue) * 100, 2);
accLDA  = round(sum(cellfun(@strcmp, allTrue, predLDA_all))  / numel(allTrue) * 100, 2);

%% Confusion Matrices (unchanged, just uses allTrue now)
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
validationz.accuracies = [accTree, accKNN, accLDA];
validationz.modelNames = {'Decision Tree', 'k-NN', 'LDA'};
disp('accuracies');
disp(validationz.modelNames);
disp(validationz.accuracies);
disp('storing and exporting data');

end