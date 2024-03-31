#!/bin/bash

#$ -q all.q
#$ -V
#$ -cwd
#$ -t 1
#$ -pe smp 1

module load miniconda3
module load salmon/1.8.0
module load Trinity/2.8.5
conda activate YAATAP

# run complete YAATAP
snakemake -p -k --resources load=10 -s Snakefile.v2 --rerun-triggers mtime --cluster "qsub -q all.q -V -l h={params.server} -cwd -pe smp {threads}" --jobs 10 --jobname "{rulename}.{jobid}"

# generate DAG
#snakemake --dag | dot -Tsvg > dag.svg
