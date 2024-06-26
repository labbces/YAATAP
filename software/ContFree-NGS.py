#!/usr/bin/env python

'''                             Description
        Removing reads from contaminating organisms in NGS datasets
'''

import argparse
import os
from ete3 import NCBITaxa
from Bio import SeqIO
import re

# creating arguments
parser = argparse.ArgumentParser(prog='ContFree-NGS.py', description='Removing reads from contaminating organisms in Next Generation Sequencing datatasets', add_help=True)
parser.add_argument('--taxonomy', dest='taxonomy_file', metavar='<taxonomy file>', help='A taxonomy classification file', required=True)
parser.add_argument('--sequencing_type, --s', dest='sequencing_type', metavar='<p or s>', help='paired-end (p) or single-end (s)', required=True)
parser.add_argument('--R1', dest='R1_file', metavar='<R1 file>', help='read file 1', required=True)
parser.add_argument('--R2', dest='R2_file', metavar='<R2 file>', help='read file 2', required=False)
parser.add_argument('-o', dest='output_path', metavar='<output path>', help='path to output files')
parser.add_argument('--taxon', dest='taxon', metavar='<Taxon>', type=str, help='Only this taxon and its descendants will be maintained',required=True)
parser.add_argument('--v', '--version', action='version', version='%(prog)s v1.0')

# getting arguments
args = parser.parse_args()
taxonomy_file = args.taxonomy_file
sequencing_type = args.sequencing_type
R1_file = args.R1_file
R2_file = args.R2_file
output_path = args.output_path
taxon = args.taxon
paired = 0
single = 0

if not os.path.exists(output_path):
        os.makedirs(output_path)

if sequencing_type == 'p':
        paired = 1
        print("Working with paired-end reads \n")
elif sequencing_type == 's':
        single = 1
        print("Working with single-end reads \n")
else:
        print("ERROR: --sequencing_type must be 'p' for paired-end reads or 's' for single-end reads")
        print("Exiting. \n")
        exit()

index_R1 = SeqIO.index_db(R1_file[:-5] + "index")
index_R2 = SeqIO.index_db(R2_file[:-5] + "index")

# checking for indexed file and create it if dont exists 
def create_indexed_db_for_paired_fastq_files():
        indexdb_R1_file = R1_file[:-5] + "index"
        indexdb_R2_file = R2_file[:-5] + "index"
        if not os.path.exists(indexdb_R1_file) and not os.path.exists(indexdb_R2_file):
                print("Creating an indexed database for your paired-end reads, please wait ... \n")
                R1_index_db = SeqIO.index_db(indexdb_R1_file, R1_file, "fastq")
                R2_index_db = SeqIO.index_db(indexdb_R2_file, R2_file, "fastq")
        else:
                print("Working with existing index!")

def create_indexed_db_for_single_fastq_files():
        indexdb_R1_file = R1_file[:-5] + "index"
        if not os.path.exists(indexdb_R1_file):
                print("Creating an indexed database for your single-end reads, please wait ... \n")
                R1_index_db = SeqIO.index_db(indexdb_R1_file, R1_file, "fastq")
        else:
                print("Working with existing index!")

if paired == 1:
        create_indexed_db_for_paired_fastq_files()
else:
        create_indexed_db_for_single_fastq_files()

# opening indexed files
if paired == 1:
        try:
                index_R1 = SeqIO.index_db(R1_file[:-5] + "index")
                index_R2 = SeqIO.index_db(R2_file[:-5] + "index")
        except:
                print("ERROR: An exception occurred while trying to open your indexed paired-end databse")
                print("Exiting. \n")
                exit()
else:
        try:
                index_R1 = SeqIO.index_db(R1_file[:-5] + "index")
        except:
                print("ERROR: An exception occurred while trying to open your indexed single-end databse")
                print("Exiting. \n")
                exit()


# getting NCBI taxonomy database and user taxon
ncbi = NCBITaxa()
descendants = ncbi.get_descendant_taxa(taxon, intermediate_nodes=True)

# translate user taxon and append it to descendants 
#name2taxid = ncbi.get_name_translator([taxon])
#the_values = name2taxid.values()  
#user_tax_id = list(the_values)[0][0]
descendants.append(taxon)

# create output names
# getting file informations - Pattern in SRR1979658.trimmed_00.kraken
n = re.search(r"(?<=\_)[0-9]+(?=\.kraken)", taxonomy_file)
iden = re.search(r"[\w]+(?=\.trimmed)", taxonomy_file)

