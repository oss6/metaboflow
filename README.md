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

TODO.

## TODO

- Merge workflow configuration with defaults
- Add ability to compare models
- Add input summary to output (to know how data was generated)
- Add summary file and terminal
