# metaboflow

> Experimental metabolomics workflow.

`metaboflow` uses the following steps:

1. Pre-processing using `dimspy`.
2. Normalisation, missing value imputation, and transformation using `structToolbox`.
3. Statistical analysis using `structToolbox`.

## Install

1. Clone this repository.
2. Install [Miniconda](https://docs.conda.io/projects/conda/en/latest/user-guide/install).
3. Run `./install.sh`

Note: you can remove the conda environment using - `conda env remove -y --name metaboflow`

## Basic usage

To use the tool you have to provide a configuration file (check the examples and/or the schema JSON):

```
./metaboflow.R -c examples/workflow-configuration1.json
```

## Backlog

- Merge workflow configuration with defaults
- Add summary file and terminal

## Future work

Possible future work for `metaboflow`:

- Background processing