if paired == 1:
        filtered_R1 = n.group(0) + "." + iden.group(0) + ".trimmed.filtered.R1.fastq"
        filtered_R2 = n.group(0) + "." + iden.group(0) + ".trimmed.filtered.R2.fastq"
        unfiltered_R1 = n.group(0) + "." + iden.group(0) + ".trimmed.unclassified.R1.fastq"
        unfiltered_R2 = n.group(0) + "." + iden.group(0) + ".trimmed.unclassified.R2.fastq"
        filtered_R1_output = os.path.join(output_path, filtered_R1)
        filtered_R2_output = os.path.join(output_path, filtered_R2)
        unfiltered_R1_output = os.path.join(output_path, unfiltered_R1)
        unfiltered_R2_output = os.path.join(output_path, unfiltered_R2)
else:
        filtered_R1 = R1_file[:-5] + "filtered.fastq"
        unfiltered_R1 = R1_file[:-5] + "unclassified.fastq"

# create counter
count_descendants_sequences = 0
count_unclassified_sequences = 0
count_contaminant_sequences = 0

# filtering files
if paired == 1:
        with open(taxonomy_file, "r") as taxonomy_classification_file, open(filtered_R1_output, "w") as classified_R1, open(filtered_R2_output, "w") as classified_R2, open(unfiltered_R1_output, "w") as unclassified_R1, open(unfiltered_R2_output, "w") as unclassified_R2:
                for line in taxonomy_classification_file:
                        # getting IDs
                        R1_sequence_id = line.split()[1] +"/1"
                        R2_sequence_id = line.split()[1] +"/2"
                        taxonomy_id = int(line.split()[2])

                        # getting sequences in descendants (user taxonomic level)
                        if line.startswith("C"):
                                if taxonomy_id in descendants:
                                        count_descendants_sequences += 1
                                        SeqIO.write(index_R1[R1_sequence_id], classified_R1, "fastq")
                                        SeqIO.write(index_R2[R2_sequence_id], classified_R2, "fastq")
                                else:
                                        count_contaminant_sequences += 1
                        # getting unclassified reads in taxonomy_classification_file file
                        elif line.startswith("U"):
                                count_unclassified_sequences += 1
                                SeqIO.write(index_R1[R1_sequence_id], unclassified_R1, "fastq")
                                SeqIO.write(index_R2[R2_sequence_id], unclassified_R2, "fastq")

                print("-------------------------------------------------")
                print("Contamination removal was successfully completed!")
                print("-------------------------------------------------")
                print("{} descendants sequences: {}".format(taxon, count_descendants_sequences))
                print("Contaminant sequences: {}".format(count_contaminant_sequences))
                print("Unlabelled sequences: {}".format(count_unclassified_sequences))
                print("-------------------------------------------------")
                print("{} descendants sequences are in the filtered files".format(taxon))
                print("Contaminant sequences were discarded")
                print("Unlabelled sequences are in the unclassified files")

else:
        with open(taxonomy_file, "r") as taxonomy_classification_file, open(filtered_R1, "w") as classified_R1, open(unfiltered_R1, "w") as unclassified_R1:
                for line in taxonomy_classification_file:

                        # getting IDs
                        R1_sequence_id = line.split()[1]
                        taxonomy_id = int(line.split()[2])

                        # getting sequences in descendants (user taxonomic level)
                        if line.startswith("C"):
                                if taxonomy_id in descendants:
                                        count_descendants_sequences += 1
                                        SeqIO.write(index_R1[R1_sequence_id], classified_R1, "fastq")
                                else:
                                        count_contaminant_sequences += 1
                        # getting unclassified reads in taxonomy_classification_file file
                        elif line.startswith("U"):
                                count_unclassified_sequences += 1
                                SeqIO.write(index_R1[R1_sequence_id], unclassified_R1, "fastq")

                print("-------------------------------------------------")
                print("Contamination removal was successfully completed!")
                print("-------------------------------------------------")
                print("{} descendants sequences: {}".format(taxon, count_descendants_sequences))
                print("Contaminant sequences: {}".format(count_contaminant_sequences))
                print("Unlabelled sequences: {}".format(count_unclassified_sequences))
                print("-------------------------------------------------")
                print("{} descendants sequences are in the filtered files".format(taxon))
                print("Contaminant sequences were discarded")
        print("Unlabelled sequences are in the unclassified files")

