#!/bin/sh

declare -A NAME
declare -A DESC
declare -A SECT
declare -A VERS

DESTDIR=collect-config

NAME[collect-config]="collect-config.sh"
DESC[collect-config]="save configuration in a repository"
SECT[collect-config]=1
VERS[collect-config]="1.13"

for f in "${!NAME[@]}" ; do  # gibt Indexliste aus
   if test "${NAME[$f]}.${SECT[$f]}.txt" -nt "${NAME[$f]}.${SECT[$f]}" ; then
      txt2man -t "${NAME[$f]}" -r "${DESC[$f]}" -v "${VERS[$f]}" -s "${SECT[$f]}" \
	 < "${NAME[$f]}.${SECT[$f]}.txt" > "${DESTDIR}-${VERS[collect-config]}/${NAME[$f]}.${SECT[$f]}" && \
      printf "created %-13s man page.\n" ${NAME[$f]};
   fi
done
