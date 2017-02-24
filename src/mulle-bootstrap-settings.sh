#! /bin/sh
#
#   Copyright (c) 2015 Nat! - Mulle kybernetiK
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are met:
#
#   Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
#   Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
#   Neither the name of Mulle kybernetiK nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#   AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#   IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#   ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
#   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#   INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#   POSSIBILITY OF SUCH DAMAGE.
MULLE_BOOTSTRAP_SETTINGS_SH="included"


config_usage()
{
    cat <<EOF >&2
usage:
   mulle-bootstrap config [options] [key] [value]

   Options:
      -d   : delete config setting
      -l   : list config values

   Use:
      mulle-bootstrap config <key> to read
      mulle-bootstrap config <key> <value> to write
EOF
  exit 1
}


expansion_usage()
{
    cat <<EOF >&2
usage:
   mulle-bootstrap expansion [options] <key> [value]

   Options:
      -d   : delete setting
      -g   : use global .bootstrap folder instead of local

   Use:
      mulle-bootstrap expansion <key> to read
      mulle-bootstrap expansion <key> <value> to write
EOF
  exit 1
}


setting_usage()
{
    cat <<EOF >&2
usage:
   mulle-bootstrap setting [options] <key> [value]

   Options:
      -a   : append value to setting
      -d   : delete setting
      -g   : use global .bootstrap folder instead of local
      -p   : show current setting value
      -r   : specify repository for build setting

   Use:
      mulle-bootstrap setting <key> to read settings
      mulle-bootstrap setting <key> <value> to write settings
EOF
  exit 1
}


warn_user_setting()
{
   local path

   path="$1"

   if [ "$MULLE_BOOTSTRAP_WARN_USER_SETTINGS" = "YES" ]
   then
      log_warning "Using `dirname -- "${path}"` for `basename -- "${path}"`"
   fi
}

KNOWN_CONFIG_KEYS="\
absolute_symlinks
addictions_dir
brew_permissions
build_dir
build_log_dir
build_preferences
caches_path
check_usr_local_include
clean_before_build
clean_dependencies_before_build
clean_empty_parent_folders
clean_folders
configurations
create_default_files
create_example_files
dependencies_dir
dist_clean_folders
dont_warn_scripts
editor
embedded_symlinks
framework_dir_name
header_dir_name
install_clean_folders
install_symlinks
library_dir_name
mangle_minwg_compiler
no_warn_local_setting
open_${mainfile}_file
output_clean_folders
override_branch
stashes_dir
symlinks
warn_environment_setting
warn_user_setting
xcodebuild
"

KNOWN_ROOT_SETTING_KEYS="\
brews
embedded_repositories
repositories
version
"

KNOWN_BUILD_SETTING_KEYS="\
WARNING_CFLAGS
CMAKEFLAGS
GCC_PREPROCESSOR_DEFINITIONS
LD
OTHER_CFLAGS
OTHER_CXXFLAGS
OTHER_LDFLAGS
build_preferences
cmake
cmake_generator
cmake_keep_builddir
configurations
configure_flags
dispense_headers_path
dispense_other_path
fallback-configuration
final
make
sdks
xcconfig
xcode_project
xcode_proper_skip_install
xcode_schemes
xcode_targets
xcodebuild
"


warn_environment_setting()
{
   local key

   key="$1"
   if [ "$MULLE_BOOTSTRAP_WARN_ENVIRONMENT_SETTINGS" = "YES" ]
   then
      # don't trace some boring ones
      if [ "${key}" != "MULLE_FLAG_ANSWER" -a \
           "${key}" != "MULLE_FLAG_LOG_VERBOSE" -a \
           "${key}" != "MULLE_TRACE" ]
      then
         log_warning "Using environment variable \"${key}\""
      fi
   fi
}


# returns 2 if file is missing
__read_setting()
{
   local path="$1"

   egrep -s -v '^#|^[ ]*$' "${path}"
}


