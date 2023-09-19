#!/usr/bin/env python

#Usage:
#snakemake -p -k --resources load=6 -s Snakefile --rerun-incomplete --cluster "qsub -q all.q -V -cwd -pe smp {threads}" --jobs 6 --jobname "{rulename}.{jobid}"

configfile: "config.yaml"

import pandas as pd
from pandas.errors import EmptyDataError
import yaml
import os

# capturando o nome do arquivo "_samples.csv" na pasta de execucao
sample_file = [file for file in os.listdir() if file.endswith('_samples.csv')][0]

# extraindo o genotipo do nome do arquivo "_samples.csv"
GENOTYPE = os.path.splitext(sample_file)[0].replace('_samples', '')

# extraindo samples separadas por virgula
samples = pd.read_csv(GENOTYPE+'_samples.csv')

# reference transcriptome
reference_transcriptome = "/Storage/data1/riano/Sugarcane/Pantranscriptome/Assemblies/CD-HIT_48_genotypes_transcriptome_salmonInx/"

# split kraken in parts
parts = pd.read_csv("parts.csv")

#Software executable
ffq = config["software"]["ffq"]
jq = config["software"]["jq"]
fastqc = config["software"]["fastqc"]
bbduk = config["software"]["bbduk"]
kraken2 = config["software"]["kraken2"]
create_index = config["software"]["create_index"]
contfree_ngs = config["software"]["contfree_ngs"]
trinity = config["software"]["trinity"]
cd_hit_est = config["software"]["cd_hit_est"]
extract_contigs = config["software"]["extract_contigs"]
busco = config["software"]["busco"]
transrate = config["software"]["transrate"]
salmon = config["software"]["salmon"]

rule all:
	input:
		#Getting only total parts before run Trinity:
		expand("MyAssembly_{genotype}/6_contamination_removal/{sample}.trimmed.filtered.total.R1.fastq", genotype=GENOTYPE, sample=samples),
		expand("MyAssembly_{genotype}/6_contamination_removal/{sample}.trimmed.filtered.total.R2.fastq", genotype=GENOTYPE, sample=samples),
		expand("MyAssembly_{genotype}/6_contamination_removal/{sample}.trimmed.unclassified.total.R1.fastq", genotype=GENOTYPE, sample=samples),
		expand("MyAssembly_{genotype}/6_contamination_removal/{sample}.trimmed.unclassified.total.R2.fastq", genotype=GENOTYPE, sample=samples),
		expand("MyAssembly_{genotype}_k25andk31_busco", genotype=GENOTYPE),
		expand("MyAssembly_{genotype}/9_transrate/transrate_comparative_Shorgum_vs_{genotype}", genotype=GENOTYPE),
		expand("MyAssembly_{genotype}/10_salmon/quant/", genotype=GENOTYPE)
		

rule download_fastq:
	"""
	Baixa os arquivos brutos (fastq.gz) das leituras 1 e 2 das amostras do genotipo {params.genotype}.
	"""
	priority: 1
	output:
		R1 = "MyAssembly_{genotype}/1_raw_reads_in_fastq_format/{sample}_1.fastq",
		R2 = "MyAssembly_{genotype}/1_raw_reads_in_fastq_format/{sample}_2.fastq"
	threads: 1
	resources:
		load=6
	params:
		genotype="{genotype}",
		server="figsrv"
	log:
		"MyAssembly_{genotype}/logs/download_fastq/{sample}.log"
	name: "download_fastq"
	shell:
		"""
		cd MyAssembly_{params.genotype}/1_raw_reads_in_fastq_format && \
		{ffq} --ftp {wildcards.sample} | grep -Eo '\"url\": \"[^\"]*\"' | grep -o '\"[^\"]*\"$' | xargs wget && \
		gzip -dc < {wildcards.sample}_1.fastq.gz > {wildcards.sample}_1.fastq && \
		gzip -dc < {wildcards.sample}_2.fastq.gz > {wildcards.sample}_2.fastq && \
		cd -
		"""

