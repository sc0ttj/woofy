#!/bin/sh

# sc0ttman
# Initrd-Editor: unpack, edit and rebuild your "initrd.gz" file
# a simple GUI.. requires X desktop, GtkDialog3 and Xdialog
# possible to easily modify, to translate
# do as you like with this, or not at all :)

# usage: initrd-editor.sh [ /full/path/to/initrd.gz ] [ /full/path/to/save/dir ]
# note: both paths must start with / and are optional

#120404 must be run as root, see #110505
#120412 various fixes, disable auto install, support spacefm file manager, silent option
#120413 exit and cleanup if filetype of initrd.gz not listed or supported


[ "`whoami`" != "root" ] && exec sudo -A ${0} ${@} #120404

# export all functions
set -a

# setup vars to be used
FILEMAN=''
GTKDIALOG=''
XPID=''
INSTALL_CHECK=''
ERROR=''

SCRIPT_PATH="$0"
SCRIPT_NAME=`basename $0`
# apps to use, first listed is most preferable
[ ! "$FILEMAN" ] && FILEMAN="`which rox`"
[ ! "$FILEMAN" ] && FILEMAN="`which thunar`"
[ ! "$FILEMAN" ] && FILEMAN="`which Thunar`"
[ ! "$FILEMAN" ] && FILEMAN="`which nautilus`"
[ ! "$FILEMAN" ] && FILEMAN="`which spacefm`" #120412
[ ! "$FILEMAN" ] && FILEMAN="`which pcmanfm`"
[ ! "$FILEMAN" ] && FILEMAN="`which mc`"
[ ! "$FILEMAN" ] && FILEMAN="`which asm`"
# setup desired options for the file manager in use
[ "$FILEMAN" = "`which asm`" ] && FILEMAN="rxvt -e ${FILEMAN}"
[ "$FILEMAN" = "`which mc`" ] && FILEMAN="rxvt -e ${FILEMAN}"
[ "$FILEMAN" = "`which rox`" ] && FILEMAN="${FILEMAN} -n"
# use latest gtkdialog
GTKDIALOG=`which gtkdialog4`
[ ! "$GTKDIALOG" ] && GTKDIALOG=`which gtkdialog3`
[ ! "$GTKDIALOG" ] && GTKDIALOG=`which gtkdialog2`
[ ! "$GTKDIALOG" ] && GTKDIALOG=`which gtkdialog`
# setup dirs
WORKDIR="/tmp/initrd-editor" # no trailing slash
# use given save dir, or default if none given
[ -d "$2" ] && SAVEDIR="${2%*/}" || SAVEDIR="$HOME/Downloads" #120412 no trailing slash
echo "save dir is $SAVEDIR"

# GUI text
LOC_GUI_TITLE="Initrd.gz Editor - rebuild your init script"
LOC_GUI_FILE="Choose your initrd.gz file:"
LOC_GUI_EDIT_DIALOG="Edit the contents of initrd.gz\nClick OK only when you are finished."
LOC_GUI_SAVE_DIALOG="Success - your new initrd.gz is ready, in ${SAVEDIR}"
LOC_ERROR_FILE="Error: File not found."
LOC_ERROR_FILETYPE="Error: File must have a .gz extension"
LOC_ERROR_WORKDIR="Error: Work directory not available"
LOC_ERROR_SAVEDIR="Error: Save directory not available"
LOC_ERROR_UNSUPPORTED="Error: File type of this initrd.gz is not supported."

