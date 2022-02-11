echo 'Installing R packages:'
Rscript install.R

echo 'Installing Python packages:'
conda env create -f environment.yml

conda activate metaboflow
