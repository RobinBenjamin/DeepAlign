#!/bin/bash

# ============== global variables defined here ========= # start
declare MAXSIZE=5000            #-> maximal subjext length   (default: 5000)
# ============== global variables defined here ========= # end



#---------------------------------------------------------#
##### ===== All functions are defined here ====== #########
#---------------------------------------------------------#


# ----- usage ------ #
function usage()
{
	echo "DeepAlign_Search v1.00 [Nov-30-2018] "
	echo "    Search a template database to find structurally similar proteins for a query protein structure "
	echo ""
	echo "USAGE:  ./DeepAlign_Search.sh <-q query_pdb> [-l data_list] [-d data_db] [-L refer_list] [-D refer_db] "
	echo "                              [-t tmsco] [-p pval] [-k topK] [-f score_func] [-C cut_alignment] [-c CPU_num]"
	echo "                              [-o output_root] [-O output_file] [-s sort] [-S options] [-H home] "
	echo "Options:"
	echo ""
	echo "***** required arguments *****"
	echo "-q query_pdb         : Query protein file in PDB format. "
	echo ""
	echo "***** relevant directories ***"
	echo "-l data_list         : The list of protein database [default = databases/bc40_list]"
	echo ""
	echo "-d data_db           : The folder containing the database files (i.e., .pdb files) [default = databases/pdb_BC100/]"
	echo ""
	echo "-L refer_list        : The list of reference database [default = databases/reference_list]"
	echo ""
	echo "-D refer_db          : The folder containing the reference files (in .pdb format) [default = databases/reference_pdb/]"
	echo ""
	echo "***** optional arguments *****"
	echo "-t tmsco             : Apply TMscore cutoff during searching process [default = 0.35]"
	echo ""
	echo "-p pval              : Keep the results for top proteins according to P-value cutoff [default = 0.001; set -1 to disable]"
	echo ""
	echo "-k topK              : Keep the results for top topK proteins [default = 100]"
	echo "                       set 0 to skip the re-align step and NO alignment; set -1 to scan ALL the input_list without filter."
	echo "                       set -2 to scan ALL the refined alignment after filter."
	echo ""
	echo "-f score_func        : 1:distance-score,2:vector-score,4:evolution-score; these scores could be combined [default 7]"
	echo ""
	echo "-C cut_alignment     : If specified, then the final template structure will be cut according to the alignment [default 0]"
	echo ""
	echo "-c CPU_num           : Number of processors. [default = 1]"
	echo ""
	echo "***** output arguments *****"
	echo "-o output_root       : The root for output file. At least one brief summary 'query.SortedScore_pvalue' will be generated."
	echo "                       [default = './\${input_name}_DeepSearch'] "
	echo ""
	echo "-O output_file       : The file containing a complex summary of the topK (>0) prediction results."
	echo "                       if not specified, then only a brief summary of the results will be generated. [default = null]"
	echo ""
	echo "***** other arguments *****"
	echo "-s sort              : screen output is sorted with respect to a specific column. [default = 8 for DeepScore] "
	echo "   tnam qnam tlen qlen -> BLOSUM CLESUM DeepScore -> LALI RMSDval TMscore -> MAXSUB GDT_TS GDT_HA -> SeqID nLen dCut uGDT"
	echo "      1    2    3    4 (5)     6      7         8 (9)  10      11      12 (13)   14     15     16 (17)  18   19   20   21"
	echo ""
	echo "-S options           : the arguments for DeepAlign, such as '-n -1' [default = null]"
	echo ""
	echo "-H home              : home directory of DeepSearch (i.e., \$DeepSearchHome)."
	echo "                       [default = `dirname $0`]"
	echo ""
	exit 1
}


#-------------------------------------------------------------#
##### ===== get pwd and check DeepThreaderHome ====== #########
#-------------------------------------------------------------#

#------ current directory ------#
curdir="$(pwd)"

