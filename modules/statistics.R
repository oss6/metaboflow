suppressWarnings(suppressMessages({
  library(methods)
  library(structToolbox)
  library(ggplot2)
  library(ggrepel)
}))

Statistics = function (workflow_config, workflow_data, plotter) {
  instance = .Statistics(
    workflow_config = workflow_config,
    workflow_data = workflow_data,
    plotter = plotter
  )
  return(instance)
}

.Statistics = setRefClass(
  'Statistics',
  fields = list(
    workflow_config = 'list',
    workflow_data = 'WorkflowData',
    plotter = 'Plotter',
    
    pca_model = 'ANY',
    plsda_model = 'ANY',
    plsr_model = 'ANY',
    ttest_model = 'ANY',
    fold_change_model = 'ANY'
  ),
  methods = list(
    run_pca = function (plot = FALSE) {
      pca_model <<- model_apply(PCA(), workflow_data$pim_transformed)
      
      if (plot) {
        plotter$add_plot(chart_plot(pca_scores_plot(factor_name = workflow_config$factor_name), pca_model))
      }
    },
    
    run_ttest = function (save_output = FALSE) {
      ttest_model <<- model_apply(
        ttest(alpha = workflow_config$t_test$alpha, mtc = 'fdr', factor_names = workflow_config$factor_name),
        workflow_data$pim_transformed_two_labels)
      
      ttest_output_not_ordered = as_data_frame(ttest_model)
      ttest_output = ttest_output_not_ordered[order(ttest_output_not_ordered$t_p_value),]
      
      if (save_output) {
        write.table(ttest_output, paste(workflow_config$output_directory, 'ttest.tsv', sep = '/'), sep = '\t', col.names = NA)
      }
      
      return(list(
        output_not_ordered = ttest_output_not_ordered,
        output = ttest_output)
      )
    },
    
    run_fold_change = function (save_output = FALSE) {
      fcm = filter_smeta(
        mode = 'exclude',
        factor_name = workflow_config$factor_name, levels = c(workflow_config$qc_label)) +
        fold_change(factor_name = workflow_config$factor_name)
      fold_change_model <<- model_apply(fcm, workflow_data$pim_data)
      
      log2_fold_change = log2(fold_change_model[2]$fold_change)
      
      if (save_output) {
        write.table(log2_fold_change, paste(workflow_config$output_directory, 'fold-change.tsv', sep = '/'), sep = '\t', col.names = NA)
      }
      
      return(log2_fold_change)
    },
    
    volcano_plot = function (log2_fold_change, ttest_result) {
      volcano_plot_df = data.frame(colnames(workflow_data$pim), log2_fold_change, ttest_result$t_p_value)
      colnames(volcano_plot_df) = c('mz', 'log2FoldChange', 'pvalue')
      rownames(volcano_plot_df) = NULL
      
      volcano_plot_df$dir <- 'NO'
      # if log2Foldchange > 0.6 and pvalue < 0.05, set as "UP"
      volcano_plot_df$dir[volcano_plot_df$log2FoldChange > 0.6 & volcano_plot_df$pvalue < 0.05] <- 'UP'
      # if log2Foldchange < -0.6 and pvalue < 0.05, set as "DOWN"
      volcano_plot_df$dir[volcano_plot_df$log2FoldChange < -0.6 & volcano_plot_df$pvalue < 0.05] <- 'DOWN'
      
      volcano_plot_df$label <- NA
      volcano_plot_df$label[volcano_plot_df$dir != 'NO'] <- volcano_plot_df$mz[volcano_plot_df$dir != 'NO']
      
      plotter$add_plot(
        ggplot(
          data = volcano_plot_df,
          aes(x = log2FoldChange, y = -log10(pvalue), col = dir, label = label)
        ) +
        geom_point() +
        theme_minimal() +
        geom_text_repel() +
        scale_color_manual(values = c('blue', 'black', 'red')) +
        geom_vline(xintercept = c(-0.6, 0.6), col = "red") +
        geom_hline(yintercept = -log10(0.05), col = "red")
      )
    },
    
    run_plsda = function (plot = FALSE) {
      fname = workflow_config$factor_name
      workflow_data$pim_transformed_two_labels$sample_meta[[fname]] <<- factor(workflow_data$pim_transformed_two_labels$sample_meta[[fname]])
      
      m = PLSDA(factor_name = workflow_config$factor_name)
      plsda_model <<- model_apply(m, workflow_data$pim_transformed_two_labels)
      
      if (plot) {
        plotter$add_plot(chart_plot(plsda_scores_plot(factor_name = workflow_config$factor_name), plsda_model))
        plotter$add_plot(chart_plot(plsda_vip_summary_plot(), plsda_model))
      }
    },
    
    run_plsr = function (plot = FALSE) {
      # convert the labels to numeric factors
      workflow_data$pim_transformed_two_labels$sample_meta$classLabel <<- as.numeric(workflow_data$pim_transformed_two_labels$sample_meta$classLabel)
      m = PLSR(factor_name = workflow_config$factor_name, number_components = 3)
      plsr_model <<- model_apply(m, workflow_data$pim_transformed_two_labels)
      
      # diagnostic charts
      g1 = chart_plot(plsr_cook_dist(), plsr_model)
      g2 = chart_plot(plsr_prediction_plot(), plsr_model)
      g3 = chart_plot(plsr_qq_plot(), plsr_model)
      g4 = chart_plot(plsr_residual_hist(), plsr_model)
      
      if (plot) {
        plotter$add_plot(plot_grid(plotlist = list(g1, g2, g3, g4), nrow = 2, align = 'vh'))
      }
    }
  )
)