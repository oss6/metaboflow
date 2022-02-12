if (!requireNamespace('BiocManager', quietly = TRUE)) {
  install.packages('BiocManager')
}

BiocManager::install('structToolbox')
BiocManager::install(c('pmp', 'ropls'))

install.packages(c(
  'ggplot2',
  'ggrepel',
  'reticulate',
  'argparse',
  'rjson',
  'cowplot'
), repos = 'http://cran.us.r-project.org')
