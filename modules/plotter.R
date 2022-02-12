suppressWarnings(suppressMessages({
  library(methods)
  library(ggplot2)
  library(ggrepel)
}))

Plotter = function () {
  instance = .Plotter()
  
  instance$plots = list()
  instance$index = 1
  
  return(instance)
}

.Plotter = setRefClass(
  'Plotter',
  fields = list(
    plots = 'list',
    index = 'numeric'
  ),
  methods = list(
    add_plot = function (pl) {
      plots[[index]] <<- pl
      index <<- index + 1
    }
  )
)