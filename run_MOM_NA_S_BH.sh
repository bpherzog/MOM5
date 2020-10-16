#!/bin/sh

rm -f MOM_NA_S.log MOM_NA_S.o*

qsub << EOF
#!/bin/tcsh

#PBS -A UMCP0009                             
#PBS -l walltime=12:00:00                   
#PBS -l select=15:ncpus=36:mpiprocs=36:mem=109GB              
##PBS -l select=16:ncpus=32:mpiprocs=32             
#PBS -N MOM_NA_S               
#PBS -j oe        
#PBS -q regular                             
#PBS -m abe
#PBS -M bherzog@umd.edu              

./na_s_run_BH.csh > MOM_NA_S.log

EOF
