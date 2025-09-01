% analysis code for EEG adaptation experiment (we look at V1 but could 
% cover any ROI in the Poncet and Ales template).

% Part 1 of this code processes the EEG data. It takes the data files for 
% each participant in the dataDir, extracts the timecourse for each trial, 
% and averages reps per condition.

% Part 2 takes a Fourier transform and then averages across hemispheres.
% For pre- and post- adapt we average bins across the whole period
% For adapt we do the same AND look at individual bins across the whole
% timecourse

% Part 3 calculates the SNR for each period, and for each bin in the adapt
% period

% Part 4 calculates the difference before-after at the wanted frequency

% Part 5 plots FTs for pre- and post- adapt periods (same data as above
% visualised in a different way)

% Part 6 plots the SNR at each second of the adapt period

% Part 7 calculates the regression across the adapt period for each ppt and
% plots as boxplots (same data as above visualised in a different way)

%% set up 
clear; close all;

homeDir = getenv('HOME');   
expDir = ('/Documents/adaptation/exp2_EEG_pupil/');
dataDir = strcat(homeDir,expDir,'data/');
resultsDir = strcat(homeDir,expDir,'results/EEG/');
plotsDir = strcat(homeDir,expDir,'plots/EEG/');

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

highestFreq = 25;
flickerFreq = 5;
signalFreq = flickerFreq*2;

%% 1. process EEG data 

% We are using this template from Poncet and Ales to create a V1 ROI
load('ANT64_Waveguard_customTemplates');
ROIweights = customTemplates.weights(2:end, 1:2); %1:2 is V1L and V1R

totalRemovedBins = 0;