rule fastqc:
        """
        Gera um relatorio FastQC com a qualidade das leituras 1 e 2 das amostras do genotipo {params.genotype}.
        """
	input:
                R1 = "MyAssembly_{genotype}/1_raw_reads_in_fastq_format/{sample}_1.fastq",
                R2 = "MyAssembly_{genotype}/1_raw_reads_in_fastq_format/{sample}_2.fastq" 
        priority: 1
	output:
		html_1= "MyAssembly_{genotype}/2_raw_reads_fastqc_reports/{sample}_1_fastqc.html",
		zip_1 = "MyAssembly_{genotype}/2_raw_reads_fastqc_reports/{sample}_1_fastqc.zip",
                html_2= "MyAssembly_{genotype}/2_raw_reads_fastqc_reports/{sample}_2_fastqc.html",
                zip_2 = "MyAssembly_{genotype}/2_raw_reads_fastqc_reports/{sample}_2_fastqc.zip"
	threads: 1
	resources: 
		load = 1
	params:
		genotype="{genotype}",
		server="figsrv"
	log:
		"MyAssembly_{genotype}/logs/fastqc/{sample}.log"
	shell:
		"{fastqc} -f fastq {input.R1} -o MyAssembly_{params.genotype}/2_raw_reads_fastqc_reports 2> {log};"
		"{fastqc} -f fastq {input.R2} -o MyAssembly_{params.genotype}/2_raw_reads_fastqc_reports 2> {log}"

rule salmon_index:
	"""
	Gera um index do salmon para a quantificacao das leituras cruas.
	"""
	priority: 1
	input:
		transcriptome = reference_transcriptome
	output:
		salmon_index="/Storage/data1/riano/Sugarcane/Pantranscriptome/Assemblies/CD-HIT_48_genotypes_transcriptome_salmonInx/"
	params:
		server="figsrv"
	resources:
		load=1
	threads: 1
#	log:
#		"MyAssembly_{genotype}/logs/salmon/index/salmon_index.log"
	name: "salmon_index"
	shell:
		"""
		/usr/bin/time -v {salmon} index -t {input.transcriptome} -p {threads} -i {output.salmon_index} > {log} 2>&1
		"""

rule salmon_quant:
	"""
	Quantifica as leituras cruas contra o indice do salmon do pan-transcriptoma (CD-HIT 100%).
	"""
	priority: 1
	input:
		salmon_index="/Storage/data1/riano/Sugarcane/Pantranscriptome/Assemblies/CD-HIT_48_genotypes_transcriptome_salmonInx/",
                R1 = "MyAssembly_{genotype}/1_raw_reads_in_fastq_format/{sample}_1.fastq",
                R2 = "MyAssembly_{genotype}/1_raw_reads_in_fastq_format/{sample}_2.fastq"
	output:
		"MyAssembly_{genotype}/3_salmon/quant/{sample}/aux_info/meta_info.json",
		"MyAssembly_{genotype}/3_salmon/quant/{sample}/quant.sf"
	params:
		server="figsrv",
		genotype="{genotype}"	
	resources:
		load=6
	threads: 6
	log:
		"datasets_{genotype}/logs/salmon/quant/{sample}.log"
	name: "salmon_quant"
	shell:
		"""
		/usr/bin/time -v {salmon} quant -p {threads} -i {input.salmon_index} -l A -1 {input.R1} -2 {input.R2} -o datasets_{params.genotype}/3_salmon/quant/{wildcards.sample} > {log} 2>&1
		"""

