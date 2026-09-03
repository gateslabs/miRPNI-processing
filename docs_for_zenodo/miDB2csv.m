function [MAVs, Data1k, Data1kf, Data30k, Data30kf] = miDB2csv(inDB, numchans)

% i think i'll split them into separate vals , mavs and emg1k/f
% cant do 30k cause too big
disp('converting to csv')

mavtestmat = [];
emg1ktestmat = [];
emg1kftestmat = [];

Fs = 1000;

for i = 1:length(inDB) 
    restime = inDB(i).RestTime;  % duration in ms
    cuetime = inDB(i).HoldTime;  % duration in ms
    
    %adding a logical vector for rest and cue times, sttarting with the 1000
    %hz data
    disp('concatenating 1khz EMG data for csv export')

    restSamples_1k = restime * (Fs / 1000); 
    cueSamples_1k  = cuetime * (Fs / 1000);   

    restvec_1k = zeros([restSamples_1k, 1]);
    cuevec_1k  = ones([cueSamples_1k, 1]);

    timevec_1k = [restvec_1k;cuevec_1k];
    trialvec_1k = i*ones(size(timevec_1k));
    
    EMG1kf = inDB(i).EMG1kf;
    EMG1k = inDB(i).EMG1k;

    emg1_node = [trialvec_1k, timevec_1k, EMG1k];
    emg1ktestmat = [emg1ktestmat; emg1_node];

    emg1f_node = [trialvec_1k, timevec_1k, EMG1kf];
    emg1kftestmat = [emg1kftestmat; emg1f_node];

    %creating time vector for new MAV calculations
    n_windows = size(inDB(i).MAVs, 1);
    % --- Build time vector (one entry per MAV window) ---
    % Each value = start time of that window in seconds
    win_ms = 50;
    time_s = (0 : n_windows - 1)' * (win_ms / 1000);  % [n_windows x 1]

    trial_vec_mav = i*ones(size(time_s));
    mav_node = [trial_vec_mav, time_s, inDB(i).MAVs];
    mavtestmat = [mavtestmat; mav_node];
end


%%
header = ["TrialID", "MovementCue"];
emg1head = header;
emg1fhead = header;

mavhead = ["TrialID", "WindowStartTime"];

for i = 1:numchans
    emg1head(:,i+2) = append("EMG1k_",num2str(i));
    emg1fhead(:,i+2) = append("EMG1kf_",num2str(i));
    mavhead(:,i+2) = append("MAV_",num2str(i));
end

%% adding header variable to final csv
emg1ktestmat = [emg1head; emg1ktestmat];
emg1kftestmat = [emg1fhead; emg1kftestmat];
mavtestmat = [mavhead; mavtestmat];

MAVs = mavtestmat;
Data1k = emg1ktestmat;
Data1kf = emg1kftestmat;

% %% adding 30k data if it extists:
% if isfield(inDB,'EMG30kf')
%     [Data30k, Data30kf] = miDB30k2csv(inDB,numchans);
% else
%     disp('no 30k data here!')
%     Data30k = [];
%     Data30kf = [];
% end
Data30k = [];
Data30kf = [];