function [cleanData,nRemovedBins]=EEGremoveVar(inputData, highVar)
% this function identifies bins with high variance and removes them from
% the data
% INPUTS:
    % inputData = matrix of data - trials * channels * sample freq (Hz) * nBins
    % highVar = the value in which log(variance) above this should be removed
% OUTPUTS:
    % cleanData = matrix of data with same shape as inputData, with NaNs replacing high variance bins
    % nRemovedBins = count of how many bins have been removed

dataWithNans=inputData;
[nTrials,nSensors,nSamps,binsPerTrial]=size(inputData);
varPerBin=squeeze(nanstd(inputData,[],3).^2);
logVarPerBin=log(varPerBin(:));
badBinIndices=find(logVarPerBin>highVar);
[i,j,k]=ind2sub([nTrials,nSensors,binsPerTrial],badBinIndices);
% Loop over the filtered data replacing bins with NaNs
removedBins = 0;
for thisBadBin=1:length(badBinIndices)
    %fprintf('.'); % this means we can see how many bins have been removed in the command window
    dataWithNans(i(thisBadBin),j(thisBadBin),1:1000,k(thisBadBin))=nan(1000,1);
    removedBins = removedBins + 1;
end
cleanData = dataWithNans;
nRemovedBins = removedBins;