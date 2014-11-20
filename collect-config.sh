#!/bin/bash

#####################################################################
# Written and maintained by:
#    Stefan Jakobs <projects AT localside.net>
#
# Please send all comments, suggestions, bug reports,
#    etc, to <projects AT localside.net>.
#####################################################################
# Copyright (c) 2012-2014 Stefan Jakobs
# License GPL-3.0
#####################################################################
#
# Copy all config files to a fix location and check them in

## Variables ##
CONFIG="/etc/collect-config.conf"
METAFILE=".collect-config.meta"
VERSION='$Revision: 1.13 $'

RCSREPO=${RCSREPO:=RCS}
CIOPT="-q -u"
RCSOPT=""

WARN=1
ERR=2

## Functions ##
function usage {
   echo "${0##*/} [-l|--list-orphans] [-r|--remove-orphans]"
   echo "                  [-d|--diff [-R|--revision <rev>]]"
   echo "                  [--collect-config] [--check-permissions]"
   echo "                  [--check-packages] [--check-links]"
   echo "                  [-v|--version] [-?|-h|--help]"
   exit 1
}

function print_version {
   local myversion="${VERSION//Revision: /}"
   echo "Version: ${myversion//$/}"
}

# cp_ci <source1> [<source2> ...] <destination>
# copy file(s) to a file or directory and check it in.
# ENV: wrote=[0|1]; revision=1.[0-9]+
function cp_ci {
   local retval=0
   local myciopt="$CIOPT"
   # append revision to ci options:
   if [ -n "$revision" ]; then
      myciopt="-r${revision} ${CIOPT}"
   fi
   # check if ci exists
   if ! type ci &>/dev/null || ! type rcs &>/dev/null ; then
      echo "error: can not find rcs/ci"
      return 1;
   fi
   local msg="collect-config routine check-in"     # ci   : message
   local q="$1"   # source
   local z="$2"   # destination
   shift
   if [ -z "$q" ] || [ -z "$z" ]; then
      echo "cp_ci <source1> [<source2> ...] <destination>"
      return 1
   fi
   # check if we have more than one source
   while [ -n "$2" ]; do
      q="$q $1"
      z=$2
      shift
   done
   test -n "$DEBUG" && echo "q: $q"
   test -n "$DEBUG" && echo "z: $z"
   if [ -d $z ]; then # destination is a directory
      test -d $z/$RCSREPO || mkdir $z/$RCSREPO
      for f in $q; do
         # echo an error message if source file doesn't exist
         if [ -e "$f" ]; then
            # skip error message if source is a dir
            if ! [ -d "$q" ]; then
               local fbase="$(basename $f)"
               # copy file only when source is newer than destination
               if [ "$f" -nt "$z/$fbase" ]; then
                  test -n "$DEBUG" && echo "copy source: $q -> $z/$fbase"
                  if ! cp -fp $f $z/$fbase; then
                     echo "error: copy failed ($q -> $z/$fbase)"
                     retval=1
                     return
                  fi
               fi
               if ! rcsdiff -q $z/$fbase &>/dev/null; then
                  if rcs $RCSOPT -l $z/$fbase 2>/dev/null ; then
                     if ci $myciopt -m"$msg" $z/$fbase ; then
                        wrote=1   # signal caller that we used this revisionnumber
                     else
                        retval=1
                     fi
                  else
                     if ci $myciopt -i -t-"$HOSTNAME: $fbase" -m"$msg" $z/$fbase ; then
                        wrote=1   # signal caller that we used this revisionnumber
                     else
                        retval=1
                     fi
                  fi
               fi
            else
               echo "warning: directory $q skipped"
            fi
         else
            echo "error: source file $f doesn't exist"
            retval=1
         fi
      done
   else # destination is not a directory
      if [ -e "$q" ]; then
         # skip error message if dest is a dir
         if ! [ -d "$q" ]; then
            local zdir="$(dirname $z)"
            # copy file only when source is newer than destination
            if [ "$q" -nt "$z" ]; then
               test -n "$DEBUG" && echo "copy source: $q -> $z"
               if ! cp -fp $q $z; then
                  echo "error: copy failed ($q -> $z)"
                  retval=1
               fi
            fi
            test -d $zdir/$RCSREPO || mkdir $zdir/$RCSREPO
            if ! rcsdiff -q $z &>/dev/null; then
               if rcs $RCSOPT -l $z 2>/dev/null ; then
                  if ci $myciopt -m"$msg" $z; then
                     wrote=1   # signal caller that we used this revisionnumber
                  else
                     retval=1
                  fi
               else
                  if ci $myciopt -i -t-"$HOSTNAME: $z" -m"$msg" $z ; then
                     wrote=1   # signal caller that we used this revisionnumber
                  else
                     retval=1
                  fi
               fi
            fi
         else
            echo "warning: directory $q skipped"
         fi
      else
         echo "error: source file $q doesn't exist"
         retval=1
      fi
   fi
   return $retval
}

