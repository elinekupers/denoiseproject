
function epoched_data = trial2epoch(trial_data)
 
% Define a trial epoched data (12 s, 12000 time
% points) and an epoch as our desired 1 s (1000 time point)
n_epochs_per_trial                  = 12;
nchannels                           = size(trial_data{1}, 2);
nepochtimepoints                    = 1000;
ntimepoints_per_trial               = nepochtimepoints * n_epochs_per_trial;
nepochs                             = n_epochs_per_trial*numel(trial_data); % all runs together

epoched_data = catcell(3, trial_data);
epoched_data = epoched_data(1:ntimepoints_per_trial, :,:);
epoched_data = reshape(epoched_data, nepochtimepoints, nepochs,nchannels);


end

