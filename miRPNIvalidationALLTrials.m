function validationz = miRPNIvalidationALLTrials(matfiles, set) % tt = miRPNIvalidationALLTrials(matFiles, movements, 1)
% inputs:
% matfiles: a list of days to grab from, for example - 
% matFiles    = {'P3_S1_EMG.mat', 'P3_S2_EMG.mat', 'P3_S3_EMG.mat',...
%     'P3_S4_EMG.mat','P3_S5_EMG.mat','P3_S6_EMG.mat',...
%     'P3_S7_EMG.mat','P3_S8_EMG.mat','P3_S9_EMG.mat'}; 
% -or-
% mf = {'P1_S1_EMG.mat', 'P1_S2_EMG.mat', 'P1_S3_EMG.mat',...
% 'P1_S4_EMG.mat','P1_S5_EMG.mat','P1_S6_EMG.mat',...
% 'P1_S7_EMG.mat','P1_S8_EMG.mat','P1_S9_EMG.mat', 'P1_S10_EMG.mat', 'P1_S11_EMG.mat', 'P1_S12_EMG.mat'};
% set: run for either set 1 (rest, fist, pinch, point) or set 2 (rest, thumb, idx, middle)

largeDB = struct([]); %empty dataset to add to.

%%
for fileIdx = 1:numel(matfiles)
    fname = matfiles{fileIdx};
    fprintf('Processing %s ...\n', fname);

    % Load the HDF5-based .mat (v7.3) file
    load(fname);
    

    %generate list of tasknames from task numbers
    for i = 1:numel(miDB)
        nomcondition = find(movements(:,2) == string(miDB(i).TaskNumber));
        nomresult = movements(nomcondition,1);
        miDB(i).TaskName = nomresult;
    end

    % remove extraneous 30k data for the sake of concatenation
    if isfield(miDB, "EMG30k")
        miDB = rmfield(miDB, "EMG30k");
    end
    if isfield(miDB, "EMG30kf")
        miDB = rmfield(miDB, "EMG30kf");
    end

    % filter out data to only contain these movements (based on set number)
    if set == 1
        keymovements = ['1', '7', '8', '9']'; % rest, fist, pinch, point
    elseif set == 2
        keymovements = ['1', '2', '3', '4']'; %running this model because there are some seesssions that dont have grasps above
    else
        disp('choose a set');
    end
    
    taskNumbers = [miDB.TaskNumber];
    g = ismember(string(taskNumbers), keymovements);
    miDB2 = miDB(g);


    % grab only the MAVs relevant to movement (not based on movement onset atm)
    for i = 1:numel(miDB2)
        winStart = length(miDB2(i).MAVs)-miDB2(i).HoldTime+1; %this should ensure start of hold time regardless of rest time
        %winStart = miDB(i).HoldTime + 1000; %a thousand ms into hold period 
        winEnd = winStart + 999;
    
        miDB2(i).MAVz = miDB2(i).MAVs([winStart:winEnd],:);
    
        % collapse into a 1xnumchans array for prediction
        miDB2(i).MAVcollapse = mean(miDB2(i).MAVz,1); % (averaged across timesteps)
        
        %for sanity's sake: add session number to database
        miDB2(i).SessionNumber = fileIdx;
    end

    %append to larger matrix if anything exists in miDB2
    if size(miDB2,2) > 0
        largeDB = [largeDB,miDB2];
    end
end
    
%

%% Format Data for fitc* commands

disp('Extracting and formatting data...');

numTrials = length(largeDB);
X = []; % Predictor matrix (Features)
Y = {}; % Response cell array (Labels) - Changed to cell array

for i = 1:numTrials
    % Extract the MAV features for this trial
    %currentFeatures = miDB(i).MAVz; 
    currentFeatures = largeDB(i).MAVcollapse;
    
    % Check if MAVs is empty or invalid
    if ischar(currentFeatures) || isstring(currentFeatures)
        continue; 
    end
    
    numSamples = size(currentFeatures, 1);
    
    % Extract the label and force it into a cell array of characters
    currentLabel = {char(largeDB(i).TaskName)}; %which should have been added ealier in this function
    
    % Append to our master X and Y arrays
    X = [X; currentFeatures];
    Y = [Y; repmat(currentLabel, numSamples, 1)];
end

disp(['Data formatted! Total samples: ', num2str(size(X,1)), ', Features: ', num2str(size(X,2))]);


%% Split Data into Training and Testing Sets (Manual Split)
disp('Splitting data into train/test sets using randperm...');

% Get the total number of rows
numObservations = size(X, 1);
validationz.numObservations = numObservations;

