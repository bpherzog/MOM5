#!/bin/csh -f
#### script to run MOM5 test simulation

##set exp_name  =  TEST_HIRES                          # experiment name
set exp_name  =  TEST_NA_S                             # experiment name
set root_dir  =  $cwd                                # dirrectory where this script starts
set exp_dir   =  $root_dir/exp                       # dirrectory where is MOM5 run script
set mom_run_dir =  $root_dir/work/$exp_name          # dirrectory where MOM5 runs
set mom_input_dir = $mom_run_dir/INPUT               # dirrectory where is MOM5 input
set mom_restart_dir = $mom_run_dir/RESTART           # dirrectory where are MOM5 restart files
set soda_archive = /glade/scratch/chepurin/$exp_name # dirrectory to archive results 

#### move RESTART files to the INPUT
  mv -f $mom_restart_dir/*  $mom_input_dir/            # move MOM5's restart files into the INPUT dirrectory

#### run MOM_TEST
  if ( -e $mom_input_dir/ocean_cor.res.nc ) then
    rm -f $mom_input_dir/ocean_cor.res.nc              # remove correctors file if it exists in the MOM5 
                                                       # input dirrectory  to run model in the forecast mode
    echo " "
    echo "ocean_cor.res.nc file was removed from $mom_input_dir"
    echo " "				
  endif

  if ( -e $mom_run_dir/time_stamp.out ) then
    rm -f $mom_run_dir/time_stamp.out                  # remove all time_stamp.out from MOM5 run dirrectory
    echo "all *.out files were rmoved from $mom_run_dir"
    echo
  endif
					   
  cd $exp_dir                                          # go to MOM5's run script dirrectory
##  ./MOM_TEST_run.csh  $exp_name                        # execute MOM_TEST_run script
##  ./MOM_NA_run.csh  $exp_name                         # execute MOM_NA_run script
  ./MOM_NA_S_run.csh  $exp_name                         # execute MOM_NA_S_run script

  echo "start tot arhcive results"
#### get model assimilation time 
  echo
  echo "===== get model assimilation time"
  echo
  cd $mom_run_dir                                      # go to MOM5 run dirrectory
  mv -f  ascii/*time_stamp.out ./time_stamp.out        # mv time_stamp.out file back
  set time_stamp = `tail -1 time_stamp.out`            # get last line from the time_stamp.out file
  set year_asm   = `printf "%.4d" $time_stamp[1]`      # get assimilation year
  set month_asm  = `printf "%.2d" $time_stamp[2]`      # get assimilation month
  set day_asm    = `printf "%.2d" $time_stamp[3]`      # get assimilation day
  set enddate    = $year_asm$month_asm$day_asm         # get data ssimilation time
#  rm -f time_stamp.out                                 # remove time_stamp.out from run directory
  echo
  echo "assimilation time -> $enddate"
  echo

#### archive results
  cd $root_dir
  
  cp -fr $mom_restart_dir $soda_archive/RESTARTS/$enddate.RESTART     # archive restart files
  mv -f $mom_run_dir/history/soda4_nh_* $soda_archive/ORIGINAL/      # archive test results

#end                                                  # end of mom_test run
