#!/bin/csh -f
# 
#  This initialization file needs to be run once per installation.                ---
#  Rerunning will delete an existing database and install the current version     ---
#  of the Speciation Modeling Tool.                                               ---
#
#  This application requires that it be run on the postgres server and that       ---
#  local connections are trusted (i.e. no passwords required).                    ---
#
#============================================================================================
#
#  The following environment variables are required before the Speciation Tool 
#  initialization (see Assigns.sptool file):
#
#      SPTOOL_SRC_HOME - set to the Speciation Tool source code directory
#      SPTOOL_DB       - set to the database name for this installation
#
#      IDIR			- shared data directory
#      Import data files:
#      MECHANISM		- gas mechanism definitions
#      MECHANISMPM		- PM mechanism definitions
#      MECHANISM_DESCRIPTION	- description of chemical mechanisms	
#      INVTABLE			- invtable
#      CARBONS			- carbon assignments
#      PROFILES_STATIC		- static profiles
#      PROFILES_GAS		- gas profile properties
#      WEIGHTS_GAS		- gas profile weights
#      PROFILES_PM		- pm profile properties
#      WEIGHTS_PM		- pm profile weights
#      SPECIES_PROPERTIES	- species properties
#      SPECIES_RENAME		- rename species for AQM requirements
#      CAMX_FCRS		- list of profiles where FPRM is renamed FCRS (CAMx support)
#      VBS_SVOC_FACTORS 	- SVOC saturation concentrations by profile id
#      VBS_IVOC_FACTORS 	- IVOC non-methane fraction by profile id
#      IVOC_SPECIES		- IVOC species molecular weights
#
#  Optional environment variable:
#      SPTOOL_USER     - postgres user name; will default to current user (whoami)
#      POSTGRES_BIN    - location of postgres execuatable; defaults to system default (which)
#
#============================================================================================
#  v4.0
#  Sep 2016
#
#  Note - calls to the EMF have been commented out for the stand alone public release.
#============================================================================================

set script_name = init_sptooldb_v4.0.csh
set exitstatus = 0

#============================================================================================
# Verify that required environment variables are set
#
echo " "
if ( $?SPTOOL_SRC_HOME ) then
    echo "SPTOOL_SRC_HOME = $SPTOOL_SRC_HOME"
    if  (! -d $SPTOOL_SRC_HOME) then
        set exitstatus = 1
        echo "       ERROR: This is not a directory."
    endif
else
    set exitstatus = 1
    echo "ERROR: Required environment variable SPTOOL_SRC_HOME not set"
    echo "       in script $script_name"
endif

if ( $?PERL_DBI ) then
    echo "PERL_DBI = $PERL_DBI"
else
    set exitstatus = 1
    echo ""
    echo "ERROR: Required environment variable PERL_DBI not set"
    echo "       in script $script_name"
    echo ""
endif

if ( $?SPTOOL_DB ) then
    echo "New database: SPTOOL_DB = $SPTOOL_DB"
else
    set exitstatus = 1
    echo "ERROR: Required environment variable SPTOOL_DB not set"
    echo "       in script $script_name"
endif

if ( $exitstatus != 0 ) then
    ## log w/ EMF server that script is running
    $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: $script_name aborted because missing key environmental variables SPTOOL_SRC_HOME and SPTOOL_DB" -t "e"
    echo ""
    echo "ABORT: Required environment variables are undefined. Update and source the Assigns.sptool file."
    echo "ABORT: $script_name script aborted with errors."
    echo " "
    exit ( 1 )
endif
#
#============================================================================================
# Verify that optional environment variables are set
#
# Determine or set current user
if ( $?SPTOOL_USER ) then
    echo "SPTOOL_USER = $SPTOOL_USER"
else
    set SPTOOL_USER = `whoami`
    echo "SPTOOL_USER = $SPTOOL_USER"
endif

# Determine or set which Perl is being used
if ( $?PERL_BIN ) then
    echo "PERL_BIN = $PERL_BIN"
else
    set temp = `which perl`
    set PERL_BIN = `dirname $temp`
    echo "PERL_BIN = $PERL_BIN"
endif

set PGPASSWORD=$SPTOOL_PWD

echo "SPTOOL_PWD = $SPTOOL_PWD"
echo "PGPASSWORD = $PGPASSWORD"
set db_conn = "host=127.0.0.1 user=$SPTOOL_USER password=$SPTOOL_PWD dbname=postgres"
echo "db_conn = $db_conn"

# Determine or set which psql is being used
if ( $?POSTGRES_BIN ) then
    echo "POSTGRES_BIN = $POSTGRES_BIN"

    $POSTGRES_BIN/psql "$db_conn" -l < /dev/null >& /dev/null