## functions
self_install () {
   # check if installed
   INSTALL_CHECK=`which $SCRIPT_NAME`
   # if it was not found, copy to /usr/bin
   [ "$INSTALL_CHECK" = "" ] && cp -f "$SCRIPT_PATH" "/usr/bin/"
}
# error checking
check_errors () {
   # file maybe changed since above, re-check
   FILENAME=`basename "$FILE"`
   FILEEXT=${FILENAME##*.} # file extension only
   if [ ! -f "$FILE" ];then
      ERROR="$LOC_ERROR_FILE"
   elif [ "$FILEEXT" != "gz" ];then
      ERROR="$LOC_ERROR_FILETYPE"
   elif [ ! -d "$WORKDIR" ];then
      mkdir "$WORKDIR" || ERROR="$LOC_ERROR_WORKDIR"
   elif [ ! -d "$SAVEDIR" ];then
      mkdir "$SAVEDIR" || ERROR="$LOC_ERROR_SAVEDIR"
   fi
   # set final message
   LOC_GUI_ERROR_DIALOG="$ERROR"
}
# check archive type
check_filetype () {
   CPIOTEST=''
   CPIOTEST=`file -z "$FILE" | grep cpio`
   GZIPTEST=''
   GZIPTEST=`file -z "$FILE" | grep "filesystem data"`
}
# extract function
extract_file () {
   cd "$WORKDIR"
   if [ "$CPIOTEST" != "" ];then
      zcat "$FILE" | cpio -i -d
      # make sure nothing mounted
      [ -d "${WORKDIR}/mntd/" ] && rm -r "${WORKDIR}/mntd/" 2>&1
   elif [ "$GZIPTEST" != "" ];then
      # need to copy file to workdir
      cp "$FILE" "${WORKDIR}"
      # unpack
      [ -f "${WORKDIR}/initrd" ] && rm -f "${WORKDIR}/initrd" 2>&1
      gunzip "${WORKDIR}/initrd.gz"
      # mount
      mkdir "${WORKDIR}/mntd"
      mount -o loop initrd "${WORKDIR}/mntd"
   else
      Xdialog --title "Initrd Editor" --msgbox "$LOC_ERROR_UNSUPPORTED" 0 0
      cleanup_files
      exit 1
   fi
}
# edit initrd function
edit_init () {
   if [ -d "${WORKDIR}/mntd" ];then # if initrd is mounted
      $FILEMAN "${WORKDIR}/mntd" &
   else
      $FILEMAN "$WORKDIR" &
   fi
   XPID=$!
   sleep 1
   Xdialog --title "Initrd Editor" --msgbox "$LOC_GUI_EDIT_DIALOG" 0 0
   kill $XPID > /dev/null 2>&1
   rox -D "$WORKDIR" > /dev/null 2>&1
}
# compress function
compress_file () {
   cd "${WORKDIR}"
   # remove any old ones
   [ -f "${SAVEDIR}/initrd.gz" ] && rm -f "${SAVEDIR}/initrd.gz"
   # build the new file
   if [ "$CPIOTEST" != "" ];then
      find . | cpio -o -H newc | gzip -9 > "${SAVEDIR}/initrd.gz"
   else
      sync
      [ -d "${WORKDIR}/mntd" ] && umount -f "${WORKDIR}/mntd"
      sync
      gzip "${WORKDIR}/initrd"
      mv -f "${WORKDIR}/initrd.gz" "${SAVEDIR}/initrd.gz"
   fi
   # show file in file manager, only if save dir not chosen by user
   if [ "$SAVEDIR" = "$HOME/Downloads" ];then
      $FILEMAN "${SAVEDIR}" &
   fi
   sleep 1
   [ "$SILENT" = true ] || Xdialog --title "Initrd Editor" --msgbox "$LOC_GUI_SAVE_DIALOG" 0 0 #120412
}
cleanup_files () {
   # clean up and exit program
   [ -d "${WORKDIR}/temp" ] && umount "${WORKDIR}/temp" 2>&1
   rm -r -f "${WORKDIR}/" 2>&1
   sync
}
# run program function
run_program () {
   # install to /usr/bin, if not there already
   #120412 dont run self_install func - Barry K has own solution in Woof2 now
   #self_install 
   # check arrors and exit with a message, if needed
   check_errors
   if [ "$ERROR" != "" ];then
      Xdialog --title "Initrd Editor" --msgbox "$LOC_GUI_ERROR_DIALOG" 0 0
      # exit with error
      exit 1
   else
      # do the thing
      cd "$WORKDIR"
      check_filetype
      extract_file
      edit_init
      compress_file
      cleanup_files
      # exit without error
      killall gtkdialog4 --p INITRD_EDITOR_GUI -c > /dev/null 2>&1
      exit 0
   fi
}

# check for file given through command line
if [ -f "$1" ];then
   # assign given file to $FILE
   FILE="$1"
   # run with no gui
   run_program
fi

# if no file given, user must use GUI to choose a file
[ "$FILE" = "" ] && FILE="/choose/your/path/to/initrd.gz"
# GUI
export INITRD_EDITOR_GUI='<window title="Initrd Editor">
<vbox>
<frame>
   <vbox homogeneous="true">
      <text><label>'${LOC_GUI_TITLE}'</label></text>
   </vbox>
</frame>
<frame>
   <vbox>
      <text><label>'${LOC_GUI_FILE}'</label></text>
      <hbox>
         <entry tooltip-text="The initrd.gz file.">
            <default>'$FILE'</default>
            <variable>FILE</variable>
         </entry>
         <button>
            <input file icon="gtk-open"></input>
            <action type="fileselect">FILE</action>
         </button>
      </hbox>
   </vbox>
</frame>
<frame>
   <vbox>
      <hbox>
         <button ok>
            <action>run_program</action>
         </button>
         <button cancel></button>
      </hbox>
   </vbox>
</frame>
</vbox>
</window>'

# run the GUI
$GTKDIALOG -p INITRD_EDITOR_GUI -c
unset INITRD_EDITOR_GUI

# exit without error
exit 0