for thisROI = 1:2

    thisROIweights = ROIweights(:,thisROI);

    % empty array to stack all ppt data - 4 conds * 1000 time points * nBins * n ppts
    % these arrays will be averaged across reps for each cond and ppt, and
    % be binned for later plotting
    preProbe_allData = zeros(nConds,sampleFreqHz,probeDurSecs,length(dirPath)-2);
    adapt_allData = zeros(nConds,sampleFreqHz,adaptDurSecs,length(dirPath)-2);
    postProbe_allData = zeros(nConds,sampleFreqHz,probeDurSecs,length(dirPath)-2);

    % Design the filter outside the loop 
    bpFilt = designfilt('bandpassfir', 'FilterOrder', 1000, 'CutoffFrequency1', 2, 'CutoffFrequency2', 25, 'SampleRate', 1000);
    
    for thisFolderIndex = 3:length(dirPath) % could be parfor
        
        fprintf('Processing participant: %d\n',thisFolderIndex)

        preProbe_allBlocks = [];
        adapt_allBlocks = [];
        postProbe_allBlocks = [];

        for thisBlock=1:nBlocks
            % **** load in ppt files ****
            % eye tracking file - needed for trial order
            pptTrialFile = dir(fullfile(dirPath{thisFolderIndex}, '/', string(thisBlock), '/*trialDataAfter.mat'));
            pptTrialData = load(strcat(pptTrialFile.folder, '/', pptTrialFile.name));
            % EEG file
            fListDat = dir(fullfile(dirPath{thisFolderIndex},'/', string(thisBlock), '*.cnt'));
            for thisSubjIndex = 1:length(fListDat)
                fileName = fullfile(dirPath,fListDat(thisSubjIndex).name);
                EEG{1} = processcnt3(fullfile(fListDat.folder,fListDat.name));
            end
            E = EEG{1};

            % **** event codes and times ****
            nTriggers = length(E.triggers);

            % as long as the event is not empty, save out the code and
            % trigger offsets
            trigIndex = 1;
            for thisTrig=1:nTriggers
                numCode=str2num(E.triggers(thisTrig).code);
                if (~isempty(numCode))
                    eventCodes(trigIndex)=numCode;
                    eventTimes(trigIndex)=E.triggers(thisTrig).time; % Time in ms
                    eventTriggers(trigIndex)=E.triggers(thisTrig).offset; % Integer sample offset in file
                    trigIndex=trigIndex+1;
                end
            end

            % timings for each period of each trial
            preProbe_rawData = eventPeriod(eventTriggers, eventCodes, 106, E.data, probeSamples);
            adapt_rawData = eventPeriod(eventTriggers, eventCodes, 102, E.data, adaptSamples);
            postProbe_rawData = eventPeriod(eventTriggers, eventCodes, 100, E.data, probeSamples);

            % **** noise removal ****
            % the filter runs by default along the first dimension so needs
            % to be shifted
            preProbe_forFilter = shiftdim(preProbe_rawData,2);
            preProbe_afterFilter = filter(bpFilt, preProbe_forFilter);
            preProbe_filtered = shiftdim(preProbe_afterFilter,1);
        
            adapt_forFilter = shiftdim(adapt_rawData,2);
            adapt_afterFilter = filter(bpFilt, adapt_forFilter);
            adapt_filtered = shiftdim(adapt_afterFilter,1);
        
            postProbe_forFilter = shiftdim(postProbe_rawData,2);
            postProbe_afterFilter = filter(bpFilt, postProbe_forFilter);
            postProbe_filtered = shiftdim(postProbe_afterFilter,1);

            % cut out unwanted channels and seconds
            % Reshape this into nTrials*nChans*1000 time points*nBins 
            preProbe_binned = reshape(preProbe_filtered(:,1:64,:), [nTrialsPerBlock,64,sampleFreqHz,probeDurSecs]);
            adapt_binned = reshape(adapt_filtered(:,1:64,:), [nTrialsPerBlock,64,sampleFreqHz,adaptDurSecs]);
            postProbe_binned = reshape(postProbe_filtered(:,1:64,:), [nTrialsPerBlock,64,sampleFreqHz,probeDurSecs]);
            
            % remove bins with high variance
            [preProbe_clean, preProbeRemovedBins] = EEGremoveVar(preProbe_binned, 8);
            [adapt_clean, adaptRemovedBins] = EEGremoveVar(adapt_binned, 8);
            [postProbe_clean, postProbeRemovedBins] = EEGremoveVar(postProbe_binned, 8);
            
            totalRemovedBins = totalRemovedBins+preProbeRemovedBins+adaptRemovedBins+postProbeRemovedBins;

            % **** sort conditions ****
            % get trial order
            allTrialOrder = pptTrialData.R.trialOrderPerBlock';
            pptTrialOrder = allTrialOrder(:);
            [sortedTrialOrder,sortIndices] = sort(pptTrialOrder);

            % sort trials
            preProbe_sorted = preProbe_clean(sortIndices,:,:,:);
            adapt_sorted = adapt_clean(sortIndices,:,:,:);
            postProbe_sorted = postProbe_clean(sortIndices,:,:,:);

            % **** apply V1 template ****
            preProbe_ROI = applyROItemplate(preProbe_sorted, probeDurSecs, thisROIweights);
            adapt_ROI = applyROItemplate(adapt_sorted, adaptDurSecs, thisROIweights);
            postProbe_ROI = applyROItemplate(postProbe_sorted, probeDurSecs, thisROIweights);

            % stack both blocks into one
            preProbe_allBlocks = cat(4, preProbe_allBlocks, preProbe_ROI);
            adapt_allBlocks = cat(4, adapt_allBlocks, adapt_ROI);
            postProbe_allBlocks = cat(4, postProbe_allBlocks, postProbe_ROI);
            
        end %for thisBlock
        
        % **** average repetitions ****
        % dimensions are currently trials*sampleFreq*nBins*nBlocks but we
        % want all trials across all blocks combined before averaging
        preProbe_blockShift = permute(preProbe_allBlocks,[4 1 2 3]);
        adapt_blockShift = permute(adapt_allBlocks,[4 1 2 3]);
        postProbe_blockShift = permute(postProbe_allBlocks,[4 1 2 3]);
        
        preProbe_combineBlocks = reshape(preProbe_blockShift, [nConds*nRepsTotal sampleFreqHz probeDurSecs]);
        adapt_combineBlocks = reshape(adapt_blockShift, [nConds*nRepsTotal sampleFreqHz adaptDurSecs]);
        postProbe_combineBlocks = reshape(postProbe_blockShift, [nConds*nRepsTotal sampleFreqHz probeDurSecs]);

        preProbe_aveConds = conditionAverage(preProbe_combineBlocks,nRepsTotal,nConds);
        adapt_aveConds = conditionAverage(adapt_combineBlocks,nRepsTotal,nConds);
        postProbe_aveConds = conditionAverage(postProbe_combineBlocks,nRepsTotal,nConds);

        % **** stack each ppt data to final data set ****
        preProbe_allData(:,:,:,thisFolderIndex-2) = preProbe_aveConds;
        adapt_allData(:,:,:,thisFolderIndex-2) = adapt_aveConds;
        postProbe_allData(:,:,:,thisFolderIndex-2) = postProbe_aveConds;
        
        fprintf('Finished participant: %d\n',thisFolderIndex)

    end % for thisFolderIndex

    % save these outputs
    save(sprintf('%s/preProbe_allData_%d',resultsDir,thisROI),  'preProbe_allData');
    save(sprintf('%s/adapt_allData_%d',resultsDir,thisROI), 'adapt_allData');
    save(sprintf('%s/postProbe_allData_%d',resultsDir,thisROI), 'postProbe_allData');
    
    save(sprintf('%s/totalRemovedBins_%d',resultsDir,thisROI), 'totalRemovedBins');

