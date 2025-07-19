#!/usr/bin/perl

###############################################################
###############################################################
## Script: extractSequences                                  ##
## Will extract a subset of sequences from a multifasta file ##
## The user must provide in a separate file the list of      ##
##  identifiers that must be extracted                       ##
## Author: Diego Mauricio Riaño-Pachón                       ##
## Last Modification: December 16, 2010                      ##
###############################################################

use strict;
use warnings;
use diagnostics;
use Bio::DB::Fasta;
use Bio::SeqIO;
use Getopt::Long;

my $version="0.7";
my $fastafile='';
my $minlength=0;
my $license='';
my $help='';

#Get input from user

GetOptions(
    'license|l'       => \$license,
    'help|h|?'        => \$help,
    'fastafile|f=s'   => \$fastafile,
    'minlength|m=i'   => \$minlength,
);


#Check input from user

if($help){
 &usage;
 exit 1
}
if($license){
 &license;
 exit 1
}
if(!-s $fastafile){
 print STDERR "\n\tFATAL:  You must provide a multifasta file.\n\n";
 &usage;
 exit 0;
}
if(!$minlength){
 $minlength=1000;
}

&process();

sub process{
 my $dbinx=indexdb($fastafile);
 #####
 ##Create output file
 #####
 my $outfile=$fastafile;
 $outfile=~s/\.fasta//;
 $outfile.="_gt".$minlength."bp.fasta";
 my $outfile_obj = Bio::SeqIO->new('-file'   => ">$outfile",
                                   '-format' => 'Fasta');

 foreach my $id($dbinx->get_all_primary_ids){
  if($dbinx->get_Seq_by_id($id)){
   my $seq_obj=$dbinx->get_Seq_by_id($id);
   if($seq_obj->length >= $minlength){
    $outfile_obj->write_seq($seq_obj);
   }
  }
  else{
   print STDERR "ID=$id not found in file\n";
  }
 }
}

sub indexdb{
 my $file=shift;
# my $reinx=1;
 my $reinx=0;
 my $dbinx = Bio::DB::Fasta->new("$file", -reindex=>$reinx);
}

sub usage{
    print STDERR "$0 version $version, Copyright (C) 2010-2015 Diego Mauricio Riano Pachon\n";
    print STDERR "$0 comes with ABSOLUTELY NO WARRANTY; for details type `$0 -l'.\n";
    print STDERR "This is free software, and you are welcome to redistribute it under certain conditions;\n";
    print STDERR "type `$0 -l' for details.\n";
    print STDERR <<EOF;
NAME
    $0   extracts a subset of sequences from amultifasta file given alist of identifiers.

USAGE
    $0 --fastafile file.fasta --minlength 1000

OPTIONS
    --fastafile -f    Multifasta file.                   REQUIRED
    --minlength -m    Min length of contig to keep.      REQUIRED
    --help      -h    This help.
    --license   -l    License.

EOF
}
sub license{
    print STDERR <<EOF;

Copyright (C) 2017 Diego Mauricio Riaño Pach<C3>
e-mail: diriano\@gmail.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
EOF
exit;
}
