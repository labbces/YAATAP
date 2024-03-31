# YAATAP
yetAnotherAutoTranscriptAssemblyPipeline

### Installing and running

```bash
# install mamba
conda install -n base -c conda-forge mamba

# install snakemake (v7.25.0)
mamba create -c conda-forge -c bioconda -n YAATAP snakemake=7.25.0

# dry-run YAATAP
conda activate YAATAP
snakemake -np
```

### Requirements

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

### References

Köster, J., Rahmann, S. (2012) Snakemake - a scalable bioinformatics workflow engine, Bioinformatics, Volume 28, Issue 19, 1 October 2012, Pag 2520–2522 - https://doi.org/10.1093/bioinformatics/bts480
