function averagedData = conditionAverage(inputData,nReps,nConds)
% this function averages across conditions. This function assumes that the
% trial data is in condition order i.e. if nReps = 3, rows 1-3 will be
% condition 1, 4-6 will be condition 2 and so on.
% INPUTS:
    % inputData = matrix of data - trials * sample freq (Hz) * nBins
    % nReps = number of reps of each condition
    % nConds = number of conds
% OUTPUTS:
    % averageData = matrix of data averaged by condition - conditions * sample freq (Hz) * nBins

for thisCond = 1:nConds
    thisCondAverage = squeeze(nanmean(inputData(nReps*thisCond-nReps+1:nReps*thisCond,:,:)));
    averagedData(thisCond,:,:) = thisCondAverage;
end

averagedData = squeeze(averagedData);
    