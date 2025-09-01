% analysis code for pupillometry adaptation experiment

% Part 1 of this code processes the eye tracking data. It takes the data files for 
% each participant in the dataDir, and extracts the timecourse for each trial.

% Part 2 calculates the regression across the adapt period for each ppt and
% plots as boxplots

% Part 3 calculates the difference before-after

%% set up
clear; close all;

homeDir = getenv('HOME');   
expDir = ('/Documents/adaptation/exp2_EEG_pupil/');
dataDir = strcat(homeDir,expDir,'data/');
resultsDir = strcat(homeDir,expDir,'results/pupil/');
plotsDir = strcat(homeDir,expDir,'plots/pupil/');

dataPath = dir([dataDir,'*']);
isDataFile = [dataPath.isdir];
pptFolders = dataPath(isDataFile);

% dirPath gives you full folder directories
for thisFolderIndex = 1:length(pptFolders)
    dirPath{thisFolderIndex} = strcat(homeDir, expDir, dataDir, '/', pptFolders(thisFolderIndex).name);
end

% variables
condNames = {'Lum / Lum','Lum / S','S / Lum','S / S'};

sampleFreqHz = 1000;
adaptDurSecs = 21;
probeDurSecs = 5;
probeSamples = probeDurSecs*sampleFreqHz;
adaptSamples = adaptDurSecs*sampleFreqHz;
extraStartSecs = 2; % we cut out the first 2 seconds to avoid onset transients

nConds = 4;
nReps = 3;
nBlocks = 2;
nRepsTotal = nReps*nBlocks;
nTrialsPerBlock = nConds*nReps;

%% 1. process eye tracking data

% empty array to stack all ppt data - 4 conds * time points * n ppts
preProbe_allData = [];
adapt_allData = [];
postProbe_allData = [];

% we want to keep track of how many bins are removed
totalRemovedBins = 0;
totalBins = 0;

