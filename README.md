# YAATAP
yetAnotherAutoTranscriptAssemblyPipeline

## Requirements

* snakemake v7.25.0
* sratoolkit v3.0.10
* ffq v0.3.0
* jq-linux64 jq-1.6
* FastQC v0.11.8
* BBDuk v35.85
* Kraken2 v2.0.7-beta
* ContFree-NGS.py v1.0
* Trinity v2.8.5
* CD-HIT-EST v4.8.1
* BUSCO v3
* transrate v1.0.3
* Salmon v1.3.0
* Python 3.x

## Installing and running

```bash
# add bioconda and conda-forge channels before creating the environment
conda config --add channels bioconda
conda config --add channels conda-forge

# create YAATAP environment
conda env create -n YAATAP -f environment.txt

# dry-run YAATAP
conda activate YAATAP
snakemake -np

# running in the cluster
qsub Snakefile.sh
```

## Input

To run YAATAP, it is necessary to configure the following input files:

- **[config.yaml](https://github.com/labbces/YAATAP/blob/main/config.yaml)**: Snakemake configuration file, containing paths to executable software.
- **[genotype_samples.csv](https://github.com/labbces/YAATAP/blob/main/SP80-3280_samples.csv)**: CSV file with accessions (SRA) of the raw data to be downloaded (e.g. SRR1974519,SRR1979656,SRR1979657,...).
>Note: The filename for this file should include the name of the genotype to be assembled. For example, for the genotype SP80-3280, the file should be named "SP80-3280_samples.csv".
- **[parts.csv](https://github.com/labbces/YAATAP/blob/main/parts.csv)**: CSV file indicating how many parts the Kraken file should be divided into (to divide it into 6 parts, this file should contain the following content: 00, 01, 02, 03, 04).

## Workflow

![](https://github.com/labbces/YAATAP/blob/main/images/complete_DAG.svg)

## Common issues

<details>
  <summary>There is not enough space on the disk</summary>
  
  The SRA Toolkit by default stores the download cache of accessions in your home directory. If you are downloading new datasets on an HPC, one solution to this error is to properly configure the location for SRA cache storage.
  >Follow this simple tutorial to set up your cache directory: https://github.com/ncbi/sra-tools/wiki/03.-Quick-Toolkit-Configuration






</details>

<details>
  <summary>No module named 'busco'</summary>
  
  Snakemake might encounter issues when executing BUSCO, leading to the following error
  
  ```
  No module named 'busco'
  There was a problem installing BUSCO or importing one of its dependencies. See the user guide and the GitLab issue board (https://gitlab.com/ezlab/busco/issues) if you need further assistance.
  ```
  
  To fix it, simply update the shebang in BUSCO to specify your python environment (the path to python in Conda):

  ```bash
  conda activate YAATAP

  # copy the path to python
  which python
  /home/your_username/.conda/envs/YAATAP/bin/python

  # open the executable script of busco  
  which busco
  ~/.conda/envs/YAATAP/bin/busco

  # update the shebang
  vi ~/.conda/envs/YAATAP/bin/busco

  # before
  #!/usr/bin/env python3

  # after
  #!/home/your_username/.conda/envs/YAATAP/bin/python
  ```
</details>

## References

Köster, J., Rahmann, S. (2012) Snakemake - a scalable bioinformatics workflow engine, Bioinformatics, Volume 28, Issue 19, 1 October 2012, Pag 2520–2522 - https://doi.org/10.1093/bioinformatics/bts480
