suppressWarnings(suppressMessages({
  library(methods)
  library(ggplot2)
}))


RSD = function (workflow_config, plotter) {
  instance = .RSD(workflow_config = workflow_config, plotter = plotter)

  instance$rsd_qc = read.csv(paste(workflow_config$output_directory, 'rsd.tsv', sep = '/'), sep = '\t')
  colnames(instance$rsd_qc) = c('rsd')
  
  return(instance)
}

.RSD = setRefClass(
  'RSD',
  fields = list(
    workflow_config = 'list',
    plotter = 'Plotter',
    rsd_qc = 'ANY'
  ),
  methods = list(
    plot_hist = function () {
      plotter$add_plot(
        ggplot(rsd_qc, aes(x = rsd)) +
        geom_histogram(binwidth = 5) +
        geom_vline(xintercept = 20) +
        labs(title = 'RSD plot', x = 'RSD QC', y = 'Frequency')
      )
    }
  )
)