rule filter_stranded:
	"""
	Filtra leituras stranded e pareadas (ISR) apos quantificacao no pan-transcriptoma.
	"""
	priority: 1
	input:
		meta_info = expand("MyAssembly_{genotype}/3_salmon/quant/{sample}/aux_info/meta_info.json", genotype=GENOTYPE, sample=samples),
	output:
		filtered_samples = "MyAssembly_{genotype}/3_salmon/quant/{genotype}_srrlist.csv"
	threads: 1
	resources:
		load=1
	params:
		genotype="{genotype}",
		server="figsrv"
	log:
		"MyAssembly_{genotype}/logs/filter_stranded/{genotype}.log"
	name: "filter_stranded"
	shell:
		"""
		{jq} -r '.library_types[]' {input.meta_info} > MyAssembly_{params.genotype}/3_salmon/quant/lib.txt 2>> {log}
		ls MyAssembly_{wildcards.genotype}/3_salmon/quant/ | grep -E "(SRR|ERR)" > MyAssembly_{params.genotype}/3_salmon/quant/id.txt 2>> {log}
		paste MyAssembly_{params.genotype}/3_salmon/quant/id.txt MyAssembly_{params.genotype}/3_salmon/quant/lib.txt -d, > MyAssembly_{params.genotype}/3_salmon/quant/stranded_status.csv 2>> {log}
		grep .S MyAssembly_{params.genotype}/3_salmon/quant/stranded_status.csv > MyAssembly_{params.genotype}/3_salmon/quant/stranded_samples.csv 2>> {log}
		cut -f1 -d, MyAssembly_{params.genotype}/3_salmon/quant/stranded_samples.csv | paste -s -d, > MyAssembly_{params.genotype}/3_salmon/quant/{params.genotype}_srrlist.csv 2>> {log}
		"""

def get_filter_stranded_samples(wildcards):
	#this file is created by filter_stranded (rule above)
	try:
		with open(f"MyAssembly_{wildcards.genotype}/3_salmon/quant/{wildcards.genotype}_srrlist.csv", "r") as f1:
			stranded_samples = pd.read_csv(f1)
		return stranded_samples
	except EmptyDataError:
		print("Empty file - {f1}")

rule bbduk:
	"""
	Se as leituras cruas forem stranded e pareadas (resultado do filtro anterior):
	- Remove os adaptadores de sequenciamento com illumina (adapters.fa) dos arquivos brutos (fastq.gz);
	- Remove sequencias de RNA ribossomal (rRNA) dos arquivos brutos (fastq.gz);
	- Filtra sequencias por minlength=75 e qualidade < Q20.
	"""
	input:
		fastq_raw = "MyAssembly_{genotype}/2_raw_reads_fastqc_reports/{sample}_1_fastqc.html",
		R1 = "MyAssembly_{genotype}/1_raw_reads_in_fastq_format/{sample}_1.fastq",
		R2 = "MyAssembly_{genotype}/1_raw_reads_in_fastq_format/{sample}_2.fastq",
		new_srrlist = "MyAssembly_{genotype}/3_salmon/quant/{genotype}_srrlist.csv"
        priority: 1
	output:
		R1 = "MyAssembly_{genotype}/3_trimmed_reads/{sample}.trimmed.R1.fastq",
		R2 = "MyAssembly_{genotype}/3_trimmed_reads/{sample}.trimmed.R2.fastq",
		refstats = "MyAssembly_{genotype}/3_trimmed_reads/{sample}.trimmed.refstats",
		stats = "MyAssembly_{genotype}/3_trimmed_reads/{sample}.trimmed.stats"
	log:
		"MyAssembly_{genotype}/logs/bbduk/{sample}.log"
	threads: 4
	resources:
		load=5
	params:
		server="figsrv"
	shell:
		"{bbduk} -Xmx40g threads={threads} in1={input.R1} in2={input.R2} "
		"refstats={output.refstats} stats={output.stats} "
		"out1={output.R1} out2={output.R2} "
		"rref=/Storage/progs/bbmap_35.85/resources/adapters.fa "
		"fref=/Storage/progs/sortmerna-2.1b/rRNA_databases/rfam-5.8s-database-id98.fasta,"
		"/Storage/progs/sortmerna-2.1b/rRNA_databases/silva-bac-16s-id90.fasta,"
		"/Storage/progs/sortmerna-2.1b/rRNA_databases/rfam-5s-database-id98.fasta,"
		"/Storage/progs/sortmerna-2.1b/rRNA_databases/silva-bac-23s-id98.fasta,"
		"/Storage/progs/sortmerna-2.1b/rRNA_databases/silva-arc-16s-id95.fasta,"
		"/Storage/progs/sortmerna-2.1b/rRNA_databases/silva-euk-18s-id95.fasta,"
		"/Storage/progs/sortmerna-2.1b/rRNA_databases/silva-arc-23s-id98.fasta,"
		"/Storage/progs/sortmerna-2.1b/rRNA_databases/silva-euk-28s-id98.fasta "
		"minlength=75 qtrim=w trimq=20 tpe tbo 2> {log}"