for thisFolderIndex=3:length(dirPath)
    
    fprintf('Processing participant: %d\n',thisFolderIndex)

    preProbe_allBlocks = [];
    adapt_allBlocks = [];
    postProbe_allBlocks = [];

    for thisBlock=1:nBlocks
        % **** load in ppt files ****
        pptPupilFile = dir(fullfile(dirPath{thisFolderIndex}, '/', string(thisBlock), '/*_EL.mat'));
        pptTrialFile = dir(fullfile(dirPath{thisFolderIndex}, '/', string(thisBlock), '/*trialDataAfter.mat'));
        pptPupilData = load(strcat(pptPupilFile.folder, '/', pptPupilFile.name));
        pptTrialData = load(strcat(pptTrialFile.folder, '/', pptTrialFile.name));
        
        % **** pupil size at time points ****
        % array of diameter and time
        pupilDataTime = cat(2, pptPupilData.samples.pupilSize, pptPupilData.samples.time);
        
        % array of triggers and times
        eyeLinkMessages = cat(1, pptPupilData.events.Messages.info, num2cell(pptPupilData.events.Messages.time))';
        beginMessage = find(strcmp(eyeLinkMessages, 'SYNCTIME'));
        neededEyeLinkMessages = eyeLinkMessages((beginMessage(1)+1):end,:); % synctime comes just before experiment actually starts
        
        % array of start times for each period
        preProbe_start = [];
        adapt_start = [];
        postProbe_start = [];
        for thisMessage = 1:length(neededEyeLinkMessages)
            [flickerType, timeValue]=neededEyeLinkMessages{thisMessage,:};
            if contains(neededEyeLinkMessages{thisMessage},'PREPROBESTART')
                preProbe_start = cat(1, preProbe_start, timeValue);
                % array of adapt start time - have to work this out as trigger is wrong
                adapt_start = cat(1, adapt_start, (timeValue+(probeSamples+2000))); % probeDur and 2s wait
            elseif contains(neededEyeLinkMessages{thisMessage},'PROBESTART')
                postProbe_start = cat(1, postProbe_start, timeValue);
            end
        end
    
        % **** sort conditions ****
        % retrieve trial order and cat it to each start time
        allTrialOrder = pptTrialData.R.trialOrderPerBlock';
        pptTrialOrder = allTrialOrder(:);
        
        % sort trial order
        [sortedTrialOrder,sortIndices] = sort(pptTrialOrder);
        preProbe_start_sorted = preProbe_start(sortIndices);
        adapt_start_sorted = adapt_start(sortIndices);
        postProbe_start_sorted = postProbe_start(sortIndices);
        
        % **** get data after start times ****
        preProbe_data = pupilEventPeriod(preProbe_start_sorted,pupilDataTime,probeSamples);      
        adapt_data = pupilEventPeriod(adapt_start_sorted,pupilDataTime,adaptSamples);       
        postProbe_data = pupilEventPeriod(postProbe_start_sorted,pupilDataTime,probeSamples);
        % these data matrices now have 12 rows (trials ordered 111222333444) and 7000 or 230000 columns (time points)
    
        % **** remove noise ****
        % interpolate across points where diameter spikes to 0 and a bit each side
        for thisTrial=1:nTrialsPerBlock
            preProbe_noSpikes(thisTrial,:) = removePupilSpikes(preProbe_data(thisTrial,:), 3, 51);
            adapt_noSpikes(thisTrial,:) = removePupilSpikes(adapt_data(thisTrial,:), 3, 51);
            postProbe_noSpikes(thisTrial,:) = removePupilSpikes(postProbe_data(thisTrial,:), 3, 51);
        end
        % remove bins with high variance
        [preProbe_clean, preProbeRemovedBins, preProbeAllBins] = pupilRemoveVar(preProbe_noSpikes, 10000);
        [adapt_clean, adaptRemovedBins, adaptAllBins] = pupilRemoveVar(adapt_noSpikes, 10000);
        [postProbe_clean, postProbeRemovedBins, postProbeAllBins] = pupilRemoveVar(postProbe_noSpikes, 10000);
        % keep track of bins removed
        totalRemovedBins = totalRemovedBins+preProbeRemovedBins+adaptRemovedBins+postProbeRemovedBins;
        totalBins = totalBins+preProbeAllBins+adaptAllBins+postProbeAllBins;
        
        % save this block
        preProbe_allBlocks = cat(3, preProbe_allBlocks, preProbe_clean);
        adapt_allBlocks = cat(3, adapt_allBlocks, adapt_clean);
        postProbe_allBlocks = cat(3, postProbe_allBlocks, postProbe_clean);

    end % for thisBlock

    % here we just reshape the data so all blocks are along one dimensions
    % but trials remains sorted
    preProbe_combineBlocks = reshape(shiftdim(preProbe_allBlocks,2), [nRepsTotal*nConds probeSamples]);
    adapt_combineBlocks = reshape(shiftdim(adapt_allBlocks,2), [nRepsTotal*nConds adaptSamples]);
    postProbe_combineBlocks = reshape(shiftdim(postProbe_allBlocks,2), [nRepsTotal*nConds probeSamples]);

    % **** store each ppt data ****
    preProbe_allData = cat(3, preProbe_allData, preProbe_combineBlocks);
    adapt_allData = cat(3, adapt_allData, adapt_combineBlocks);
    postProbe_allData = cat(3, postProbe_allData, postProbe_combineBlocks);

    fprintf('Finished participant: %d\n',thisFolderIndex)

end % end for each ppt loop

save(sprintf('%s/preProbe_allData',resultsDir), 'preProbe_allData');
save(sprintf('%s/adapt_allData',resultsDir), 'adapt_allData');
save(sprintf('%s/postProbe_allData',resultsDir), 'postProbe_allData');

save(sprintf('%s/totalRemovedBins',resultsDir), 'totalRemovedBins');
save(sprintf('%s/totalBins',resultsDir), 'totalBins');

%% 2. regression for adapt
% we want to calculate the regression for each ppt indiviually. We can't
% really average this across participants very reliably as there will be
% lots of individudal differences (e.g. starting pupil size, angle of
% camera etc.). so we can plot this regression for each person or plot tje
% regression values across ppts as boxplots.

load(sprintf('%s/adapt_allData',resultsDir));

lumRegAllPpts = [];
sRegAllPpts = [];

for thisPpt = 1:size(adapt_allData,3)

    adapt_lum_mean = squeeze(nanmean(adapt_allData(1:nTrialsPerBlock,1:adaptSamples,thisPpt),1)); 
    adapt_s_mean = squeeze(nanmean(adapt_allData(nTrialsPerBlock+1:nTrialsPerBlock*2,1:adaptSamples,thisPpt),1));

    adapt_lum_sem = squeeze(nanstd(adapt_allData(1:nTrialsPerBlock,1:adaptSamples,thisPpt),[],1))./sqrt(nTrialsPerBlock); 
    adapt_s_sem = squeeze(nanstd(adapt_allData(nTrialsPerBlock+1:nTrialsPerBlock*2,1:adaptSamples,thisPpt),[],1))./sqrt(nTrialsPerBlock);

    % do the actual regression
    LumRegression = fitlm(1:adaptSamples, adapt_lum_mean);
    sRegression = fitlm(1:adaptSamples, adapt_s_mean);

    % plot regression for each ppt
