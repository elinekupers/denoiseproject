function dfdEyeScript(subjects)

%
% dfdEyeScript(subjects)
%
% INPUTS:
% subjects    : Vector of subject numbers one would like to analyze
%
% DESCRIPTION: Function to analyze eyetracking data recorded during MEG visual steady
% state experiment, for subject 6, 7 and 8.
%
% DEPENDENCIES: This function depends on functions from the meg_utils
% repository and mgl toolbox
%
% AUTHORS. YEAR. TITLE. JOURNAL.

% =========================================================================
% =============== Check options and load in toolboxes =====================
% =========================================================================

% Check input
if subjects < 6; error('Subject does not have eye tracking data'); end;

% Note: Think about how putting these functions in our repository
toolbox_pth = '/Volumes/server/Projects/MEG/Eyetracking_scripts/';


% Add necessary paths:
addpath(fullfile(toolbox_pth));
addpath(genpath(fullfile(toolbox_pth,'toolboxes','mgl')));
addpath(genpath(fullfile(toolbox_pth,'toolboxes','mrToolsUtilities')));
addpath(genpath('~/matlab/git/meg_utils'));

% Check options:
saveEyd           = false;  % Convert edf to eyd.mat file and save it?
saveFigures       = true;  % Save images?
saveStats         = true;  % Save statistics for barplot
removeFirstEpoch  = true;  % Delete first and last epoch?
savePath          = fullfile(dfdRootPath, 'exampleAnalysis','figures_rm1epoch');
dataPath          = fullfile(dfdRootPath, 'exampleAnalysis', 'data');

rad.x = 15; % screen radius in deg. CHECK!!!
rad.y = 12; % screen radius in deg. CHECK!!!