#    $POSTGRES_BIN/psql -h 127.0.0.1 -l -U $SPTOOL_USER < /dev/null >& /dev/null 
    if ( $status != 0 ) then
        echo " "
        echo "ERROR: PostgreSQL not found1."
        echo "       Check software requirements."
        echo " "
        exit ( 1 )
    endif
else
    psql "$db_conn" -l < /dev/null >& /dev/null
    if ( $status != 0 ) then
       echo " "
       echo "ERROR: PostgreSQL not found2."
       echo "       Check software requirements."
       echo " "
       exit ( 1 )
    else
       set temp = `which psql`
       set POSTGRES_BIN = `dirname $temp`
       echo "POSTGRES_BIN = $POSTGRES_BIN"
    endif
endif

echo "db_conn = $db_conn"

#============================================================================================
#  drop, create db, create language, create shared schema, grant permissions
#
    $POSTGRES_BIN/psql "$db_conn" -c "drop database $SPTOOL_DB"
#$POSTGRES_BIN/dropdb "$db_conn" $SPTOOL_DB  ! Force user to dropdb to protect existing dbs
    $EMF_CLIENT -k $EMF_JOBKEY -m "Creating database $SPTOOL_DB"  ## log w/ EMF server

set db_conn = "host=127.0.0.1 user=$SPTOOL_USER password=$SPTOOL_PWD dbname=postgres"
#set db_conn = "postgres":"//$SPTOOL_USER":"$SPTOOL_PWD@127.0.0.1":"5432/postgres"
#echo "db_conn = $db_conn"

$POSTGRES_BIN/psql "$db_conn" -c "create database $SPTOOL_DB"
#$POSTGRES_BIN/createdb "$db_conn" $SPTOOL_DB
if ( $status != 0 ) then
    set errMsg = "ERROR: failed to create a new database $SPTOOL_DB. This usually means the database already exists."
    echo $errMsg
    echo "       To replace the existing database type 'dropdb $SPTOOL_DB' from the command line and restart $script_name."
    $EMF_CLIENT -k $EMF_JOBKEY -m "$errMsg" -t "e"
    exit ( 1 )
else
    echo "Database $SPTOOL_DB created"
endif

set db_conn = "host=127.0.0.1 user=$SPTOOL_USER password=$SPTOOL_PWD dbname=$SPTOOL_DB"
#echo "db_conn = $db_conn"

# Let's assume template1 already has plpgsql installed, if so all new databases will get this language automatically.  https://www.postgresql.org/docs/9.6/static/xplang-install.html
# check to see if language exists before create
#set list = `$POSTGRES_BIN/createlang "$db_conn" -l $SPTOOL_DB | grep plpgsql`
#if ( "$list" =~ *plpgsql* ) then
#   echo "NOTICE: plpgsql language exists."
#else
#   $POSTGRES_BIN/createlang "$db_conn" plpgsql $SPTOOL_DB
#   if ( $status != 0 ) then
#       set errMsg = "ERROR: psql failed to create plpgsql language in database"
#       echo $errMsg
#       #emf#       $EMF_CLIENT -k $EMF_JOBKEY -m "$errMsg" -t "e" 
#       exit ( 1 ) 
#   endif
#endif

$POSTGRES_BIN/psql "$db_conn" -c "create schema shared" $SPTOOL_DB
if ( $status != 0 ) then
    set errMsg = "ERROR: psql failed to create shared schema"
    echo $errMsg
    $EMF_CLIENT -k $EMF_JOBKEY -m "$errMsg" -t "e"
    exit ( 1 )
else
    echo "Shared schema created"
endif
$POSTGRES_BIN/psql "$db_conn" -c "grant create on database $SPTOOL_DB to public" $SPTOOL_DB
if ( $status != 0 ) then
    set errMsg = "ERROR: psql failed to grant permissions on schema"
    echo $errMsg
    $EMF_CLIENT -k $EMF_JOBKEY -m "$errMsg" -t "e"
    exit ( 1 )
else
    echo "Create permissions granted on $SPTOOL_DB"
endif
$POSTGRES_BIN/psql "$db_conn" -c "grant all on schema shared to public" $SPTOOL_DB
if ( $status != 0 ) then
    set errMsg = "ERROR: psql failed to grant permissions on schema"
    echo $errMsg
    $EMF_CLIENT -k $EMF_JOBKEY -m "$errMsg" -t "e"
    exit ( 1 )
else
    echo "All permissions granted on shared schema"
endif
#
#============================================================================================
# Import database Speciation Tool functions and initialize tables
# Include ON_ERROR_STOP=1 so that it will give a non-zero error status if it
# fails to run all commands in file (otherwise a failure will return 0)
#
echo "Defining custom functions and initializing tables.  ...working"
$EMF_CLIENT -k $EMF_JOBKEY -m "Definining custom functions and initializing tables"  ## log w/ EMF server

