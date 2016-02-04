function [sensorData, badChannels, badEpochs] = dfdPreprocessData(sensorDataIn, varThreshold, ...
    badChannelThreshold, badEpochThreshold, verbose)
% Preprocess MEG data
%
%sensorData = dfdPreprocessData(sensorDataIn, varThreshold, ...
%    badChannelThreshold, badEpochThreshold)
%
% INPUTS
%   sensorDataIn: 3D array, time points x epochs x channels
%
%   varThreshold: Vector of length 2 ([min max]) to indicate variance
%                   threshold. For any channel in any give epoch, if the
%                   variance in the time series is outside [min max] * the
%                   median variance across all channels and all epochs,
%                   then label that channel during that epoch as 'bad'
%                       Default = [.05 20]
%
%  badChannelThreshold: Fraction ([0 1]). If more than this fraction of
%                   channels in any given epoch is labeled 'bad', then
%                   label all channels for this epoch as 'bad'.
%                       Default = 0.2
%
%  badEpochThreshold: Fraction ([0 1]). If more than this fraction of
%                   epochs for any given channel is labeled 'bad', then
%                   label all epochs for this  channel as 'bad'
%                       Default = 0.2
%
% verbose:          Whether to plot debug figures and display info
%
% OUTPUTS
%   sensorData:     Same as sensorDataIn (3D array, time points x epochs x
%                   channels), except that for which 'bad', data has been
%                   replaced with NaN
%
%
% Example:
%  sensorData = dfdPreprocessData(sensorDataIn, [.01 10], .2, .2);

if notDefined('varThreshold'), varThreshold = [.05 20]; end
if notDefined('badChannelThreshold'), badChannelThreshold = .2; end
if notDefined('badEpochThreshold'), badEpochThreshold = .2; end
if notDefined('verbose'), verbose = false; end
if notDefined('use3channels'), use3channels = false; end

% This identifies any epochs whos variance is outside some multiple of the
% grand variance
outliers = meg_find_bad_epochs(sensorDataIn, varThreshold);

% any epoch in which more than 10% of channels were bad should be removed
% entirely
badEpochs = mean(outliers,2)>badChannelThreshold;

% once we remove 'badEpochs', check whether any channels have more
% than 10% bad epochs, and we will remove these
badChannels = mean(outliers(~badEpochs,:),1)>badEpochThreshold;

outliers(badEpochs,:)   = 1;
outliers(:,badChannels) = 1;

% Plot outiers for epochs and channels
if verbose
    figure; imagesc(outliers);
    xlabel('channel number'); ylabel('epoch number'); title('Bad channels / epochs')
    fprintf('(dfdPreprocessData): %5.2f%% of epochs removed\n', sum(sum(outliers))/(size(sensorDataIn,2)*size(sensorDataIn,3))*100);
end

% Check how many sensors there are, if there are more than 192, it will be
% a neuromag360 dataset and we need a different layout for interpolation
if size(sensorDataIn,3) > 192;
    sensorPositions = 'neuromag360xyz';
else
    sensorPositions = [];
end

% Interpolate epochs over neighbouring channels
sensorData = dfdChannelRepair(sensorDataIn, outliers, 'nearest',sensorPositions);

% Denoise with three environmental channels
if use3channels
    environmentalChannels = 158:160;
    dataChannels          = 1:157;
    sensorData = dfdEnvironmentalDenoising(sensorData, environmentalChannels, dataChannels);
end

return

function outliers = meg_find_bad_epochs(ts, thresh)
if ~exist('thresh', 'var') || isempty(thresh),
    thresh = [0.1 10];
end

var_matrix       = squeeze(nanvar(ts,[],1)); % var_matrix will be epochs x channels
var_grand_median = nanmedian(var_matrix(:)); % grand median

outliers = var_matrix < thresh(1) * var_grand_median | ...
    var_matrix > thresh(2) * var_grand_median;
return


function ts = meg_remove_bad_epochs(outliers, ts)
% epochs x channel
num_time_points = size(ts,1);
num_epochs      = size(ts,2);
num_channels    = size(ts,3);

ts = reshape(ts, [num_time_points, num_epochs*num_channels]);

ts(:, logical(outliers(:))) = NaN;

ts = reshape(ts, [num_time_points, num_epochs, num_channels]);

return

function sensorDataDenoised = dfdEnvironmentalDenoising(sensorData,environmentalChannels, dataChannels)
% Make empty arrays for regressed 'clean' data
sensorDataDenoised = sensorData;

warning off stats:regress:RankDefDesignMat

% Start regression, keep residuals
for channel = dataChannels; 
    if verbose
        fprintf('[%s]: Channel %d\n', mfilename, channel);
    end
    for epoch = 1:size(sensorData,2);
        [~,~,R] = regress(sensorData(:,epoch,channel),[squeeze(sensorData(:,epoch,environmentalChannels)) ones(size(sensorData,1),1)]);
        sensorDataDenoised(:,epoch,channel) = R;
        clear R 
    end
end
warning on stats:regress:RankDefDesignMat

return

