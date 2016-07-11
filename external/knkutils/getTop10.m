function pcchan = getTop10(results,whichfun, topn)
% retrieve the top 10 (or top n) channels from a results structure
% outputted by med_denoise.
%  pcchan = getTop10(results,[whichfun], [topn])
%
%  whichfun is presumably used if meg_denoise was run with multiple
%  functions for computing model accuracy. Usually there will be just one
%  function (e.g., SNR, or R^2).
%
%  topn: how many of the top channels to return


if notDefined('whichfun'),  whichfun = 1; end 
if notDefined('topn'),      topn = 10; end

% max across 3 conditions 
finalsnr = [getsignalnoise(results.origmodel(whichfun)); ...
    getsignalnoise(results.finalmodel(whichfun))];
% max across before and after 
finalsnr = max(finalsnr);
% exclude noise pool
finalsnr(results.noisepool) = -inf;
% sort 
[~,idx] = sort(finalsnr,'descend');
% find the top 10 (or top n, if a different number was requested)
pcchan = false(size(results.noisepool));
pcchan(idx(1:topn))= 1;