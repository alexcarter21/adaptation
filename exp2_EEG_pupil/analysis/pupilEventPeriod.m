function pupilDataAllTrials = pupilEventPeriod(startTimes,allData,eventDurationSamples)
% this function seperates time course pupillometry data into shorter timecourses for
% each event. similar to eventPeriod for EEG but different data structure.
% INPUTS:
    % startTimes = 1D array of timings for each event trigger
    % allData = this should be the raw EEG data, matrix of channels by time points
    % eventDurationSamples = how many time points the event is
% OUTPUT:
    % pupilDataAllTrials = 2D matrix of trials * time points

pupilDataAllTrials = zeros(length(startTimes),eventDurationSamples);
for thisTrial=1:length(startTimes)
    [row, column] = find(allData==startTimes(thisTrial));
    pupilDataOneTrial = allData(row:(row+eventDurationSamples-1));
    pupilDataAllTrials(thisTrial,:) = pupilDataOneTrial;
end