$POSTGRES_BIN/psql "$db_conn" -v ON_ERROR_STOP=1 -q -f $SPTOOL_SRC_HOME/drop_table.sql $SPTOOL_DB
if ( $status != 0 ) then
    set errMsg = "ERROR: psql failed to initialize drop table function (drop_table.sql)"
    echo $errMsg
    $EMF_CLIENT -k $EMF_JOBKEY -m "$errMsg" -t "e"
    exit ( 1 )
endif

#$POSTGRES_BIN/psql "$db_conn" -v ON_ERROR_STOP=1 -q -f $SPTOOL_SRC_HOME/truncate_table.sql $SPTOOL_DB
#if ( $status != 0 ) then
#    set errMsg = "ERROR: psql failed to initialize truncate table function (truncate_table.sql)"
#    echo $errMsg
#    $EMF_CLIENT -k $EMF_JOBKEY -m "$errMsg" -t "e"
#    exit ( 1 )
#endif

$POSTGRES_BIN/psql "$db_conn" -v ON_ERROR_STOP=1 -q -t -f $SPTOOL_SRC_HOME/table_defs.sql $SPTOOL_DB
if ( $status != 0 ) then
    set errMsg = "ERROR: psql failed to initialize shared tables (table_defs.sql)"
    echo $errMsg
    $EMF_CLIENT -k $EMF_JOBKEY -m "$errMsg" -t "e"
    exit ( 1 )
endif

$POSTGRES_BIN/psql "$db_conn" -v ON_ERROR_STOP=1 -q -t -f $SPTOOL_SRC_HOME/table_inps.sql $SPTOOL_DB
if ( $status != 0 ) then
    set errMsg = "ERROR: psql failed to define scenario tables function (table_inps.sql) "
    echo $errMsg
    $EMF_CLIENT -k $EMF_JOBKEY -m "$errMsg" -t "e"
    exit ( 1 )
endif

$POSTGRES_BIN/psql "$db_conn" -v ON_ERROR_STOP=1 -q -t -f $SPTOOL_SRC_HOME/make_splits.sql $SPTOOL_DB
if ( $status != 0 ) then
    set errMsg = "ERROR: psql failed to define split factor functions (make_splits.sql)"
    echo $errMsg
    $EMF_CLIENT -k $EMF_JOBKEY -m "$errMsg" -t "e"
    exit ( 1 )
endif

$POSTGRES_BIN/psql "$db_conn" -v ON_ERROR_STOP=1 -q -t -f $SPTOOL_SRC_HOME/make_pm_splits.sql $SPTOOL_DB
if ( $status != 0 ) then
    set errMsg = "ERROR: psql failed to define PM split factor functions (make_pm_splits.sql)"
    echo $errMsg
    $EMF_CLIENT -k $EMF_JOBKEY -m "$errMsg" -t "e"
    exit ( 1 )
endif

$POSTGRES_BIN/psql "$db_conn" -v ON_ERROR_STOP=1 -q -t -f $SPTOOL_SRC_HOME/prep_out.sql $SPTOOL_DB
if ( $status != 0 ) then
    set errMsg = "ERROR: psql failed to define output functions (prep_out.sql)"
    echo $errMsg
    $EMF_CLIENT -k $EMF_JOBKEY -m $errMsg -t "e"
    exit ( 1 )
endif

echo "Speciation Tool functions and tables successfully defined in $SPTOOL_DB."
echo

#
#============================================================================================
# Import shared data to Speciation Tool database shared schema
# File names set in environment variables (see Assigns.sptool).
# Argument list for import_rawdata.pl is <database name> <table name identifier> <inputfile>
#

# First check that required files are defined
if ( ! $?MECHANISM && ! $?MECHANISMPM ) then
   echo
   echo "===>>>  ABORT <<<==="
   echo "===>>>  ABORT <<<===        No chemical mechanism inputs provided for import."
   echo "===>>>  ABORT <<<==="
   echo
   echo
   exit ( 1 )
endif
if ( ! $?SPECIES_PROPERTIES ) then
   echo
   echo "===>>>  ABORT <<<==="
   echo "===>>>  ABORT <<<===        No SPECIES PROPERTIES input provided for import."
   echo "===>>>  ABORT <<<==="
   echo
   echo
   exit ( 1 )
endif
if ( ! $?INVTABLE ) then
   echo
   echo "===>>>  ABORT <<<==="
   echo "===>>>  ABORT <<<===        No INVTABLE input provided for import."
   echo "===>>>  ABORT <<<==="
   echo
   echo
   exit ( 1 )
endif