end % for thisROI

%% 2. average V1 hemispheres
% here we load in left and right ROIs and average them. because the phase 
% is different for Left and Right hemispheres we need to FT before we 
% average

% pre-adapt probe
preProbe_L = load(sprintf('%s/preProbe_allData_1.mat',resultsDir));
preProbe_R = load(sprintf('%s/preProbe_allData_2.mat',resultsDir));
% adapt
adapt_L = load(sprintf('%s/adapt_allData_1.mat',resultsDir));
adapt_R = load(sprintf('%s/adapt_allData_2.mat',resultsDir));
% post-adapt probe
postProbe_L = load(sprintf('%s/postProbe_allData_1.mat',resultsDir));
postProbe_R = load(sprintf('%s/postProbe_allData_2.mat',resultsDir));

% average the bins of each period and FT
preProbe_aveBin_FTV1 = binAve_FT_hemAve(preProbe_L.preProbe_allData,preProbe_R.preProbe_allData,extraStartSecs,probeDurSecs);
adapt_aveBin_FTV1 = binAve_FT_hemAve(adapt_L.adapt_allData,adapt_R.adapt_allData,extraStartSecs,adaptDurSecs);
postProbe_aveBin_FTV1 = binAve_FT_hemAve(postProbe_L.postProbe_allData,postProbe_R.postProbe_allData,extraStartSecs,probeDurSecs);
        
save(sprintf('%s/preProbe_aveBin_FTV1',resultsDir), 'preProbe_aveBin_FTV1');
save(sprintf('%s/adapt_aveBin_FTV1',resultsDir), 'adapt_aveBin_FTV1');
save(sprintf('%s/postProbe_aveBin_FTV1',resultsDir), 'postProbe_aveBin_FTV1');

% we also want to do the FT of each bin across the entire adapt period
% take a FT for every bin and average L and R
adapt_perBin_FTL = abs(fft(adapt_L.adapt_allData,[],2))./1000;
adapt_perBin_FTR = abs(fft(adapt_R.adapt_allData,[],2))./1000;
adapt_perBin_FTV1 = mean(cat(5,adapt_perBin_FTL,adapt_perBin_FTR),5);
save(sprintf('%s/adapt_perBin_FTV1',resultsDir), 'adapt_perBin_FTV1');

%% 3. calculate SNR

allFreqs = 1:highestFreq;
responseFreqs = [flickerFreq, flickerFreq*2, flickerFreq*3, flickerFreq*4];
noiseFreqs=setdiff(allFreqs,responseFreqs);

% start with calculating the SNR for the average of each period
load(sprintf('%s/preProbe_aveBin_FTV1',resultsDir));
load(sprintf('%s/adapt_aveBin_FTV1',resultsDir));
load(sprintf('%s/postProbe_aveBin_FTV1',resultsDir));

% empty arrays to store data...
preProbe_snr = zeros(nConds,highestFreq,length(dirPath)-2);
adapt_snr = zeros(nConds,highestFreq,length(dirPath)-2);
postProbe_snr = zeros(nConds,highestFreq,length(dirPath)-2);

for thisPpt = 1:(length(dirPath)-2) % For each participant...
    for thisCond = 1:nConds % ... and for each condition
        wantedDataPre = preProbe_aveBin_FTV1(thisCond,2:highestFreq+1,thisPpt);
        preProbe_snr(thisCond,:,thisPpt) = calculateSNR(wantedDataPre,noiseFreqs);

        wantedDataAdapt = adapt_aveBin_FTV1(thisCond,2:highestFreq+1,thisPpt);
        adapt_snr(thisCond,:,thisPpt) = calculateSNR(wantedDataAdapt,noiseFreqs);

        wantedDataPost = postProbe_aveBin_FTV1(thisCond,2:highestFreq+1,thisPpt);
        postProbe_snr(thisCond,:,thisPpt) = calculateSNR(wantedDataPost,noiseFreqs);
    end % thisCond
