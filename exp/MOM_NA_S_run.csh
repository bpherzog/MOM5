#!/bin/csh -f
# Minimal runscript for MOM experiments

set type          = MOM_SIS       # type of the experiment
set name          = $1           
set platform      = cheyenne       # A unique identifier for your platform
#set platform      = yellowstone    # A unique identifier for your platform
set npes          = 8              # number of processor
                                   # Note: If you change npes you may need to change
                                   # the layout in the corresponding namelist

set root          = $cwd:h         # The directory in which you checked out src
set code_dir      = $root/src                         # source code directory
set workdir       = $root/work     # where the model is run and model output is produced
                                   # This is recommended to be a link to the $WORKDIR of the platform.
set expdir        = $workdir/$name
set inputDataDir  = $expdir/INPUT   # This is path to the directory that contains the input data for this experiment.
                                     # You should have downloaded and untared this directory from MOM4p1 FTP site.
set diagtable     = $inputDataDir/diag_table           # path to diagnositics table
set datatable     = $inputDataDir/data_table           # path to the data override table.
set fieldtable    = $inputDataDir/field_table          # path to the field table
set namelist      = $inputDataDir/input.nml            # path to namelist file

set executable    = $root/exec/$platform/$type/fms_$type.x      # executable created after compilation

#set archive       = $ARCHIVE/$type #Large directory to host the input and output data.



#===========================================================================
# The user need not change any of the following
#===========================================================================

#
# Users must ensure the correct environment file exists for their platform.
#
source $root/bin/environs.$platform  # environment variables and loadable modules

set mppnccombine  = $root/bin/mppnccombine.$platform  # path to executable mppnccombine
set time_stamp    = $root/bin/time_stamp.csh          # path to cshell to generate the date

set echo

# Check if the user has extracted the input data
  if ( ! -d $inputDataDir ) then
    echo "ERROR: the experiment directory '$inputDataDir' does not exist or does not contain input and preprocessing data directories!"
    echo "Please copy the input data from the MOM data directory. This may required downloading data from a remote git annex if you do not already have the data locally."
    echo "cd $root/data/archives"
    echo "git annex get $name.input.tar.gz"
    echo "mkdir -p $workdir"
    echo "cp $name.input.tar.gz $workdir"
    echo "cd $workdir"
    echo "tar zxvf $name.input.tar.gz"
    echo "Or use the --download option to do this automatically"
    exit 1
  endif

# setup directory structure
  if ( ! -d $expdir )         mkdir -p $expdir
  if ( ! -d $expdir/RESTART ) mkdir -p $expdir/RESTART

#
#Check the existance of essential input files
#
#  if ( ! -e $inputDataDir/grid_spec.nc ) then
#    echo "ERROR: required input file does not exist $inputDataDir/grid_spec.nc "
#    exit 1
#  endif
#  if ( ! -e $inputDataDir/ocean_temp_salt.res.nc ) then
#    echo "ERROR: required input file does not exist $inputDataDir/ocean_temp_salt.res.nc "
#    exit 1
#  endif



# --- make sure executable is up to date ---
  set makeFile = Makefile
  cd $executable:h
  make -f $makeFile
  if ( $status != 0 ) then
    unset echo
    echo "ERROR: make failed"
    exit 1
  endif
#-------------------------------------------

#Change to expdir

  cd $expdir

# Create INPUT directory. Make a link instead of copy
# 
if ( ! -d $expdir/INPUT   ) mkdir -p $expdir/INPUT

  if ( ! -e $namelist ) then
    echo "ERROR: required input file does not exist $namelist "
    exit 1
  endif
  if ( ! -e $datatable ) then
    echo "ERROR: required input file does not exist $datatable "
    exit 1
  endif
  if ( ! -e $diagtable ) then
    echo "ERROR: required input file does not exist $diagtable "
    exit 1
  endif
  if ( ! -e $fieldtable ) then
    echo "ERROR: required input file does not exist $fieldtable "
    exit 1
  endif

  cp $namelist   input.nml
  cp $datatable  data_table
  cp $diagtable  diag_table
  cp $fieldtable field_table 

#Preprocessings
  $root/exp/preprocessing.csh
  
#set runCommand = "$mpirunCommand $npes $executable >fms.out"
#set runCommand = "mpirun.lsf $executable >fms.out"
set runCommand = "$mpirunCommand $executable >fms.out"
echo "About to run the command $runCommand"

#   --- run the model ---

$runCommand
set model_status = $status
if ( $model_status != 0) then
    echo "ERROR: Model failed to run to completion"
    exit 1
endif

#----------------------------------------------------------------------------------------------
# generate date for file names ---
    set begindate = `$time_stamp -bf digital`
    echo 'begindate = ' $begindate
    if ( $begindate == "" ) set begindate = tmp`date '+%j%H%M%S'`
    set enddate = `$time_stamp -ef digital`
    if ( $enddate == "" ) set enddate = tmp`date '+%j%H%M%S'`
#    if ( -f time_stamp.out ) rm -f time_stamp.out
#----------------------------------------------------------------------------------------------
# get a tar restart file
  cd RESTART
  cp $expdir/input.nml .
  cp $expdir/*_table .
# combine netcdf files
  if ( $npes > 1 ) then
    #Concatenate blobs restart files. mppnccombine would not work on them.
    ncecat ocean_blobs.res.nc.???? ocean_blobs.res.nc
    rm ocean_blobs.res.nc.????
    set file_previous = ""
    set multires = (`ls *.nc.????`)
    foreach file ( $multires )
	if ( $file:r != $file_previous:r ) then
	    set input_files = ( `ls $file:r.????` )
              if ( $#input_files > 0 ) then
                 $mppnccombine -n4 $file:r $input_files
                 if ( $status != 0 ) then
                   echo "ERROR: in execution of mppnccombine on restarts"
                   exit 1
                 endif
                 rm $input_files
              endif
           else
              continue
           endif
           set file_previous = $file
       end
  endif

  cd $expdir
  mkdir history
  mkdir ascii
#----------------------------------------------------------------------------------------------
# rename ascii files with the date
  foreach out (`ls *.out`)
     mv $out ascii/$begindate.$out
  end

#----------------------------------------------------------------------------------------------
# combine netcdf files
  if ( $npes > 1 ) then
    #Don't combine blobs history files. They need special handling.
    mv ocean_blobs.nc.???? history/
    set file_previous = ""
    set multires = (`ls *.nc.????`)
    foreach file ( $multires )
	if ( $file:r != $file_previous:r ) then
	    set input_files = ( `ls $file:r.????` )
              if ( $#input_files > 0 ) then
                 $mppnccombine -n4 $file:r $input_files
                 if ( $status != 0 ) then
                   echo "ERROR: in execution of mppnccombine on restarts"
                   exit 1
                 endif
                 rm $input_files
              endif
           else
              continue
           endif
           set file_previous = $file
       end
  endif

#----------------------------------------------------------------------------------------------
# rename nc files with the date
  foreach ncfile (`/bin/ls *.nc`)
#     mv $ncfile history/$enddate.forecast.$ncfile
     mv $ncfile history/$ncfile
  end

  unset echo


echo end_of_run
echo "NOTE: Natural end-of-script."

#Archive the results

#cd $workdir
#tar cvf $name.output.tar --exclude=data_table --exclude=diag_table --exclude=field_table --exclude=fms_$type.x --exclude=input.nml --exclude=INPUT $name
#gzip $name.output.tar
#mv $name.output.tar.gz $archive/

exit 0
  
