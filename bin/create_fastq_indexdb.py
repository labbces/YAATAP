#!/usr/bin/env python

'''				Description
		This script creates a indexdb for FASTQ files!
		This step is necessary to run ContFree-NGS.py
'''

import argparse
import sys
import os
from Bio import SeqIO

# creating arguments
parser = argparse.ArgumentParser(prog='create_indexdb.py', description='create indexdb for FASTQ files', add_help=True)
parser.add_argument('-R1', dest='R1_file', metavar='<R1 file>', help='R1 FASTQ file', required=True)
parser.add_argument('-R2', dest='R2_file', metavar='<R1 file>', help='R2 FASTQ file', required=True)
parser.add_argument('-o', dest='output_path', metavar='<output path>', help='path to output files')
parser.add_argument('-v', '--version', action='version', version='%(prog)s v1.0')

# getting arguments
args = parser.parse_args()
R1 = args.R1_file
R2 = args.R2_file
output_path = args.output_path
cwd = os.getcwd()

if not os.path.exists(output_path):
	os.makedirs(output_path)

# generate index names 
index_R1 = os.path.basename(R1[:-5] + "index")
index_R2 = os.path.basename(R2[:-5] + "index")

# join index name + output path
index_R1_output = os.path.join(output_path, index_R1)
index_R2_output = os.path.join(output_path, index_R2)

# generate index database with biopython
print("Creating an indexed database for R1 reads, please wait ... \n")
record_R1_index_db = SeqIO.index_db(index_R1_output, R1, "fastq")
print("R1 index created!")

print("Creating an indexed database for R2 reads, please wait ... \n")
record_R2_index_db = SeqIO.index_db(index_R2_output, R2, "fastq")
print("R2 index created!")
