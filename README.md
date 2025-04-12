# Yet Another Auto Transcript Assembly Pipeline
[![Snakemake](https://img.shields.io/badge/workflow-snakemake-blue)](https://snakemake.readthedocs.io/) [![Status](https://img.shields.io/badge/status-active-success.svg)]() [![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)  

YAATAP is a fully automated pipeline for _de novo_ transcriptome assembly, implemented using Snakemake. It performs every step from raw RNA-seq data download to the final transcriptome assembly and quality assessment.

--- 

# requirements

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
* Salmon v1.8.0
* Python 3.x

---

# installing and configuring environments

```bash
# clone this repository
git clone https://github.com/labbces/YAATAP.git
cd YAATAP

# add bioconda and conda-forge channels before creating the environment
conda config --add channels bioconda
conda config --add channels conda-forge

# create YAATAP environment
conda env create -n YAATAP -f environment.txt
```

---

# configuring pipeline

To run YAATAP, the following files must be configured:

- **[config.yaml](https://github.com/labbces/YAATAP/blob/main/config.yaml)**: contains paths to external tools.  
- **[genotype_samples.csv](https://github.com/labbces/YAATAP/blob/main/SP80-3280_samples.csv)**: CSV file listing SRA accessions to be downloaded (e.g. `SRR1974519`,`SRR1979656`,`SRR1979657`,...).  
>[!IMPORTANT]
>The filename must include the genotype name, e.g., `SP80-3280_samples.csv`.  
- **[parts.csv](https://github.com/labbces/YAATAP/blob/main/parts.csv)**: defines the number of parts for Kraken2 database splitting (e.g., `00`,`01`,`02`,`03`,`04`).

---

# usage

```bash
# activate the environment
conda activate YAATAP

# dry-run (test)
snakemake -np

# run on HPC (example with SGE)
qsub Snakefile.sh
```

---

# common issues

<details>
  <summary>There is not enough space on the disk</summary>
  
  By default, SRA Toolkit caches downloaded reads in your home directory. On HPC systems, configure a custom cache location: [Quick Toolkit Configuration](https://github.com/ncbi/sra-tools/wiki/03.-Quick-Toolkit-Configuration)
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

---

# contact

For questions, feel free to open an [issue](https://github.com/labbces/YAATAP/issues).

---

# license

```
MIT License

Copyright (c) 2025 Felipe Vaz Peres

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
