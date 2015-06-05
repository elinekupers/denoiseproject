function fH = plotSNRvsPCsAllSubjectsPanel6B(dataAll,condColors,axmax,figureDir,saveFigures)

%% SNR increase as a function of number of PCs removed for all subjects -
%% Fig. 6B

% get the trend for the top 10 channels of all sessions
snr_top10 = [];
for k = 1:numel(dataAll) 
    snr = abs(cat(3,dataAll{k}{1}.evalout(:,1).beta_md)) ./ cat(3,dataAll{k}{1}.evalout(:,1).beta_se);    
    xvaltrend = [];
    for icond = 1:3
        this_snr = squeeze(snr(icond,:,1:11))';
        xvaltrend = cat(2, xvaltrend, mean(this_snr(:,dataAll{k}{1}.results.pcchan{1}),2));
    end
    snr_top10 = cat(3,snr_top10,xvaltrend);
end

%% Plot them together

% define colors - vary saturation for different subjects
satValues = linspace(0.1,1,8);
colorRGB = varysat(condColors,satValues);
ttls = {'FULL','RIGHT','LEFT'};

fH = figure; set(fH, 'Color', 'w');
% plot for each condition
for icond = 1:3
    subplot(1,3,icond);hold on;
    for nn = 1:8 % for each subject
        plot(0:axmax, squeeze(snr_top10(:,icond,nn)), 'color', squeeze(colorRGB(icond,nn,:)));
    end
    axis square; xlim([0,axmax]);
    ylim([0,12]); set(gca,'ytick',0:5:10); % for SL: ylim([0,40]); set(gca,'ytick',0:10:40);
    title(ttls{icond});
    makeprettyaxes(gca,9,9);
end

if saveFigures
    figurewrite(fullfile(figureDir,'Figure6BSNRvPCsAllSubjsBB'),[],0,'.',1);
end