#-------- check usage -------#
if [ $# -lt 1 ];
then
	usage
fi


#---------------------------------------------------------#
##### ===== All arguments are defined here ====== #########
#---------------------------------------------------------#

# ----- get arguments ----- #
#-> required arguments
query_pdb=""

#-> optional arguments
#--| data related
data_list=""
data_db=""
refer_list=""
refer_db=""
#--| parameter related
tmsco=0.35                      #-> tmscore cutoff [0.35]
pval=0.001                      #-> pvalue cutoff [0.001]
topK=100                        #-> minimal output number [100]
score_func=7                    #-> score function [7: using all for score_func]
cut_alignment=0                 #-> cut alignment or not [0: we don't cut template]
CPU_num=1                       #-> default CPU_num is 1
#--| output related
output_root=""
output_file=""
#--| other arguments
sort_col=8                      #-> sort by DeepScore
#---- screen output format -----#
#   tnam qnam tlen qlen -> BLOSUM CLESUM DeepScore -> LALI RMSDval TMscore -> MAXSUB GDT_TS GDT_HA -> SeqID nLen dCut uGDT
#      1    2    3    4 (5)     6      7         8 (9)  10      11      12 (13)   14     15     16 (17)  18   19   20   21
options=""
#--| home directory
home=`dirname $0`               #-> home directory


#-> parse arguments
while getopts ":q:l:d:L:D:t:p:k:f:C:c:o:O:a:s:S:H:" opt;
do
	case $opt in
	#-> required arguments
	q)
		query_pdb=$OPTARG
		;;
	#-> optional arguments
	#--| data related
	l)
		data_list=$OPTARG
		;;
	d)
		data_db=$OPTARG
		;;
	L)
		refer_list=$OPTARG
		;;
	D)
		refer_db=$OPTARG
		;;
	#--| parameter related
	t)
		tmsco=$OPTARG
		;;
	p)
		pval=$OPTARG
		;;
	k)
		topK=$OPTARG
		;;
	f)
		score_func=$OPTARG
		;;
	C)
		cut_alignment=$OPTARG
		;;
	c)
		CPU_num=$OPTARG
		;;
	#--| output related
	o)
		output_root=$OPTARG
		;;
	O)
		output_file=$OPTARG
		;;
	#--| other arguments
	s)
		sort_col=$OPTARG
		;;
	S)
		options=$OPTARG
		;;
	H)
		home=$OPTARG
		;;
	#-> default
	\?)
		echo "Invalid option: -$OPTARG" >&2
		exit 1
		;;
	:)
		echo "Option -$OPTARG requires an argument." >&2
		exit 1
		;;
	esac
done




#---------------------------------------------------------#
##### ===== Part 0: initial argument check ====== #########
#---------------------------------------------------------#


#========================== Part 0.1 check the relevant roots of input arguments =======================#

# ------ check home directory ---------- #
if [ ! -d "$home" ]
then
	echo "home directory $home not exist " >&2
	exit 1
fi
home=`readlink -f $home`
LOCAL_HOME=${home}

# ------ check input pdb ------#
if [ ! -s "$query_pdb" ]
then
	echo "input query_pdb $query_pdb not found !!" >&2
	exit 1
fi
query_pdb=`readlink -f $query_pdb`
fulnam=`basename $query_pdb`
relnam=${fulnam%.*}

#----------- check data  -----------#
if [ "$refer_list" == "" ]
then
	refer_list="${LOCAL_HOME}/databases/reference_list"
fi
if [ "$refer_db" == "" ]
then
	refer_db="${LOCAL_HOME}/databases/reference_pdb/"
fi
if [ "$data_list" == "" ]
then
	data_list="${LOCAL_HOME}/databases/bc40_list"
fi
if [ "$data_db" == "" ]
then
	data_db="${LOCAL_HOME}/databases/pdb_BC100/"
fi

#-- get name ---#
refer_fulnam=`basename $refer_list`
refer_relnam=${refer_fulnam%.*}
data_fulnam=`basename $data_list`
data_relnam=${data_fulnam%.*}

#-- topk and data_len ---#
data_len=`wc $data_list | awk '{print $1}'`
rel_topk=$topK


#========================== Part 0.2 check the relevant roots of output arguments ========================#

# ------ check output directory ------#
if [ "$output_root" == "" ]
then
	output_root=${relnam}_DeepSearch
