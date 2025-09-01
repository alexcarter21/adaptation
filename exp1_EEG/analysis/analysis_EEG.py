#%% set up
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from scipy import stats
import seaborn as sns
import pingouin as pg
from statannotations.Annotator import Annotator  # Ensure you have the correct import path
import os

base_dir = os.path.expanduser('~/Documents/adaptation/exp1_EEG')
results_dir = 'results' # directory of all participants' data
plots_dir = 'plots'

# set aesthetics for plots
sns.set(style="ticks")
custom_palette = [(.4,.4,.4),(.9,.3,.3),(.3,.3,.9)] # these correspond to luminance, L-M and S

#%% adapt regression

# Import the wanted csv file
wide_data = pd.read_csv(os.path.join(base_dir,results_dir,'EEGreg.csv'))

# Melt the DataFrame to long format
wide_data['Subject'] = range(1, len(wide_data) + 1)
long_data = pd.melt(
    wide_data,
    id_vars=['Subject'],  
    var_name='Condition', 
    value_name='Score'  
)

# print(long_data)

print('Regression')

# Run t-tests against 0 to see if any change
print('t-tests')
adapt_conditions = long_data["Condition"].unique()
for cond in adapt_conditions:
    print(cond)
    ttest_results = pg.ttest(x=wide_data[cond], y=0)
    print(ttest_results)

# repeated measures ANOVA 
print('ANOVA')
anova = pg.rm_anova(dv='Score', within='Condition', subject='Subject', data=long_data)
print(anova)

# post-hoc tests on ANOVA to see which comparisons are significant
print('Post-hoc')
post_hoc_results = pg.pairwise_tests(dv='Score', within='Condition', subject='Subject', data=long_data, padjust='fdr_bh')
print(post_hoc_results)

# boxplots
plt.figure(figsize=(6, 6))
plt.axhline(y=0, color='darkgray', linestyle='--', zorder=0)
ax = sns.boxplot(x='Condition', y='Score', data=long_data, notch=True, palette=custom_palette, width=.5)
ax.tick_params(axis='both', labelsize=16)
# ** annotations **
# pairs = list(post_hoc_results[['A', 'B']].itertuples(index=False, name=None))
# annotator = Annotator(ax, pairs=pairs, data=long_data, x='Condition', y='Score')
# annotator.configure(test=None, text_format='star', loc='inside')
# annotator.set_pvalues_and_annotate(post_hoc_results['p-corr'])
# **
ax.margins(x=0.2)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
plt.title('Boxplot of EEG Regression')
plt.xlabel('Adaptation Condition', fontsize = 'x-large')
plt.ylabel('EEG Regression', fontsize = 'x-large')
plt.savefig(os.path.join(base_dir,plots_dir,'EEG_reg.jpg'),dpi=300)
plt.show()

#%% difference (after-before)

# Import the wanted csv file
wide_data = pd.read_csv(os.path.join(base_dir,results_dir,'difference_wide.csv'))

# Melt the DataFrame to long format
wide_data['Subject'] = range(1, len(wide_data) + 1)
long_data = pd.melt(
    wide_data,
    id_vars=['Subject'], 
    var_name='Condition', 
    value_name='Score'  
)

# Split the 'Condition' column into 'Adapt' and 'Probe'
long_data[['Adapt', 'Probe']] = long_data['Condition'].str.split(' / ', expand=True)

print(long_data)

print(f'Difference')

# Run t-tests against 0 to see if any change
print('t-tests')
conditions = long_data["Condition"].unique()
for cond in conditions:
    print(cond)
    ttest_results = pg.ttest(x=wide_data[cond], y=0, alternative='greater')
    print(ttest_results)

# repeated measures ANOVA
print('ANOVA')
anova = pg.rm_anova(dv='Score', within=['Adapt','Probe'], subject='Subject', data=long_data)
print(anova)

# post-hoc tests on ANOVA to see which comparisons are significant
print('Post-hoc')
post_hoc_results = pg.pairwise_tests(dv='Score', within='Condition', subject='Subject', data=long_data, padjust='fdr_bh')
print(post_hoc_results)

# boxplots
# within - this is a useful separate plot for presentations as 9 conditions is a lot in one
subsetWithin = long_data[long_data['Condition'].isin(['Lum / Lum', 'L-M / L-M', 'S / S'])]
plt.figure(figsize=(6, 6))
ax = sns.boxplot(data=subsetWithin, x='Condition', y='Score', palette=custom_palette,notch=True,width=.2)
# ** ANOVA annotations **
# post_hoc_results = pg.pairwise_tests(dv='Score', within='Condition', subject='Subject', data=subsetWithin, padjust='fdr_bh')
# pairs = list(post_hoc_results[['A', 'B']].itertuples(index=False, name=None))
# annotator = Annotator(ax, pairs=pairs, data=subsetWithin, x='Condition', y='Score')
# annotator.configure(test=None, text_format='star', loc='inside')
# annotator.set_pvalues_and_annotate(post_hoc_results['p-corr'])
# **
ax.tick_params(axis='both', labelsize=16)
plt.title(f'Within')
plt.xlabel('Probe', fontsize = 'x-large')
plt.xticks([0,1,2],['Lum','L-M','S'])
plt.ylabel('EEG Difference (Proportion)', fontsize = 'x-large')
plt.ylim([-1,1])
plt.yticks([-1,-.5,0,.5,1])
plt.axhline(y=0, color='darkgray', linestyle='--', zorder=0)
ax.margins(x=0.2)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
plt.savefig(os.path.join(base_dir,plots_dir,'EEG_diff_within.jpg'),dpi=300)
plt.show()

# all 
plt.figure(figsize=(6, 6))
ax = sns.boxplot(data=long_data, x='Probe', y='Score', palette=custom_palette,notch=True,width=.6,hue='Adapt')
ax.tick_params(axis='both', labelsize=16)
plt.title(f'All')
plt.xlabel('Probe', fontsize = 'x-large')
plt.xticks([0,1,2],['Lum','L-M','S'])
plt.ylabel('EEG Difference (Proportion)', fontsize = 'x-large')
plt.ylim([-1,1])
plt.yticks([-1,-.5,0,.5,1])
plt.axhline(y=0, color='darkgray', linestyle='--', zorder=0)
ax.margins(x=0.2)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
plt.savefig(os.path.join(base_dir,plots_dir,'EEG_diff_all.jpg'),dpi=300)
plt.show()
