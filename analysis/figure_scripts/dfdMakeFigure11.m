function dfdMakeFigure11()
%% Function to reproduce Figure 11 with SNR difference before and after 
% denoising control analyses
%
% dfdMakeFigure11()
% 
% AUTHORS. TITLE. JOURNAL. YEAR.
%
% This figure will show ...
%
% This function assumes that data is downloaded with the DFDdownloaddata
% function. 



%% Choices to make:
whichSubjects        = 1:8;
dataDir              = fullfile(dfdRootPath, 'analysis', 'data');   % Where to save data?
figureDir            = fullfile(dfdRootPath, 'analysis', 'figures');% Where to save images?
saveFigures          = true;   % Save figures in the figure folder?
colors               = dfdGetColors(3);
numOfControls        = 5;


%% Prepare data for figure
snr_diff = zeros(length(whichSubjects),numOfControls+1,3); % All controls, plus original result for all three conditions
for k = 1:length(whichSubjects)

    whichSubject = whichSubjects(k);
    fprintf(' Load subject %d \n', whichSubject);
    data = prepareData(dataDir,whichSubject,11);
    
    results_null = [data(1),data{2}];
    
    % get top 10 channels 
    pcchan = getTop10(results_null{1,1}.results);
    
    % compute the difference between pre and post
    for icond = 1:3
        for nn = 1:length(results_null)
            snr_pre  = getsignalnoise(results_null{nn}.results.origmodel,icond);
            snr_post = getsignalnoise(results_null{nn}.results.finalmodel,icond);
            snr_diff(k,nn,icond) = mean(snr_post(pcchan)-snr_pre(pcchan));
        end
    end
end

%% Plot figure
fH = figure('position',[0,300,700,300]);
% define what the different conditions are 
types = {'MEG Denoise','Order shuffled','Random Amplitude','Phase-scrambled','Replace PCs with random values','All channels in noisepool'}; % 
% re-arrange the order of the bars 
neworder = [1,5,6];
newtypes = types(neworder);

snr_diff2 = snr_diff(:,neworder,:);
nnull = length(neworder);
for icond = 1:3
    subplot(1,3,icond);
    % mean and sem across subjects 
    mn  = mean(snr_diff2(:,:,icond));
    sem = std(snr_diff2(:,:,icond))/sqrt(8);
    bar(1:nnull, mn,'EdgeColor','none','facecolor',colors(icond,:)); hold on
    errorbar2(1:nnull,mn,sem,1,'-','color',colors(icond,:));
    % format figure and make things pretty 
    set(gca,'xlim',[0.2,nnull+0.8],'ylim',[-1,5]);
    makeprettyaxes(gca,9,9);
    set(gca,'XTickLabel',types(neworder));
%     set(gca,'XTickLabelRotation',45);
    set(get(gca,'XLabel'),'Rotation',45); 
    ylabel('Difference in SNR (post-pre)')
end

if saveFigures
    figurewrite(fullfile(figureDir,'figure11_control'),[],0,'.',1);
end