% =========================================================================
% ================= Define paths and load in data =========================
% =========================================================================
for whichSubject = subjects
    edffile = dir(sprintf(fullfile(dataPath, 'eye','s0%d_eyelink.edf'),whichSubject));
    tmp = load(sprintf(fullfile(dataPath, 's0%d_conditions.mat'),whichSubject)); conditions = tmp.conditions;
    
    if saveEyd
        eyd = mglEyelinkEDFRead(sprintf(fullfile(dataPath, 'eye',edffile.name)));
        save(sprintf(fullfile(dataPath, 'eye', 's0%d_eyd.mat'),whichSubject), 'eyd');
    else
        tmp = load(sprintf(fullfile(dataPath, 'eye','s0%d_eyd.mat'),whichSubject));
        eyd = tmp.eyd; clear tmp;
    end
    
    % =====================================================================
    % ================ Get eye traces (blinks are removed) ================
    % =====================================================================
    
    % Define the start and end time of experiment, which will be a
    % an argument for the msGetEyeData function.
    % Blink window is pretty conservative right now. could be [-0.1,0.1] (100
    % ms either way)
    startTime   = esFindStart(eyd); % find the first message that contains MEG trigger
    endTime     = 0; % number of messages to omit from end (if any)
    timeLims    = [eyd.messages(startTime).time(1), eyd.messages(end-endTime).time];
    blinkWinSec = [0.2 0.35];
    s = msGetEyeData(eyd,timeLims,blinkWinSec);
    
    % =====================================================================
    % ===================== Get triggers and timings ======================
    % =====================================================================
    
    % Use MEG messages to get the eye movements for the different conditions
    
    % ------------- Delete irrelevant messages ----------------------------
    eyd.messages = eyd.messages(1,startTime:end);
    
    % ------------- Make a matrix for trigger nr and time stamp -----------
    triggers = zeros(size(eyd.messages(1,:),2),2);
    
    % ------------- Get trigger nr and time stamp -------------------------
    for ii = 1:size(eyd.messages(1,:),2);                         % Last triggers while quiting the program are getting deleted
        triggers(ii,1) = str2num(eyd.messages(1,ii).message(14)); % Trigger nr
        triggers(ii,2) = eyd.messages(1,ii).time(1)-s.timeRaw(1); % Get timing and set time to zero
    end
    
    % ------------- Add triggers for the blank periods --------------------
    onsets = ssmeg_trigger_2_onsets(triggers, whichSubject, 'eye');
    
    % --------- Delete last 12 epochs since those are not recorded
    % --------- % Question: Is this true for all subjects?
    onsets = onsets(1:end-12);
    conditions = conditions(1:end-12);
    
    if removeFirstEpoch;       
        % Define
        badEpochs = zeros(size(onsets));
        badEpochs(1:6:end) = 1;        
        % Remove
        onsets = onsets(~badEpochs);
        conditions = conditions(~badEpochs);      
    end
    
    
    %% Convert x,y position and velocity vetors into epoched matrices (t x epoch)
    
    % ------------- Define epochs in variables of eyetracking data --------
    [eyets, ~]   = meg_make_epochs(s.time, onsets, [0 .999], 1000, 'eye');
    [eyexPos, ~] = meg_make_epochs(s.xyPos(:,1), onsets, [0 .999], 1000, 'eye');
    [eyeyPos, ~] = meg_make_epochs(s.xyPos(:,2), onsets, [0 .999], 1000, 'eye');
    [eyexVel, ~] = meg_make_epochs(s.xyVel(:,1), onsets, [0 .999], 1000, 'eye');
    [eyeyVel, ~] = meg_make_epochs(s.xyVel(:,2), onsets, [0 .999], 1000, 'eye');
    
    % ------------- Make design matrix ------------------------------------
    design = zeros(size(onsets,1),3);
    design(conditions==1,1) = 1; % condition 1 is full field
    design(conditions==5,2) = 1; % condition 5 is left field
    design(conditions==7,3) = 1; % condition 7 is right field
    
    % ------------- Define conditions -------------------------------------
    blank   = sum(design,2)==0;
    full	= design(:,1)==1;
    left    = design(:,2)==1;
    right	= design(:,3)==1;
    conds   = {blank,full,left,right};
    condsName = {'Blank','Full','Left','Right'};
    
    
    
    %% ====================================================================
    %  ============ Plot eye traces for visual inspection =================
    %  ====================================================================
    colors = [0 0 0; 63, 121, 204; 228, 65, 69; 116,183,74]/255;

    %% Plot X COORDINATES
    deglims = 20;
    figure(1); clf; set(gcf,'Color', 'w');
    subplot(2,2,1);
    
    % All eyetracking data
    plot(s.time/1000,s.xyPos(:,1), 'Color', [.7 .7 .7]); hold on;
    % Plot per stimulus condition
    for nn = 1:4
        plot(eyets(:,conds{nn})/1000,eyexPos(:,conds{nn}), 'Color', colors(nn,:));
    end
    grid on;
    ylim(deglims*[-1,1]); xlabel('Time (s)'); ylabel('X (deg)');
    
    %% Plot Y COORDINATES
    subplot(2,2,3);
    
    % All eyetracking data
    plot(s.time/1000,s.xyPos(:,2), 'Color', [.7 .7 .7]); hold on;
    % Plot per stimulus condition
    for nn = 1:4
        plot(eyets(:,conds{nn})/1000,eyeyPos(:,conds{nn}), 'Color', colors(nn,:));
    end
    
    grid on;
    ylim(deglims*[-1,1]); xlabel('Time (s)'); ylabel('Y (deg)');
    
    %% Plot XY ON GRID
    subplot(2,2,[2,4]);
    
    % All eyetracking data
    plot(s.xyPos(:,1),s.xyPos(:,2), 'Color', [.7 .7 .7]); axis square; grid on; hold on;
    % Plot per stimulus condition
    for nn = 1:4
        plot(eyexPos(:,conds{nn}),eyeyPos(:,conds{nn}), 'Color', colors(nn,:));
    end
    
    xlim(deglims*[-1,1]); ylim(deglims*[-1,1]);
    xlabel('X (deg)', 'Fontsize', 20);  ylabel('Y (deg)', 'Fontsize', 20);
    set(gca, 'FontSize', 20);
    
    plot(rad.x*[-1 1 1 -1 -1], rad.y*[-1 -1 1 1 -1], 'k--')
    %% =================================================
    %  =============== Detect saccades =================
    %  =================================================
    
    % Eyelink also detects saccades, but the algorithm isn't that reliable.
    % This is only if you actually want to do analyses with the saccades (e.g.,
    % look at how microsaccades are modulated by attention). If just for
    % monitoring goodness of fixation, you can probably just rely on the
    % Eyelink detected saccades (eyd.saccades)
    vThres = 6;
    msMinDur = 6;
    
    % Concatenate all conditions for XY position and XY velocity
    eyexyVel = [eyexVel(:), eyeyVel(:)];
    eyexyPos = [eyexPos(:), eyeyPos(:)];
    
    %% ALL data
    [sacRaw,radius] = microsacc(s.xyPos,s.xyVel,vThres,msMinDur);
    
    % remove the ones that occurr closely together (overshoot)
    numSacs = size(sacRaw,1);
    minInterSamples = ceil(0.01*s.eyeInfo.smpRate);
    interSac = sacRaw(2:end,1)- sacRaw(1:end-1,2);
    sac = sacRaw([1; find(interSac > minInterSamples)+1],:);
    fprintf('%d rejected for close spacing\n', numSacs - size(sac,1));
    
    fprintf('%d saccades detected\n', size(sac,1));
    
    % saved detected saccades into s
    s.sacsRaw          = sacRaw;
    s.sacs             = sac;
    s.sacDetectRadius  = radius;
    s.eyeInfo.vThres   = vThres;
    s.eyeInfo.msMinDur = msMinDur;
    
    fprintf('number of saccades detected: %d, detectRadius: [%0.3f %0.3f]\n', ...
        size(s.sacs,1), s.sacDetectRadius(1), s.sacDetectRadius(2));
    
    % look at detected saccades
    figure(2); clf; set(gcf,'Color', 'w');
    msSacStats1(s);
    title('Angular distribution ALL');
    
    % ALL trials
    all_traceMean = nanmean(s.xyPos);
    all_traceMedian = nanmedian(s.xyPos);
    all_traceCov = cov(s.xyPos(~isnan(s.xyPos(:,1)),:));
    
    % Plot confidence interval ellipses
    figure; clf; set(gcf,'Color', 'w');
    subplot(1,2,1); hold on;
    
    % distribution of samples
    plot(s.xyPos(:,1),s.xyPos(:,2),'.','markersize',1);
    % 95% confidence ellipse
    error_ellipse(all_traceCov,all_traceMean,'conf',0.95,'color','k');
    % median
    plot(all_traceMedian(1),all_traceMedian(2),'+r','markersize',5);
    grid on; axis square;
    xlim(5*[-1,1]); ylim(5*[-1,1]);
    title('Eye position of all samples');
    xlabel('Horizontal (deg)'); ylabel('Vertical (deg)');
    
    subplot(1,2,2); hold on; % distribution of saccades
    dxy = s.sacs(:,6:7);
    sacMean = mean(dxy);
    sacMedian = median(dxy);
    sacCov = cov(dxy);
    % plot all samples
    plot(dxy(:,1),dxy(:,2),'.','markersize',2);
    % 95% confidence ellipse
    error_ellipse(sacCov,sacMean,'conf',0.95,'color','k');
    % median
    plot(sacMedian(1),sacMedian(2),'+r','markersize',5);
    grid on; axis square;
    xlabel('Horizontal (deg)'); ylabel('Vertical (deg)');
    xlim(5*[-1,1]); ylim(5*[-1,1]);
    title('Saccade vectors');
    
    
    
    %% Epoched data
    
    allSacs       = {};
    allSacsMedian = {};
    allData       = {};
    
    % For all conditions (Both, Left, Right, Blank)
    for nn = 1:4
        % Get velocity
        thiseyexVel = eyexVel(:,conds{nn});
        thiseyeyVel = eyeyVel(:,conds{nn});
        % Get position
        thiseyexPos = eyexPos(:,conds{nn});
        thiseyeyPos = eyeyPos(:,conds{nn});
          
        % Concatenate all conditions for XY position and XY velocity
        eyexyVel = [thiseyexVel(:), thiseyeyVel(:)];
        eyexyPos = [thiseyexPos(:), thiseyeyPos(:)];

        % Define microsaccades
        [sacRaw,radius] = microsacc(eyexyPos,eyexyVel,vThres,msMinDur);
        
        % Remove the ones that occurr closely together (overshoot)
        numSacs = size(sacRaw,1);
        minInterSamples = ceil(0.01*s.eyeInfo.smpRate);
        interSac = sacRaw(2:end,1)- sacRaw(1:end-1,2);
        sac = sacRaw([1; find(interSac > minInterSamples)+1],:);
        fprintf('%d rejected for close spacing\n', numSacs - size(sac,1));     
        fprintf('%d saccades detected\n', size(sac,1));
        
        % Saved detected saccades into variable called 's'
        s.sacsRaw          = sacRaw;
        s.sacs             = sac;
        s.sacDetectRadius  = radius;
        s.eyeInfo.vThres   = vThres;
        s.eyeInfo.msMinDur = msMinDur;
        s.time             = eyets(:,conds{nn});
        s.xyPos            = eyexyPos;
        
        fprintf('number of saccades detected: %d, detectRadius: [%0.3f %0.3f]\n', ...
            size(s.sacs,1), s.sacDetectRadius(1), s.sacDetectRadius(2));
        
        % Look at detected saccades
        figure(2+nn); clf; set(gcf,'Color', 'w','name',sprintf('%s',condsName{nn}));
        msSacStats1(s);
        title('Angular distribution');
        
        % Get mean and median of positions in trials
        traceMean = nanmean(s.xyPos);
        traceMedian = nanmedian(s.xyPos);
        traceCov = cov(s.xyPos(~isnan(s.xyPos(:,1)),:));
        
        % Plot it
        figure; clf; set(gcf,'Color', 'w');
        subplot(1,2,1); hold on;
        
        % distribution of samples
        plot(s.xyPos(:,1),s.xyPos(:,2),'.','markersize',1);
        % 95% confidence ellipse
        error_ellipse(traceCov,traceMean,'conf',0.95,'color','k');
        % median
        plot(traceMedian(1),traceMedian(2),'+r','markersize',5);
        grid on; axis square;
        xlim(5*[-1,1]); ylim(5*[-1,1]);
        title(sprintf('Eye position of %s samples',condsName{nn}));
        xlabel('Horizontal (deg)'); ylabel('Vertical (deg)');
        
        subplot(1,2,2); hold on; % distribution of saccades
        dxy = s.sacs(:,6:7);
        sacMean = mean(dxy);
        sacMedian = median(dxy);
        sacCov = cov(dxy);
        % plot all samples
        plot(dxy(:,1),dxy(:,2),'.','markersize',2);
        % 95% confidence ellipse
        error_ellipse(sacCov,sacMean,'conf',0.95,'color','k');
        % median
        plot(sacMedian(1),sacMedian(2),'+r','markersize',5);
        grid on; axis square;
        xlabel('Horizontal (deg)'); ylabel('Vertical (deg)');
        xlim(5*[-1,1]); ylim(5*[-1,1]);
        title('Saccade vectors');
        
        allSacs{nn} = s.sacs;
        allSacsMedian{nn} = sacMedian;
        allData{nn} = s;

    end
    
            
        if saveStats
            % Put statistics in struct
            stats = struct('freqBoth', size(allSacs{1},1),'freqLeft',size(allSacs{2},1), 'freqRight',size(allSacs{3},1), 'freqBlank',size(allSacs{3},1), ...
                            'mdAmplBoth', allSacsMedian{1}, 'mdAmplLeft', allSacsMedian{2}, 'mdAmplRight', allSacsMedian{3}, 'mdAmplBlank', allSacsMedian{4}, 'allData',allData);
            % Save data
            fname = fullfile(dataPath,sprintf('s0%d_freq_mdAmpl',whichSubject));
            save([fname '.mat'],'stats')
        end

    
    %% Export images
    if saveFigures
        if removeFirstEpoch; postFix = '_rm1epoch'; else postFix = []; end;
            hgexport(1,fullfile(savePath,sprintf('S%2d_eyetracking_fig1_xypositions%s.eps', whichSubject, postFix)));
            hgexport(2,fullfile(savePath,sprintf('S%2d_eyetracking_fig2_microsaccades_all%s.eps', whichSubject,postFix)));
            hgexport(3,fullfile(savePath,sprintf('S%2d_eyetracking_fig3_microsaccades_both%s.eps', whichSubject, postFix)));
            hgexport(4,fullfile(savePath,sprintf('S%2d_eyetracking_fig4_microsaccades_blank%s.eps', whichSubject, postFix)));
            hgexport(5,fullfile(savePath,sprintf('S%2d_eyetracking_fig5_microsaccades_left%s.eps', whichSubject,postFix)));
            hgexport(6,fullfile(savePath,sprintf('S%2d_eyetracking_fig6_microsaccades_right%s.eps', whichSubject,postFix)));
            hgexport(7,fullfile(savePath,sprintf('S%2d_eyetracking_fig7_xypos_ms_all%s.eps', whichSubject,postFix)));
%             hgexport(8,fullfile(savePath,sprintf('S%2d_eyetracking_fig8_xypos_ms_blank%s.eps', whichSubject,postFix)));
%             hgexport(9,fullfile(savePath,sprintf('S%2d_eyetracking_fig9_xypos_ms_both%s.eps', whichSubject,postFix)));
%             hgexport(10,fullfile(savePath,sprintf('S%2d_eyetracking_fig10_xypos_ms_right%s.eps', whichSubject,postFix)));
%             hgexport(11,fullfile(savePath,sprintf('S%2d_eyetracking_fig11_xypos_ms_left%s.eps', whichSubject,postFix)));
%             hgexport(12,fullfile(savePath,sprintf('S%2d_eyetracking_fig12_xypos_ms_combined%s.eps', whichSubject,postFix)));
    end
    
end

end


function startTime   = esFindStart(eyd)
    startTime = NaN;
    for ii = 1:length(eyd.messages)
        if strfind(eyd.messages(ii).message, 'MEG Trigger')
            startTime = ii; return
        end
    end
end

