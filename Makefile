#######################################################################
#
# Makefile für collect-config 
# ---------------------------
# Beschreibung:
# Dieses Makefile konfiguriert bzw. setzt einen Host zurück auf die
# durch collect-config.conf und dessen Repository definierte
# Konfiguration.
#######################################################################

SHELL:=/bin/bash
ROOT:=
CONFIG:=/opt/config

COLLECTBIN=/usr/sbin/collect-config.sh

#
# High-level Befehle
#
all: dirs.done collect-config.done profile.done

install: packages.done dirs.done collect-config.done links

links: hardlink.done softlink.done permission.done

clean:
	@rm -f \
	   collect-config.make \
	   *.done 

# include other makefiles
-include collect-config.make

#
# Rezepte für die Dateien, die indexiert/regeneriert werden müssen
#

# SUDO_USER wird für ci und andere Späße benötigt. Sorge dafür, dass es
# in jeder Bash-Sitzung zur Verfügung steht.
# DEPRECATED #
profile.done:
	@echo "erstelle neue $(ROOT)/root/.profile"
	@if ! [ -e $(ROOT)/root/.profile ] || ! grep "^export SUDO_USER" $(ROOT)/root/.profile; then \
	   echo '# set SUDO_USER; ce needs it' >> $(ROOT)/root/.profile; \
	   echo 'tty=$$(/usr/bin/tty 2> /dev/null)' >> $(ROOT)/root/.profile; \
	   echo 'test $$? -ne 0 && tty=""' >> $(ROOT)/root/.profile; \
	   echo 'export SUDO_USER=$$(who| while read u t x; do test "$$tty" = "/dev/$$t" && echo $$u; done)' >> $(ROOT)/root/.profile; \
	fi
	@touch $@

# Erstelle alle Systemverzeichnisse, die in collect-config.conf genannt werden
dirs.done: etc/collect-config.conf 
	@unset DIRS; \
	echo "create directories ..."; \
	source etc/collect-config.conf; \
	for dir in "$${!COLLECTION[@]}"; do \
	   for f in $${COLLECTION[$$dir]}; do \
	      DIRS="$${f%/*}\n$$DIRS"; \
	   done; \
	done; \
	for dir in "$${!HARDLINK[@]}"; do \
	   for f in $${HARDLINK[$$dir]}; do \
	      DIRS="$${f%/*}\n$$DIRS"; \
	   done; \
	done; \
	for dir in "$${!SOFTLINK[@]}"; do \
	   for f in $${SOFTLINK[$$dir]}; do \
	      DIRS="$${f%/*}\n$$DIRS"; \
	   done; \
	done; \
	while read line; do \
	   test -d $(ROOT)/$$line || mkdir -p $(ROOT)/$$line || exit 1; \
	done <<< "$$(echo -e "$$DIRS" | sort -u)"
	@touch $@;

# Erzeuge ein Makefile, das die Dateien aus dem Repository zurück ins
# System installiert. Für die eigentliche Installation muss dann
# collect-config.done aufgerufen werden.
collect-config.make: etc/collect-config.conf Makefile
	@unset ALL; \
	source etc/collect-config.conf; \
	echo "#####################################################################" > $@; \
	echo "# DO NOT EDIT. Generated makefile" >> $@; \
	echo "#####################################################################" >> $@; \
	for dir in in "$${!COLLECTION[@]}"; do \
	   for f in $${COLLECTION[$$dir]}; do \
	      echo "$(ROOT)$$f: $$dir/$${f##*/}" >> $@; \
	      echo -e "\t@cp -puv $$dir/$${f##*/} \$$@" >> $@; \
	      echo >> $@; \
	      ALL="$$ALL $(ROOT)$$f"; \
	   done; \
	done; \
	echo "collect-config.done: dirs.done $$ALL" >> $@; \
	echo -e "\t@touch \$$@" >> $@;


# Checke die in /etc/collect-config.conf aufgeführten Dateien ins
# Repository ein, d.h. rufe collect-config.sh auf.
run-collect-config:
	@echo "run collect-config.sh"
	@test -x $(COLLECTBIN) && $(COLLECTBIN)

