#! /bin/sh
#
# (c) 2015, coded by Nat!, Mulle KybernetiK
#

if [ "${MULLE_BOOTSTRAP_NO_COLOR}" != "YES" ]
then
   # Escape sequence and resets
   C_RESET="\033[0m"

   # Useable Foreground colours, for black/white white/black
   C_RED="\033[0;31m"     C_GREEN="\033[0;32m"
   C_BLUE="\033[0;34m"    C_MAGENTA="\033[0;35m"
   C_CYAN="\033[0;36m"

   C_BR_RED="\033[0;91m"
   C_BOLD="\033[1m"

   #
   # restore colors if stuff gets wonky
   #
   trap 'printf "${C_RESET} >&2 ; exit 1"' TERM INT
fi


fail()
{
   printf "${C_BR_RED}Error: $*${C_RESET}\n" >&2
   exit 1
}

#
# https://github.com/hoelzro/useful-scripts/blob/master/decolorize.pl
#

#
# stolen from:
# http://stackoverflow.com/questions/1055671/how-can-i-get-the-behavior-of-gnus-readlink-f-on-a-mac
# ----
#
_prepend_path_if_relative()
{
   case "$2" in
      /*)
         echo "$2"
      ;;

      *)
         echo "$1/$2"
      ;;
   esac
}


resolve_symlinks()
{
   local dir_context path

   path="`readlink "$1"`"
   if [ $? -eq 0 ]
   then
      dir_context=`dirname -- "$1"`
      resolve_symlinks "`_prepend_path_if_relative "$dir_context" "$path"`"
   else
      echo "$1"
   fi
}


canonicalize_path()
{
   if [ -d "$1" ]
   then
   (
      cd "$1" 2>/dev/null && pwd -P
   )
   else
      local dir
      local file

      dir="`dirname "$1"`"
      file="`basename -- "$1"`"
      (
         cd "${dir}" 2>/dev/null &&
         echo "`pwd -P`/${file}"
      )
   fi
}


realpath()
{
   canonicalize_path "`resolve_symlinks "$1"`"
}


get_windows_path()
{
   local directory

   directory="$1"
   if [ -z "${directory}" ]
   then
      return 1
   fi

   ( cd "$directory" ; pwd -PW ) || fail "failed to get pwd"
   return 0
}


get_sh_windows_path()
{
   local directory

   directory="`which sh`"
   directory="`dirname -- "${directory}"`"
   directory="`get_windows_path "${directory}"`"

   if [ -z "${directory}" ]
   then
      fail "could not find sh.exe"
   fi
   echo "${directory}/sh.exe"
}


sed_mangle_escape_slashes()
{
   sed -e 's|/|\\\\|g'
}


main()
{
   local prefix
   local mode

   prefix=${1:-"/usr/local"}
   [ $# -eq 0 ] || shift
   mode=${1:-755}
   [ $# -eq 0 ] || shift

   if [ -z "${prefix}" ] || [ -z "${mode}" ]
   then
      fail "usage: install.sh [prefix] [mode]"
   fi

   prefix="`realpath "${prefix}" 2> /dev/null`"
   if [ ! -d "${prefix}" ]
   then
      fail "\"${prefix}\" does not exist"
   fi

   local bin
   local libexec

   bin="${prefix}/bin"
   libexec="${prefix}/libexec/mulle-bootstrap"

   if [ ! -d "${bin}" ]
   then
      mkdir -p "${bin}" || fail "could not create ${bin}"
   fi

   if [ ! -d "${libexec}" ]
   then
      mkdir -p "${libexec}" || fail "could not create ${libexec}"
   fi


   install -m "${mode}" "mulle-bootstrap" "${bin}/mulle-bootstrap" || exit 1
   printf "install: ${C_MAGENTA}${C_BOLD}%s${C_RESET}\n" "${bin}/mulle-bootstrap" >&2

   install -m "${mode}" "mulle-bootstrap-dotdump" "${bin}/mulle-bootstrap-dotdump" || exit 1
   printf "install: ${C_MAGENTA}${C_BOLD}%s${C_RESET}\n" "${bin}/mulle-bootstrap-dotdump" >&2

   case `uname` in
      MINGW*)
         for i in mulle-mingw-*sh
         do
            install -m "${mode}" "${i}" "${bin}/$i" || exit 1
            printf "install: ${C_MAGENTA}${C_BOLD}%s${C_RESET}\n" "$bin/$i" >&2
         done

         SH_PATH="`get_sh_windows_path | sed_mangle_escape_slashes`"
         INSTALL_PATH="${bin}" # `get_windows_path "${bin}" | sed_mangle_escape_slashes`"

         for i in mulle-mingw-*bat
         do
            cat "${i}" \
               | sed -e 's|C:\\Program\ Files\\Git\\usr\\bin\\shx\.exe|'"${SH_PATH}|g" \
               | sed -e 's|mulle-mingw-dumpdef.sh|'"${INSTALL_PATH}/mulle-mingw-dumpdef.sh|g" > "${bin}/$i" || exit 1
            chmod "${mode}" "${bin}/${i}" || exit 1
            printf "install: ${C_MAGENTA}${C_BOLD}%s${C_RESET}\n" "$bin/$i" >&2
         done
      ;;
   esac

   for i in src/mulle*.sh
   do
      mkdir -p "${libexec}" 2> /dev/null
      install -v -m "${mode}" "${i}" "${libexec}" || exit 1
   done

   if [ -d "test" ]
   then
      # use attractive colors :)
      printf "${C_GREEN}If you are new to mulle-bootstrap I would suggest checking out\n" >&2
      printf "the ${C_YELLOW}README.md${C_GREEN} in ${C_CYAN}./test${C_GREEN} and doing the examples.\n" >&2
   fi
}

main "$@"

