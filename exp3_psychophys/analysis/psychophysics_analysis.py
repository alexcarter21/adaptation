# This code runs analysis on psychophysical adaptation data similar to that by Webster and Mollon.
# 1. Loops through all ppts and cleans the data to create a data frame of conditions and final match contrast
# 2. Plot data as box plot
# 3. Repeated measures ANOVA
# 4. Helmert planned contrasts - for each test condition we compare the same adapt condition to the other adapt conditions.
# 5. t-tests - for each condition compared to 0

#%% set up

# modules
import pandas as pd
import numpy as np
import os
import ast
import seaborn as sns
import matplotlib.pyplot as plt
import glob
import pingouin as pg

# settings
data_dir = os.path.expanduser('~/Documents/adaptation/exp3_psychophys/data')

all_ppt_df = []

# Get all matching files in data_dir
data_files = glob.glob(os.path.join(data_dir, "*_testAdapt3_*.csv"))
print(len(data_files))

#%% 1. Clean and organise data

for data_file in data_files:
    print(f"Loading file: {data_file}")
    df = pd.read_csv(data_file)

    # Select specific columns to create a new DataFrame
    new_df = df[['participant',
                'Adapt_Lcomp','Adapt_Mcomp','Adapt_Scomp',
                'Lcomp','Mcomp','Scomp',
                'finalMatchCont']]

    # Define the conditions - the results files has 3 components for L,M and S cones 
    # but we want one column corresponding to the condition overall
    adapt_conditions = [
        (df['Adapt_Lcomp'] == 1) & (df['Adapt_Mcomp'] == 1) & (df['Adapt_Scomp'] == 1),
        (df['Adapt_Lcomp'] == 1) & (df['Adapt_Mcomp'] == -1) & (df['Adapt_Scomp'] == 0),
        (df['Adapt_Lcomp'] == 0) & (df['Adapt_Mcomp'] == 0) & (df['Adapt_Scomp'] == 1)
    ]

    test_conditions = [
        (df['Lcomp'] == 1) & (df['Mcomp'] == 1) & (df['Scomp'] == 1),
        (df['Lcomp'] == 1) & (df['Mcomp'] == -1) & (df['Scomp'] == 0),
        (df['Lcomp'] == 0) & (df['Mcomp'] == 0) & (df['Scomp'] == 1)
    ]

    values = ['luminance', 'L-M', 's_cone'] 

    # Create the new columns
    new_df['adapt'] = np.select(adapt_conditions, values)
    new_df['test'] = np.select(test_conditions, values)

    # Filter out rows with NaNs - the results file has this in between blocks and we are not removing 
    # and data. We can also remove the original L,M and S cone component columns.
    df_filtered = new_df.dropna(subset=['finalMatchCont'])
    clean_df = df_filtered.drop(columns=['Adapt_Lcomp','Adapt_Mcomp','Adapt_Scomp','Lcomp','Mcomp','Scomp'])

    # Convert strings to floats for the final contrast match
    clean_df['finalMatchCont'] = clean_df['finalMatchCont'].apply(lambda x: float(ast.literal_eval(x)[0]))

    all_ppt_df.append(clean_df)

# all_ppt_df is a list of data frames. Combine all DataFrames into one
combined_df = pd.concat(all_ppt_df, ignore_index=True)

# Group by participant and combined adapt/test condition
grouped_df = combined_df.groupby(['participant', 'adapt', 'test'])['finalMatchCont'].mean().reset_index()

# We want final match as a proportion of the target (0.4)
grouped_df["finalMatchCont"] = grouped_df["finalMatchCont"] / 0.4

#print(grouped_df)

#%% 2. Plotting

# Set desired order and color palette
test_order = ['luminance', 'L-M', 's_cone']
color_palette = {
    'luminance': (0.5, 0.5, 0.5),  
    'L-M': (1, 0, 0),             
    's_cone': (0, 0, 1)      
}
color_palette_dark = {
    'luminance': (0.2, 0.2, 0.2),  
    'L-M': (0.6, 0, 0),             
    's_cone': (0, 0, 0.6)      
}

# Create the plot
plt.figure(figsize=(10, 6))
sns.boxplot(
    data=grouped_df,
    x='test',
    y='finalMatchCont',
    hue='adapt',
    order=test_order,
    hue_order=test_order,
    palette=color_palette,
    notch = True
)

# Overlay individual data points
'''
sns.stripplot(
    data=grouped_df,
    x='test',
    y='finalMatchCont',
    hue='adapt',
    order=test_order,
    hue_order=test_order,
    palette=color_palette_dark,
    dodge=True,
    jitter=False,
    linewidth=0.5,
)
'''

plt.axhline(y=1, color='black', linestyle='--', linewidth=1)

plt.ylabel('Final Match Contrast (Proportion)')
plt.xlabel('Test Condition')
plt.xticks([0,1,2],labels=['Luminance','L-M','S'])
plt.legend(title='Adapt Condition')
plt.legend().set_visible(False)
sns.despine()
plt.tight_layout()
plt.show()

#%% 3. Repeated measures ANOVA

aov = pg.rm_anova(
    dv='finalMatchCont',      # dependent variable
    within=['adapt', 'test'], # within-subject factors
    subject='participant',    # subject ID
    data=grouped_df,
    detailed=True
)

print('ANOVA')
print(aov)

#%% 4. Helmert

helmert = []

# Loop through each test condition
for test_level in grouped_df['test'].unique():
    sub_df = grouped_df[grouped_df['test'] == test_level]
    
    # Pivot so we have adapt levels as columns
    pivot = sub_df.pivot(index='participant', columns='adapt', values='finalMatchCont')
    
    # Same adapt vs average of the others
    for adapt_level in pivot.columns:
        others = [c for c in pivot.columns if c != adapt_level]
        contrast_scores = pivot[adapt_level] - pivot[others].mean(axis=1)
        
        # One-sample t-test against 0 (contrast difference)
        contrast = pg.ttest(contrast_scores, 0)
        contrast['test'] = test_level
        contrast['adapt'] = adapt_level
        helmert.append(contrast)

# Similar to above, helmert is a list of dfs, and we want one df
contrasts_df = pd.concat(helmert, ignore_index=True)

# Adjust for multiple contrasts
contrasts_df['p-corr'] = pg.multicomp(contrasts_df['p-val'].values, method='fdr_bh')[1]

print('Helmert')
print(contrasts_df)

#%% 5. t-tests

grouped_df["condition"] = grouped_df["adapt"] + "_" + grouped_df["test"]

ttests = []

for cond, sub_df in grouped_df.groupby("condition"):
    ttest = pg.ttest(sub_df["finalMatchCont"], 1,alternative='less') 
    ttest["condition"] = cond
    ttests.append(ttest)

ttests_df = pd.concat(ttests, ignore_index=True)
print('ttests')
print(ttests_df)

# %%
