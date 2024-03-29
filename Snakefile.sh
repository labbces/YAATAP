#!/bin/bash

#$ -q all.q
#$ -V
#$ -cwd
#$ -t 1
#$ -pe smp 1

module load miniconda3
module load salmon/1.8.0
#conda activate YAATAP

conda activate /home/felipe.peres/.conda/envs/snakemake-tutorial/envs/snakemake_conekt

snakemake -p -k --resources load=6 -s Snakefile.v1 --rerun-incomplete --cluster "qsub -q all.q -V -l h={params.server} -cwd -pe smp {threads}" --jobs 6 --jobname "{rulename}.{jobid}"

#snakemake --dag MyAssembly_QS99-2014/7_trinity_assembly/MyAssembly_QS99-2014_trinity_k25.Trinity.fasta | dot -Tsvg > dag.svg
#snakemake -np --cluster "qsub -q all.q -V -cwd -l h={params.server} -pe smp {threads} -l mem_free={resources.mem_free}G" --jobs 10
