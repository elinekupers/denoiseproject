function [results,evalout,denoisedspec,denoisedts] = denoisedata(design,data,evokedfun,evalfun,opt)
% [results,evalout,denoisedspec,denoisedts] = ...
%         denoisedata(design,data,evokedfun,evalfun,opt)
% ---------------------------------------------------------------- 
% INPUTS:
% -----------------
% data      : time series [channel x time samples x epoch]
% design    : design matrix [epoch x nconds]
% evokedfun : function handle (to compute evoked response for noise pool
%             selection
% evalfun   : function handle or a cell of function handles (to compute the
%             output responses of interest for evaluation
% opt       : options
%     npoolmethod : noise pool selection method 
%     epochGroup  : for grouping epochs together for denoising [epoch x 1] vector
%     npcs        : number of pcs to try (default 50)
%     xvalratio   : how to split training and test data for cross
%                   validation. could be a number between 0 to 1, defining
%                   the ratio of test data (relative to training data). 
%                   or -1, which does leave-one-out (default). 
%     fitbaseline : whether to add constant term in glm 
%                   when false, mean is projected out from design matrix and
%                   data (default)
%     resampling  : how to do resampling for noise channel selection
%                   (cell 1) and actual evaluation (cell 2)
%                   options: 'full', 'xval', or 'boot' (default
%                   {'xval','xval'})
%     pccontrolmode: how to compute null pcs for control
%                    0: do nothing (default). 1: permute fourier phase. 
%                    2: permute assignment to epochs. 3: use white fourier
%                    amplitude but keep fourier phase. 4: use random pcs      
%     pcstop      :  when to stop adding PCs into the model (default: 1.05)
%     pcn         :  top number of channels to use for determining PC
%                    cutoff 
%     verbose     :  whether to print messages to screen (default: true)
% 
% OUTPUTS:
% -----------------
% results:
%     finalmodel  : final [bootstrapped] glm solution for the model with optimal number of pcs
%     origmodel   : glm solution without denoising (for comparison)
%     noisepool   : channels included in the noise pool (vector of booleans)
%     pcnum       : optimal number of pcs for denoising
%     opt         : options used 
% 
% evalout         : [cross-validated] glm solution for each pc tried
% denoisedspec    : denoised output data with optimal number of pcs (output of evalfun)
% denoisedts      : denoised raw data with optimal number of pcs (same dimensions
%                   as input 'data')
% 
  
% first, get data dimensions 
[nchan,ntime,nepoch] = size(data); 
% handle inputs and options 
if notDefined('evokedfun'), evokedfun = @(x)getstimlocked(x,opt.freq); end
if notDefined('evalfun'),   evalfun   = @(x)getbroadband(x,opt.freq);  end
if notDefined('opt'),       opt       = struct(); end
if ~isfield(opt,'npoolmethod'), opt.npoolmethod = {'r2',[],'n',60};  end
if ~isfield(opt,'epochGroup'),  opt.epochGroup  = 1:nepoch;          end
if ~isfield(opt,'npcs'),        opt.npcs        = 50;                end
if ~isfield(opt,'fitbaseline'), opt.fitbaseline = false;             end
if ~isfield(opt,'xvalratio'),   opt.xvalratio   = -1;                end
if ~isfield(opt,'resampling'),  opt.resampling  = {'xval','xval'};   end
if ~isfield(opt,'pccontrolmode'), opt.pccontrolmode = 0;             end
if ~isfield(opt,'pcstop'),      opt.pcstop      = 1.05;              end
if ~isfield(opt,'pcn'),         opt.pcn         = 10;                end
if ~isfield(opt,'preprocessfun'), opt.preprocessfun = [];            end
if ~isfield(opt,'savepcs'),     opt.savepcs     = false;             end
if ~isfield(opt,'verbose'),     opt.verbose     = true;              end

if opt.verbose
    fprintf('---------------------------------------------------------------------\n');
    fprintf('(denoisedata) data dimenions: %d channels x %d time samples x %d epochs\n', ...
        nchan,ntime,nepoch);
    fprintf('---------------------------------------------------------------------\n');
end

% --------------------------------------------------------------
% discard epochs for which epochGroup is undefined
% --------------------------------------------------------------
nepoch2 = sum(opt.epochGroup~=0);
if nepoch2 ~= nepoch
    if opt.verbose
        fprintf('(denoisedata) !! discarding %d epochs with undefined epoch group!! \n', nepoch-nepoch2); 
    end
    opt.epochGroupOrig = opt.epochGroup;
    discardepochs   = ~ismember(opt.epochGroup, 1:nepoch);
    opt.epochGroup  = opt.epochGroup(~discardepochs);
    data            = data(:,:,~discardepochs);
    design          = design(~discardepochs,:);
    %nepoch         = epoch2;
end

% --------------------------------------------------------------
% perform fit to get R^2 values
% --------------------------------------------------------------
if opt.verbose, fprintf('(denoisedata) computing evoked model ...\n'); end
out = evalmodel(design,data,evokedfun,opt.resampling{1},opt);

% --------------------------------------------------------------
% select noise pool
% --------------------------------------------------------------
if opt.verbose, fprintf('(denoisedata) selecting noise pool ...\n'); end
noisepool = selectnoisepool(out, opt.npoolmethod);
noisedata = data(noisepool,:,:);
if opt.verbose, fprintf('\t%d noise channels selected ...\n', sum(noisepool)); end
% check that the number of pcs we request isn't greater than the size of
% noisepool
if opt.npcs > sum(noisepool)
    fprintf('WARNING!!!: npcs > nnoise! Setting npcs to size of noise pool %d\n', sum(noisepool));
    opt.npcs = sum(noisepool);
end
    
% --------------------------------------------------------------
% compute PCs
% --------------------------------------------------------------
% pcs are stored in nrep cells; each cell is a matrix of [ntime x npcs]
nrep = max(opt.epochGroup);
if opt.verbose
    fprintf('(denoisedata) computing pcs for %d epoch groups ...\n', nrep); 
end
% do preprocessing before computing pcs
if ~isempty(opt.preprocessfun), noisedata = opt.preprocessfun(noisedata); end
pcs = cell(nrep,1);
for rp = 1:nrep
    % get current noise time series (ntime x nchan)
    currepochs = opt.epochGroup == rp;
    if nnz(currepochs)~=0
        currnoise  = noisedata(:,:,currepochs);
        currnoise  = reshape(currnoise,[], ntime*sum(currepochs))';
        % unit-length normalize each time-series
        temp = unitlengthfast(currnoise);
        % perform SVD and select top PCs
        %[u,s,v] = svd(temp);
        [coef,u,eigvals] = princomp(temp);
        %u = u(:,1:opt.npcs);
        % scale so that std is 1 (ntime x npcs)
        pcs{rp} = bsxfun(@rdivide,u,std(u,[],1));
    end
end

% --------------------------------------------------------------
% Perturb PCs, if requested
% --------------------------------------------------------------
switch opt.pccontrolmode
    case 1 % phase scramble the pcs 
        if opt.verbose
            fprintf('(denoisedata) phase scrambling pcs for control ...\n')
        end
        for rp = 1:nrep
            if ~isempty(pcs{rp})
                pc_fft = fft(pcs{rp},[],1);
                pc_amp = abs(pc_fft);
                pc_ph  = angle(pc_fft);
                nsamps = size(pcs{rp},1);
                perminds = permutedim(repmat((1:nsamps)',1,sum(noisepool)),1,[],1);
                pcs{rp} = real(ifft(pc_amp.*exp(1i*pc_ph(perminds)),[],1));
            end
        end
    case 2 % shuffle assignment of pcs to epochs
        if opt.verbose
            fprintf('(denoisedata) randomly assigning pcs for control ...\n')
        end
        while true
            perminds = randperm(nrep);
            if sum(perminds == (1:nrep)) == 0
                break;
            end
        end
        pcs = pcs(perminds);
    case 3 % insert random fourier amplitude but preserving fourier phase 
        if opt.verbose
            fprintf('(denoisedata) amplitude scrambling pcs for control ...\n')
        end
        for rp = 1:nrep
            if ~isempty(pcs{rp})
                pc_fft = fft(pcs{rp},[],1);
                white_fft = fft(randn(size(pcs{rp})),[],1);
                pc_amp = abs(pc_fft); pc_ph  = angle(pc_fft);
                white_amp = abs(white_fft); white_ph = angle(white_fft);
                pcs{rp} = real(ifft(white_amp.*exp(1i*pc_ph),[],1));
                %pcs{rp} = real(ifft(pc_amp.*exp(1i*white_ph),[],1));
            end
        end
    case 4 % use random pcs 
        if opt.verbose
            fprintf('(denoisedata) using random pcs for control ...\n')
        end
        for rp = 1:nrep
            pcs{rp} = randn(size(pcs{rp}));
        end
end

% --------------------------------------------------------------
% denoise in time and recompute spectral time series
% --------------------------------------------------------------
% evalaute each evalfun we pass in
if ~iscell(evalfun), evalfun = {evalfun}; end
nmodels = length(evalfun);
% we can skip through this step if user specifies the numbers pcs we want
if opt.pcstop > 0 
    if opt.verbose
        fprintf('(denoisedata) trying %d pcs \n', opt.npcs);
    end
    % loop through each pc
    for p = 0:opt.npcs
        if opt.verbose, fprintf('(denoisedata) denoising for %d pcs ...\n', p); end
        
        if p == 0
            if ~isempty(opt.preprocessfun), denoiseddata = opt.preprocessfun(data);
            else denoiseddata = data; end
        else
            denoiseddata = denoisetimeseries(data,pcs,p,opt.epochGroup,opt.preprocessfun);
        end
        
        % compute spectral time series and evaluate goodness of fit (by
        % applying evalfun we passed in)
        for fh = 1:nmodels
            evalout(p+1,fh) = evalmodel(design,denoiseddata,evalfun{fh},opt.resampling{2},opt);
        end
    end
else
    evalout = [];
end

% --------------------------------------------------------------
% % choose number of PCs, ala Kendrick
% --------------------------------------------------------------
% we probably eventually want to do something fancier, like fitting a curve
% Unlike fMRI data, EEG/MEG has fewer channels and curve is often not as
% smooth 
% QUESTION: how should we define xvaltrend?? in other words, how should R^2
% be combined across channels? now it's just an average across channels...
if opt.verbose, fprintf('(denoisedata) choosing pcs ...\n'); end
pcnum = zeros(1,nmodels);
for fh = 1:nmodels
    if opt.pcstop <= 0 % in this case, the user decides
        if opt.verbose
            fprintf('(denoisedata) user specified: number of pcs = %d \n', -opt.pcstop);
        end
        chosen = -opt.pcstop;
    else
        % npcs x channels, averaged across non-noise channels
        r2 = cat(1,evalout(:,fh).r2);
        % max cross validation for each channel
        maxr2 = max(r2,[],1); 
        % exclude those in noisepool
        maxr2(noisepool) = -inf;
        % sort these 
        [~, idx] = sort(maxr2,'descend');
        % pick the top x, determined by opt.pcn
        pcchan = false(size(noisepool));
        pcchan(idx(1:min(opt.pcn,length(idx)))) = 1;
        % take the average of these 
        xvaltrend = mean(r2(:,pcchan,1),2);
        %xvaltrend = mean(r2(:,~noisepool),2);
        % chosen the stopping point as within 95% of maximum 
        chosen = choosepc(xvaltrend,opt.pcstop);
        pcchan2{fh} = pcchan;
        
        if opt.verbose, fprintf('\tevalfunc %d: %d pcs\n', fh, chosen); end
    end
    % record the number of PCs
    pcnum(fh) = chosen;
end

% --------------------------------------------------------------
% get final model and denoised time series
% --------------------------------------------------------------
% pull out the final models and add pcnum to it
for fh = 1:nmodels
    denoiseddata = denoisetimeseries(data,pcs,pcnum(fh),opt.epochGroup,opt.preprocessfun);
    [finalmodel(fh), denoisedspec{fh}] = evalmodel(design,denoiseddata,evalfun{fh},'boot',opt);
    [origmodel(fh)] = evalmodel(design,data,evalfun{fh},'boot',opt);
    % return denoised time series, if requested 
    if nargout > 3, denoisedts{fh} = denoiseddata; end
end

results.finalmodel = finalmodel;
results.origmodel  = origmodel;
results.noisepool  = noisepool;
results.pcnum      = pcnum;
if exist('pcchan2','var'), results.pcchan = pcchan2; end
if opt.savepcs,            results.pcs = pcs; end
results.opt        = opt;

return;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [out,datast] = evalmodel(design,data,func,how,opt)
% INPUTS:
% data   : [channels x time x epochs]
% design : [epochs x nvectors]
% func   : a function that summarizes data into [epochs x channels]
% how    : defines how fitting is done ['full' or 'xval'(default)]
%
% OUTPUTS:
% r2     : goodness of fit   [channels x 1]
% beta   : betas for the fit [nperms x channels]

% check inputs
if notDefined('how'),  how  = 'xval';   end
if notDefined('opt'),  opt  = struct(); end
if ~isfield(opt,'verbose'),     opt.verbose     = true;  end
if ~isfield(opt,'fitbaseline'), opt.fitbaseline = false; end
if ~isfield(opt,'xvalratio'),   opt.xvalratio   = -1;    end
if ~isfield(opt,'xvalmaxperm'), opt.xvalmaxperm = 500;   end
if ~isfield(opt,'nboot'),       opt.nboot = 100;   end

% datast should be dimensions [epochs x channels]
datast = func(data);
nepochs = size(datast,1);
% sanity checks
assert(nepochs==size(design,1));
assert(sum(isnan(datast(:)))==0 && sum(isinf(datast(:)))==0);

if ~opt.fitbaseline % remove baseline from data and design
    %pmatrix = projectionmatrix(constructpolynomialmatrix(nepochs,0));
    %datast  = pmatrix*datast; design  = pmatrix*design;
    datast = bsxfun(@minus, datast, mean(datast));
    design = bsxfun(@minus, design, mean(design));
    r2wantmeansub = 0;
else % add constant term to design matrix
    if opt.verbose, fprintf('\tadding constant term to design matrix\n'); end
    design = [design, ones(nepochs,1)];
    r2wantmeansub = 1;
end

switch how
    case 'full'
        if opt.verbose, fprintf('\tfull fit: no resampling\n'); end
        % do glm
        beta = design \ datast;
        modelfit = design*beta;
        % compute goodness of fit
        r2 = calccod(modelfit,datast,1,[],1);
        
        % save into output struct
        out = struct('r2',r2,'beta',beta,'modelfit',modelfit);
        
    case 'xval'
        % figure out how to choose train and test data
        if opt.xvalratio == -1 % do n-fold cross validation
            epochs_test = (1:nepochs)';
            if opt.verbose, fprintf('\txval: n-fold/leave-one-out\n'); end
        else % else, divide up according to opt.xvalratio
            ntest = round(nepochs * opt.xvalratio);
            ntest(ntest<1) = 1; ntest(ntest>=nepochs)=nepochs-1;
            % if too many permutations, so we choose randomly
            % just an arbitrary definition for "too many"
            if nchoosek(nepochs,ntest) > max(nepochs*3, opt.xvalmaxperm)
                epochs_test = zeros(opt.xvalmaxperm,ntest);
                for nn = 1:opt.xvalmaxperm
                    tmp = randperm(nepochs);
                    epochs_test(nn,:) = tmp(1:ntest);
                end
            else
                epochs_test = nchoosek(1:nepochs,ntest);
            end
            if opt.verbose
                fprintf('\txval: ntest %d; ntrain %d (%0.2f test)\n', ntest, nepochs-ntest,opt.xvalratio); 
            end
        end
        
        % for each train/test permutation
        modelfit = []; beta = []; r2perm = [];
        for nn = 1:size(epochs_test,1)
            curr_test = epochs_test(nn,:);
            curr_train= setdiff(1:nepochs,curr_test);
            % do glm on training data
            % beta_train = [n x channels]
            beta_train= design(curr_train,:)\ datast(curr_train,:);
            modelfit_test = design(curr_test,:)*beta_train;
            % save prediction for this epcoh
            modelfit = cat(1,modelfit,modelfit_test); %[epochs x channels]
            beta     = cat(3,beta,    beta_train);    %[n x channels x perms]
            r2perm   = cat(1,r2perm,  calccod(modelfit_test,datast(curr_test,:),[],r2wantmeansub)); % [perms x 1]
        end
        % both data and predicted are [epochs x channels]; r2 = [1 x channels]
        r2 = calccod(modelfit,datast(vectify(epochs_test'),:),[], r2wantmeansub);
        
        % save into output struct
        out = struct('r2',r2,'beta',beta,'modelfit',modelfit, 'epochs_test', epochs_test, 'r2perm', r2perm);
        
    case 'boot'
        epochs_boot = randi(nepochs,opt.nboot,nepochs);
        % compute bootstrapped fits 
        beta = []; r2boot = [];%modelfit = []; 
        for nn = 1:opt.nboot
            % do glm on randomly selected epochs 
            curr_boot = epochs_boot(nn,:);
            curr_design = design(curr_boot,:);
            curr_datast = datast(curr_boot,:);
            beta_boot = curr_design \ curr_datast;
            modelfit_boot = curr_design * beta_boot;
            % save predictions
            %modelfit = cat(3,modelfit, modelfit_boot); % [epochs x channels x boot]
            beta     = cat(3,beta,beta_boot);          % [n x channels x boot]
            r2boot   = cat(1,r2boot,calccod(modelfit_boot,curr_datast,[],r2wantmeansub));
        end
        r2 = median(r2boot);
        temp = prctile(beta,[16 50 84],3);
        beta_md = temp(:,:,2);
        beta_se = diff(temp(:,:,[1 3]),[],3)/2;
        % save into output struct
        out = struct('r2',r2,'beta',beta,'beta_md',beta_md,'beta_se',beta_se,'epochs_boot', epochs_boot, 'r2boot', r2boot);
        
    otherwise
        error('(denoisedata:evalmodel) resampling method not parsed: %s', how);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function noisepool = selectnoisepool(out,npoolmethod)
% selects noise channels
% npoolmethod is a cell array
%   entry 1 defines what variable is used ['r2'(default) | 'beta']
%   entry 2 (optional) defines function on 'out' [default [] ] 
%           for example: can pass in a function to calculate snr
%   entry 3 defines how noise channels are selected ['n' (default)|'thres']
%           if 'n', then we choose the worst X channels 
%           if 'thres', then we choose channels with entry1 < X
%   entry 4 defines X 
%   example: {'r2',[],'thres',0}

% check inputs 
var  = npoolmethod{1}; if isempty(var), var = 'r2'; end
if ~strcmp(var,'r2') && ~strcmp(var,'beta')
    error('(denoisedata:selectnoisepool): npoolmethod{1} not parsed: %s', var);
end
func = npoolmethod{2};
compmethod = npoolmethod{3}; if isempty(compmethod), compmethod = 'n'; end
compval    = npoolmethod{4}; 
if isempty(compval) 
    if strcmp(compmethod,'n'), compval = 60;
    elseif strcmp(compmethod,'thres') compval = 0; end
end

% compute 
vals = out.(var);
if ~isempty(func), vals = func(vals); end
if strcmp(compmethod,'n')
    noisepool = false(1,size(out.r2,2));
    [~,sortedinds] = sort(vals,'ascend');
    noisepool(sortedinds(1:compval)) = true;
end
if strcmp(compmethod,'thres')
    noisepool = vals < compval;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function denoiseddata = denoisetimeseries(data,pcs,p,epochGroup,preprocessfun)
% denoise time series
% INPUTS:
% data   : [channels x time x epochs]
% pcs    : nrep cells; each is a matrix of [ntime x npcs]
% p      : how many number of pcs we want to use 
% how    : defines how epochs are grouped 
%
% OUTPUTS:
% denoiseddata : [channels x time x epochs]
%
[nchan,ntime,nepoch] = size(data);
nrep = max(epochGroup);

% preprocess data, if requested 
if ~notDefined('preprocessfun'), data = preprocessfun(data); end

denoiseddata = zeros(nchan,ntime,nepoch);
cummnepoch   = 0;
% project out appropriate number of pcs from each epoch or epoch group
for rp = 1:nrep
    % get time series (ntime x nchan) for current epoch group
    currepochs = epochGroup == rp;
    currnepoch = sum(currepochs);
    
    if currnepoch ~= 0
        currsig    = data(:,:,currepochs);
        currsig    = reshape(currsig,[nchan,ntime*currnepoch])';
        
        % denoise data for this epoch and this number of pcs
        currdenoisedsig = currsig - pcs{rp}(:,1:p)*(pcs{rp}(:,1:p)\currsig);
        
        % reshape into ntime x nepoch x nchan
        currdenoisedsig = reshape(currdenoisedsig,[ntime, currnepoch, nchan]);
        % save into denoiseddata for this number of pcs [nchan x ntime x nrep]
        denoiseddata(:,:,cummnepoch+(1:currnepoch)) = permute(currdenoisedsig, [3,1,2]);
        cummnepoch = cummnepoch + currnepoch;
    end
    if rp==nrep, assert(cummnepoch(end) == nepoch); end % sanity check
end
