function averagedBinsV1 = binAve_FT_hemAve(inputDataL, inputDataR, startSecs, endSecs) 
% this function averages bins for the entire period, takes a Fourier
% transform and then averages across hemispheres
% INPUTS:
    % inputDataL / R = matrix of data - conditions * sample freq (Hz) * nBins * nParticipants
    % startSecs = at which bin during the period to start
    % endSecs = at which bin during the period to end
% OUTPUTS:
    % averagedBinsV1 = matrix of data - conditions * frequencies * nParticipants

% ** start with left hem **
% get the wanted binned data
wantedBinsL = inputDataL(:,:,startSecs:endSecs,:);

% average bins before FT to reduce noise
averagedBinsL = squeeze(mean(wantedBinsL,3));

% now take a FT of the average
averagedBinsFTL = abs(fft(averagedBinsL,[],2))./1000;

% ** now right hem **
% get the wanted binned data
wantedBinsR = inputDataR(:,:,startSecs:endSecs,:);

% average bins before FT to reduce noise
averagedBinsR = squeeze(mean(wantedBinsR,3));

% now take a FT of the average
averagedBinsFTR = abs(fft(averagedBinsR,[],2))./1000;

% ** finally average the hems **
averagedBinsV1 = mean(cat(4,averagedBinsFTL,averagedBinsFTR),4);