_copy_no_clobber_setting_file()
{
   local src="${1:-.}" ; shift
   local dst="${1:-.}" ; shift

   if [ ! -f "${dst}" ]
   then
      exekutor cp ${COPYMOVEFLAGS} "${src}" "${dst}"  >&2
   else
      value1="`__read_setting "${src}"`"
      value2="`__read_setting "${dst}"`"

      if [ "${value1}" != "${value2}" ]
      then
         log_warning "\"${src}\" is incompatible with \"${dst}\", which is already present and not being overwritten."
         return
      fi
      log_fluff "Skipping \"${src}\" as it's already present."
   fi
}


#
# Base function, not be called outside of this file
#
_read_setting()
{
   local apath="$1"

   [ ! -z "${apath}" ] || fail "no path given to read_setting"

   local value

   # file not found = 2 (same as grep)

   if [ "$MULLE_FLAG_LOG_SETTINGS" = "YES" ]
   then
      local  yesno

      if [ ! -r "${apath}" ]
      then
         yesno="not "
      fi

      log_trace2 "Looking for setting-file \"${apath}\" (pwd=$PWD) : ${yesno}found"
   fi

   if [ "${READ_SETTING_RETURNS_PATH}" = "YES" ]
   then
      if [ ! -r "${apath}" ]
      then
         return 2
      fi

      if [ "$MULLE_FLAG_LOG_VERBOSE" = "YES"  ]
      then
         local key

         key="`basename -- "${apath}"`"
         log_setting "${C_MAGENTA}${key}${C_SETTING} found as \"${apath}\""
      fi

      echo "${apath}"
      return 0
   fi

   local rval

   #
   # remove empty lines, remove comment lines
   #
   if ! value="`__read_setting "${apath}"`"
   then
      return 2   # it's grep :)
   fi

   if [ "${MULLE_FLAG_LOG_VERBOSE}" = "YES" -o "$MULLE_FLAG_LOG_SETTINGS" = "YES" ]
   then
      local key

      key="`basename -- "${apath}"`"
      apath="`absolutepath "${apath}"`"

      # make some boring names less prominent
      if [ "$MULLE_FLAG_LOG_SETTINGS" = "YES" ] ||
         [ "${key}" != "repositories" -a \
           "${key}" != "repositories.tmp" -a \
           "${key}" != "build_order" -a \
           "${key}" != "versions" -a \
           "${key}" != "embedded_repositories" -a \
           "${key}" != "MULLE_REPOSITORIES" -a \
           "${key}" != "MULLE_NAT_REPOSITORIES" \
         ]
      then
         log_printf "${C_SETTING}%b${C_RESET}\n" "Setting ${C_MAGENTA}${key}${C_SETTING} found in \"${apath}\" as ${C_MAGENTA}${C_BOLD}${value}${C_SETTING}"
      fi
   fi

   echo "${value}"
}


read_setting()
{
   _read_setting "$@"
}