fi
mkdir -p $output_root
output_root=`readlink -f $output_root`

#----------- assign output_file with absolute directory --------#
if [ "$output_file" != "" ]
then
	dir_output_file=`dirname $output_file`
	nam_output_file=`basename $output_file`
	if [ "$dir_output_file" == "." ]
	then
		output_file=$output_root/$output_file
	fi
else
	output_file="-1"
fi


#-----------------------------------------------------#
##### ===== Part 1: DeepSearch process ====== #########
#-----------------------------------------------------#

#-> create tmp root
DATE=`date '+%Y_%m_%d_%H_%M_%S'`
tmp="tmp_${relnam}_${RANDOM}_${DATE}"
prot=${output_root}/${tmp}
mkdir -p $prot


#================== Part 1.1 estimate p-value from refer_list ==================# 

#---- default value ----#
MEAN=0
VARI=0.5
#---- calculate Z-score and E-value -------#
if [ 1 -eq "$(echo "$pval > 0" | bc)" ]    #-> calculate refer_list for p-value if pval > 0
then
	#--------- echo -----------------#
	echo "step0: calculate Z-score and E-value"

	#--------- preliminary ----------#
	#--| cut refer_list into N threads
	${LOCAL_HOME}/util/List_Div_Shuf $refer_list $CPU_num $prot
	OUT=$?
	if [ $OUT -ne 0 ]
	then
		echo "${LOCAL_HOME}/util/List_Div_Shuf $refer_list $CPU_num $prot" >&2
		exit 1
	fi
	#--| run DeepAlign for these N-cut refer_list
	deepalign="DeepAlign $options -P 0 -u 0 -e $MAXSIZE "

	#--------- Z-score ----------#
	#--| calculate Z-score
	for ((i=0;i<$CPU_num;i++))
	do
		# screen output for 'proc=0'
		if [ $i -eq 0 ]   #-> for proc=0, we add option "-v"
		then
			addi=" -v "
		else
			addi=""
		fi
		# check list
		if [ ! -s ${prot}/${refer_relnam}.$i ]
		then
			continue
		fi
		# run program
		(${LOCAL_HOME}/${deepalign} ${addi} -f ${prot}/${refer_relnam}.$i -r $refer_db -q $query_pdb -m 3 -g 0 -h 1 -c 0 -p 0 -b ${prot}/${relnam}_${refer_relnam}_zscore.$i -w ${prot}/${relnam}_${refer_relnam}_tmpout.$i)&
		OUT=$?
		if [ $OUT -ne 0 ]
		then
			echo "${LOCAL_HOME}/${deepalign} ${addi} -f ${prot}/${refer_relnam}.$i -r $refer_db -q $query_pdb -m 3 -g 0 -h 1 -c 0 -p 0 -b ${prot}/${relnam}_${refer_relnam}_zscore.$i -w ${prot}/${relnam}_${refer_relnam}_tmpout.$i" >&2
			exit 1
		fi
	done
	wait
	#--| collect Z-score
	rm -f ${prot}/${relnam}_${refer_relnam}.Score_zsco
	for ((i=0;i<$CPU_num;i++))
	do
		rm -f ${prot}/${relnam}_${refer_relnam}_tmpout.$i
		if [ -s ${prot}/${relnam}_${refer_relnam}_zscore.$i ]
		then
			cat ${prot}/${relnam}_${refer_relnam}_zscore.$i >> ${prot}/${relnam}_${refer_relnam}.Score_zsco
		fi
		rm -f ${prot}/${relnam}_${refer_relnam}_zscore.$i
	done
	#--| calculate mean/vari
	awk '{print $6}' ${prot}/${relnam}_${refer_relnam}.Score_zsco | sort -g -r | tail -n+4 > ${prot}/${relnam}_${refer_relnam}.rank_zscore_val
	reso=`${LOCAL_HOME}/util/Stat_List ${prot}/${relnam}_${refer_relnam}.rank_zscore_val`
	MEAN=`echo $reso | cut -d ' ' -f 3`
	VARI=`echo $reso | cut -d ' ' -f 7`
	rm -f ${prot}/${relnam}_${refer_relnam}.rank_zscore_val
	rm -f ${prot}/${relnam}_${refer_relnam}.Score_zsco

	#--------- E-value ----------#
	#--| calculate E-value
	for ((i=0;i<$CPU_num;i++))
	do
		# screen output for 'proc=0'
		if [ $i -eq 0 ]   #-> for proc=0, we add option "-v"
		then
			addi=" -v "
		else
			addi=""
		fi
		# check list
		if [ ! -s ${prot}/${refer_relnam}.$i ]
		then
			continue
		fi
		# run program
		(${LOCAL_HOME}/${deepalign} ${addi} -f ${prot}/${refer_relnam}.$i -r $refer_db -q $query_pdb -j 0 -m 0 -p 0 -w ${prot}/${relnam}_${refer_relnam}_evalue.$i -s $score_func)&
		OUT=$?
		if [ $OUT -ne 0 ]
		then
			echo "${LOCAL_HOME}/${deepalign} ${addi} -f ${prot}/${refer_relnam}.$i -r $refer_db -q $query_pdb -j 0 -m 0 -p 0 -w ${prot}/${relnam}_${refer_relnam}_evalue.$i -s $score_func" >&2
			exit 1
		fi
	done
	wait
	#--| collect E-value
	rm -f ${prot}/${relnam}_${refer_relnam}.Score_evd
	for ((i=0;i<$CPU_num;i++))
	do
		rm -f ${prot}/${refer_relnam}.$i
		if [ -s ${prot}/${relnam}_${refer_relnam}_evalue.$i ]
		then
			cat ${prot}/${relnam}_${refer_relnam}_evalue.$i >> ${prot}/${relnam}_${refer_relnam}.Score_evd
		fi
		rm -f ${prot}/${relnam}_${refer_relnam}_evalue.$i
	done
	#--| calculate miu/beta
	awk '{print $a}' a=${sort_col} ${prot}/${relnam}_${refer_relnam}.Score_evd | sort -g -r | tail -n+4 > ${prot}/${relnam}_${refer_relnam}.rank_evalue_val
	${LOCAL_HOME}/util/Fitting_EVD ${prot}/${relnam}_${refer_relnam}.rank_evalue_val > ${output_root}/${relnam}_${refer_relnam}.pvalue_param
	rm -f ${prot}/${relnam}_${refer_relnam}.rank_evalue_val
	rm -f ${prot}/${relnam}_${refer_relnam}.Score_evd
