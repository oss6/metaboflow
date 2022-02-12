library(methods)

WorkflowData = function (workflow_config) {
  instance = .WorkflowData(workflow_config = workflow_config)

  # Read the peak intensity matrix
  instance$pim = read.csv(file = paste(workflow_config$output_directory, 'peak-intensity-matrix.tsv', sep = '/'), check.names = FALSE, sep = '\t')
  instance$pim = instance$pim[-1]
  instance$pim[instance$pim == 0.0] = NA

  # Read the samples metadata
  # 'meta_blank-filtered.tsv'
  instance$pim_sample_meta = read.csv(file = paste(workflow_config$output_directory, 'peak-intensity-matrix_meta.tsv', sep = '/'), check.names = FALSE, sep = '\t')
  instance$pim_sample_meta = instance$pim_sample_meta[-c(1, 2, 3, 4)]

  # Create a dummy variable metadata
  instance$pim_variable_meta = data.frame(matrix(1, ncol = 1, nrow = ncol(instance$pim)))
  rownames(instance$pim_variable_meta) = colnames(instance$pim)
  colnames(instance$pim_variable_meta) = c('dummy')
  
  instance$pim_data = DatasetExperiment(instance$pim, instance$pim_sample_meta, instance$pim_variable_meta)
  
  return(instance)
}

.WorkflowData = setRefClass(
  'WorkflowData',
  fields = list(
    workflow_config = 'list',
    pim = 'ANY',
    pim_sample_meta = 'ANY',
    pim_variable_meta = 'ANY',
    pim_data = 'DatasetExperiment',
    pim_transformed = 'DatasetExperiment',
    pim_transformed_two_labels = 'DatasetExperiment'
  )
)