read_raw_setting()
{
   local key="$1"

   [ $# -ne 1 ]     && internal_fail "parameterization error"
   [ -z "${key}" ] && internal_fail "empty key in read_raw_setting"

   if _read_setting "${BOOTSTRAP_DIR}.local/${key}"
   then
      return
   fi
   _read_setting "${BOOTSTRAP_DIR}/${key}"
}

#
# this has to be flexible, because fetch and build settings read differently
#
_read_bootstrap_setting()
{
   local key="$1"

   [ $# -ne 1 ]     && internal_fail "parameterization error"
   [ -z "${key}" ] && internal_fail "empty key in _read_bootstrap_setting"

   local value

   #
   # to access unmerged data (needed for embedded repos)
   #
   if [ "${MULLE_BOOTSTRAP_SETTINGS_NO_AUTO}" = "YES" ]
   then
      suffix=""
   else
      suffix=".auto"
   fi

   _read_setting "${BOOTSTRAP_DIR}${suffix}/${key}"
}


#
# this knows intentionally no default, you cant have an empty
# local setting
#
_read_environment_setting()
{
   local key
   local value
   local envname

   [ $# -ne 1  ] && internal_fail "parameterization error"

   key="$1"

   [ -z "${key}" ] && internal_fail "empty key in _read_environment_setting"

   envname="MULLE_BOOTSTRAP_`echo "${key}" | tr '[:lower:]' '[:upper:]'`"

   if [ "$MULLE_FLAG_LOG_SETTINGS" = "YES" ]
   then
      log_trace2 "Looking for setting \"${key}\" as environment variable \"${envname}\""
   fi

   value="`printenv "${envname}"`"
   if [ "${value}" = "" ]
   then
      return 2
   fi

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = "YES" ]
   then
      log_trace "Setting ${C_MAGENTA}${C_BOLD}${key}${C_TRACE} found in environment variable \"${envname}\" as ${C_MAGENTA}${C_BOLD}${value}${C_TRACE}"
   fi

   warn_environment_setting "${envname}"

   echo "${value}"
   return 0
}


list_environment_settings()
{
   local line
   local key
   local envkey
   local value

   env | while read line
   do
      key="`echo "${line}" | \
            sed -n 's/^MULLE_BOOTSTRAP_\([^=]*\)=.*/\1/p' | \
            tr '[:upper:]' '[:lower:]'`"
      value="`echo "${line}" | \
            sed -n 's/^MULLE_BOOTSTRAP_[^=]*=\(.*\)/\1/p'`"

      if [ ! -z "${key}" -a ! -z "${value}" ]
      then
         envkey="`echo "${line}" | \
            sed -n 's/^\(MULLE_BOOTSTRAP_[^=]*\)=.*/\1/p'`"

         echo "${key}=\"${value}\" (${envkey})"
      fi
   done
}


_read_home_setting()
{
   local key
   local value
   local default

   [ $# -ne 1  ] && internal_fail "parameterization error"

   key="$1"

   [ -z "${key}" ] && internal_fail "empty key in _read_home_setting"

   if ! value="`_read_setting "${HOME}/.mulle-bootstrap/${key}"`"
   then
      return 2
   fi

   warn_user_setting "${HOME}/.mulle-bootstrap/${key}"

   echo "$value"
}


list_dir_settings()
{
   local directory="$1"

   local filename
   local key
   local value

   IFS="
"
   for filename in `ls -1 "${directory}" 2> /dev/null`
   do
      IFS="${DEFAULT_IFS}"

      key="`basename -- "${filename}"`"
      value="`_read_setting "${directory}/${key}"`"
      if [ ! -z "${value}" ]
      then
         echo "${key}=\"${value}\""
      fi
   done

   IFS="${DEFAULT_IFS}"
}


list_local_settings()
{
   list_dir_settings "${BOOTSTRAP_DIR}.local/config"
}


list_home_settings()
{
   list_dir_settings "${HOME}/.mulle-bootstrap"
}


####
#
# Functions building on _read_ functions
#
read_config_setting()
{
   if [ "${MULLE_TRACE_SETTINGS_FLIP_X}" = "YES" ]
   then
      set +x
   fi

   local key
   local default

   [ $# -lt 1 -o $# -gt 2 ] && internal_fail "parameterization error"

   key="$1"
   default="$2"

   [ -z "${key}" ] && internal_fail "empty key in read_config_setting"

   #
   # always lowercase config keys
   #
   key=`echo "${key}" | tr '[:upper:]' '[:lower:]'`

   local value

   if ! value="`_read_environment_setting "${key}"`"
   then
      if ! value="`_read_setting "${BOOTSTRAP_DIR}.local/config/${key}"`"
      then
         if ! value="`_read_home_setting "${key}"`"
         then
            if [ ! -z "${default}" ]
            then
               log_setting "Setting ${C_MAGENTA}${key}${C_SETTING} set to default ${C_MAGENTA}${default}${C_SETTING}"
               value="${default}"
            fi
         fi
      fi
   fi

   echo "$value"

   if [ "${MULLE_TRACE_SETTINGS_FLIP_X}" = "YES" ]
   then
      set -x
   fi
}


#
# values in "overrides" override those inherited by repositories
# values in "settings" are overriden by those inherited by repositories
#
read_build_setting()
{
   if [ "${MULLE_TRACE_SETTINGS_FLIP_X}" = "YES" ]
   then
      set +x
   fi

   local key
   local default
   local package

   [ $# -lt 2 -o $# -gt 3 ] && internal_fail "parameterization error"

   package="$1"
   key="$2"
   default="$3"

   [ -z "${key}" ] && internal_fail "empty parameter in read_config_setting"

   local value

   value="`_read_bootstrap_setting "${package}.build/${key}"`"
   if [ $? -ne 0 ]
   then
      if [ ! -z "${default}" ]
      then
         log_setting "Build Setting ${C_MAGENTA}${package}${C_SETTING} \
for ${C_MAGENTA}${key}${C_SETTING} \
set to default ${C_MAGENTA}${default}${C_SETTING}"
      fi
      value="${default}"
   fi

   echo "$value"

   if [ "${MULLE_TRACE_SETTINGS_FLIP_X}" = "YES" ]
   then
      set -x
   fi
#   [ "${value}" = "${default}" ]
#
#   return $?
}


read_root_setting()
{
   if [ "${MULLE_TRACE_SETTINGS_FLIP_X}" = "YES" ]
   then
      set +x
   fi

   local default
   local key

   key="$1"
   default="$2"

   [ -z "${key}" ] && internal_fail "empty key in read_root_setting"

   local value
   local rval

   value="`_read_bootstrap_setting "${key}"`"
   if [ $? -ne 0 ]
   then
      if [ ! -z "${default}" ]
      then
         log_setting "Root setting for ${C_MAGENTA}${key}${C_SETTING} set to default ${C_MAGENTA}${default}${C_SETTING}"
      fi
      value="${default}"
   fi

   echo "$value"

   if [ "${MULLE_TRACE_SETTINGS_FLIP_X}" = "YES" ]
   then
      set -x
   fi
#   [ "${value}" = "${default}" ]
#
#   return $?
}


####
# Used for finding script files
#
find_root_setting_file()
{
   READ_SETTING_RETURNS_PATH="YES" read_root_setting "$@"
}


find_build_setting_file()
{
   READ_SETTING_RETURNS_PATH="YES" read_build_setting "$@"
}


####
# Functions building on read_ functions
#
read_yes_no_build_setting()
{
   local value

   value="`read_build_setting "$1" "$2" "$3"`"
   is_yes "$value" "$1/$2"
}


read_yes_no_config_setting()
{
   local value

   value="`read_config_setting "$1" "$2"`"
   is_yes "$value" "$1"
}


read_sane_config_path_setting()
{
   local key
   local value
   local default

   key="$1"
   default="$2"

   value="`read_config_setting "${key}" "${default}"`"
   if [ $? -eq 0 ]
   then
      assert_sane_subdir_path "${value}"
      echo "$value"
   fi
}


#
# this is used during copy operations into .auto to already expand variables
# src is relative to srcbootstrap folder
#
read_expanded_setting()
{
   local filepath="$1"
   local default="$2"
   local srcbootstrap="$3"

   [ -z "${srcbootstrap}" ] && internal_fail "empty srcbootstrap"
   [ $# -eq 3 ]             || internal_fail "wrong parameters"

   local value

   value="`(
      MULLE_BOOTSTRAP_SETTINGS_NO_AUTO="YES"
      BOOTSTRAP_DIR="${srcbootstrap}"
      _read_setting "${filepath}"
   )`"

   if [ -z "${value}" ]
   then
      value="${default}"
   fi

   IFS="
"
   echo "${value}" | while read line
   do
      IFS="${DEFAULT_IFS}"
      expanded_variables "${line}" "${srcbootstrap}"
   done
}


_merge_settings_in_front()
{
   local settings1="$1"
   local settings2="$2"
   local key="$3"

   local result

   result="${settings2}"

   local line

   # https://stackoverflow.com/questions/742466/how-can-i-reverse-the-order-of-lines-in-a-file/744093#744093

   IFS="
"
   for line in `echo "${settings1}" | sed -n '1!G;h;$p'`
   do
      result="`echo "${result}" | grep -v -x "${line}"`"
      result="${line}
${result}"
   done

   IFS="${DEFAULT_IFS}"

   if [ "$MULLE_FLAG_LOG_SETTINGS" = "YES" -o \
        "$MULLE_FLAG_MERGE_LOG" = "YES"  ]
   then
      log_trace2 "----------------------"
      log_trace2 "Merged settings:      "
      log_trace2 "----------------------"
      log_trace2 "${result}"
      log_trace2 "----------------------"
   fi
   echo "${result}"
}


merge_settings_in_front()
{
   local settings1
   local settings2
   local result

   settings1="`_read_setting "$1"`"
   if [ ! -z "$2" ]
   then
      settings2="`_read_setting "$2"`"
   fi

   _merge_settings_in_front "${settings1}" "${settings2}" "`basename -- "$1"`"
}


###
#
#
all_build_flag_keys()
{
   local package

   package="$1"

   local keys1
   local keys2

   keys1=`(cd "${BOOTSTRAP_DIR}.auto/overrides" 2> /dev/null || exit 1 ; \
           ls -1 | egrep '\b[A-Z][A-Z_0-9]+\b')`
   keys2=`(cd "${BOOTSTRAP_DIR}.auto/${package}.build" 2> /dev/null || exit 1 ; \
           ls -1 | egrep '\b[A-Z][A-Z_0-9]+\b')`
   keys3=`(cd "${BOOTSTRAP_DIR}.auto/settings" 2> /dev/null || exit 1 ; \
           ls -1 | egrep '\b[A-Z][A-Z_0-9]+\b')`

   echo "${keys1}
${keys2}
${keys3}
" | sort | sort -u | egrep -v '^[ ]*$'
   return 0
}


#
# setting ops
#
_setting_list()
{
   fail "Not yet implemented"
}


_chosen_bootstrapdir()
{
   local option="$1"

   if [ "${option}" = "YES" ]
   then
      echo "${BOOTSTRAP_DIR}"
   else
      echo "${BOOTSTRAP_DIR}.local"
   fi
}


_chosen_setting_directory()
{
   local repository="$1"
   local option="$2"

   local bootstrapdir

   if [ "${option}" = "YES" ]
   then
      bootstrapdir="${BOOTSTRAP_DIR}"
      if [ ! -z "${repository}" ]
      then
         echo "${bootstrapdir}/${repository}.build"
      else
         echo "${bootstrapdir}"
      fi
   else
      bootstrapdir="${BOOTSTRAP_DIR}.local"
      if [ ! -z "${3}" ]
      then
         echo "${bootstrapdir}/${repository}.build"
      else
         echo "${bootstrapdir}/settings/"
      fi
   fi
}


_setting_read()
{
   local key="$1"
   local repository="$2"

   local bootstrapdir
   local directory

   if [ "${OPTION_PROCESSED_READ}" = "NO" ]
   then
      bootstrapdir="`_chosen_bootstrapdir "${OPTION_GLOBAL}"`"
      directory="`_chosen_setting_directory "${repository}" "${OPTION_GLOBAL}"`"
      _read_setting "${directory}/${name}"

      return
   fi

   if [ -z "${repository}" ]
   then
      read_root_setting "$1"
   else
      read_build_setting "${repository}" "{key}"
   fi
}


_setting_write()
{
   local key="$1"
   local value="$2"
   local repository="$3"

   local bootstrapdir
   local directory

   bootstrapdir="`_chosen_bootstrapdir "${OPTION_GLOBAL}"`"
   directory="`_chosen_setting_directory "${repository}" "${OPTION_GLOBAL}"`"

   mkdir_if_missing "${directory}"

   local filename

   filename="${directory}/${key}"
   redirect_exekutor "${filename}" echo "${value}"
   exekutor touch "${bootstrapdir}"
}


_setting_append()
{
   local key="$1"
   local value="$2"
   local repository="$3"

   local bootstrapdir
   local directory

   bootstrapdir="`_chosen_bootstrapdir "${OPTION_GLOBAL}"`"
   directory="`_chosen_setting_directory "${repository}" "${OPTION_GLOBAL}"`"

   mkdir_if_missing "${directory}"

   local filename

   filename="${directory}/${key}"
   redirect_append_exekutor "${filename}" echo "${value}"
   exekutor touch "${bootstrapdir}"
}


_setting_delete()
{
   local bootstrapdir
   local directory

   bootstrapdir="`_chosen_bootstrapdir "${OPTION_GLOBAL}"`"
   directory="`_chosen_setting_directory "${repository}" "${OPTION_GLOBAL}"`"

   local filename

   filename="${directory}/${key}"
   remove_file_if_present "${filename}"
   exekutor touch "${bootstrapdir}" 2> /dev/null
}


#
# config ops
#
_config_list()
{
   log_info "environment:"
   list_environment_settings | sed 's/^/   /'

   log_info ".bootstrap.local/config ($PWD):"
   list_local_settings | sed 's/^/   /'

   log_info "~/.mulle-bootstrap:"
   list_home_settings | sed 's/^/   /'
}


_config_read()
{
   local key="$1"

   read_config_setting "${key}"
}


_config_append()
{
   fail "Not yet implemented"
}


_config_write()
{
   mkdir_if_missing "${BOOTSTRAP_DIR}.local/config"

   exekutor echo "$2" > "${BOOTSTRAP_DIR}.local/config/$1"
   exekutor touch "${BOOTSTRAP_DIR}.local"
}


_config_delete()
{
   if [ -f "${BOOTSTRAP_DIR}.local/config/$1" ]
   then
      exekutor rm "${BOOTSTRAP_DIR}.local/config/$1"  >&2
      exekutor touch "${BOOTSTRAP_DIR}.local"  >&2
   fi
}


#
# expansion ops
#
_expansion_read()
{
   local key="$1"

   local bootstrapdir

   if [ "${OPTION_PROCESSED_READ}" = "NO" ]
   then
      bootstrapdir="`_chosen_bootstrapdir "${OPTION_GLOBAL}"`"
      _read_setting "${bootstrapdir}/${key}"

      return
   fi

   read_root_setting "${key}"
}


_expansion_write()
{
   local bootstrapdir

   bootstrapdir="`_chosen_bootstrapdir "${OPTION_GLOBAL}"`"
   mkdir_if_missing "${bootstrapdir}"

   redirect_exekutor "${bootstrapdir}/$1" echo "$2"
   exekutor touch "${bootstrapdir}"
}


_expansion_append()
{
   fail "Not yet implemented"
}


_expansion_delete()
{
   local bootstrapdir

   bootstrapdir="`_chosen_bootstrapdir "${OPTION_GLOBAL}"`"

   remove_file_if_present "${bootstrapdir}/$1"
   exekutor touch "${bootstrapdir}"
}


_expansion_list()
{
   fail "Not yet implemented"
}


_generic_main()
{
   local type="$1" ; shift
   local known_keys_1="$1"; shift
   local known_keys_2="$1"; shift

   local OPTION_APPEND="NO"
   local OPTION_GLOBAL="NO"
   local OPTION_PROCESSED_READ="NO"
   local key
   local value
   local command
   local repository

   command="read"

   while [ $# -ne 0 ]
   do
      case "${type}" in
         setting|expansion)
            case "$1" in
               -g|--global)
                  OPTION_GLOBAL="YES"
                  shift
                  continue
               ;;

               -p|--processed)
                  OPTION_PROCESSED_READ="YES"
                  shift
                  continue
               ;;
            esac
         ;;
      esac

      case "${type}" in
         setting)
            case "$1" in
               -r|--repository)
                  [ $# -ne 0 ] || fail "repository name missing"
                  repository="$1"
                  shift
                  continue
               ;;
            esac
         ;;
      esac

      case "$1" in
         -h|-help|--help)
            ${type}_usage
         ;;

         -a|--append)
            OPTION_APPEND="YES"
            shift
            continue
         ;;

         -d|--delete)
            command="delete"
         ;;

         -l|--list)
            command="list"
         ;;

         -n|--off|--no|--NO)
            command="write"
            value="NO"
         ;;

         -y|--on|--yes|--YES)
            command="write"
            value="YES"
         ;;

         -*)
            log_error "${MULLE_EXECUTABLE_FAIL_PREFIX}: Unknown option $1"
            config_usage
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   case "${command}" in
      read|write|delete)
         key="$1"
         [ -z "${key}" ] && ${type}_usage
         shift

         if [ ! -z "${known_keys_1}" ]
         then
            local match

            match="`echo "${known_keys_1}" | fgrep -s -x "${key}"`"
            if [ -z "${match}" ]
            then
               match="`echo "${known_keys_2}" | fgrep -s -x "${key}"`"
               if [ -z "${match}" ]
               then
                  log_warning "${key} is not a known key. Maybe OK, maybe not."
               fi
            fi
         fi
      ;;
   esac

   case "${command}" in
      read)
         if [ $# -ne 0 ]
         then
            command="write"
            value="$1"
            shift

            if [ "${value}" = "-" ]
            then
               value="`cat`"
            fi
         fi
      ;;
   esac

   if [ $# -ne 0 ]
   then
      ${type}_usage
   fi

   case "${command}" in
      read)
         _${type}_read "${key}" "${repository}"
      ;;

      list)
         _${type}_list "${repository}"
      ;;

      delete)
         _${type}_delete "${key}" "${repository}"
      ;;

      write)
         if [ "${OPTION_APPEND}" = "YES" ]
         then
            _${type}_append "${key}" "${value}" "${repository}"
         else
            _${type}_write "${key}" "${value}" "${repository}"
         fi
      ;;
   esac
}


config_main()
{
   _generic_main "config" "${KNOWN_CONFIG_KEYS}" "" "$@"
}


expansion_main()
{
   _generic_main "expansion" "${KNOWN_EXPANSION_KEYS}" "" "$@"
}


setting_main()
{
   _generic_main "setting" "${KNOWN_ROOT_SETTING_KEYS}" "${KNOWN_BUILD_SETTING_KEYS}" "$@"
}

#
# read some config stuff now
#
settings_initialize()
{
   log_debug ":settings_initialize:"

   [ -z "${MULLE_BOOTSTRAP_FUNCTIONS_SH}" ] && . mulle-bootstrap-functions.sh

   # MULLE_BOOTSTRAP_NO_WARN_LOCAL_SETTINGS="`read_config_setting "no_warn_local_setting"`"
   MULLE_BOOTSTRAP_WARN_USER_SETTINGS="`read_config_setting "warn_user_setting" "YES"`"
   MULLE_BOOTSTRAP_WARN_ENVIRONMENT_SETTINGS="`read_config_setting "warn_environment_setting" "YES"`"
}

settings_initialize