rule fastqc_after_bbduk:
        """
        Gera um relatorio FastQC com a qualidade das leituras trimadas 1 e 2 das amostras do genotipo {params.genotype}.
        """
	input:
		R1 = "MyAssembly_{genotype}/3_trimmed_reads/{sample}.trimmed.R1.fastq",
		R2 = "MyAssembly_{genotype}/3_trimmed_reads/{sample}.trimmed.R2.fastq"
        priority: 1
	output:
		html_1= "MyAssembly_{genotype}/4_trimmed_reads_fastqc_reports/{sample}.trimmed.R1_fastqc.html",
		zip_1 = "MyAssembly_{genotype}/4_trimmed_reads_fastqc_reports/{sample}.trimmed.R1_fastqc.zip",
		html_2= "MyAssembly_{genotype}/4_trimmed_reads_fastqc_reports/{sample}.trimmed.R2_fastqc.html",
		zip_2 = "MyAssembly_{genotype}/4_trimmed_reads_fastqc_reports/{sample}.trimmed.R2_fastqc.zip"
	threads: 1
	resources:
		load=1
	params:
		genotype="{genotype}",
		server="figsrv"
	log:
		"MyAssembly_{genotype}/logs/fastqc_after_bbduk/{sample}.log"
	shell:
		"{fastqc} -f fastq {input.R1} -o MyAssembly_{params.genotype}/4_trimmed_reads_fastqc_reports 2> {log};"
		"{fastqc} -f fastq {input.R2} -o MyAssembly_{params.genotype}/4_trimmed_reads_fastqc_reports 2> {log}"

rule kraken:
        """
        Gera o relatorio do Kraken2 com a taxonomia de todas as sequencias baseado no banco de dados: /Storage/data1/felipe.peres/kraken2/completeDB
        """
	input:
		"MyAssembly_{genotype}/4_trimmed_reads_fastqc_reports/{sample}.trimmed.R1_fastqc.html",
		R1 = "MyAssembly_{genotype}/3_trimmed_reads/{sample}.trimmed.R1.fastq",
		R2 = "MyAssembly_{genotype}/3_trimmed_reads/{sample}.trimmed.R2.fastq"
        priority: 1
	output:
		"MyAssembly_{genotype}/5_trimmed_reads_kraken_reports/{sample}.trimmed.kraken"
	threads: 10
	resources:
		load=10
	params:
		server="figsrv"
	log:
		"MyAssembly_{genotype}/logs/kraken2/{sample}.log"
	shell:
		"{kraken2} --db /Storage/data1/felipe.peres/kraken2/completeDB "
		"--threads {threads} --report-zero-counts --confidence 0.05 --output {output} --paired {input.R1} {input.R2} 2> {log}"