# Überprüfe, ob alle Pakete installiert sind.
# Wenn nicht, dann versuche sie zu installieren.
packages.done: etc/collect-config.conf
	@unset ALL; \
	source etc/collect-config.conf; \
	retval=0; \
	deb=$$(which dpkg-query 2>/dev/null); \
	rpm=$$(which rpm 2>/dev/null); \
	distri=""; \
	if [ -n "$$deb" ] && [ -z "$$rpm" ]; then \
	   query="$$deb -l"; \
	   distri=debian; \
	elif [ -n "$$rpm" ] && [ -z "$$deb" ]; then \
	   query="$$rpm -q"; \
	   if [ -e /etc/SuSE-release ]; then \
	      inst="zypper -qn in"; \
	      distri="suse"; \
	   else \
	      inst="yum -qy install"; \
	      distri="redhat"; \
	   fi; \
	else \
	   echo "error: can not find package manager"; \
	   exit 1; \
	fi; \
	echo "install $$distri packages ..."; \
	for pac in "$${!PACKAGES[@]}"; do \
	   for version in "$${PACKAGES[$$pac]}"; do \
	      if [ $$distri = "debian" ]; then \
	         read stat package vers rest <<< \
	            $$($$query $$pac 2>/dev/null | tail -1); \
	         if [ "$$stat" = "ii" ]; then \
	            if [[ "$$vers" =~ $${version} ]]; then \
	               echo "OK: $$pac installed and match version ($${BASH_REMATCH[0]})"; \
	            else \
	               echo "error: $$pac installed, but doesn't match version ($$vers : $$version)"; \
	               retval=1; \
	            fi; \
	         else \
	            echo "try: install $$pac"; \
	            if [ -n "$$version" ]; then \
	               sep="="; \
	            else \
	               sep=""; \
	            fi; \
	            if ! apt-get -qq install $${pac}$${sep}$${version} 2>/dev/null; then \
	               echo "error: installation failed - $${pac}$${sep}$${version}"; \
	               retval=1; \
	            fi; \
	         fi; \
	      elif [ $$distri = "suse" ] || [ $$distri = "redhat" ]; then \
	         [ -n "$$version" ] && version="-$${version}"; \
	         result=$$($$query $$pac 2>/dev/null); \
	         if [ "$$?" -eq 0 ]; then \
	            if [[ "$$result" =~ $${pac}$${version} ]]; then \
	               echo "OK: $$pac installed and match version ($${BASH_REMATCH[0]})"; \
	            else \
	               echo "error: $$pac installed, but does not match version ($${pac}$${version} : $$result)."; \
	               retval=1; \
	            fi; \
	         else \
	            echo "try: install $$pac"; \
	            if ! $$inst $${pac}$${version} 2>/dev/null; then \
	               echo "error: installation failed - $${pac}$${version}"; \
	               retval=1; \
	            fi; \
	         fi; \
	      fi; \
	   done; \
	done; \
	if [ $$retval -eq 0 ]; then touch $@; fi

# erstelle die Hardlinks, die in $HARDLINK aufgeführt sind
hardlink.done: etc/collect-config.conf
	@echo "create hardlinks ..." ; \
	unset ALL; \
	retval=0; \
	source etc/collect-config.conf; \
	for file in "$${!HARDLINK[@]}"; do \
	   if ! [ -r "$(ROOT)$$file" ]; then \
	      echo "error: hardlink: can not access $(ROOT)$$file"; \
	      retval=1; \
	   else \
	      for link in $${HARDLINK[$$File]}; do \
	         if [ -e "$(ROOT)$$link" ]; then \
	            echo "warning: hardlink: link $(ROOT)$$link exists already"; \
	         else \
	            if ! ln $(ROOT)$$file $(ROOT)$$link; then \
	               echo "error: hardlink: failed to create link $(ROOT)$$link"; \
	               retval=1; \
	            fi; \
	         fi; \
	      done; \
	   fi; \
	done; \
	if [ $$retval -ge 1 ]; then \
	   exit $$retval; \
	else \
	   touch $@; \
	fi;

# erstelle die Softlinks, die in $SOFTLINK aufgeführt sind
softlink.done: etc/collect-config.conf
	@echo "create softlinks ..." ; \
	unset ALL; \
	retval=0; \
	source etc/collect-config.conf; \
	for file in "$${!SOFTLINK[@]}"; do \
	   if ! [ -r "$(ROOT)$$file" ]; then \
	      echo "error: softlink: can not access $(ROOT)$$file"; \
	      retval=1; \
	   else \
	      for link in $${SOFTLINK[$$file]}; do \
	         if [ -e "$(ROOT)$$link" ]; then \
	            echo "warning: softlink: link $(ROOT)$$link exists already"; \
	         else \
	            if ! ln -s $(ROOT)$$file $(ROOT)$$link; then \
	               echo "error: softlink: failed to create link $(ROOT)$$link"; \
	               retval=1; \
	            fi; \
	         fi; \
	      done; \
	   fi; \
	done; \
	if [ $$retval -ge 1 ]; then \
	   exit $$retval; \
	else \
		touch $@; \
	fi;

# setze die Rechte gemäß $PERMISSON
permission.done: etc/collect-config.conf
	@echo "set permissions ..." ; \
	unset ALL; \
	retval=0; \
	if [ "$$(id -u)" -ne 0 ]; then \
	   echo "   your not root - skipping 'set permissions'"; \
	   exit; \
   fi; \
	source etc/collect-config.conf; \
	for fgroup in "$${!PERMISSION[@]}"; do \
	   IFS=: read perm owner group <<< "$${PERMISSION[$$fgroup]}"; \
	   for file in "$$fgroup"; do \
	      if ! [ -e "$(ROOT)$$file" ]; then \
	         echo "error: permisson: $(ROOT)$$file does not exist"; \
	         retval=1; \
	      else \
	         if [ -n "$$perm" ]; then \
	            if ! chmod $$perm $(ROOT)$$file ; then \
	               echo "error: permission: chmod $$perm $(ROOT)$$file failed"; \
	               retval=1; \
	            fi; \
	         fi; \
	         if [ -n "$$owner" ] || [ -n "$$group" ]; then \
	            if ! chown $${owner}$${group:+:$$group} $(ROOT)$$file; then \
	               echo "error: permission: failed to chown on $(ROOT)$$file"; \
	               retval=1; \
	            fi; \
	         fi; \
	      fi; \
	   done; \
	done; \
	if [ $$retval -ge 1 ]; then \
	   exit $$retval; \
	else \
	   touch $@; \
	fi;
 
