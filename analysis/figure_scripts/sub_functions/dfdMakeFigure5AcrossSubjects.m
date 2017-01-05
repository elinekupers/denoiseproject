function dfdMakeFigure5AcrossSubjects

%% Function to reproduce Figure 5 (Spatialmap) across all subjects
%
% dfdMakeFigure5AcrossSubjects()
%
% AUTHORS. TITLE. JOURNAL. YEAR.
%
% This figure will show an interpolated spatial map of the SNR values in
% each channel for the stimulus locked signal, broadband signals before
% using the denoising algorithm. The three separate conditions (Full,
% left, right hemifield stimulation are shown separately).
%
% This function assumes that data is downloaded with the DFDdownloaddata
% function.

%% Choices to make:
whichSubjects    = [1:8];        % Subject 1 is the example subject.
% whichSubjects    = [9:12];%[14,16,18,20];        % Subject 1 is the example subject.
figureDir       = fullfile(dfdRootPath, 'analysis', 'figures'); % Where to save images?
dataDir         = fullfile(dfdRootPath, 'analysis', 'data');    % Where to save data?
saveFigures     = true;     % Save figures in the figure folder?
threshold       = 0;

%% Compute SNR across subjects
contrasts = [eye(3); 0 1 -1];
contrasts = bsxfun(@rdivide, contrasts, sqrt(sum(contrasts.^2,2))); % Full, Left, Right and L-R
computeSNR    = @(x) nanmean(x,3) ./ nanstd(x, [], 3);
% computeSignal = @(x) nanmean(x,3);

contrastNames = {
    'Full'...
    'Left'...
    'Right'...
    'Left-Right'
    };

%% Load denoised data of all subjects

for whichSubject = whichSubjects
    subjnum = find(whichSubjects==whichSubject);
    data = prepareData(dataDir,whichSubject,5);
    bb = data{1};
    sl = data{2};
    
    % SL
    num_channels = size(sl.results.origmodel.beta,2);
    num_boots    = size(sl.results.origmodel.beta,3);
    num_contrasts = length(contrasts);
    
    tmp_data = reshape(sl.results.origmodel.beta,3,[]);
    tmp = contrasts*tmp_data;
    tmp = reshape(tmp, num_contrasts, num_channels, num_boots);
    sSL = computeSNR(tmp)';
    
    % BB before
    tmp_data = reshape(bb.results.origmodel.beta,3,[]);
    tmp = contrasts*tmp_data;
    tmp = reshape(tmp, num_contrasts, num_channels,num_boots);
    sBBBefore = computeSNR(tmp)';
    
    if subjnum == 1
        sSLAcrossSubjects = NaN(size(contrasts,1),length(sl(1).badChannels), length(whichSubjects));
        sBBBeforeAcrossSubjects = sSLAcrossSubjects;
    end
    
    sSLAcrossSubjects(:,:,subjnum) = to157chan(sSL', ~sl.badChannels,'nans');
    sBBBeforeAcrossSubjects(:,:,subjnum) = to157chan(sBBBefore', ~bb.badChannels,'nans');
    
end



%% Plot stimulus-locked signal, broadband before and after denoising on sensormap
figure('position',[1,600,1400,800]); set(gcf, 'Name', 'Figure 5, Group Data', 'NumberTitle', 'off')
n = 0;

% sem = @(x,dim) std(x, [], dim) / sqrt(size(x,dim));
% t_stat = @(x,dim) nanmean(x,dim) ./ sem(x,dim);
for icond = 1:numel(contrastNames)
    
    % get stimulus-locked snr
    %     sl_snr1 = nanmean(sSLAcrossSubjects,3) ./ sem(sSLAcrossSubjects,3);
    sl_snr1 = nanmean(sSLAcrossSubjects,3);
    
    % threshold
    sl_snr1(abs(sl_snr1) < threshold) = 0;
    
    % get broadband snr before denoising
    %     ab_snr1 = nanmean(sBBBeforeAcrossSubjects,3)  ./ sem(sBBBeforeAcrossSubjects,3);
    ab_snr1 = nanmean(sBBBeforeAcrossSubjects,3);
    
    % threshold
    ab_snr1(abs(ab_snr1) < threshold) = 0;
 
    
    % Define ranges colormap
    clims_sl = [-25.6723,25.6723];
    clims_ab = [-8,8];
    if icond == 4; clims_ab = [-5.5363, 5.5363];  end;
    cmap = 'bipolar';
    
    if size(sl_snr1,2) > 157
        % Combine channels
        sl_snr1 = dfd204to102(sl_snr1(icond,:));
        ab_snr1 = dfd204to102(ab_snr1(icond,:));
    else
        sl_snr1 = sl_snr1(icond,:);
        ab_snr1 = ab_snr1(icond,:);
    end
    
    % plot spatial maps
    subplot(4,2,(icond-1)*2+1)
    [~,ch] = megPlotMap((sl_snr1),clims_sl,gcf,cmap,...
        sprintf('%s : Stimulus Locked Original', contrastNames{icond}));
    makeprettyaxes(ch,9,9);   
    title(sprintf('SL no DN %s', contrastNames{icond}))
    
    subplot(4,2,(icond-1)*2+2)
    [~,ch] = megPlotMap((ab_snr1),clims_ab,gcf,cmap,...
        sprintf('%s Original', contrastNames{icond}));
    makeprettyaxes(ch,9,9);
    title(sprintf('Broadband Pre %s', contrastNames{icond}))
    
    n = n + 2;
end

if saveFigures
    hgexport(gcf,fullfile(figureDir,sprintf('figure5_AcrossSubject%d_bipolar_threshold%d_raw.eps',whichSubject, threshold)));
end
