# metaboflow

> Experimental metabolomics workflow.

`metaboflow` uses the following steps:

1. Pre-processing using `dimspy`.
2. Normalisation, missing value imputation, and transformation using `structToolbox`.
3. Statistical analysis using `structToolbox`.

## Requirements

- Python >= 3.7
- Miniconda >= 4.10.x (not a strict requirement - you can install Python packages globally)
- R >= 4.1.x

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

To reproduce an example, please follow these steps:

1. Download [batch_06.zip](https://metabolomics-training.galaxy.bham.ac.uk/datasets/e0d573412f19989e/display?to_ext=zip) and [filelist_batch_06.txt](https://metabolomics-training.galaxy.bham.ac.uk/datasets/e75dd2bbc510e6b8/display?to_ext=tsv).
2. Put these files in the `examples` directory.
3. If using a workflow configuration that uses Galaxy then [create an API access key](https://galaxyproject.org/develop/api/). Put the access key in the appropriate place in the configuration: `galaxy.api_key`.
4. Run the workflow using the above command.

## Backlog

- Merge workflow configuration with defaults
- Add summary file and terminal

## Future work

Possible future work for `metaboflow`:

- Background processing
