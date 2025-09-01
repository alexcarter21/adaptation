function [cleanData,nRemovedBins,nTotalBins] = pupilRemoveVar(inputData, highVar)
% this function bins the timecourse data, identifies bins with high 
% variance and removes them from the data
% INPUTS:
    % inputData = matrix of data - trials * samples
    % highVar = the value in which variance above this should be removed
% OUTPUTS:
    % cleanData = matrix of data with same shape as inputData, with NaNs replacing high variance bins
    % nRemovedBins = count of how many bins have been removed
    % nTotalBins = total number of bins

% split into 1s bins
binnedData = reshape(inputData, [size(inputData,1),1000,(size(inputData,2)/1000)]); 
nTotalBins = numel(binnedData);

% calculate variance and find bins with big variance
varOfBins = squeeze(std(binnedData,[],2).^2); 
badBinIndicies = find(varOfBins>highVar);

% replace these bins with NaNs
[i,j]=ind2sub([12,(length(inputData)/1000)],badBinIndicies);
removedBins = 0;
for thisBadBin=1:length(badBinIndicies)
    %fprintf('.'); % this means we can see how many bins have been removed in the command window
    binnedData(i(thisBadBin),:,j(thisBadBin))=nan(1000,1);
    removedBins = removedBins + 1;
end
cleanData = reshape(binnedData, [size(inputData,1),size(inputData,2)]); % reshape back to original size
nRemovedBins = removedBins;
