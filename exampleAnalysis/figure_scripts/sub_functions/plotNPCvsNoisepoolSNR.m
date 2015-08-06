function fH = plotNPCvsNoisepoolSNR(whichSubjects,dataAll,npools,npcs,saveFigures,figureDir)

%% Plot difference in SNR (post-pre) as a function of number of channels in
%% noise pool and number of PCs removed

% nchan in noisepool x npcs removed x conds x nsessions
allSubjectsResults = [];

for whichSubject = whichSubjects
    fprintf(' compute SNR for subject %d \n', whichSubject);    
    
    % load results
    allvals = nan(length(npools),length(npcs),3);
    for np = 1:length(npools)
        for nc = 1:length(npcs)
            results = dataAll{whichSubject}{1}.allResults(np,nc);
            results = results{1};
            if isempty(results), continue; end
            
            % get top 10
            pcchan = getTop10(results);
            
            % get snr before and after, nconds x nchannels
            ab_signal1 = abs(results.origmodel.beta_md(:,pcchan));
            ab_noise1  = results.origmodel.beta_se(:,pcchan);
            ab_signal2 = abs(results.finalmodel.beta_md(:,pcchan));
            ab_noise2  = results.finalmodel.beta_se(:,pcchan);
            ab_snr1    = ab_signal1./ab_noise1;
            ab_snr2    = ab_signal2./ab_noise2;
            % get snr difference for each condition (post-pre)
            for icond = 1:3
                allvals(np,nc,icond) = mean(ab_snr2(icond,:))-mean(ab_snr1(icond,:));
            end
        end
    end
    % concate across sessions
    allSubjectsResults = cat(4,allSubjectsResults,allvals);
end

%%
fH = figure('position',[0,300,450,900],'color','w');
clims = [[0,6];[0,6];[0,6]];
conditionNames = {'FULL','RIGHT','LEFT'};
for icond = 1:3
    subplot(3,1,icond);
    imagesc(1:length(npcs),1:length(npools),mean(allSubjectsResults(:,:,icond,:),4),clims(icond,:));
    
    set(gca,'ydir','normal');
    xlabel('Number of PCs removed');
    ylabel('Number of Channels in Noise pool');
    
    makeprettyaxes(gca,9,9);
    set(gca,'xtick',1:length(npcs),'ytick',1:length(npools),...
        'xticklabel',cellstr(num2str(npcs','%d')),'yticklabel',cellstr(num2str(npools','%d')));
    axis image; ch = colorbar; makeprettyaxes(ch,9,9);
    title(conditionNames{icond});
end

if saveFigures
    figurewrite(fullfile(figureDir,'SF2GridSubjMean_NPCSvsNoisePool'),[],0,'.',1);
end