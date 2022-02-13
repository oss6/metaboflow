#!/usr/bin/env Rscript

cat('---------------------------------\n')
cat('------- metaboflow v0.1.0 -------\n')
cat('---------------------------------\n\n')

suppressWarnings(suppressMessages({
  library(ggplot2)
  library(ggrepel)
  library(pls)
  library(structToolbox)
  library(pmp)
  library(reticulate)
  library(argparse)
  library(rjson)
  library(cowplot)
}))

source('modules/plotter.R')
source('modules/rsd.R')
source('modules/workflow_data.R')
source('modules/data_transformer.R')
source('modules/statistics.R')

parser = ArgumentParser()
parser$add_argument(
  '-e',
  '--conda-env',
  default = NULL,
  help = "Which conda environment to use [default \"%(default)s\"]"
)
parser$add_argument(
  '-c',
  '--workflow-config',
  default = NULL,
  help = "Path to the workflow configuration file [default \"%(default)s\"]"
)
parser$add_argument(
  '-s',
  '--skip-processing',
  action = 'store_true',
  default = FALSE,
  help = "Whether to skip processing [default]"
)

args = parser$parse_args()

workflow_config = fromJSON(file = args$workflow_config)

# TODO: add validation

if (!is.null(args$conda_env)) {
  Sys.setenv(RETICULATE_PYTHON = args$conda_env)
}

# ---------------------------------------------
# Pre-processing
# ---------------------------------------------

if (is.null(workflow_config[['skip_processing']])) {
  workflow_config$skip_processing = FALSE
}

if (!args$skip_processing & !workflow_config$skip_processing) {
  cat('Data processing\n')
  cat('---------------\n\n')

  source_python('modules/processing/process.py')
  process_samples(args$workflow_config)
}

# Prepare PDF plotting
plotter = Plotter()

# Process RSD QC data
cat('\nProcess RSD QC data\n')
cat('-------------------\n\n')

cat('reading RSD file and plot histogram...\n')
rsd = RSD(workflow_config, plotter)
rsd$plot_hist()
rsd_summary = rsd$summary()
cat(paste('RSD QC:', rsd_summary, '\n'))
cat('done\n')

# Load workflow data
cat('reading workflow input data...\n')
workflow_data = WorkflowData(workflow_config)
cat('done\n')

# -------------------------------------------------
# Normalisation, imputation, transform, and scaling
# -------------------------------------------------

cat('\nNormalisation, missing values imputation, transform, and scaling\n')
cat('----------------------------------------------------------------\n\n')

data_transformer = DataTransformer(workflow_config)

cat('set missing values imputation\n')
data_transformer$impute_missing_values()

cat('set normalisation\n')
data_transformer$normalise()

cat('set transformation\n')
data_transformer$transform()

cat('set scaling\n')
data_transformer$scale()

cat('applying normalisation, missing value imputation, transform, and scaling...\n')
data_transformer$apply_to_data(workflow_data)
cat('done\n')

workflow_data$pim_transformed = predicted(data_transformer$model)
workflow_data$pim_transformed_two_labels = data_transformer$remove_qc_samples()

write.table(
  workflow_data$pim_transformed$data,
  paste(workflow_config$output_directory, 'peak-intensity-matrix_transformed.tsv', sep = '/'),
  sep = '\t',
  col.names = NA
)

# ---------------------------------------------
# Statistical analysis
# ---------------------------------------------

cat('\nStatistical analysis\n')
cat('--------------------\n\n')

mb_stats = Statistics(workflow_config, workflow_data, plotter)

cat('running PCA...\n')
mb_stats$run_pca(plot = TRUE)
cat('done\n')

cat('running t-tests...\n')
ttest_result = mb_stats$run_ttest(save_output = TRUE)
cat('done\n')

cat('running fold change...\n')
fold_change_result = mb_stats$run_fold_change(save_output = TRUE)
cat('done\n')

cat('running volcano plot routine...\n')
mb_stats$volcano_plot(fold_change_result, ttest_result$output_not_ordered)
cat('done\n')

cat('running PLS-DA...\n')
mb_stats$run_plsda(plot = TRUE)
cat('done\n')

cat('running PLSR...\n')
mb_stats$run_plsr(plot = TRUE)
cat('done\n')

cat('saving plots...\n')
pdf(file = paste(workflow_config$output_directory, 'plots.pdf', sep = '/'))
suppressWarnings(invisible(lapply(plotter$plots, print)))
cat('done\n\n')

# ---------------------------------------------
# Workflow summary
# ---------------------------------------------

workflow_summary = as.data.frame(matrix(c(
  c('peak-intensity-matrix.tsv', 'Non-normalised peak intensity matrix'),
  c('peak-intensity-matrix_comprehensive.tsv', 'Comprehensive version of the non-normalised peak intensity matrix'),
  c('peak-intensity-matrix_meta.tsv', 'Non-normalised peak intensity matrix sample metadata'),
  c('peak-intensity-matrix_transformed.tsv', 'Transformed peak intensity matrix (normalised, missing values imputation, scaling, transform)'),
  c('rsd.tsv', 'List of RSD values for each peak'),
  c('fold-change.tsv', 'Fold change values'),
  c('ttest.tsv', 't-test summary for each peak'),
  c('plots.pdf', 'All generated plots'),
  c('workflow-configuration.json', 'The workflow configuration that generated the results'),
  c('RSD', rsd$summary())
), nrow = 10, ncol = 2, byrow = TRUE))

colnames(workflow_summary) = c('Resource name/Statistic', 'Description')

write.table(
  workflow_summary,
  file = paste(workflow_config$output_directory, 'SUMMARY.tsv', sep = '/'),
  sep = '\t',
  row.names = FALSE
)

cat('Workflow summary saved in SUMMARY.tsv\n')