% Create a randomly shuffled list of indices
shuffledIdx = randperm(numObservations);

% Define the split ratio (e.g., 80% training, 20% testing)
trainRatio = 0.8;
numTrain = round(trainRatio * numObservations);


% Assign indices to train and test sets
trainIdx = shuffledIdx(1:numTrain);
testIdx  = shuffledIdx(numTrain+1:end);

% Create the final training and testing arrays
X_train = X(trainIdx, :);
Y_train = Y(trainIdx, :);

X_test = X(testIdx, :);
Y_test = Y(testIdx, :);

validationz.X_train = X_train;
validationz.Y_train = Y_train;
validationz.X_test = X_test;
validationz.Y_test = Y_test;

%% Train Classifiers

disp('Training Classifiers...');

% 1. Decision Tree
disp(' - Training Decision Tree (fitctree)...');
mdlTree = fitctree(X_train, Y_train);

% 2. k-Nearest Neighbors (k-NN)
disp(' - Training k-NN (fitcknn)...');
mdlKNN = fitcknn(X_train, Y_train, 'NumNeighbors', 5);

% 3. Linear Discriminant Analysis (LDA)
% (Using LDA instead of SVM (fitcecoc) because SVM might take a very long 
% time to train on hundreds of thousands of rows)
disp(' - Training LDA (fitcdiscr)...');
mdlLDA = fitcdiscr(X_train, Y_train);

validationz.mdlTree = mdlTree;
validationz.mdlKNN = mdlKNN;
validationz.mdlLDA = mdlLDA;

%% Make Predictions

disp('Making predictions on test data...');
predTree = predict(mdlTree, X_test);
predKNN  = predict(mdlKNN, X_test);
predLDA  = predict(mdlLDA, X_test);

validationz.predTree = predTree;
validationz.predKNN = predKNN;
validationz.predLDA = predLDA;

% Calculate overall percentage accuracy for each model
disp(' - Calculating overall accuracy...');
accTree = round(sum(cellfun(@strcmp, Y_test, predTree)) / length(Y_test) * 100, 2);
accKNN  = round(sum(cellfun(@strcmp, Y_test, predKNN)) / length(Y_test) * 100, 2);
accLDA  = round(sum(cellfun(@strcmp, Y_test, predLDA)) / length(Y_test) * 100, 2);


%% Visualize Results (Confusion Matrices)
disp('Step 6: Generating Confusion Matrices...');

% 5b. Create a new, multi-panel figure
mainFig = figure('WindowState', 'maximized', 'Name', 'Multi-Model Performance Comparison', 'NumberTitle', 'off');

% Use tiledlayout to create a 1 row x 3 column grid of subplots.
tl = tiledlayout(mainFig, 1, 3);
tl.TileSpacing = 'compact';
tl.Padding = 'compact';

% Create overall x and y labels for the whole figure
xlabel(tl, 'Predicted Class', 'FontSize', 14, 'FontWeight', 'bold');
ylabel(tl, 'True Class', 'FontSize', 14, 'FontWeight', 'bold');

% --- Panel 1: Decision Tree ---
nexttile(tl);
cmTree = confusionchart(Y_test, predTree, ...
    'Title', sprintf('Decision Tree\nDecoder accuracy: %.1f%%', accTree), ...
    'Normalization', 'row-normalized', ... % This is how we get percentage in each box
    'RowSummary', 'off', ...
    'ColumnSummary', 'off');
cmTree.FontSize = 10; % Adjust font size of labels and percentages

% --- Panel 2: k-Nearest Neighbors ---
nexttile(tl);
cmKNN = confusionchart(Y_test, predKNN, ...
    'Title', sprintf('k-Nearest Neighbors\nDecoder accuracy: %.1f%%', accKNN), ...
    'Normalization', 'row-normalized', ...
    'RowSummary', 'off', ...
    'ColumnSummary', 'off');
cmKNN.FontSize = 10;

% --- Panel 3: Linear Discriminant Analysis ---
nexttile(tl);
cmLDA = confusionchart(Y_test, predLDA, ...
    'Title', sprintf('Linear Discriminant\nDecoder accuracy: %.1f%%', accLDA), ...
    'Normalization', 'row-normalized', ...
    'RowSummary', 'off', ...
    'ColumnSummary', 'off');
cmLDA.FontSize = 10;

disp('Done!');

validationz.accuracies = [accTree, accKNN, accLDA];
validationz.modelNames = {'Decision Tree', 'k-NN', 'LDA'};
disp('accuracies');
disp(validationz.modelNames)
disp(validationz.accuracies)

disp('storing and exporting data')


end