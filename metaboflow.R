#!/usr/bin/env Rscript

# BiocManager::install(c('pmp', 'ropls'))

suppressWarnings(suppressMessages(library(ggplot2)))
suppressWarnings(suppressMessages(library(ggrepel)))
suppressWarnings(suppressMessages(library(pls)))
suppressWarnings(suppressMessages(library(structToolbox)))
suppressWarnings(suppressMessages(library(pmp)))
suppressWarnings(suppressMessages(library(reticulate)))
suppressWarnings(suppressMessages(library(argparse)))
suppressWarnings(suppressMessages(library(rjson)))

parser = ArgumentParser()

parser$add_argument("-e", "--conda-env", default=NULL,
                    help = "Which conda environment to use [default \"%(default)s\"]")
parser$add_argument("-c", "--workflow-config", default=NULL,
                    help = "Path to the workflow configuration file [default \"%(default)s\"]")

args = parser$parse_args()

workflow_config = fromJSON(file = 'examples/workflow-configuration.json')

if (!is.null(args$conda_env)) {
  Sys.setenv(RETICULATE_PYTHON = args$conda_env)
}

# ---------------------------------------------
# Pre-processing
# ---------------------------------------------

#Sys.setenv(RETICULATE_PYTHON = "/Users/ossama-edbali/opt/miniconda3/envs/metaboflow/bin/python")
# use_condaenv('metaboflow', required = TRUE)
source_python('processing.py')
process_samples(args$workflow_config)

pim = read.csv(file = 'out/peak-intensity-matrix.tsv', check.names = FALSE, sep = '\t')
pim = pim[-1]
pim[pim == 0.0] <- NA

pim_sample_meta = read.csv(file = 'out/meta_blank-filtered.tsv', check.names = FALSE, sep = '\t')
pim_sample_meta = pim_sample_meta[-c(1, 2, 3, 4)]

pim_variable_meta <- data.frame(matrix(1, ncol = 1, nrow = ncol(pim)))
rownames(pim_variable_meta) = colnames(pim)
colnames(pim_variable_meta) = c('dummy')

pim_data = DatasetExperiment(pim, pim_sample_meta, pim_variable_meta)

# ---------------------------------------------
# Normalisation, imputation, and glog transform
# ---------------------------------------------

transformation_model = knn_impute(
    neighbours = workflow_config$imputation$neighbours,
    feature_max = workflow_config$imputation$feature_max,
    sample_max = workflow_config$imputation$sample_max)

if (workflow_config$normalisation$type == 'pqn') {
  transformation_model = transformation_model +
    pqn_norm(qc_label = workflow_config$normalisation$qc_label, factor_name = workflow_config$normalisation$factor_name)
} else if (workflow_config$normalisation$type == 'constant_sum') {
  transformation_model = transformation_model + constant_sum_norm(scaling_factor = workflow_config$normalisation$scaling_factor)
} else if (workflow_config$normalisation$type == 'vector') {
  transformation_model = transformation_model + vec_norm()
} else {
  # throw error
}

if (workflow_config$transform$type == 'glog') {
  transformation_model = transformation_model + glog_transform(
    qc_label = workflow_config$transform$qc_label,
    factor_name = workflow_config$transform$factor_name)
} else if (workflow_config$transform$type == 'log') {
  transformation_model = transformation_model + log_transform(base = workflow_config$transform$base)
} else if (workflow_config$transform$type == 'nroot') {
  transformation_model = transformation_model + nroot_transform(root = workflow_config$transform$root)
} else {
  # throw error
}

transformation_model = transformation_model + mean_centre()

transformation_model = model_apply(transformation_model, pim_data)

# ---------------------------------------------
# PCA
# ---------------------------------------------

pca_model = model_apply(PCA(), predicted(transformation_model))

chart_plot(pca_scores_plot(factor_name='classLabel'), pca_model)