fi


#================== Part 1.2 run main search for data_list ==================# 

if [ $rel_topk -ge 0 ] || [ $rel_topk -eq -2 ]
then
	#--------- echo -----------------#
	echo "step1: run main search for $data_list"

	#--------- preliminary ----------#
	#--| cut refer_list into N threads
	${LOCAL_HOME}/util/List_Div_Shuf $data_list $CPU_num $prot
	OUT=$?
	if [ $OUT -ne 0 ]
	then
		echo "${LOCAL_HOME}/util/List_Div_Shuf $data_list $CPU_num $prot" >&2
		exit 1
	fi
	#--| run DeepAlign for these N-cut refer_list
	deepalign="DeepAlign -u 0 -P 0 -e $MAXSIZE $options "

	#--------- main search ----------#
	#--| calculate main search
	for ((i=0;i<$CPU_num;i++))
	do
		# screen output for 'proc=0'
		if [ $i -eq 0 ]   #-> for proc=0, we add option "-v"
		then
			addi=" -v "
		else
			addi=""
		fi
		# check list
		if [ ! -s ${prot}/${data_relnam}.$i ]
		then
			continue
		fi
		# run program
		(${LOCAL_HOME}/${deepalign} ${addi} -f ${prot}/${data_relnam}.$i -r $data_db -q $query_pdb -m 2 -g $MEAN -h $VARI -c $tmsco -p 0 -w ${prot}/${relnam}_${data_relnam}.$i -s $score_func)&
		OUT=$?
		if [ $OUT -ne 0 ]
		then
			echo "${LOCAL_HOME}/${deepalign} ${addi} -f ${prot}/${data_relnam}.$i -r $data_db -q $query_pdb -m 2 -g $MEAN -h $VARI -c $tmsco -p 0 -w ${prot}/${relnam}_${data_relnam}.$i -s $score_func" >&2
			exit 1
		fi
	done
	wait

	#--| collect main search
	rm -f ${prot}/${relnam}_${data_relnam}.Score
	for ((i=0;i<$CPU_num;i++))
	do
		rm -f ${prot}/${data_relnam}.$i
		if [ -s ${prot}/${relnam}_${data_relnam}.$i ]
		then
			cat ${prot}/${relnam}_${data_relnam}.$i >> ${prot}/${relnam}_${data_relnam}.Score
		fi
		rm -f ${prot}/${relnam}_${data_relnam}.$i
	done
	sort -g -r -k ${sort_col} ${prot}/${relnam}_${data_relnam}.Score > ${output_root}/${relnam}_${data_relnam}.SortedScore
	rm -f ${prot}/${relnam}_${data_relnam}.Score