rule split_kraken_output:
        """
        Splita o relatorio do Kraken2 em X partes (parts.csv).
	- Etapa necessaria para utilizar menos RAM.
        """
	input:
		"MyAssembly_{genotype}/5_trimmed_reads_kraken_reports/{sample}.trimmed.kraken"
        priority: 1
	output:
		expand("MyAssembly_{{genotype}}/5_trimmed_reads_kraken_reports/parts/{{sample}}.trimmed_{part}.kraken", part=parts)
	params:
		identificator = "{sample}",
		genotype = "{genotype}",
		server = "figsrv"
	threads: 1
	resources: 
		load=1
	log:
		"MyAssembly_{genotype}/logs/split_kraken_output/{sample}.log"
	shell:
		"split --number=l/10 -d --additional-suffix=.kraken {input} MyAssembly_{params.genotype}/5_trimmed_reads_kraken_reports/parts/{params.identificator}.trimmed_ 2> {log}"

rule create_index_contfree_ngs:
        """
        Gera um index para as sequencias antes de rodar o ContFree-NGS.
        """
	input: 
		R1 = "MyAssembly_{genotype}/3_trimmed_reads/{sample}.trimmed.R1.fastq",
		R2 = "MyAssembly_{genotype}/3_trimmed_reads/{sample}.trimmed.R2.fastq"
        priority: 1
	output:
		R1 = "MyAssembly_{genotype}/6_contamination_removal/index/{sample}.trimmed.R1.index",
		R2 = "MyAssembly_{genotype}/6_contamination_removal/index/{sample}.trimmed.R2.index"
	threads: 1
	resources:
		load=1
	params:
		genotype="{genotype}",
		server="bcmsrv"
	log:
		"MyAssembly_{genotype}/logs/create_index/{sample}.log"
	shell:
		"{create_index} -R1 {input.R1} -R2 {input.R2} -o MyAssembly_{params.genotype}/6_contamination_removal/index/ 2> {log}"

rule contfree_ngs:
        """
        Executa o ContFree-NGS para remover leituras que nao estao no taxon Viridiplantae.
        """
	input:
		R1 = "MyAssembly_{genotype}/6_contamination_removal/index/{sample}.trimmed.R1.index",
		R2 = "MyAssembly_{genotype}/6_contamination_removal/index/{sample}.trimmed.R2.index",
		kraken_file = "MyAssembly_{genotype}/5_trimmed_reads_kraken_reports/parts/{sample}.trimmed_{part}.kraken"
        priority: 1
	output: 
		filtered_parts_R1 = "MyAssembly_{genotype}/6_contamination_removal/parts/{part}.{sample}.trimmed.filtered.R1.fastq", 
		filtered_parts_R2 = "MyAssembly_{genotype}/6_contamination_removal/parts/{part}.{sample}.trimmed.filtered.R2.fastq", 
		unclassified_parts_R1 = "MyAssembly_{genotype}/6_contamination_removal/parts/{part}.{sample}.trimmed.unclassified.R1.fastq",
		unclassified_parts_R2 = "MyAssembly_{genotype}/6_contamination_removal/parts/{part}.{sample}.trimmed.unclassified.R2.fastq"
	threads: 1
	resources: 
		load=1
	params:
		genotype="{genotype}",
		server="bcmsrv"
	log:
		"MyAssembly_{genotype}/logs/contfree_ngs/{sample}.{part}.log"
	shell:
		"python3.8 {contfree_ngs} --taxonomy {input.kraken_file} --s p --R1 {input.R1} --R2 {input.R2} --taxon Viridiplantae -o MyAssembly_{params.genotype}/6_contamination_removal/parts/ 2> {log};"

