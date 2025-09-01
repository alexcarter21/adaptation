function eventPeriodData = eventPeriod(eventOffsets, eventTriggers, eventTriggerCode, allData, eventDurationSamples)
% this function seperates time course EEG data into shorter timecourses for
% each event
% INPUTS:
    % eventOffsets = 1D array of timings for each event trigger (offset of trigger)
    % eventTriggers = 1D array of trigger labels for every event
    % eventTriggerCode = the wanted trigger label for wanted events
    % allData = this should be the raw EEG data, matrix of channels by time points
    % eventDurationSamples = how many time points the event is
% OUTPUT:
    % eventPeriodData = 3D matrix of trials * channels * time points

offsetPoints=eventOffsets(eventTriggers==eventTriggerCode);
for thisOffset=1:length(offsetPoints)
    electrodeTimeArray=allData(:,offsetPoints(thisOffset):(offsetPoints(thisOffset)+eventDurationSamples-1));
    eventPeriodData(thisOffset,:,:)=electrodeTimeArray;
end