end % thisPpt

save(sprintf('%s/preProbe_snr',resultsDir), 'preProbe_snr');
save(sprintf('%s/adapt_snr',resultsDir), 'adapt_snr');
save(sprintf('%s/postProbe_snr',resultsDir), 'postProbe_snr');

% and for each bin across the whole adapt period
load(sprintf('%s/adapt_perBin_FTV1',resultsDir));

adapt_snrPerBin = zeros(nConds,highestFreq,adaptDurSecs,length(dirPath)-2);
for thisPpt = 1:length(dirPath)-2 % For each participant...
    for thisCond = 1:nConds % ... and for each condition
        for thisBin = 1:adaptDurSecs
            wantedDataAdaptBin = adapt_perBin_FTV1(thisCond,2:highestFreq+1,thisBin,thisPpt);
            adapt_snrPerBin(thisCond,:,thisBin,thisPpt) = calculateSNR(wantedDataAdaptBin,noiseFreqs);
        end
    end % thisCond
end % thisPpt

save(sprintf('%s/adapt_snrPerBin',resultsDir), 'adapt_snrPerBin');

%% 4. difference at signal frequency
% here we need to isolate the wanted frequency and calculate the difference
% before - after
    
load(sprintf('%s/preProbe_snr',resultsDir));
load(sprintf('%s/postProbe_snr',resultsDir));

% pull out signal freq
preProbe_signal = squeeze(preProbe_snr(:,signalFreq,:));
postProbe_signal = squeeze(postProbe_snr(:,signalFreq,:));

