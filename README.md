# adaptation
Code for three adaptation experiments: EEG, pupillometry, behavioural


In exp 1 and 2 participants were shown 5Hz flickering disks for pre-adapt probe (5s), adapt (30s or 21s respectively), post-adapt probe (5s). Adapt and probe stimuli could be luminance, L-M or S stimulating (exp 1) or luminance or S (exp 2). Within a trial the probes were always the same, but could be different to the adapt (9 conditions).

Take time course data (EEG or pupil size) and compute regression values across an adaptation period, and calculates the difference (after-before) for each participant (in MATLAB - processing_EEG.m or processing_pupil.m). All code and functions provided are my own, but EEG code is dependent on functions not included here. Also run statistical tests and plot figures (in Python - analysis_EEG.py or analysis_EEG_pupil.py). Figures are included, but data is not.

In exp 3 participants were shown 5Hz flickering disks on right side of the screen for 60s at the start of each block (adaptation - luminance, L-M or S). Trials were then 4s and were shown a test flicker in same location as adaptation, and had to match another flicker on the left side by adjusting the contrast using up and down arrows (test - luminance, L-M or S). There were 8s adaptation top-up between trials and this was always the same as the start of the block (3 blocks, 9 conditions).

exp 3 was built using PsychoPy (testAdapt3.psyexp), and analysed in python (psychophysics_analysis.py) which runs statistical tests and plots figures. Figures are included, but data is not.
