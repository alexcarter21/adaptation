function ROIdata = applyROItemplate(eventData, nBins, ROIelecWeights)
% this function applies the weights from Poncet and Ales to each channel in
% the EEG data
% INPUTS:
    % eventData = matrix of data - trials * channels * sample freq (Hz) * nBins
    % nBins = number of 1s bins
    % ROIelecWeights = weights to be applied
% OUTPUTS:
    % ROIdata = matrix of data with same shape as eventData, without
    % channels - trials * sample freq * nBins

% V1 template cannot andle NaNs, so replace with 0
eventData(isnan(eventData))=0;

for thisIt=1:size(eventData,1)
    for this1sBin=1:nBins
        sNew=squeeze(eventData(thisIt,:,:,this1sBin));
        ROIdata(thisIt,:,this1sBin)=ROIelecWeights'*sNew/1000;
    end
end

ROIdata = squeeze(ROIdata);