function get_revision {
   # check if meta data exists
   local  __metarev=$1
   if ! [ -r ${CONFDIR}/${METAFILE} ]; then
      # find highest revision number (assume major = 1)
      local max=0;
      while read file rev; do
         # if config dir is empty then rev will be NULL, so set it to zero.
         rev=${rev:-0}
         rev=${rev%;}
         if ! [[ "$rev" =~ [0-9]* ]]; then
            echo "warning: failure while searching highest revision (not a number)"
         else
            if [ "$max" -lt "${rev#*\.}" ]; then
               max=${rev#*\.}
            fi
         fi
      done <<< "$(grep -R "^head\b\s\s*[0-9]" ${CONFDIR}/* 2> /dev/null)"
      echo "revision=1.${max}" > ${CONFDIR}/${METAFILE}
   fi
   source ${CONFDIR}/.collect-config.meta
   local rev=$(echo "$revision + 0.1" | bc )
   eval $__metarev="'$rev'"
}

function set_revision {
   local rev=$1
   if [ -z "$rev" ]; then
      echo "error: failed to set revision (revision empty)"
   elif ! [[ "$rev" =~ [0-9]+\.[0-9]+ ]]; then
      echo "error: failed to set revision (wrong schema: $rev)"
   else
      # set new revision
      echo "revision=$rev" > ${CONFDIR}/${METAFILE}
      if [ $? -ne 0 ]; then
         echo "error: failed to write revision to ${CONFDIR}/${METAFILE}"
      fi
   fi
}

function get_diff {
   local rev2diff="$1"
   # show a diff of the system file and the repo file
   for dir in "${!COLLECTION[@]}"; do
      # skip directories quietly
      if [ -d "$CONFDIR/$dir" ]; then 
         for f in ${COLLECTION[$dir]}; do
            if [ -z "$rev2diff" ]; then
               # compare the system file with the repo file
               diff -u $f ${CONFDIR}/${dir}/${f##*/}
               #diff -u --ignore-matching-lines='$Revision.*$' --ignore-matching-lines='$Id.*$' \
               #      $f ${CONFDIR}/${dir}/${f##*/}
            else
               # compare the head with revision $rev2diff
               rcsdiff -q -r${rev2diff} -u ${CONFDIR}/${dir}/${f##*/}
            fi
         done
      fi
   done
}

function collect_config {
   get_revision revision
   local wrote=0
   # copy files and check them in
   for dir in "${!COLLECTION[@]}"; do
      if ! [ -d "$CONFDIR/$dir" ]; then
         mkdir -p $CONFDIR/$dir || break
      fi
      if [ -n "${COLLECTION[$dir]}" ]; then
         for f in ${COLLECTION[$dir]}; do
            # cp_ci needs to read $revision
            # cp_ci will set global variable wrote=1 if it checks in a file
            cp_ci $f $CONFDIR/$dir || \
               { echo "error: cp_ci failed for $f"; retval=1; }
         done
      fi
   done
   if [ $wrote -eq 1 ]; then
      set_revision $revision
   fi
}

function deb_or_rpm {
   # check if system uses deb or rpm
   deb=$(which dpkg-query 2>/dev/null)
   rpm=$(which rpm 2>/dev/null)
   distri=""
   
   if [ -n "$deb" ] && [ -z "$rpm" ]; then
      query="$deb -l"
      distri=debian
   elif [ -n "$rpm" ] && [ -z "$deb" ]; then
      query="$rpm -q"
      if [ -e /etc/SuSE-release ]; then
         inst="zypper -qn in"
         distri="suse"
      else
         inst="yum -qy install"
         distri="redhat"
      fi
   else
      echo "error: can not find package manager."
      exit $ERR
   fi
}

function check_packages {
   deb_or_rpm
   # check if all packages are installed
   for pac in "${!PACKAGE[@]}"; do
      for version in "${PACKAGE[$pac]}"; do
         if [ $distri = "debian" ]; then
            read stat package vers rest <<< \
               $($query $pac 2>/dev/null | tail -1)
            if [ "$stat" = "ii" ]; then
               if ! [[ "$vers" =~ ${version} ]]; then
                  echo "warning: $pac installed, but doesn't match version ($vers : $version)"
                  retval=$WARN
               fi
            else
               echo "error: $pac not installed"
               retval=$ERR
            fi
         elif [ $distri = "suse" ] || [ $distri = "redhat" ]; then
            [ -n "$version" ] && version="-${version}"
            result=$($query $pac 2>/dev/null)
            if [ "$?" -eq 0 ]; then    # package is installed
               if ! [[ "$result" =~ ${pac}${version} ]]; then
                  echo "warning: $pac installed, but does not match version (${pac}${version} : $result)."
                  retval=$WARN
               fi
            else
               echo "error: $pac not installed."
               retval=$ERR
            fi
         fi
      done
   done
}

function check_hardlinks {
   # check if hardlinks exist
   for file in "${!HARDLINK[@]}"; do
      if ! [ -r "$file" ]; then
         echo "error: hardlink: can not access $file"
         retval=$ERR
      else
         read inode linkcnt <<<"$(stat --format '%i %h' $file)"
         declare -i cnt=0
         for link in ${HARDLINK[$file]}; do
            if ! [ -r "$link" ]; then
               echo "error: hardlink: can not access $link"
               retval=$ERR
            else
               cnt=$cnt+1
               if [ "$inode" -ne "$(stat --format %i $link)" ]; then
                  echo "error: hardlink: $link is not hardlinked to $file"
                  retval=$ERR
               fi
            fi
         done
         if [ $linkcnt -lt $cnt ]; then
            echo "error: hardlink: $file has $cnt hardlinks instead of $cnt"
            retval=$ERR
         fi
      fi
   done
}

function check_softlinks {
   # check if softlinks exist
   for file in "${!SOFTLINK[@]}"; do
      if ! [ -r "$file" ]; then
         echo "error: softlink: can not access $file"
         retval=$ERR
      else
         for link in ${SOFTLINK[$file]}; do
            if ! [ -r "${link}" ]; then
               echo "error: softlink: can not access link $link"
               retval=$ERR
            fi
            islink="$(readlink $link)"
            if [ -z "$islink" ] || ! [[ "$file" =~ ${islink}$ ]]; then
               echo "error: softlink: $link is not a link to $file"
               retval=$ERR
            fi
         done
      fi
   done
}

function check_perms {
   # check permissions, owner and group
   # $PERMISSION[file]='PERM:USER:GROUP'
   for file in "${!PERMISSION[@]}"; do
      IFS=: read perm owner group <<< "${PERMISSION[$file]}"
      while IFS=: read isperm isowner isgroup isfile; do
         if [ -z "$isfile" ]; then
            echo "error: permission: $file causes wrong result"
         else
            if [ -n "$perm" ] && ! [[ "$perm" =~ ${isperm}$ ]]; then 
               echo "error: permission: $isfile has permissions $isperm, but should have $perm"
               retval=$ERR
            fi
            if [ -n "$owner" ] && [ "$owner" != "$isowner" ]; then
               echo "error: permission: $isfile is owned by $isowner, but should be owned by $owner"
               retval=$ERR
            fi
            if [ -n "$group" ] && [ "$group" != "$isgroup" ]; then
               echo "error: permission: $isfile group is $isgroup, but should be $group"
               retval=$ERR
            fi
         fi
      done <<< "$(stat --format %a:%U:%G:%n $file)" 
   done
}

function find_orphans {
   pushd $CONFDIR > /dev/null
   local orphans=""
   local filelist=$(find ./ -mindepth 2 ! -name '*,v' ! -name '*RCS')
   for path in $filelist; do
      local path=${path#\./}     # remove leading ./
      local dir_only=${path%/*}
      local file_only=${path##*/}
      local orphaned=1           # assume file is an orphan
      # check if path is a directory and an key of COLLECTION
      # if yes, then it is still valid
      if [ -n "${COLLECTION[${path}]}" ]; then
         orphaned=0
      elif [ -n "${COLLECTION[${dir_only}]}" ]; then
         for file in ${COLLECTION[${dir_only}]} ; do
            if [ "${file##*/}" == '*' ] || [[ "${file_only}" =~ "${file##*/}" ]] ; then
               orphaned=0 
               break
            fi
         done
      fi
      if [ $orphaned -eq 1 ]; then
         orphans="${CONFDIR}${path} ${orphans}"
      fi
   done
   popd > /dev/null
   echo "$orphans"
}

function list_orphans {
   local orphans=$(find_orphans)
   for item in $orphans; do
      echo "orphaned: $item"
   done
}

function remove_orphans {
   local orphans=$(find_orphans)
   if [ -n "$orphans" ]; then
      echo "remove orphaned files:"
   fi
   for item in $orphans; do
      rm -vrf $item
   done
}

#### Main ####

# check if the config is available
if [ -r "$CONFIG" ]; then
   source $CONFIG
   if [ -z $CONFDIR ]; then
      echo "error: \$CONFDIR is empty, please edit $CONFIG"
      exit $ERR
   else
      test -d $CONFDIR || mkdir -p $CONFDIR || \
        { echo "error: can not create $CONFDIR";  exit 1; }
      if ! [ -w $CONFDIR ]; then
         echo "error: can not write into $CONFDIR"
         exit $ERR
      fi
   fi
else
   echo "error: can not read $CONFIG"
   exit $ERR
fi

# set global variables
opt_d=0
opt_R=0

# evaluate arguments
ARGS=$(getopt -o "dlrR:?hv" \
              -l "list-orphans,remove-orphans,check-permissions,collect-config,check-packages,check-links,diff,revision:,help,version" \
              -n "$0" -- "$@")
if [ $? -ne 0 ]; then
   usage;
fi
eval set -- "$ARGS"  # set $@ to $ARGS

# run all checks if there is no argument
if [ "$1" == "--" ]; then
   collect_config
   check_packages
   check_hardlinks
   check_softlinks
   check_perms
else
   while [ -n "$1" ]; do
      case "$1" in
         -d|--diff)
            opt_d=1
            shift ;;
         -l|--list-orphans)
            list_orphans
            shift ;;
         -r|--remove-orphans)
            remove_orphans
            shift;;
         -R|--revision)
            opt_R=1
            rev2diff="$2"
            # call function $2
            shift 2 ;;
         #--something) with argument
         #if [ -n "$2" ]; then echo "Argument: $2"; fi
         # shift 2;;
         --collect-config)
            collect_config
            shift ;;
         --check-packages)
            check_packages
            shift;;
         --check-links)
            check_hardlinks
            check_softlinks
            shift ;;
         --check-permissions)
            check_perms
            shift ;;
         -h|-\?|--help)
            usage
            shift ;;
         -v|--version)
            print_version
            shift ;;
         --)
            shift
            break ;;
      esac
   done
fi

# evaluate options
if [ $opt_d -eq 1 ]; then
   if [ $opt_R -eq 1 ]; then
      get_diff "$rev2diff"
   else # R=0 && d=1
      get_diff
   fi
else
   if [ $opt_R -eq 1 ]; then
      get_revision revision
      echo "revision: $revision"
   fi
fi

exit $retval
