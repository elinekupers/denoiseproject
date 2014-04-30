clear all;

%% set up data conditions
% get data into [channel x time x epoch] format 
% create corresponding design matrix [epoch x n] format, here n = 1
sessionum = 5;
conditionNumbers = 1:6;%1:2
[dataset,conditionNames,megDataDir] = megGetDataPaths(sessionum, conditionNumbers);
megDataDir = fullfile(megDataDir,dataset);
disp(dataset);
disp(conditionNames);
%load(fullfile('tmpmeg',[dataset,'_fitfull0']));

%% load data 
tepochs    = [];
sensorData = [];
for ii = 1:length(conditionNames)
    %dataName = ['ts_', lower(regexprep(conditionNames{ii},' ','_')), '_epoched'];
    dataName = ['ts_', lower(regexprep(conditionNames{ii},' ','_'))];
    disp(dataName);
    data     = load(fullfile(megDataDir,dataName));
    currdata = data.(dataName);
    tepochs  = cat(1,tepochs,ii*ones(size(currdata,2),1));
    sensorData = cat(2,sensorData,currdata);
end

% format data into the right dimensions 
sensorData = permute(sensorData,[3,1,2]);
sensorData = sensorData(1:157,:,:);
% remove bad epochs
[sensorData,okEpochs] = megRemoveBadEpochs({sensorData},0.5);
tepochs = tepochs(okEpochs{1});
% find bad channels 
badChannels = megIdenitfyBadChannels(sensorData, 0.5);
%badChannels(98) = 1; % for now we add this in manually
fprintf('badChannels : %g \n', find(badChannels)');
% remove bad epochs and channels
net=load('meg160xyz.mat');
sensorData = megReplaceBadEpochs(sensorData,net);
sensorData = sensorData{1};
sensorData = sensorData(~badChannels,:,:);
% design matrix
onConds = find(cellfun(@isempty,strfind(conditionNames,'OFF')));
design = zeros(size(sensorData,3),length(onConds));
for k = 1:length(onConds)
    design(tepochs==onConds(k),k) = 1;
end

%save(sprintf('tmpmeg/%s',dataset),'sensorData', 'design', 'freq', 'badChannels');

%% Denoise 
% define some parameters for doing denoising 
T = 1; fmax = 150;
freq = megGetSLandABfrequencies((0:fmax)/T, T, 12/T);
evokedfun = @(x)getstimlocked(x,freq);
evalfun   = {@(x)getbroadband(x,freq), @(x)getstimlocked(x,freq)};
%evalfun   = @(x)getbroadband(x,freq);

opt.freq = freq;
opt.npcs = 50;
opt.xvalratio = -1;
opt.resampling = {'xval','xval'};
%opt.npoolmethod = {'r2',[],'n',60};
opt.npoolmethod = {'r2',[],'thres',0};
opt.pccontrolmode = 0;
opt.fitbaseline = false;
opt.verbose = true;

opt.pcstop = -44;
% do denoising 
% use evokedfun to do noise pool selection 
% use evalfun   to do evaluation 
[results,evalout,~,denoisedts]= denoisedata(design,sensorData,evokedfun,evalfun,opt);

%tmpmegdir = '/Volumes/HelenaBackup/denoisesuite/tmpmeg/';
%save(fullfile(tmpmegdir,sprintf('%02d_%s_fitfull',sessionum,dataset)),'results', 'badChannels');
%return;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Do some evaluations 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% look at whether broadband signal as a function of pcs
warning off
printFigsToFile = true;
types = {'BroadBand','StimulusLocked'};
noisepool = results.noisepool;
opt = results.opt;

if printFigsToFile
    savepth = fullfile(megDataDir, 'denoisefigures0');
    fprintf('Saving images to %s\n', savepth);
    if ~exist(savepth, 'dir'), mkdir(savepth); end
    if length(conditionNames)==2, stradd0 = conditionNames{1}(:,4:end); else stradd0 = 'ALL'; end
    if opt.pccontrolmode, stradd0 = sprintf('%s_NULL%d',stradd0,opt.pccontrolmode); end
    disp(stradd0);
end

%%
% compute axses 
clims    = getblims(evalout,[15,85;5,95]);
numconds = size(clims,1);

if ~printFigsToFile
    whichbeta = 1;
    clims_ab = squeeze(clims(whichbeta,:,:))';
    
    figure('Position',[1 200 1200 800]);
    for p = 0:opt.npcs
        for fh = 1:length(evalfun)
            beta = mean(evalout(p+1,fh).beta(whichbeta,:,:),3); % [1 x channel x perms], averaged across perms  
            beta = to157chan(beta,~badChannels, 'nans');          % map back to 157 channel space
            r2   = evalout(p+1,fh).r2;
            r2   = to157chan(r2,~badChannels,'nans');
            
            subplot(2,2,fh);   % plot beta weights 
            ttl = sprintf('%s: PC = %02d', types{fh}, p);
            fH = megPlotMap(beta,clims_ab(fh,:),[],'jet',ttl);
            %ssm_plotOnMesh(beta, [], [], [],'2d');
            
            subplot(2,2,fh+2); % plot r^2 
            ttl = sprintf('%s R2: PC = %02d', types{fh}, p);
            fH = megPlotMap(r2,[],[],'jet',ttl);
        end
        pause;
    end
    
else
    for p = 0:opt.npcs
        for fh = 1:length(evalfun)
            % loop through each beta and plot beta weights
            for whichbeta = 1:numconds
                
                beta = mean(evalout(p+1,fh).beta(whichbeta,:,:),3); % [1 x channel x perms], averaged across perms
                beta = to157chan(beta,~badChannels, 'nans');        % map back to 157 channel space
                
                ttl = sprintf('%s: PC = %02d', types{fh}, p);
                fH = megPlotMap(beta,clims(whichbeta,:,fh),[],'jet',ttl);
                
                if numconds > 1, stradd = [stradd0, '_', conditionNames{onConds(whichbeta)}(:,4:end)];
                else stradd = stradd0; end
                
                %saveas(fH,fullfile(savepth, sprintf('%s_%s_PC%02d.png',stradd,types{fh},p)),'png');
                figurewrite(sprintf('%s_%s_PC%02d',stradd,types{fh},p),[],[],savepth,0);
                
            end
            
            if fh == 1
                % plot r^2
                r2   = evalout(p+1,fh).r2;
                r2   = to157chan(r2,~badChannels,'nans');
                ttl = sprintf('%s R2: PC = %02d', types{fh}, p);
                fH = megPlotMap(r2,[],[],'jet',ttl);
                
                figurewrite(sprintf('%s_R2_%s_PC%02d',stradd0,types{fh},p),[],[],savepth,0);
            end
        end
    end
end

%% look at coverage of noise channels

signalnoiseVec = zeros(1,size(evalout(1,1).beta,2));
signalnoiseVec(noisepool)  = 1;
signalnoiseVec = to157chan(signalnoiseVec,~badChannels,'nans');

fH = megPlotMap(signalnoiseVec,[0,1],[],'autumn',sprintf('Noise channels: N = %d',sum(noisepool)));
colorbar off;

if printFigsToFile, figurewrite(sprintf('%s_noisepool',stradd0),[],[],savepth); end


%% look at how r^2 changes as a function of denoising 
r2 = []; % npcs x channels [x evalfuns]
for fh = 1:size(evalout,2)
    r2 = cat(3, r2,cat(1,evalout(:,fh).r2));
end

for fh = 1:size(evalout,2)
    figure('Position',[1 200 600 600]);
    
    ax(1) = subplot(2,2,[1,2]);
    imagesc(r2(:,:,fh)'); colorbar;
    xlabel('n pcs'); ylabel('channel number');
    title('R^2 as a function of denoising');
    
    ax(2) = subplot(2,2,3);
    plot(0:opt.npcs, r2(:,:,fh),'color',[0.5,0.5,0.5]); hold on;
    plot(0:opt.npcs, mean(r2(:,:,fh),2),'r'); hold on;
    xlabel('n pcs'); ylabel('r2');
    title('R^2 for individual channels')
    
    ax(3) = subplot(2,2,4);
    plot(0:opt.npcs, mean(r2(:,:,fh),2),'b'); hold on;
    plot(0:opt.npcs, mean(r2(:,~noisepool,fh),2),'r');
    %plot(0:opt.npcs, prctile(r2(:,:,fh),95,2),'g');
    vline(results.pcnum(fh),'k');
    xlabel('n pcs'); ylabel('average r2');
    legend('all channels','non-noise channels','Location','best');
    title('mean R^2')
    
    if printFigsToFile
        fs = 14;
        for ii = 1:3
            set(get(ax(ii),'Title'),'FontSize',fs);
            set(get(ax(ii),'XLabel'),'FontSize',fs);
            set(get(ax(ii),'YLabel'),'FontSize',fs);
            set(ax(ii),'box','off','tickdir','out','ticklength',[0.025 0.025]);
        end
        figurewrite(sprintf('%s_R2vPCs_%s',stradd0,types{fh}),[],[],savepth);
    else
        pause;
    end
end

%% Plot SNR improvement 

% get SNR before and after 
fields = {'origmodel','finalmodel'};
snr = [];
for k = 1:2
    %signal = max(abs(results.(fields{k})(1).beta_md),[],1);
    %noise  = mean(results.(fields{k})(1).beta_se,1);
    %snr = cat(1,snr, signal./noise);
    signal = abs(results.(fields{k})(1).beta_md);
    noise  = results.(fields{k})(1).beta_se;
    snr = cat(3,snr,signal./noise);
end

% plot and visualize 
axismin = 0; axismax = 20;
%plot(snr(1,:),snr(2,:),'ob');
c = ['b','r','g']; hold on;
for nn = 1:numconds
    plot(snr(nn,:,1),snr(nn,:,2),['o' c(nn)]);
end
line([axismin,axismax],[axismin,axismax],'color','k');
xlim([axismin,axismax]); ylim([axismin,axismax]); axis square;
xlabel('orig model SNR'); ylabel('final model SNR');
legend(conditionNames(onConds));
title(sprintf('BroadBand %d PCs', results.pcnum(1)));

if printFigsToFile
    figurewrite(sprintf('%s_SNR_%s',stradd0,types{1}),[],[],savepth,0);
end


return;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% plot the comparisons between the different kinds of null 

% load presaved files 
r2 = [];
for nn = 0:4
    if nn == 0, filename = sprintf('tmpmeg/%s_fitfull',dataset);
    else filename = sprintf('tmpmeg/%s_fitfull_null%d',dataset,nn); end
    disp(filename); load(filename);
    r2 = cat(3, r2, cat(1,evalout(:,1).r2)); 
end

%% plot and visualize
figure('Position',[1 200 1000 500]);
npcs = size(r2,1)-1;
nulltypes = {'original','phase scrambled','order shuffled','amplitude scrambled','random pcs'};
for nn = 1:5
    subplot(2,4,nn); hold on;
    plot(0:npcs, r2(:,:,nn)); hold on;
    if nn == 1, ylims = get(gca,'ylim'); end
    ylim(ylims); xlim([0,50]); xlabel('npcs'); ylabel('R^2');
    axis square; title(nulltypes{nn});
end
colors = {'k','b','r','g','m'};
%top10 = r2(end,:,1) > prctile(r2(end,:,1),90,2);
ttls = {'mean(all)','mean(non-noise)'};
funcs = {@(x)mean(x,2), @(x)mean(x(:,~noisepool),2)}; %@(x)prctile(x(:,:,1),90,2)
for kk = 1:length(funcs)
    subplot(2,4,5+kk); hold on;
    for nn = 1:5
        curr_r = r2(:,:,nn);
        plot(0:npcs,funcs{kk}(curr_r),colors{nn},'linewidth',2);
    end
    axis square; title(ttls{kk});
    xlim([0,50]); xlabel('npcs'); ylabel('R^2');
    if kk == length(funcs), legend(nulltypes,'location','bestoutside'); end
end

if printFigsToFile
    figurewrite(sprintf('ALLComparisons_R2vPCs_%s',types{1}),[],[],savepth);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% plot the broadband spectra  for particular channel
chanNum = 16;
dodenoised = 0; % toggle here 

tmp = zeros(1,157); tmp(chanNum)=1; tmp0=tmp(~badChannels); chanNum0 = find(tmp0);
disp(chanNum0)
condNum0=1;
%megPlotMap(tmp,[0,1],[],'autumn',[]);
condEpochs  = {design(:,condNum0)==1, all(design==0,2)}; %on, off

spec_orig = abs(fft(squeeze(sensorData(chanNum0,:,:))))/size(sensorData,2)*2;
spec_denoised = abs(fft(squeeze(denoisedts{1}(chanNum0,:,:))))/size(sensorData,2)*2;

f = (0:999);
%   lower and upper bound of frequencies to plot (x lim)
xl = [8 150];
%   lower and upper bound of amplitudes to plot (y lim)
fok = f;
fok(f<=xl(1) | f>=xl(2) ...
    | mod(f,60) < 1 | mod(f,60) > 59 ...
    ... | mod(f,72) < 1 | mod(f,72) > 71 ...
    | abs(f-52) < 1 ...
    ) = NaN;
% plot colors
colors = [0 0 0; .7 .7 .7; 1 0 0; 0 1 0];
fH = figure('Position',[0,600,700,500]);
set(fH, 'Color', 'w'); hold on;

for ii = 1:2
    if dodenoised
        this_data = nanmean(spec_denoised(:,condEpochs{ii}),2).^2;
    else
        this_data = nanmean(spec_orig(:,condEpochs{ii}),2).^2;
    end
    plot(fok, this_data,  '-',  'Color', colors(ii,:), 'LineWidth', 2);
end
xt = [12:12:72, 96,144];
yt = [10.^(1:5)];
set(gca, 'XLim', [8 150], 'ylim',[10,10^5], 'XTick', xt, 'ytick',yt, 'XScale', 'log', ...
    'YScale', 'log', 'FontSize', 20);
xlabel('Frequency (Hz)');
ylabel(sprintf('Power (%s)', '�V^2'));
title(sprintf('Channel %d', chanNum));
% add plot lines at multiples of stimulus frequency
ss = 12; yl = get(gca, 'YLim');
for ii =ss:ss:180, plot([ii ii], yl, 'k--'); end
%%
if dodenoised
    figurewrite(sprintf('s%d_channel%d_orig',sessionum,chanNum),[],0,'megfigs',1);
else
    figurewrite(sprintf('s%d_channel%d_denoised',sessionum,chanNum),[],0,'megfigs',1);
end

%% write out the stimulus locked data for an example channel 
% sl = getstimlocked(sensorData,freq);
% plot(sl(:,chanNum0),'k');
% xlim([0,size(design,1)]);
% c = 'bgr'; hold on;
% for k = 1:3
%     tmp = find(design(:,k)==1);
%     plot(tmp,300*ones(size(tmp)),['.' c(k)]);
% end
% xlabel('Epoch'); ylabel('Amp at SL freq (�V)');
% figurewrite(sprintf('s%d_channel%d_stimuluslockedts',sessionum,chanNum),[],0,'megfigs',1);

%% %%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% r2o = cat(1,evalout(:,1).r2);
% r2  = cat(1,evalout2(:,1).r2);
% axismin = -40; axismax = 50;
% 
% for p = 0:opt.npcs
%     
%     subplot(2,3,[1,4])
%     plot(r2o(p+1,:),r2(p+1,:),'or');
%     line([axismin,axismax],[axismin,axismax],'color','k');
%     xlim([axismin,axismax]); ylim([axismin,axismax]); axis square;
%     
%     subplot(2,3,[2,3]); hold off; 
%     %plot(r2o(p+1,:)-r2(p+1,:));
%     plot(r2o(p+1,:),'b'); hold on;
%     plot(r2(p+1,:),'r');
%     ylim([axismin,axismax]);
%     
%     subplot(2,3,[5,6]);
%     plot(r2(p+1,:)-r2o(p+1,:),'r'); 
%     
%     title(sprintf('PC = %d',p));
%     pause;
% end

