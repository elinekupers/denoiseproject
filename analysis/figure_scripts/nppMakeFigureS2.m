function nppMakeFigureS2()

%% Function to reproduce Supplementary Figure 2 with SNR pre-post difference
% for different epoch lengths and different epoch length against used npcs.
% for top ten channels of all subjects
%
% nppMakeFigureS2()
%
% Eline Kupers, Helena X. Wang, Kaoru Amano, Kendrick N. Kay, David J.
% Heeger, Jonathan Winawer. (2018) A non-invasive, quantitative study of
% broadband spectral responses in human visual cortex
% (PLOS ONE. VOLUME. ISSUE. DOI.)
%
%
% This function assumes that data is downloaded with the nppdownloaddata
% function and then analyzed by nppDenoiseVaryEpochLength.


%% Choices to make:
whichSubjects        = [1:8];
dataDir              = fullfile(nppRootPath, 'analysis', 'data');   % Where to save data?
figureDir            = fullfile(nppRootPath, 'analysis', 'figures');% Where to save images?
saveFigures          = true;     % Save figures in the figure folder?
condColors           = nppGetColors(3);
dataAll              = [];
figureNumber         = 'SF2';
epochDurs            = [1,3,6,12,24,36,72,1080];
npcs                 = [5,10:10:70];

%% Load data for all subjects
for whichSubject = whichSubjects
    fprintf(' Load subject %d \n', whichSubject);
    [data,design,exampleIndex] = prepareData(dataDir,whichSubject,figureNumber);
    dataAll{whichSubject} = {data,design,exampleIndex}; %#ok<AGROW>
end

%% Plot difference in SNR (post-pre) as a function of denoising epoch duration
fH = plotEpochLengthVersusSNR(whichSubjects,dataAll,epochDurs,condColors,saveFigures,figureDir);

%% Plot surface of difference in SNR (post-pre) as a function of epoch duration and
%% number of PCs removed. 
% Some specs:
%  - Noisepool selection by SNR,
%  - 10 PCs removed
%  - bootstrapped 1000x. 

fH = plotEpochLengthVersusNPCsVersusSNR(whichSubjects,dataAll,epochDurs,npcs,saveFigures,figureDir); %#ok<*NASGU>
