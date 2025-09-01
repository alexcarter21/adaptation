function [outSeq,goodPoints]=removePupilSpikes(inSeq, zscore_thresh, windowToChop)
% Takes an input sequence. Identifies points where points are extreme.
% weird points are identified as being more than zscore_thresh SDs away
% from the mean
% INPUTS:
    % inSeq = the input (1D) timecourse
    % zscore = How ruthless do you want to be in the chopping?
    % windowToChop = In our pupil data, a śpike'has cetain width. Chop out
    % n timepoints each side of the spike
% OUTPUTS:
    % outSeq = cleaned data, same shape as inSeq
    % goodPoints = the positions of the good points
    
% Aug 15 2023: written by ARW, adapted by AC

normInput=zscore(inSeq(:)); % We are going to look for things that are x SDs away so scale things interms of SDs
badPoints=abs(normInput)>zscore_thresh; % Identify things that are more than x SD away- badPoints is a list of 1s and 0s with 1s at the places where the SD is high
blockToConv=ones(windowToChop,1); % We want to chop out some set of points either side - because we think that a lot of the bad points (all?) are related to saccades/blinks which might start and end either side of the corrupted data
badPoints=conv(badPoints(:),blockToConv(:),'same'); % This goes through the list of badPoints and broadens each individual bad point to a wider set of bad points. Think of convolution like a blur..... The same flag makes sure that the resulting sequence is the same size as the input
badPoints=(badPoints>0); % Anything that was affected by the blur is now bad
goodPoints=find(1-badPoints); % For the next step we need to know where the good points are - they are the opposite of the bad ones!

% Now we can either set to nans or interpolate across.
% interpolate!
% Use interp1
%   Vq = interp1(X,V,Xq) interpolates to find Vq, the values of the
%    underlying function V=F(X) at the query points Xq. 

% The points we know are at goodPoints
% We want to recover the whole series (1:length(inSeq)
outSeq=interp1(goodPoints,inSeq(goodPoints),1:length(inSeq)); % Give the interp1 function a set of points that you know are good and their locations. And a set of locations that you want it to return. It will (rather stupidly) just interpolate across the gaps...

% This function might be better if it just returned the good point
% locations since itś a 1-liner to interpolate the new dataset. You might,
% instead, want to set them to NaNs or something. ...

 