fi


#================== Part 1.3 re-align topK ==================# 

if [ $rel_topk -ne 0 ]
then
	#--------- echo -----------------#
	echo "step2: re-align $rel_topk"

	#--------- preliminary ----------#
	topk_list=${output_root}/${relnam}_${data_relnam}_topKlist
	topk_align=${output_root}/${relnam}_${data_relnam}_topKalign
	mkdir -p $topk_align

	#--------- consider topK by p-value ------#
	if [ $rel_topk -gt 0 ]
	then
		#--| generate topK
		pval_para=${output_root}/${relnam}_${refer_relnam}.pvalue_param
		sorted_score=${output_root}/${relnam}_${data_relnam}.SortedScore
		sorted_file=${prot}/${relnam}_${data_relnam}.SortedScore_${sort_col}
		awk '{print $a}' a=${sort_col} $sorted_score > $sorted_file
		topk_from_pval=`${LOCAL_HOME}/util/TopK_by_EVD $sorted_file $pval_para $pval`
		if [ $topk_from_pval -gt $rel_topk ]
		then
			rel_topk=$topk_from_pval
		fi
		rm -f $sorted_file
		#--| generate topKlist
		head -n $rel_topk ${output_root}/${relnam}_${data_relnam}.SortedScore | awk '{print $1}' > $topk_list
	else
		if [ $rel_topk -eq -1 ]      #-> scan ALL input list without filter
		then
			#--| generate topK
			rel_topk=$data_len
			cp $data_list $topk_list
		else                         #-> scan ALL filtered list
			#--| generate topK
			awk '{print $1}' ${output_root}/${relnam}_${data_relnam}.SortedScore > $topk_list
			filter_len=`wc $topk_list | awk '{print $1}'`
			rel_topk=$filter_len
		fi
	fi

	#--| cut refer_list into N threads
	${LOCAL_HOME}/util/List_Div_Shuf $topk_list $CPU_num $prot
	OUT=$?
	if [ $OUT -ne 0 ]
	then
		echo "${LOCAL_HOME}/util/List_Div_Shuf $topk_list $CPU_num $prot" >&2
		exit 1
	fi
	#--| run DeepAlign for these N-cut refer_list
	deepalign="DeepAlign -u 0 -P 0 -e $MAXSIZE $options "

	#--------- main search ----------#
	#--| calculate main search
	for ((i=0;i<$CPU_num;i++))
	do
		# screen output for 'proc=0'
		if [ $i -eq 0 ]   #-> for proc=0, we add option "-v"
		then
			addi=" -v "
		else
			addi=""
		fi
		# check list
		if [ ! -s ${prot}/${relnam}_${data_relnam}_topKlist.$i ]
		then
			continue
		fi
		# run program
		(${LOCAL_HOME}/${deepalign} ${addi} -f ${prot}/${relnam}_${data_relnam}_topKlist.$i -r $data_db -q $query_pdb -m 0 -p 1 -d $topk_align -w ${prot}/${relnam}_${data_relnam}_topKsco.$i -s $score_func)&
		OUT=$?
		if [ $OUT -ne 0 ]
		then
			echo "${LOCAL_HOME}/${deepalign} ${addi} -f ${prot}/${relnam}_${data_relnam}_topKlist.$i -r $data_db -q $query_pdb -m 0 -p 1 -d $topk_align -w ${prot}/${relnam}_${data_relnam}_topKsco.$i -s $score_func" >&2
			exit 1
		fi
	done
	wait

	#--| cut_template or not
	if [ $cut_alignment -eq 1 ]
	then
		# cut templates
		for i in `cat $topk_list`
		do
			${LOCAL_HOME}/util/Domain_Proc $topk_align/${i}-${relnam}.fasta ${prot}/${i}-${relnam}.fasta_cut 0 0 0 1
			${LOCAL_HOME}/util/PDB_File_Cut $data_db/$i.pdb ${prot}/${i}-${relnam}.fasta_cut_seq1 ${prot}/$i.pdb 0
		done
		# realign templates
		for ((i=0;i<$CPU_num;i++))
		do
			## screen output for 'proc=0'
			if [ $i -eq 0 ]   #-> for proc=0, we add option "-v"
			then
				addi=" -v "
			else
				addi=""
			fi
			# check list
			if [ ! -s ${prot}/${relnam}_${data_relnam}_topKlist.$i ]
			then
				continue
			fi
			## run program
			(${LOCAL_HOME}/${deepalign} ${addi} -f ${prot}/${relnam}_${data_relnam}_topKlist.$i -r $prot -q $query_pdb -m 0 -p 1 -i 0 -d $topk_align -w ${prot}/${relnam}_${data_relnam}_topKsco.$i -s $score_func)&
			OUT=$?
			if [ $OUT -ne 0 ]
			then
				echo "${LOCAL_HOME}/${deepalign} ${addi} -f ${prot}/${relnam}_${data_relnam}_topKlist.$i -r $prot -q $query_pdb -m 0 -p 1 -i 0 -d $topk_align -w ${prot}/${relnam}_${data_relnam}_topKsco.$i -s $score_func" >&2
				exit 1
			fi
		done
		wait
		# clear templates
		for i in `cat $topk_list`
		do
			rm -f ${prot}/${i}-${relnam}.fasta_cut*
			rm -f ${prot}/$i.pdb
		done
	fi

	#--| collect main search
	rm -f ${prot}/${relnam}_${data_relnam}.TopKScore
	for ((i=0;i<$CPU_num;i++))
	do
		rm -f ${prot}/${relnam}_${data_relnam}_topKlist.$i
		if [ -s ${prot}/${relnam}_${data_relnam}_topKsco.$i ]
		then
			cat ${prot}/${relnam}_${data_relnam}_topKsco.$i >> ${prot}/${relnam}_${data_relnam}.TopKScore
		fi
		rm -f ${prot}/${relnam}_${data_relnam}_topKsco.$i
	done
	sort -g -r -k ${sort_col} ${prot}/${relnam}_${data_relnam}.TopKScore > ${output_root}/${relnam}_${data_relnam}.SortedTopKScore
	rm -f ${prot}/${relnam}_${data_relnam}.TopKScore

	#--| output the result file
	if [ "$output_file" != "-1" ]     #-> need to output the detailed summary file
	then
		rank_simp=${output_file}_simp
		rank_file=${output_root}/${relnam}_${data_relnam}.SortedTopKScore
		rank_root=${output_root}/${relnam}_${data_relnam}_topKalign
		pval_para=${output_root}/${relnam}_${refer_relnam}.pvalue_param
		run_command="$0 $@"
		${LOCAL_HOME}/util/DeepSearch_Rank $relnam $rank_file $rank_root $pval_para $output_file "${run_command}" $pval $data_len $rel_topk > $rank_simp
		OUT=$?
		if [ $OUT -ne 0 ]
		then
			echo "${LOCAL_HOME}/util/DeepSearch_Rank $relnam $rank_file $rank_root $pval_para $output_file" >&2
			exit 1
		fi
	fi
fi


#--- remove tmp -----#
rm -rf $prot


#======================= exit ====================#
exit 0