%     figure(thisPpt); 
%     subplot(1,2,1);
%     hold on;
%     plot(LumRegression,'Color',[.35 .35 .35]); % plot the data - blue crosses, and regression
%     shadedErrorBar(1:21000, LumRegression.Fitted, adapt_lum_sem, 'k'); % plot error
%     alpha(.5); % makes the error bars slightly transparent
%     title('Luminance');
%     ylim([550 900]);
%     xlim([0 21000]);
%     ylabel('Pupil Diameter (px)');
%     xlabel('Time (s)');
%     xticks([0 5000 10000 15000 20000]);
%     xticklabels({'0','5','10','15','20'});
%     legend('hide');
%     hold off;
%     subplot(1,2,2);
%     hold on;
%     plot(sRegression,'Color',[.35 .35 1]);
%     shadedErrorBar(1:21000, sRegression.Fitted, adapt_s_sem, 'b');
%     alpha(.5);
%     title('S-Cone');
%     ylim([550 900]);
%     xlim([0 21000]);
%     xticks([0 5000 10000 15000 20000]);
%     xticklabels({'0','5','10','15','20'});
%     ylabel('Pupil Diameter (px)');
%     xlabel('Time (s)');
%     legend('hide');
%     hold off;

    % store x1 estimate, error, t, p
    lumSlope = LumRegression.Coefficients{2,:};
    lumRegAllPpts = cat(1, lumRegAllPpts, lumSlope);
    sSlope = sRegression.Coefficients{2,:};
    sRegAllPpts = cat(1, sRegAllPpts, sSlope);
end

adaptHeadings = {'Luminance','S'};
adapt_regression = cat(2, lumRegAllPpts(:,1), sRegAllPpts(:,1));

regression_cell = num2cell(adapt_regression);
regression_wide = cat(1, adaptHeadings, regression_cell);
writecell(regression_wide, sprintf('%s/pupilReg.csv',resultsDir));

figure(1);
boxplot(adapt_regression, 'Notch','on', 'Colors', 'k','Symbol',' ', 'Labels', adaptHeadings);
title('REGRESSION');
yline(0,':');
saveas(gcf, sprintf('%s/adapt_regression.png',plotsDir));

%% 3. change in diameter (after-before)
% also calculate the change in pupil size after adaptation. We need to
% average the pupil size for each condition BUT:
% 1. we remove the start and end of the period to avoid onset transients
% and 2. we take the median and mean - pupil size changes a lot so median
% may have been a better measure, but doesnt actually seem to make much
% difference.

load(sprintf('%s/preProbe_allData',resultsDir));
load(sprintf('%s/postProbe_allData',resultsDir));

% average across trials
preProbe_ave = conditionAverage(preProbe_allData,nRepsTotal,nConds);
postProbe_ave = conditionAverage(postProbe_allData,nRepsTotal,nConds);

% median of 1-4s from pre and probe across ppts
preProbe_median = squeeze(nanmedian(preProbe_ave(:,1001:4000,:),2));
postProbe_median = squeeze(nanmedian(postProbe_ave(:,1001:4000,:),2));
% mean of 1-4s from pre and probe across ppts
preProbe_mean = squeeze(nanmean(preProbe_ave(:,1001:4000,:),2));
postProbe_mean = squeeze(nanmean(postProbe_ave(:,1001:4000,:),2));

% change in pupil size
difference_med = (postProbe_median-preProbe_median)./(postProbe_median+preProbe_median);
difference_mean = (postProbe_mean-preProbe_mean)./(postProbe_mean+preProbe_mean);

difference_med_wide = cat(1, condNames, num2cell(difference_med'));
writecell(difference_med_wide, sprintf('%s/difference_med_wide.csv',resultsDir));

difference_mean_wide = cat(1, condNames, num2cell(difference_mean'));
writecell(difference_mean_wide, sprintf('%s/difference_mean_wide.csv',resultsDir));

figure(2);
boxplot(difference_med', 'Notch','on', 'Labels', condNames, 'Colors', 'k');
title('DIFFERENCE (median)');
xline(0,':');
saveas(gcf, sprintf('%s/difference_median_box.png',plotsDir));

figure(3);
boxplot(difference_mean', 'Notch','on', 'Labels', condNames, 'Colors', 'k');
title('DIFFERENCE (mean)');
xline(0,':');
saveas(gcf, sprintf('%s/difference_mean_box.png',plotsDir));