rule merge:
        """
        Concatena todas as leituras 'unclassified' e 'filtered' geradas pelo ContFree-NGS.
        """
	input:
		filtered_parts_R1 = expand("MyAssembly_{{genotype}}/6_contamination_removal/parts/{part}.{{sample}}.trimmed.filtered.R1.fastq", part=parts),
		filtered_parts_R2 = expand("MyAssembly_{{genotype}}/6_contamination_removal/parts/{part}.{{sample}}.trimmed.filtered.R2.fastq", part=parts),
		unclassified_parts_R1 = expand("MyAssembly_{{genotype}}/6_contamination_removal/parts/{part}.{{sample}}.trimmed.unclassified.R1.fastq", part=parts),
		unclassified_parts_R2 = expand("MyAssembly_{{genotype}}/6_contamination_removal/parts/{part}.{{sample}}.trimmed.unclassified.R2.fastq", part=parts)
        priority: 1
	output:
		filtered_total_R1 = "MyAssembly_{genotype}/6_contamination_removal/{sample}.trimmed.filtered.total.R1.fastq",
		filtered_total_R2 = "MyAssembly_{genotype}/6_contamination_removal/{sample}.trimmed.filtered.total.R2.fastq",
		unclassified_total_R1 = "MyAssembly_{genotype}/6_contamination_removal/{sample}.trimmed.unclassified.total.R1.fastq",
		unclassified_total_R2 = "MyAssembly_{genotype}/6_contamination_removal/{sample}.trimmed.unclassified.total.R2.fastq"
	threads: 1
	resources:
		load=1
	params:
		server="figsrv"
	log:
		"MyAssembly_{genotype}/logs/merge/{sample}.log"
	shell:
		"cat {input.filtered_parts_R1} >> {output.filtered_total_R1};"
		"cat {input.filtered_parts_R2} >> {output.filtered_total_R2};"
		"cat {input.unclassified_parts_R1} >> {output.unclassified_total_R1};"
		"cat {input.unclassified_parts_R2} >> {output.unclassified_total_R2}"

filtered_total_R1 = expand("MyAssembly_{{genotype}}/6_contamination_removal/{sample}.trimmed.filtered.total.R1.fastq", sample=samples)
filtered_total_R2 = expand("MyAssembly_{{genotype}}/6_contamination_removal/{sample}.trimmed.filtered.total.R2.fastq", sample=samples)
unclassified_total_R1 = expand("MyAssembly_{{genotype}}/6_contamination_removal/{sample}.trimmed.unclassified.total.R1.fastq", sample=samples)
unclassified_total_R2 = expand("MyAssembly_{{genotype}}/6_contamination_removal/{sample}.trimmed.unclassified.total.R2.fastq", sample=samples)

rule trinity:
        """
        Executa o Trinity para montar transcriptomas com dois valores de k-mer (k = 25 e k = 31).
        """
	input:
		filtered_total_R1 = expand("MyAssembly_{{genotype}}/6_contamination_removal/{sample}.trimmed.filtered.total.R1.fastq", sample=samples),
		filtered_total_R2 = expand("MyAssembly_{{genotype}}/6_contamination_removal/{sample}.trimmed.filtered.total.R2.fastq", sample=samples),
		unclassified_total_R1 = expand("MyAssembly_{{genotype}}/6_contamination_removal/{sample}.trimmed.unclassified.total.R1.fastq", sample=samples),
		unclassified_total_R2 = expand("MyAssembly_{{genotype}}/6_contamination_removal/{sample}.trimmed.unclassified.total.R2.fastq", sample=samples) 
        priority: 1
	output: 
		k25 = "MyAssembly_{genotype}/7_trinity_assembly/MyAssembly_{genotype}_trinity_k25.Trinity.fasta",
		k31 = "MyAssembly_{genotype}/7_trinity_assembly/MyAssembly_{genotype}_trinity_k31.Trinity.fasta"
	params:
		filtered_total_R1=','.join(filtered_total_R1),
		filtered_total_R2=','.join(filtered_total_R2),
		unclassified_total_R1=','.join(unclassified_total_R1),
		unclassified_total_R2=','.join(unclassified_total_R2),
		server="figsrv",
		genotype="{genotype}"
	resources: 
		load=10
	threads: 10
	log:
		k25 = "MyAssembly_{genotype}/logs/trinity/{genotype}.k25.log",
		k31 = "MyAssembly_{genotype}/logs/trinity/{genotype}.k31.log"
	shell:
		"/usr/bin/time -v {trinity} --seqType fq --left {params.filtered_total_R1},{params.unclassified_total_R1} --right {params.filtered_total_R2},{params.unclassified_total_R2} --SS_lib_type RF --max_memory 10G --min_contig_length 200 --CPU {threads} --output 7_trinity_assembly/MyAssembly_{params.genotype}_trinity_k25 --full_cleanup --no_normalize_reads --KMER_SIZE 25 2> {log.k25};"
		"/usr/bin/time -v {trinity} --seqType fq --left {params.filtered_total_R1},{params.unclassified_total_R1} --right {params.filtered_total_R2},{params.unclassified_total_R2} --SS_lib_type RF --max_memory 10G --min_contig_length 200 --CPU {threads} --output 7_trinity_assembly/MyAssembly_{params.genotype}_trinity_k25 --full_cleanup --no_normalize_reads --KMER_SIZE 31 2> {log.k31}"

