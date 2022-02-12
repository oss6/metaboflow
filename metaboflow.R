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

args = parser$parse_args()

workflow_config = fromJSON(file = 'examples/workflow-configuration3.json')
workflow_config = fromJSON(file = args$workflow_config)

if (!is.null(args$conda_env)) {
  Sys.setenv(RETICULATE_PYTHON = args$conda_env)
}

# ---------------------------------------------
# Pre-processing
# ---------------------------------------------

if (is.null(workflow_config[['skip_processing']])) {
  workflow_config$skip_processing = FALSE
}

if (!workflow_config$skip_processing) {
  cat('Data processing\n')
  cat('---------------\n\n')
  
  source_python('metaboflow_process.py')
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
cat('done\n')

# ---------------------------------------------
# Workflow summary
# ---------------------------------------------

