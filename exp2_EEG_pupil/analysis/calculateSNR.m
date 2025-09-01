function snr = calculateSNR(rawData, noiseFreqs)
% this function calculates the signal-to-noise ratio
% INPUTS:
    % rawData = 1D matrix of the frequency data from 1Hz to xHz
    % noiseFreqs = 1D matrix of any frequencies that response can be
    % assumed to be noise e.g. is signal is at 5Hz, noiseFreqs will be
    % [1,2,3,4,6,7...]
% OUTPUTS:
    % snr = signal-to-noise ratio for each frequency. This will be the same
    % size as rawData. Expect noise freqs to be ~1.

noiseData = rawData(noiseFreqs);
noiseMean = sqrt(sum(noiseData.^2)/length(noiseFreqs));
snr = rawData./noiseMean;