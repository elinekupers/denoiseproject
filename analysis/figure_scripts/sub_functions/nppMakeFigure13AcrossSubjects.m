function data = nppMakeFigure13AcrossSubjects(whichSubjects,figureDir,dataDir,saveFigures,threshold)
%% Function to reproduce Figure 13 (Spatialmap) across CiNet dataset subjects
%
% data = nppMakeFigure13AcrossSubjects(whichSubjects,figureDir,dataDir,saveFigures,threshold)
%
% INPUTS:
% whichSubjects : (element or vector) subject number of datasets you want to plot (see
%                   subjectDescription.rtf for info about datasets)
% figureDir     : (string) folder where to save the figure
% dataDir       : (string) folder where to find the data
% saveFigures   : (boolean) save the figure
% threshold     : (element) number to set limit for colormap
%
% OUTPUTS:
% data          : (cell) data of the plotted meshes

% AUTHORS. TITLE. JOURNAL. YEAR.
%
% This figure will show an interpolated spatial map of the SNR values in
% each channel for the stimulus locked signal, broadband signals before
% using the denoising algorithm. The three separate conditions (Full,
% left, right hemifield stimulation are shown separately).
%
% This function assumes that data is downloaded with the nppdownloaddata
% function.

%% Compute SNR across subjects
contrasts = [eye(3); 0 1 -1];
contrasts = bsxfun(@rdivide, contrasts, sqrt(sum(contrasts.^2,2)));
computeSNR    = @(x) nanmean(x,3) ./ nanstd(x, [], 3);
contrastNames = {'Full','Left','Right','Left-Right'};

if isequal(whichSubjects,[9:12])
    str = {'SL raw' 'BB raw' 'BB noisepool-PCA'}; figName = 'RAW';
elseif isequal(whichSubjects,[14,16,18,20])
    str = {'SL raw' 'BB TSSS' 'BB TSSS + noisepool-PCA'}; figName = 'TSSS';
end

%% Load denoised data of all subjects
for whichSubject = whichSubjects
    subjnum = find(whichSubject==whichSubjects);
    data = prepareData(dataDir,whichSubject,14);
    bb(subjnum) = data{1};
    sl(subjnum) = data{2};
    
    % SL
    num_channels = size(sl(subjnum).results.origmodel.beta,2);
    num_boots    = size(sl(subjnum).results.origmodel.beta,3);
    num_contrasts = length(contrasts);
    
    tmp_data = reshape(sl(subjnum).results.origmodel.beta,3,[]);
    tmp = contrasts*tmp_data;
    tmp = reshape(tmp, num_contrasts, num_channels, num_boots);
    sSL = computeSNR(tmp)';
    
    % BB before
    tmp_data = reshape(bb(subjnum).results.origmodel.beta,3,[]);
    tmp = contrasts*tmp_data;
    tmp = reshape(tmp, num_contrasts, num_channels,num_boots);
    sBBBefore = computeSNR(tmp)';
    
    % BB before
    tmp_data = reshape(bb(subjnum).results.finalmodel.beta,3,[]);
    tmp = contrasts*tmp_data;
    tmp = reshape(tmp, num_contrasts, num_channels,num_boots);
    sBBAfter = computeSNR(tmp)';
    
    if subjnum == 1
        sSLAcrossSubjects = NaN(size(contrasts,1),length(sl(1).badChannels), length(whichSubjects));
        sBBBeforeAcrossSubjects = sSLAcrossSubjects;
        sBBAfterAcrossSubjects  = sSLAcrossSubjects;
    end
    
    sSLAcrossSubjects(:,:,subjnum) = to157chan(sSL', ~sl(subjnum).badChannels,'nans');
    sBBBeforeAcrossSubjects(:,:,subjnum) = to157chan(sBBBefore', ~bb(subjnum).badChannels,'nans');
    sBBAfterAcrossSubjects(:,:,subjnum) = to157chan(sBBAfter', ~bb(subjnum).badChannels,'nans');
end


%% Plot stimulus-locked signal, broadband before and after denoising on sensormap

% stimulus locked
data{1} = sSLAcrossSubjects;
data{2} = sBBBeforeAcrossSubjects;
data{3} = sBBAfterAcrossSubjects;
cmap = bipolar;

figure,set(gcf, 'Name', figName)
for row = 1:4 % stimulus contrasts
    for col = 1:3 % types of analyses (sl, bb-pre, bb-post)
        subplot(4,3,3*(row-1)+col),
        if col == 1, clim = [-15 15]; else clim = [-4 4]; end
        megPlotMap(npp204to102(squeeze(mean(data{col}(row,:,:),3))), ...
            clim, [], cmap); drawnow;       
        if row == 1, title(str{col}); end
    end
end

if saveFigures
    % Only use figure write when producing high quality manuscript figure
    % (since it is very slow)
    hgexport(gcf, fullfile(figureDir,sprintf('figure13_AcrossSubject%d_threshold%d_%s',whichSubject, threshold, figName)));
%     figurewrite(fullfile(figureDir,sprintf('figure14a_TSSS_%s',figName)),[],0,'.',1);

end