rule cd_hit_est:
        """
        Concatena os dois transcriptomas montados pelo Trinity (k = 25 e k = 31).
        """
	input: 
		k25 = "MyAssembly_{genotype}/7_trinity_assembly/MyAssembly_{genotype}_trinity_k25.Trinity.fasta",
		k31 = "MyAssembly_{genotype}/7_trinity_assembly/MyAssembly_{genotype}_trinity_k31.Trinity.fasta"
        priority: 1
	output:
		mod_k25 = "MyAssembly_{genotype}/7_trinity_assembly/MyAssembly_{genotype}_trinity_k25.Trinity.mod.fasta",
		mod_k31 = "MyAssembly_{genotype}/7_trinity_assembly/MyAssembly_{genotype}_trinity_k31.Trinity.mod.fasta",
		merged_mod = "MyAssembly_{genotype}/7_trinity_assembly/MyAssembly_{genotype}_trinity_k25_and_k31.Trinity.merged.mod.fasta",
		final_cd_hit_est = "MyAssembly_{genotype}/7_trinity_assembly/MyAssembly_{genotype}_trinity_k25_and_k31.Trinity.merged.final.fasta"
	params:
		genotype="{genotype}",
		server="figsrv"
	resources:
		load=1
	threads: 1
	log:
		"MyAssembly_{genotype}/logs/cd_hit_est_transcriptomes/{genotype}.log"
	shell:
		"sed 's/>/>k25_{params.genotype}_/' {input.k25} > {output.mod_k25};"
		"sed 's/>/>k31_{params.genotype}_/' {input.k31} > {output.mod_k31};"
		"cat {output.mod_k25} {output.mod_k31} > {output.merged_mod};"
		"/usr/bin/time -v {cd_hit_est} -i {output.merged_mod} -o {output.final_cd_hit_est} -c 1 -n 11 -T {threads} -M 0 -d 0 -r 0 -g 1"

rule extract_contiglenght_301:
        """
        Extrai contigs com tamanho minimo = 301 do transcriptoma concatenado (k = 25 e k = 31).
        """
	input:
		transcriptome = "MyAssembly_{genotype}/7_trinity_assembly/MyAssembly_{genotype}_trinity_k25_and_k31.Trinity.merged.final.fasta"
        priority: 1
	output: 
		"MyAssembly_{genotype}_trinity_k25_and_k31.Trinity.merged.final_gt301bp.fasta"
	params:
		server="figsrv"
	resources:
		load=1
	threads: 1
	log: 
		"MyAssembly_{genotype}/logs/extract_contigs/{genotype}.log"
	shell:
		"{extract_contigs} -f {input.transcriptome} -m 301 2> {log}"

rule busco:
        """
        Avaliacao de qualidade do transcriptoma com BUSCO (banco embryophyta como referencia).
        """
	input:
		transcriptome="MyAssembly_{genotype}/7_trinity_assembly/MyAssembly_{genotype}_trinity_k25_and_k31.Trinity.merged.final_gt301bp.fasta"
        priority: 1
	output:
		busco="MyAssembly_{genotype}_k25andk31_busco"
	params:
		server="figsrv"
	resources:
		load=4
	threads: 2
	log:
		"MyAssembly_{genotype}/logs/busco/{genotype}.log"
	shell:
		"/usr/bin/time -v run_BUSCO.py -i {input.transcriptome} -o {output.busco} -c {threads} -m transcriptome -l /Storage/databases/BUSCO_DBs/embryophyta_odb9/ 2> {log}"		

