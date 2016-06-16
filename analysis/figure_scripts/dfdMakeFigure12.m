function dfdMakeFigure12()
%% Function to reproduce Figure 12AB S, N pre-post denoising
% for top ten channels of all subjects for stimulus locked signal
%
% dfdMakeFigure12()
%
% AUTHORS. TITLE. JOURNAL. YEAR.
%
% This figure will SNR, signal (mean across bootstraps) and noise (std
% across bootstraps) components of subject's stimulus.

%
% This function assumes that data is downloaded with the DFDdownloaddata
% function. 

%% Choices to make:
whichSubjects    = [1:8];     % Subject 1 has the example channel.
figureDir       = fullfile(dfdRootPath, 'analysis', 'figures'); % Where to save images?
dataDir         = fullfile(dfdRootPath, 'analysis', 'data');    % Where to save data?
saveFigures     = true;  % Save figures in the figure folder?
figureNumber    = 12;
                                         
% Define plotting parameters
colors          = dfdGetColors(3);

%% Get data
dataAll = [];
for whichSubject = whichSubjects
    fprintf('Load data subject %d \n', whichSubject);
    % Load data, design, and get example subject
    dataAll{whichSubject} = prepareData(dataDir,whichSubject,12);
end

%% Plot SNR vs number of PCs change for all channels 

% Get results for everybody and top10 channels for everybody
for k = whichSubjects
    allpcchan{k} = getTop10(dataAll{k}.results);
    allresults{k} = dataAll{k}.results;
end

% get colors for plotting
% vary saturation for different subjects
satValues = 1-linspace(0.1,1,8);
colorRGB = varysat(colors,satValues);

% plot before and after
fH = figure('position',[0,300,500,400]); set(gcf, 'Color','w');
datatypes = {'SNR','Signal','Noise'};
for t = 1:numel(datatypes);
    for icond = 1:3
        subplot(numel(datatypes),3,((t-1)*3+icond))
        plotBeforeAfter(allresults,1,allpcchan,datatypes{t},icond,[],squeeze(colorRGB(icond,:,:)));
        xlim([0.5,2.5]);
        makeprettyaxes(gca,9,9);
        if t==1; yt = [0,40]; elseif t==2; yt= [0,130]; else yt = [0,6]; end
        ylim(yt);
    end
end

if saveFigures
        figurewrite(fullfile(figureDir,'Figure12_s_n_full_sat'),[],0,'.',1);
end

