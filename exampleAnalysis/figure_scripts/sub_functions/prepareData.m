function [data,design,exampleIndex] = prepareData(dataDir,whichSubject,whichFigure)

switch whichFigure
    case 4
        % Load denoised data
        load(sprintf(fullfile(dataDir, 's0%d_denoisedData_bb.mat'),whichSubject));
        load(sprintf(fullfile(dataDir, 's0%d_conditions.mat'),whichSubject));
        load(sprintf(fullfile(dataDir, 's0%d_sensorData.mat'),whichSubject));
        
        %% preprocess raw data here
        
        %%
        
        exampleChannel = 42;
        
        % preprocessing parameters (see dfdPreprocessData)
        varThreshold        = [0.05 20];
        badChannelThreshold = 0.2;
        badEpochThreshold   = 0.2;
        dataChannels        = 1:157;
        use3Channels        = false;
        
        % ******* Preprocess data **********************
        [sensorData, badChannels0, badEpochs0] = dfdPreprocessData(sensorData(:,:,dataChannels), ...
            varThreshold, badChannelThreshold, badEpochThreshold, use3Channels);
        
        % Remove bad channels and bad epochs from data and conditions
        sensorData = sensorData(:,~badEpochs0, ~badChannels0);
                 
        % Permute sensorData for denoising
        sensorData = permute(sensorData, [3 1 2]);
        
        % time domain data before and after denoising
        data = {sensorData,denoisedts{1}}; %#ok<USENS>
        
    case 5
        bb = load(sprintf(fullfile(dataDir, 's0%d_denoisedData_bb.mat'),whichSubject));
        sl = load(sprintf(fullfile(dataDir, 's0%d_denoisedData_sl.mat'),whichSubject));
        load(sprintf(fullfile(dataDir, 's0%d_conditions.mat'),whichSubject));
        
        data = {bb,sl};
        
    case 6
        data = load(sprintf(fullfile(dataDir, 's0%d_denoisedData_full_bb.mat'),whichSubject));
        load(sprintf(fullfile(dataDir, 's0%d_conditions.mat'),whichSubject));
        
    case 7
        data = load(sprintf(fullfile(dataDir, 's0%d_denoisedData_bb.mat'),whichSubject));
        load(sprintf(fullfile(dataDir, 's0%d_conditions.mat'),whichSubject));
        
    case 8
        data = load(sprintf(fullfile(dataDir, 's0%d_denoisedData_bb.mat'),whichSubject));
        load(sprintf(fullfile(dataDir, 's0%d_conditions.mat'),whichSubject));
        
    case 9
        data = load(sprintf(fullfile(dataDir, 's0%d_denoisedData_bb.mat'),whichSubject));
        load(sprintf(fullfile(dataDir, 's0%d_conditions.mat'),whichSubject));
        
    case 11
        data = load(sprintf(fullfile(dataDir, 's0%d_denoisedData_full_sl.mat'),whichSubject));
        load(sprintf(fullfile(dataDir, 's0%d_conditions.mat'),whichSubject));
        
    case 12
        data = load(sprintf(fullfile(dataDir, 's0%d_denoisedData_sl.mat'),whichSubject));
        load(sprintf(fullfile(dataDir, 's0%d_conditions.mat'),whichSubject));
        
        
end

%% Spectrum before and after denoising

% Because some channels were removed prior to the denoising (due to
% excessive noise), there are fewer channels in the denoised data than in
% the original data. We need to identify the correspondence.
if ~exist('exampleChannel','var')
    exampleIndex = [];
    
    
    % Compute design matrix
    design = zeros(size(conditions,1),3);
    design(conditions == 1,1) = 1; % Full
    design(conditions == 5,2) = 1; % Right
    design(conditions == 7,3) = 1; % Left
    
    if whichFigure == 5
        design = [];
    else
        design = design(~data.badEpochs,:);
    end
    
else
    exampleIndex = megGetOrigChannel(exampleChannel,badChannels);
    
    % Compute design matrix
    design = zeros(size(conditions,1),3);
    design(conditions == 1,1) = 1; % Full
    design(conditions == 5,2) = 1; % Right
    design(conditions == 7,3) = 1; % Left
    
    design0 = design(~badEpochs0,:);
    design1 = design(~badEpochs,:);
    design = {design0, design1};
end