set dataset = mechanisms
if $?MECHANISM then
    echo "Importing $dataset $MECHANISM"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing $dataset"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB mechanism $MECHANISM
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $MECHANISM"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing $dataset" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (PM mechanisms)
if $?MECHANISMPM then
    echo "Importing $dataset $MECHANISMPM"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing $dataset"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB mechanismPM $MECHANISMPM
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $MECHANISMPM"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing $dataset" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (mechanism descriptions)
if $?MECHANISM_DESCRIPTION then
    echo "Importing $dataset $MECHANISM_DESCRIPTION"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing $dataset"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB mechanism_description $MECHANISM_DESCRIPTION
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $MECHANISM_DESCRIPTION"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing $dataset" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (inventory table)
echo "Importing $dataset $INVTABLE"
$EMF_CLIENT -k $EMF_JOBKEY -m "Importing $dataset"  ## log w/ EMF server
$PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB invtable $INVTABLE
if ( $status != 0 ) then
    echo "ERROR: perl script failed for importing $dataset file $INVTABLE"
    $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing $dataset" -t "e"
    exit ( 1 )
endif

set dataset = (carbons table)
if $?CARBONS then
    echo "Importing $dataset $CARBONS"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing $dataset"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB carbons $CARBONS
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $CARBONS"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing $dataset" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (static profiles)
if $?PROFILES_STATIC then
    echo "Importing $dataset $PROFILES_STATIC"
    #emf#	if ( $?PROFILES_STATIC ) then ## only import if static E.V. is set
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing $dataset"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB static $PROFILES_STATIC
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $PROFILES_STATIC"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing $dataset" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (gas profiles)
if $?PROFILES_GAS then
    echo "Importing $dataset $PROFILES_GAS"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing gas profile properties"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB gas_profiles $PROFILES_GAS
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $PROFILES_GAS"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing gas profile properties" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (gas profile weights)
if $?WEIGHTS_GAS then
    echo "Importing $dataset $WEIGHTS_GAS"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing gas profile weights"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB gas_profile_weights $WEIGHTS_GAS
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $WEIGHTS_GAS"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing gas profile weights" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (PM profiles)
if $?PROFILES_PM then
    echo "Importing $dataset $PROFILES_PM"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing PM profile properties"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB pm_profiles $PROFILES_PM
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $PROFILES_PM"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing PM profile properties" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (PM profile weights)
if $?WEIGHTS_PM then
    echo "Importing $dataset $WEIGHTS_PM"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing PM profile weights"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB pm_profile_weights $WEIGHTS_PM
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $WEIGHTS_PM"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing PM profile weights" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (species mapping)
if $?SPECIES_RENAME then
    echo "Importing $dataset $SPECIES_RENAME"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing species name map"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB rename_species $SPECIES_RENAME
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $SPECIES_RENAME"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing species rename map" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (species properties)
if $?SPECIES_PROPERTIES then
    echo "Importing $dataset $SPECIES_PROPERTIES"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing species properties"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB species $SPECIES_PROPERTIES
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $SPECIES_PROPERTIES"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing species properties" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (CAMx FCRS)
if $?CAMX_FCRS then
    echo "Importing $dataset $CAMX_FCRS"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing CAMx FRCS"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB camx_fcrs $CAMX_FCRS
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $CAMX_FCRS"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing camx fcrs" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (VBS SVOC factors)
if $?VBS_SVOC_FACTORS then
    echo "Importing $dataset $VBS_SVOC_FACTORS"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing VBS SVOC FACTORS"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB  vbs_svoc_factors $VBS_SVOC_FACTORS
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $VBS_SVOC_FACTORS"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing VBS SVOC factors" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (VBS IVOC factors)
if $?VBS_IVOC_FACTORS then
    echo "Importing $dataset $VBS_IVOC_FACTORS"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing VBS IVOC FACTORS"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB  vbs_ivoc_factors $VBS_IVOC_FACTORS
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $VBS_IVOC_FACTORS"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing VBS IVOC factors" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

set dataset = (IVOC species)
if $?IVOC_SPECIES then
    echo "Importing $dataset $IVOC_SPECIES"
    $EMF_CLIENT -k $EMF_JOBKEY -m "Importing IVOC SPECIES"  ## log w/ EMF server
    $PERL_BIN/perl $SPTOOL_SRC_HOME/import_rawdata.pl $SPTOOL_DB  ivoc_species $IVOC_SPECIES
    if ( $status != 0 ) then
        echo "ERROR: perl script failed for importing $dataset file $IVOC_SPECIES"
        $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: perl script failed for importing IVOC species" -t "e"
        exit ( 1 )
    endif
else
   echo "===>>> WARNING <<<==="
   echo "===>>> WARNING <<<===        No $dataset file defined for import.  "
   echo "===>>> WARNING <<<==="
   echo 
   echo 
   echo 
endif

echo
echo "Speciation Tool shared data successfully imported"
echo
echo "Completed: `date`"
echo
exit( 0 )
