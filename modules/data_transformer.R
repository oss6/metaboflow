library(methods)
library(structToolbox)

DataTransformer = function (workflow_config) {
  instance = .DataTransformer(workflow_config = workflow_config)
  return(instance)
}

.DataTransformer = setRefClass(
  'DataTransformer',
  fields = list(
    workflow_config = 'list',
    model = 'ANY'
  ),
  methods = list(
    impute_missing_values = function () {
      model <<- knn_impute(
        neighbours = workflow_config$imputation$neighbours,
        feature_max = workflow_config$imputation$feature_max,
        sample_max = workflow_config$imputation$sample_max)
    },
    
    normalise = function () {
      if (workflow_config$normalisation$type == 'pqn') {
        model <<- model +
          pqn_norm(qc_label = workflow_config$normalisation$qc_label, factor_name = workflow_config$normalisation$factor_name)
      } else if (workflow_config$normalisation$type == 'sum') {
        model <<- model + constant_sum_norm(scaling_factor = workflow_config$normalisation$scaling_factor)
      } else if (workflow_config$normalisation$type == 'vector') {
        model <<- model + vec_norm()
      } else {
        print('Error!')
        stop()
      }
    },
    
    transform = function() {
      if (workflow_config$transform$type == 'glog') {
        model <<- model + glog_transform(
          qc_label = workflow_config$transform$qc_label,
          factor_name = workflow_config$transform$factor_name)
      } else if (workflow_config$transform$type == 'log') {
        model <<- model + log_transform(base = workflow_config$transform$base)
      } else if (workflow_config$transform$type == 'nroot') {
        model <<- model + nroot_transform(root = workflow_config$transform$root)
      } else {
        print('Error!')
        stop()
      }
    },
    
    scale = function () {
      if (workflow_config$scaling$type == 'mean') {
        model <<- model + mean_centre()
      } else if (workflow_config$scaling$type == 'auto') {
        model <<- model + autoscale()
      } else if (workflow_config$scaling$type == 'pareto') {
        model <<- model + pareto_scale()
      } else {
        print('Error!')
        stop()
      }
    },
    
    apply_to_data = function (workflow_data) {
      model <<- model_apply(model, workflow_data$pim_data)
    },
    
    remove_qc_samples = function () {
      remqc_model = filter_smeta(mode = 'include', factor_name = workflow_config$factor_name, levels = c('cow', 'sheep'))
      remqc_model = model_apply(remqc_model, workflow_data$pim_transformed)
      
      return(predicted(remqc_model))
    }
  )
)
