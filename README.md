collect-config
==============

Problemstellung
---------------
Ein System wird aufgesetzt und eingerichtet. Mit der Zeit werden Änderungen
am System vorgenommen und die Unterschiede zu dem initial aufgesetzten
System werden immer größer. Es wird immer schwieriger festzustellen, an
welchen Stellen das System von der initialen (RPM-/DEB-)Konfiguration
abweicht.

collect-config versucht dieses Problem zu lösen, indem in einer 
Konfigurationsdatei alle Dateien aufgeführt werden, die Änderungen erfahren
haben. collect-config sichert diese Dateien in einem Repository-Verzeichnis
und benutzt RCS für die Versionskontrolle.
Des Weiteren enthält die Konfigurationsdatei eine Liste mit Paketen, die auf
dem System umbedingt installiert sein müssen. Schließlich ist es noch
möglich Soft- und Hardlinks anzugeben, die existieren müssen.
Durch die Konfigurationsdatei und das Repository kann das System mit dem
mitgelieferten Makefile in kurzer Zeit wieder aufgesetzt werden.

offene Probleme:
----------------
* Wie kann ein bestimmter Zustand aus dem Repository ins System gepushed
  werden? (Geht komplett wahrscheinlich erst mit SVN unterstützung)


Ziele
-----
* Änderungen dokumentieren
* Automatische Installation mittels Makefile


Abhängigkeiten
--------------
collect-config benötigt
* bash > 4.0
* RCS


collect-config.conf
-------------------
Beschreibung siehe Kommentare in der Datei selbst.

Definiert Repository über die Variable CONFDIR
Definiert die assoziativen Arrays:
* COLLECTION für eine Liste von Konfigurationsdateien, Skripten, ...
* PACKAGE für eine Liste von Paketen, die installiert sein sollen
* SOFTLINK für eine Liste von Softlinks mit ihren Zielen
* HARDLINK für eine Liste von Hardlinks mit ihren Zielen
* PERMISSION für eine Liste von Dateien mit ihren Besitzern und Rechten


collect-config.sh
-----------------
Das Skript führt mehrere Aufgaben durch:
 * Es wertet das Assoziative Array COLLECTION aus und checked jede dort
   definierte Datei ins Repo ein.
 * Es ermittelt das Paketmanagementsystem (RPM oder DEB) und überprüft,
   ob die in PACKAGE angegebenen Pakete in der richtigen Version (sofern
   angegeben) installiert sind. Wenn nicht gibt es eine Warnung aus.
 * Es überprüft, ob die in HARDLINK angegebenen Dateien existieren,
   wenn nicht gibt es eine Warnung aus.
 * Es überprüft, ob die in SOFTLINK angegebenen Links existieren, wenn
   nicht gibt es eine Warnung aus.
 * Es überprüft, ob die in PERMISSION angegebenen Dateien die richtigen
   Besitzer bzw. Rechte haben, wenn nicht gibt es eine Warnung aus.
Der Rückgabewert ist wie folgt:
 0) kein Fehler
 1) mindestens eine Warnung
 2) mindestens ein Fehler (kann auch Warnungen enthalten)

Makefile
--------
Das Makefile benötigt ebenfalls die collect-config Konfigurationsdatei
(collect-config.conf). Diese liest es per default aus dem Repository.
Es bietet die folgenden Rezepte:
* install             ... installiert Pakete, Verzeichnisse, Dateien, Hard-
    und Softlinks und setzt die Rechte der Dateien
* links               ... Erstellt Hard- und Softlinks und setzt die Rechte
    der Dateien (hardlink.done und softlink.done)
* clean               ... entfernt generierte Makefiles und .done Dateien
* profile.done        ... VERALTET: erzeugt einen Eintrag in /root/.profile
* dirs.done           ... erstellt alle Verzeichnisse, die in
    collect-config.conf genannt sind.
* collect-config.make ... Erzeugt aus collect-config.conf ein Makefile,
    das die Dateien zurück ins System kopieren kann. Dabei werden die
    Rechte beibehalten und nur neuere Dateien kopiert.
* run-collect-config  ... ruft collect-config.sh auf
* packages.done       ... ermittelt den Packetmanager und installiert alle
    in collect-config.conf aufgeführten Pakete
* permission.done     ... Setzt die in collect-config.conf definierten Rechte
    und Besitzer der dort genannten Dateien