% calculate % difference before and after 
% (b-a)/(a+b)
difference = (postProbe_signal-preProbe_signal) ./ (preProbe_signal+postProbe_signal);
difference_wide = cat(1, condNames, num2cell(difference'));
writecell(difference_wide, sprintf('%s/difference_wide.csv',resultsDir));

figure(1);
boxplot(difference', 'Notch', 'on', 'Colors', 'k', 'Labels', condNames);
title('DIFFERENCE');
xline(0,':');
saveas(gcf, sprintf('%s/difference_box.png',plotsDir));

%% 5. preprobe vs probe FT plots
% another way of visualising the same data above. Plots FTs of the
% pre-adapt period and post-adapt period for each condition

load(sprintf('%s/preProbe_snr',resultsDir));
load(sprintf('%s/postProbe_snr',resultsDir));

% average across ppts 
preProbe_pptAve = squeeze(mean(preProbe_snr,3));
postProbe_pptAve = squeeze(mean(postProbe_snr,3));

% calculate the SEM just for 10Hz
preProbe_sem = squeeze(nanstd(preProbe_snr,[],2))/sqrt((length(dirPath)-2));
postProbe_sem = squeeze(nanstd(postProbe_snr,[],2))/sqrt((length(dirPath)-2));

for thisCond=1:nConds
    figure(2);
    % preprobe
    subplot(2,nConds,thisCond);
    h = bar(abs(preProbe_pptAve(thisCond,:)),'facecolor','flat');
    h.CData(1:highestFreq,:)=repmat([0 0 0],highestFreq,1);
    h.CData(signalFreq,:)=repmat([0 0 1],1,1);
    h.EdgeColor = 'none';
    hold on;
    h2=errorbar(signalFreq,preProbe_pptAve(thisCond, signalFreq),preProbe_sem(thisCond));
    h2.Color=[0 0 0]; h2.LineStyle='none'; h2.CapSize=0;
    title([condNames{thisCond}]);
    if thisCond==1
        ylabel(sprintf('Pre-adapt Probe\n\nSNR'));
    end
    set(gca,'YLim',[0 6]);
    set(gca,'XLim',[1 16]);
    box off
    % probe
    subplot(2,nConds,thisCond+nConds);
    h = bar(abs(postProbe_pptAve(thisCond,:)),'facecolor','flat');
    title(condNames{thisCond});
    h.CData(1:highestFreq,:)=repmat([0 0 0],highestFreq,1);
    h.CData(signalFreq,:)=repmat([0 0 1],1,1);
    h.EdgeColor = 'none';
    hold on;
    h2 = errorbar(signalFreq,postProbe_pptAve(thisCond, signalFreq),postProbe_sem(thisCond));
    h2.Color=[0 0 0]; h2.LineStyle='none'; h2.CapSize=0;
    if thisCond==1
        ylabel(sprintf('Post-adapt Probe\n\nSNR'));
    end
    xlabel('Freq (Hz)');
    set(gca,'YLim',[0 6]);
    set(gca,'XLim',[1 16]);
    box off 
end

saveas(gcf, sprintf('%s/difference_FT.png',plotsDir));

%% 6. time course across adapt period
% this plots the SNR at each second of the adapt period for each condition

load(sprintf('%s/adapt_snrPerBin',resultsDir));

adapt_perBin_Lum = squeeze(mean(adapt_snrPerBin(1:2,signalFreq,:,:),1));
adapt_perBin_S = squeeze(mean(adapt_snrPerBin(3:4,signalFreq,:,:),1));

adapt_perBin_pptAve_Lum = squeeze(nanmean(adapt_perBin_Lum,2));
adapt_perBin_pptAve_S = squeeze(nanmean(adapt_perBin_S,2));

adapt_perBin_sem_Lum = squeeze(nanstd(adapt_perBin_Lum,[],2))/sqrt((length(dirPath)-2));
adapt_perBin_sem_S = squeeze(nanstd(adapt_perBin_S,[],2))/sqrt((length(dirPath)-2));

figure(3);
shadedErrorBar(extraStartSecs+1:adaptDurSecs,adapt_perBin_pptAve_Lum(extraStartSecs+1:adaptDurSecs),adapt_perBin_sem_Lum(extraStartSecs+1:adaptDurSecs),'-k.',1);
hold on
shadedErrorBar(extraStartSecs+1:adaptDurSecs,adapt_perBin_pptAve_S(extraStartSecs+1:adaptDurSecs),adapt_perBin_sem_S(extraStartSecs+1:adaptDurSecs),'-b.',1);
xlim([extraStartSecs+1, adaptDurSecs]);
ylim([0 4]);
xlabel('Time (s)');
ylabel('10Hz SNR');
box off

saveas(gcf, sprintf('%s/adapt_timecourse.png',plotsDir));

%% 7. adapt regression
% calculate the regression across the adapt period for each ppt and plot as
% a boxplot. This is a different way of visualising the same data above.

load(sprintf('%s/adapt_snrPerBin',resultsDir));

adapt_perBin_Lum = squeeze(mean(adapt_snrPerBin(1:2,signalFreq,extraStartSecs+1:adaptDurSecs,:),1));
adapt_perBin_S = squeeze(mean(adapt_snrPerBin(3:4,signalFreq,extraStartSecs+1:adaptDurSecs,:),1));

lumRegAllPpts = [];
sRegAllPpts = [];

for thisPpt = 1:(length(dirPath)-2)
    thisPptDataLum = squeeze(adapt_perBin_Lum(:,thisPpt));
    thisPptDataS = squeeze(adapt_perBin_S(:,thisPpt));
    
    thisPptRegLum = fitlm(1:adaptDurSecs-extraStartSecs, thisPptDataLum);
    thisPptRegS = fitlm(1:adaptDurSecs-extraStartSecs, thisPptDataS);
    
    lumSlope = thisPptRegLum.Coefficients{2,:};
    lumRegAllPpts = cat(1, lumRegAllPpts, lumSlope);
    
    sSlope = thisPptRegS.Coefficients{2,:};
    sRegAllPpts = cat(1, sRegAllPpts, sSlope);
end

adapt_regression = cat(2,lumRegAllPpts(:,1), sRegAllPpts(:,1));
adaptHeadings = {'Luminance','S'};

regression_cell = num2cell(adapt_regression);
regression_wide = cat(1, adaptHeadings, regression_cell);
writecell(regression_wide, sprintf('%s/EEGreg.csv',resultsDir));

figure(4);
boxplot(adapt_regression, 'Notch','on', 'Colors', 'k','Labels', {'Lum','S-cone'});
title('REGRESSION');
yline(0,':');

saveas(gcf, sprintf('%s/adapt_regression.png',plotsDir));