rule transrate:
        """
        Avaliacao de qualidade do transcriptoma com TRANSRATE (utilizando o transcriptoma de Sorghum bicolor como referencia).
        """
	input:
		transcriptome="MyAssembly_{genotype}/7_trinity_assembly/MyAssembly_{genotype}_trinity_k25_and_k31.Trinity.merged.final_gt301bp.fasta",
		ref="Sbicolor_454_v3.1.1.transcript.fa"
        priority: 1
	output:
		transrate=directory("MyAssembly_{genotype}/9_transrate/transrate_comparative_Shorgum_vs_{genotype}")
	params:
		server="figsrv"
	resources:
		load=4
	threads: 2
	log:
		"MyAssembly_{genotype}/logs/transrate/{genotype}.log"
	shell:
		"/usr/bin/time -v {transrate} --assembly {input.transcriptome} --reference {input.ref} --threads {threads} --output {output.transrate} 2> {log}"

rule salmon_index_quant:
        """
        Avaliacao de qualidade do transcriptoma com Salmon:
	- Gera um salmon index para o transcriptoma concatenado.
        """
	input:
		transcriptome="MyAssembly_{genotype}/7_trinity_assembly/MyAssembly_{genotype}_trinity_k25_and_k31.Trinity.merged.final_gt301bp.fasta"
        priority: 1
	output:
		salmon_index=directory("MyAssembly_{genotype}/10_salmon/index/")
	params:
		server="figsrv"
	resources:
		load=1
	threads: 2
	log:
		"MyAssembly_{genotype}/logs/salmon_index/{genotype}.log"
	shell:
		"/usr/bin/time -v {salmon} index -t {input.transcriptome} -p {threads} -i {output.salmon_index} --gencode 2> {log}"

rule salmon_quant_transcriptome:
        """
        Avaliacao de qualidade do transcriptoma com Salmon:
        - Quantificacao das leituras trimadas no transcriptoma concatenado.
        """
	input:
		salmon_index = "MyAssembly_{genotype}/10_salmon/index/",
		filtered_R1 = expand("MyAssembly_{{genotype}}/6_contamination_removal/{sample}.trimmed.filtered.total.R1.fastq", sample=samples),
                filtered_R2 = expand("MyAssembly_{{genotype}}/6_contamination_removal/{sample}.trimmed.filtered.total.R2.fastq", sample=samples),
                unclassified_R1 = expand("MyAssembly_{{genotype}}/6_contamination_removal/{sample}.trimmed.unclassified.total.R1.fastq", sample=samples),
                unclassified_R2 = expand("MyAssembly_{{genotype}}/6_contamination_removal/{sample}.trimmed.unclassified.total.R2.fastq", sample=samples)
        priority: 1
	output:
		salmon_quant=directory("MyAssembly_{genotype}/10_salmon/quant/")
	params:
		server="figsrv",
		filtered_total_R1=' '.join(filtered_total_R1),
		filtered_total_R2=' '.join(filtered_total_R2),
		unclassified_total_R1=' '.join(unclassified_total_R1),
		unclassified_total_R2=' '.join(unclassified_total_R2)
	resources:
		load=1
	threads: 2
	log: 
		"MyAssembly_{genotype}/logs/salmon_quant/{genotype}.log"
	shell:
		"/usr/bin/time -v {salmon} quant -i {input.salmon_index} -l A -1 {params.filtered_total_R1} {params.unclassified_total_R1} -2 {params.filtered_total_R2} {params.unclassified_total_R2} --validateMappings -o {output.salmon_quant} 2> {log}"
