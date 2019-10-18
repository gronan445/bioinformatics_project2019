#********************************************************************************************************************
# Author: George Ronan
# Date Created: 16 October, 2019
# Date Edited: 18 October, 2019
# Description: Code for bioinformatics project for BIOS 60318 mid-semester project
#********************************************************************************************************************
# Inputs: Proteome directory (PD) to be analyzed, expected extension (PE) of proteome files, Reference gene/proteome
#	  directory (RD), expected extension of references (RE), number of genes of interest (RN)
# NOTE - It is recommended to use the abolute path to directories for minimal potential of error
#	 This can be done simply by using $(echo $(pwd)/relative_path) as the input
# Outputs: organized hmmsearch directory containing stdouts for each run, organized hmmtable directory containing
#	   tabularized outputs for each run, and proteome_01.txt which contains the top 10 scorers for all genes
# Usage: bash gronan_project.sh <PD> <PE> <RD> <RE> <RN>
# ASSUMPTIONS - both muscle (executable) and hmmer (directory) are in a 'bin' directory sharing a parent directory with
#	        location of this program - this path can be edited as necessary
#********************************************************************************************************************

#*********************************************** INITIALIZE DIRECTORIES *********************************************
if [ ! -d "hmmsearch_outputs" ]
then
	mkdir hmmsearch_outputs
fi
if [ ! -d "hmmtable_outputs" ]
then
	mkdir hmmtable_outputs
fi
#*********************************************** BUILD REFERENCE FILES **********************************************
echo "Building Reference Files and Searching Proteome Datasets"
for fileR in $3/*.$4 # Loop through all proteome reference files in specified directory with specified extension
do
	filenameR=$(echo $fileR | rev | cut -d "/" -f 1 | rev | cut -d "." -f 1 | tr "gene_" "_" | tr -s "_")
	# Activates muscle for each proteome ref file sequentially with outnames temp_m_<filename>.txt
	#------------------------------------------------------------------------------------------------------------
	# MUSCLE PATH TO BE EDITED BELOW - DEFAULT: ../bin/muscle3.3.31
	../bin/muscle3.3.31 -in $fileR -out temp_m_$filenameR.msa -quiet # -quiet supressed stdout
	#------------------------------------------------------------------------------------------------------------
	# Activates hmmbuild for each muscle output as its created; --amino indicates proteome data, temp_hmm is to
	# supress stdout and is removed later in the loop
	#------------------------------------------------------------------------------------------------------------
	# HMMBUILD PATH TO BE EDITED BELOW - DEFAULT: ../bin/hmmer-3.2/bin/hmmbuild
	../bin/hmmer-3.2/bin/hmmbuild --amino -o temp_hmm.txt temp_b_$filenameR.hmm temp_m_$filenameR.msa
	#------------------------------------------------------------------------------------------------------------
#*********************************************** OBTAIN PROTEOME DATA ***********************************************
	for fileP in $1/*.$2 # Loop through all proteome files in specified directory with specified extension
	do
		filenameP=p_$(echo $fileP | rev | cut -d "/" -f 1 | rev | cut -d "." -f 1 | cut -d "_" -f 2)
		if [ ! -d "hmmsearch_outputs/$filenameP" ]
		then
			mkdir hmmsearch_outputs/$filenameP
		fi
		if [ ! -d "hmmtable_outputs/$filenameP" ]
		then
			mkdir hmmtable_outputs/$filenameP
		fi
		# Should activate hmmsearch for each proteome using the previously build reference file
		../bin/hmmer-3.2/bin/hmmsearch -o hmmsearch_outputs/$filenameP/hmm_$filenameP-$filenameR.txt \
		--tblout hmmtable_outputs/$filenameP/$filenameP-$filenameR-results.txt temp_b_$filenameR.hmm $fileP
		count=$(cat hmmtable_outputs/$filenameP/$filenameP-$filenameR-results.txt | wc -l | cut -d " " -f 1)
		hits=$(($count-13)) # manually counted 13 lines in tabular output not pertaining to individual hits
		echo "$filenameR $hits" >> $filenameP-total-hits.csv
	done
	echo "Gene $filenameR build and search complete"
	# Removes files generated by muscle and hmmbuild to prevent clutter
	rm temp_m_$filenameR.msa temp_b_$filenameR.hmm temp_hmm.txt
done
echo "Beginning hit counting"
for fileS in *-hits.csv
do
	for (( a=1; a<=$5; a++ ))
	do
		gID=$(cat $fileS | head -n 1 | cut -d "_" -f 1)
		echo "ID: $gID; a=$a"
		cat $fileS | grep -h "$gID" > gene_$a-$fileS
		sed -i '/"$gID"/d' $fileS
		sum=$(cat gene_$a-$fileS | cut -d " " -f 2 | awk '{total = total + $1}END{print total}')
		echo "Gene$a $sum" >> $(echo $fileS | cut -d "-" -f 1)-sums.csv
	done
	rm $fileS
done
rm *-total-hits.csv
echo "Removing candidates that do not express at least 1 copy of all genes"
grep -l " 0" *sums.csv | xargs rm -f
echo "Calculating total sum score for each proteome"
for fileF in *sums.csv
do
	tot_sum=$(cat $fileF | cut -d " " -f 2 | awk '{total = total + $1}END{print total}')
	name=$(echo $fileF | cut -d "-" -f 1)
	echo "$name $tot_sum" > proteome_list.txt
	echo "$name calculation complete"
#	rm $fileF
done
# Sort the listed proteome totals and corresponding proteomes numerically, then isolate and export the top 10
cat proteome_list.txt | sort -k 2 -n | head -n 10 > proteome_01.txt
rm proteome_list.txt # Remove the total proteome list to prevent clutter - comment out this line if the total list is
		     # desired
echo "Finished - final output has been directed to proteome_01.txt"
