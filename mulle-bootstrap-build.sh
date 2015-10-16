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

. mulle-bootstrap-local-environment.sh
. mulle-bootstrap-gcc.sh
. mulle-bootstrap-scripts.sh


check_and_usage_and_help()
{
   cat <<EOF
usage: build [repos]*

   You can optionally specify the names of the repositories to build.
   Currently available names are:
EOF
   (cd "${CLONES_SUBDIR}" ; ls -1d ) 2> /dev/null
}


if [ "$1" = "-h" -o "$1" = "--help" ]
then
   check_and_usage_and_help >&2
   exit 1
fi



CLEAN_BEFORE_BUILD=`read_config_setting "clean_before_build" "YES"`

#
# move stuff produced my cmake and configure to places
# where we expect them. Expect  others to build to
# <prefix>/include  and <prefix>/lib or <prefix>/Frameworks
#
dispense_headers()
{
   local name
   local src

   name="${1}"
   src="$2"

   local dst
   local headers
   local suffix

   log_fluff "Consider copying headers from ${C_WHITE}${src}${C_FLUFF}"

   if [ -d "${src}" ]
   then
      if dir_has_files "${src}"
      then
         headers="`read_build_setting "${name}" "dispense_headers_path" "/usr/local/${HEADER_DIR_NAME}"`"

         dst="${REFERENCE_DEPENDENCY_SUBDIR}${headers}"
         mkdir_if_missing "${dst}"

         log_fluff "Copying ${C_WHITE}${src}${C_FLUFF} to ${C_WHITE}${dst}${C_FLUFF}"
         exekutor find -x "${src}" ! -path "${src}" -depth 1 -type d -print0 | \
            exekutor xargs -0 -J % mv ${COPYMOVEFLAGS} -n % "${dst}"
         [ $? -eq 0 ]  || exit 1
         exekutor find -x "${src}" ! -path "${src}" -depth 1 \( -type f -o -type l \) -print0 | \
            exekutor xargs -0 -J % mv ${COPYMOVEFLAGS} -n % "${dst}"
         [ $? -eq 0 ]  || exit 1

         rmdir_safer "${src}"
      else
         log_fluff "But there are none"
      fi
   else
      log_fluff "But it doesn't exist"
   fi
}


dispense_binaries()
{
   local src
   local findtype
   local subpath
   local name

   name="$1"
   src="$2"
   findtype="$3"
   subpath="$4"

   local dst
   local usrlocal
   local findtype2

   findtype2="l"

   log_fluff "Consider copying binaries from ${C_WHITE}${src}${C_FLUFF} for type \"${findtype}/${findtype2}\""

   if [ -d "${src}" ]
   then
      if dir_has_files "${src}"
      then
         dst="${REFERENCE_DEPENDENCY_SUBDIR}${subpath}${subdir}"

         log_fluff "Copying ${C_WHITE}${src}${C_FLUFF} to ${C_WHITE}${dst}${C_FLUFF}"
         mkdir_if_missing "${dst}"
         exekutor find -x "${src}" ! -path "${src}" \( -type "${findtype}" -o -type "${findtype2}" \) -depth 1 -print0 | \
            exekutor xargs -0 -J % mv ${COPYMOVEFLAGS} -n % "${dst}"
         [ $? -eq 0 ]  || exit 1
      else
         log_fluff "But threre are none"
      fi
      rmdir_safer "${src}"
   else
      log_fluff "But it doesn't exist"
   fi
}


collect_and_dispense_product()
{
   local  name
   local  subdir
   local  name

   name="${1}"
   subdir="${2}"
   wasxcode="${3}"

   local  dst
   local  src

   if read_yes_no_config_setting "skip_collect_and_dispense" "NO"
   then
      log_info "Skipped collection and dispensal on request"
      return 0
   fi

   log_info "Collecting and dispensing ${C_WHITE}${name}${C_INFO} ${C_MAGENTA}`basename "${subdir}"`${C_INFO} products "
   #
   # probably should use install_name_tool to hack all dylib paths that contain .ref
   # (will this work with signing stuff ?)
   #
   if [ "${wasxcode}" = "YES" ]
   then
      log_fluff "Choosing xcode dispense path"

      src="${BUILD_DEPENDENCY_SUBDIR}/usr/local/include"
      dispense_headers "${name}" "${src}"

      src="${BUILD_DEPENDENCY_SUBDIR}/usr/include"
      dispense_headers "${name}" "${src}"

      src="${BUILD_DEPENDENCY_SUBDIR}/include"
      dispense_headers "${name}" "${src}"

      src="${BUILD_DEPENDENCY_SUBDIR}/lib${subdir}"
      dispense_binaries "${name}" "${src}" "f" "/${LIBRARY_DIR_NAME}"

      src="${BUILD_DEPENDENCY_SUBDIR}/Library/Frameworks${subdir}"
      dispense_binaries "${name}" "${src}" "d" "/${FRAMEWORK_DIR_NAME}"

      src="${BUILD_DEPENDENCY_SUBDIR}/Frameworks${subdir}"
      dispense_binaries "${name}" "${src}" "d" "/${FRAMEWORK_DIR_NAME}"
   else
      log_fluff "Choosing cmake/configure dispense path"

      src="${BUILD_DEPENDENCY_SUBDIR}/usr/local/include"
      dispense_headers "${name}" "${src}"

      src="${BUILD_DEPENDENCY_SUBDIR}/usr/local/lib"
      dispense_binaries "${name}" "${src}" "f" "/${LIBRARY_DIR_NAME}"

      # coming from Cmake and configure ?
      src="${BUILD_DEPENDENCY_SUBDIR}/usr/local/Frameworks"
      dispense_binaries "${name}" "${src}" "d" "/${FRAMEWORK_DIR_NAME}"

      src="${BUILD_DEPENDENCY_SUBDIR}/Library/Frameworks"
      dispense_binaries "${name}" "${src}" "d" "/${FRAMEWORK_DIR_NAME}"

      src="${BUILD_DEPENDENCY_SUBDIR}/Frameworks"
      dispense_binaries "${name}" "${src}" "d" "/${FRAMEWORK_DIR_NAME}"
   fi

   #
   # Delete empty dirs if so
   #
   src="${BUILD_DEPENDENCY_SUBDIR}/usr/local"
   dir_has_files "${src}"
   if [ $? -ne 0 ]
   then
      rmdir_safer "${src}"
   fi

   src="${BUILD_DEPENDENCY_SUBDIR}/usr"
   dir_has_files "${src}"
   if [ $? -ne 0 ]
   then
      rmdir_safer "${src}"
   fi

   #
   # probably should hack all executables with install_name_tool that contain .ref
   #
   # now copy over the rest of the output
   if read_yes_no_build_setting "${name}" "dispense_other_product" "NO"
   then
      local usrlocal

      usrlocal="`read_build_setting "${name}" "dispense_other_path" "/usr/local"`"

      log_fluff "Considering copying ${BUILD_DEPENDENCY_SUBDIR}/*"

      src="${BUILD_DEPENDENCY_SUBDIR}"
      if [ "${wasxcode}" = "YES" ]
      then
         src="${src}${subdir}"
      fi

      if dir_has_files "${src}"
      then
         dst="${REFERENCE_DEPENDENCY_SUBDIR}${usrlocal}"

         log_fluff "Copying everything from ${C_WHITE}${src}${C_FLUFF} to ${C_WHITE}${dst}${C_FLUFF}"
         exekutor find -x "${src}" ! -path "${src}" -depth 1 -print0 | \
               exekutor xargs -0 -J % mv -v -n % "${dst}"
         [ $? -eq 0 ]  || fail "moving files from ${src} to ${dst} failed"
      fi

      if [ "$MULLE_BOOTSTRAP_VERBOSE" = "YES"  ]
      then
         if dir_has_files "${BUILD_DEPENDENCY_SUBDIR}"
         then
            log_fluff "Directory ${C_WHITE}${BUILD_DEPENDENCY_SUBDIR}${C_FLUFF} contained files after collect and dispense"
            log_fluff "--------------------"
            ( cd "${BUILD_DEPENDENCY_SUBDIR}" ; ls -lR >&2 )
            log_fluff "--------------------"
         fi
      fi
   fi

   rmdir_safer "${BUILD_DEPENDENCY_SUBDIR}"

   log_fluff "Done collecting and dispensing product"
   log_fluff
}


enforce_build_sanity()
{
   local builddir

   builddir="$1"

   # these must not exist
   if [ -d "${BUILD_DEPENDENCY_SUBDIR}" ]
   then
      fail "A previous build left ${C_WHITE}${BUILD_DEPENDENCY_SUBDIR}${C_ERROR}, can't continue"
   fi
}


determine_suffix()
{
   local configuration
   local sdk
   local suffix
   local hackish

   configuration="$1"
   sdk="$2"

   [ ! -z "$configuration" ] || fail "configuration must not be empty"
   [ ! -z "$sdk" ] || fail "sdk must not be empty"

   suffix="/${configuration}"
   if [ "${sdk}" != "Default" ]
   then
      hackish=`echo "${sdk}" | sed 's/^\([a-zA-Z]*\).*$/\1/g'`
      suffix="${suffix}-${hackish}"
   fi
   echo "${suffix}"
}


cmake_sdk_parameter()
{
   local sdkpath

   sdkpath=`gcc_sdk_parameter "$1"`
   if [ "${sdkpath}" != "" ]
   then
      echo '-DCMAKE_OSX_SYSROOT='"${sdkpath}"
   fi
}


create_dummy_dirs_against_warnings()
{
   local relative
   local suffix

   builddir="$1"
   configuration="$2"
   suffix="$3"
   relative="$4"

   local owd

   owd="${PWD}"

   # to avoid warnings make sure directories are all there
   [ ! -e "${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${HEADER_DIR_NAME}" ]  &&  \
      mkdir_if_missing "${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${HEADER_DIR_NAME}"
   [ ! -e "${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${configuration}" ]  &&  \
      mkdir_if_missing "${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${configuration}"
   [ ! -e "${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}${suffix}" ]  &&  \
      mkdir_if_missing "${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}${suffix}"


   mkdir_if_missing "${builddir}"
   exekutor cd "${builddir}" ||  fail "failed to enter ${builddir}"

      # check that relative is right
   exekutor [ -d "${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${HEADER_DIR_NAME}" ] || internal_fail "${relative} is wrong"
   exekutor [ -d "${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${configuration}" ] || internal_fail "${relative} is wrong"
   exekutor [ -d "${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}${suffix}" ] || internal_fail "${relative} is wrong"

   exekutor cd "${owd}" ||  fail "failed to enter ${owd}"
}


build_fail()
{
   if [ -f "${1}" ]
   then
      printf "${C_RED}"
      grep -A5 "error:" "${1}" >&2
      printf "${C_RESET}"
   fi

   fail "$2 failed"
}


build_log_name()
{
   local tool
   local name

   tool="$1"
   shift
   name="$1"
   shift

   local logfile
   logfile="${BUILDLOG_SUBDIR}/${name}"

   while [ $# -gt 0 ]
   do
      if [ ! -z "${1}" ]
      then
         logfile="${logfile}-${1}"
      fi
      shift
   done

   echo "${logfile}.${tool}.log"
}

#
# remove old builddir, create a new one
# depending on configuration cmake with flags
# build stuff into dependencies
#
#
build_cmake()
{
   local configuration
   local srcdir
   local builddir
   local relative
   local name
   local sdk
   local mapped

   configuration="$1"
   srcdir="$2"
   builddir="$3"
   relative="$4"
   name="$5"
   sdk="$6"

   enforce_build_sanity "${builddir}"

   log_info "Do a cmake ${C_MAGENTA}${configuration}${C_INFO} build of \
${C_MAGENTA}${name}${C_INFO} for SDK ${C_MAGENTA}${sdk}${C_INFO} ..."

   mapped="`read_build_setting "$name" "cmake-${configuration}.map" "${configuration}"`"
   suffix="`determine_suffix "${configuration}" "${sdk}"`"
   sdk="`cmake_sdk_parameter "${sdk}"`"

   local other_cflags
   local other_cppflags
   local other_ldflags

   other_cflags="`gcc_cflags_value "${name}"`"
   other_cppflags="`gcc_cppflags_value "${name}"`"
   other_ldflags="`gcc_ldflags_value "${name}"`"


   create_dummy_dirs_against_warnings "${builddir}" "${configuration}" "${suffix}" "${relative}"

   local logfile1
   local logfile2

   mkdir_if_missing "${BUILDLOG_SUBDIR}"

   logfile1="`build_log_name "${name}" "cmake" "${configuration}" "${sdk}"`"
   logfile2="`build_log_name "${name}" "make" "${configuration}" "${sdk}"`"

   log_info "Build logs will be in ${C_WHITE}${logfile1}${C_INFO} and ${C_WHITE}${logfile2}${C_INFO}"

   owd="${PWD}"
   mkdir_if_missing "${builddir}"
   exekutor cd "${builddir}" || fail "failed to enter ${builddir}"

      #
      # cmake doesn't seem to "get" CMAKE_CXX_FLAGS or -INCLUDE
      #
      set -f

      logfile1="${owd}/${logfile1}"
      logfile2="${owd}/${logfile2}"
      if [ "$MULLE_BOOTSTRAP_DRY_RUN" = "YES" ]
      then
         logfile1="/dev/null"
         logfile2="/dev/null"
      fi

      logging_exekutor cmake "-DCMAKE_BUILD_TYPE=${mapped}" \
"-DCMAKE_INSTALL_PREFIX:PATH=${owd}/${BUILD_DEPENDENCY_SUBDIR}/usr/local"  \
"-DCMAKE_C_FLAGS=\
-I${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${HEADER_DIR_NAME} \
-F${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}${suffix} \
-F${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${configuration} \
-F${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME} \
${other_cflags} \
${sdk}" \
"-DCMAKE_CXX_FLAGS=\
-I${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${HEADER_DIR_NAME} \
-F${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}${suffix} \
-F${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${configuration} \
-F${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME} \
${other_cppflags} \
${sdk}" \
"-DCMAKE_LD_FLAGS=\
-L${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${LIBRARY_DIR_NAME}${suffix} \
-L${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${LIBRARY_DIR_NAME}/${configuration} \
-L${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${LIBRARY_DIR_NAME} \
-F${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}${suffix} \
-F${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${configuration} \
-F${relative}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME} \
${other_ldflags} \
${sdk}" \
"${relative}/${srcdir}" >> "${logfile1}" || build_fail "${logfile1}" "cmake"

      logging_exekutor make all install >> "${logfile2}" || build_fail "${logfile2}" "make"

      set +f

   exekutor cd "${owd}"

   collect_and_dispense_product "${name}" "${suffix}" || internal_fail "collect failed silently"
}


#
# remove old builddir, create a new one
# depending on configuration cmake with flags
# build stuff into dependencies
#
#
build_configure()
{
   local configuration
   local srcdir
   local builddir
   local relative
   local name
   local sdk
   local mapped

   configuration="$1"
   srcdir="$2"
   builddir="$3"
   relative="$4"
   name="$5"
   sdk="$6"

   enforce_build_sanity "${builddir}"

   log_info "Do a configure ${C_MAGENTA}${configuration}${C_INFO} build of \
${C_MAGENTA}${name}${C_INFO} for SDK ${C_MAGENTA}${sdk}${C_INFO} ..."


   mapped="`read_build_setting "$name" "configure-${configuration}.map" "${configuration}"`"
   suffix="`determine_suffix "${configuration}" "${sdk}"`"
   sdk="`gcc_sdk_parameter "${sdk}"`"

   local other_cflags
   local other_cppflags
   local other_ldflags

   other_cflags="`gcc_cflags_value "${name}"`"
   other_cppflags="`gcc_cppflags_value "${name}"`"
   other_ldflags="`gcc_ldflags_value "${name}"`"

   create_dummy_dirs_against_warnings "${builddir}" "${configuration}" "${suffix}" "${relative}"

   local logfile1
   local logfile2

   mkdir_if_missing "${BUILDLOG_SUBDIR}"

   logfile1="`build_log_name "${name}" "configure" "${configuration}" "${sdk}"`"
   logfile2="`build_log_name "${name}" "make" "${configuration}" "${sdk}"`"

   log_info "Build logs will be in ${C_WHITE}${logfile1}${C_INFO} and ${C_WHITE}${logfile2}${C_INFO}"

   owd="${PWD}"
   mkdir_if_missing "${builddir}"
   exekutor cd "${builddir}" || fail "failed to enter ${builddir}"

       set -f

      logfile1="${owd}/${logfile1}"
      logfile2="${owd}/${logfile2}"
      if [ "$MULLE_BOOTSTRAP_DRY_RUN" = "YES" ]
      then
         logfile1="/dev/null"
         logfile2="/dev/null"
      fi

      # use absolute paths for configure, safer (and easier to read IMO)
       echo "CFLAGS=\"\
-I${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${HEADER_DIR_NAME} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}${suffix} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${configuration} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME} \
${other_cflags} \
${sdk}\" \
      CPPFLAGS=\"\
-I${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${HEADER_DIR_NAME} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}${suffix} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${configuration} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME} \
${other_cppflags} \
${sdk}\" \
      LDFLAGS=\"\
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}${suffix} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${configuration} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME} \
-L${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${LIBRARY_DIR_NAME}${suffix} \
-L${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${LIBRARY_DIR_NAME}/${configuration} \
-L${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${LIBRARY_DIR_NAME} \
${other_ldflags} \
${sdk}\"" >> "${logfile1}"


       CFLAGS="\
-I${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${HEADER_DIR_NAME} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}${suffix} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${configuration} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME} \
${other_cflags} \
${sdk}" \
      CPPFLAGS="\
-I${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${HEADER_DIR_NAME} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}${suffix} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${configuration} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME} \
${other_cppflags} \
${sdk}" \
      LDFLAGS="\
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}${suffix} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${configuration} \
-F${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME} \
-L${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${LIBRARY_DIR_NAME}${suffix} \
-L${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${LIBRARY_DIR_NAME}/${configuration} \
-L${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${LIBRARY_DIR_NAME} \
${other_ldflags} \
${sdk}" \
       logging_exekutor "${owd}/${srcdir}/configure" \
          --prefix "${owd}/${BUILD_DEPENDENCY_SUBDIR}/usr/local" >> "${logfile1}" \
      || build_fail "${logfile1}" "configure"

      logging_exekutor make all install >> "${logfile2}" \
      || build_fail "${logfile2}" "make"

      set +f

   exekutor cd "${owd}"

   collect_and_dispense_product "${name}" "${suffix}" || exit 1
}


_xcode_get_setting()
{
   eval_exekutor "xcodebuild -showBuildSettings $*" || fail "failed to read xcode settings"
}


xcode_get_setting()
{
   local key

   key="$1"
   shift

   _xcode_get_setting "$@" | egrep "^[ ]*${key}" | sed 's/^[^=]*=[ ]*\(.*\)/\1/'
}


#
# Code I didn't want to throw away really
# In general just uss "public_headers" or
# "private_headers" and set them to a /usr/local/include/whatever
#
create_mangled_header_path()
{
   local name
   local key
   local default

   key="$1"
   name="$2"
   default="$3"

   local headers
   local prefix

   headers=`xcode_get_setting "${key}" $*` || exit 1
   log_fluff "${key} read as \"${headers}\""

   case "${headers}" in
      /*)
      ;;

      ./*|../*)
         log_warning "relative path \"${headers}\" as header path ???"
      ;;

      "")
         headers="${default}"
      ;;

      *)
         headers="/${headers}"
      ;;
   esac

   prefix=""
   read_yes_no_build_setting "${name}" "xcode_mangle_include_prefix"
   if [ $? -ne 0 ]
   then
      headers="`remove_absolute_path_prefix_up_to "${headers}" "include"`"
      prefix="${HEADER_DIR_NAME}"
   fi

   if read_yes_no_build_setting "${name}" "xcode_mangle_header_dash"
   then
      headers="`echo "${headers}" | tr '-' '_'`"
   fi

   echo "${headers}"
}


fixup_header_path()
{
   local key
   local setting_key
   local default
   local name

   key="$1"
   shift
   setting_key="$1"
   shift
   name="$1"
   shift
   default="$1"
   shift

   headers="`read_repo_setting "${name}" "${setting_key}"`"
   if [ "$headers" = "" ]
   then
      read_yes_no_build_setting "${name}" "xcode_mangle_header_paths"
      if [ $? -ne 0 ]
      then
         return 1
      fi

      headers="`create_mangled_header_path "${key}" "${name}" "${default}"`"
   fi

   log_fluff "${key} set to \"${headers}\""

   echo "${headers}"
}


escaped_spaces()
{
   echo "$1" | sed 's/ /\\ /g'
}


combined_escaped_search_path()
{
   for i in "$@"
   do
      if [ ! -z "$i" ]
      then
         i="`escaped_spaces "$i"`"
         if [ -z "$path" ]
         then
            path="$i"
         else
            path="$path $i"
         fi
      fi
   done

   echo "${path}"
}



build_xcodebuild()
{
   local configuration
   local srcdir
   local builddir
   local relative
   local name
   local sdk
   local project
   local schemename
   local targetname

   configuration="$1"
   srcdir="$2"
   builddir="$3"
   relative="$4"
   name="$5"
   sdk="$6"
   project="$7"
   schemename="$8"
   targetname="$9"

   [ -z "${configuration}" ] && internal_fail "configuration is empty"
   [ -z "${srcdir}" ]      && internal_fail "srcdir is empty"
   [ -z "${builddir}" ]    && internal_fail "builddir is empty"
   [ -z "${relative}" ]    && internal_fail "relative is empty"
   [ -z "${name}" ]        && internal_fail "name is empty"
   [ -z "${sdk}" ]         && internal_fail "sdk is empty"
   [ -z "${project}" ]     && internal_fail "project is empty"

   enforce_build_sanity "${builddir}"

   local info

   info=""
   if [ ! -z "${targetname}" ]
   then
      info="Target ${C_MAGENTA}${targetname}${C_INFO}"
   fi

   if [ ! -z "${schemename}" ]
   then
      info="Scheme ${C_MAGENTA}${schemename}${C_INFO}"
   fi

   log_info "Do a xcodebuild ${C_MAGENTA}${configuration}${C_INFO} of \
${C_MAGENTA}${name}${C_INFO} for SDK ${C_MAGENTA}${sdk}${C_INFO} \
${info} ..."

   local projectname

    # always pass project directly
   projectname=`read_repo_setting "${name}" "project" "${project}"`

   local mapped

   mapped=`read_build_setting "${name}" "${configuration}.map" "${configuration}"`
   [ -z "${mapped}" ] && internal_fail "mapped configuration is empty"

   local hackish
   local targetname
   local suffix

   suffix="/${configuration}"
   if [ "${sdk}" != "Default" ]
   then
      hackish="`echo "${sdk}" | sed 's/^\([a-zA-Z]*\).*$/\1/g'`"
      suffix="${suffix}-${hackish}"
   else
      sdk=
   fi

   local xcode_proper_skip_install
   local skip_install

   skip_install=
   xcode_proper_skip_install=`read_build_setting "${name}" "xcode_proper_skip_install" "NO"`
   if [ "$xcode_proper_skip_install" != "YES" ]
   then
      skip_install="SKIP_INSTALL=NO"
   fi

   local xcodebuild
   local binary

   xcodebuild=`read_config_setting "xcodebuild" "xcodebuild"`
   binary=`which "${xcodebuild}"`
   if [ "${binary}"  = "" ]
   then
      echo "${xcodebuild} is an unknown build tool" >& 2
      exit 1
   fi


   #
   # xctool needs schemes, these are often autocreated, which xctool cant do
   # xcodebuild can just use a target
   # xctool is by and large useless fluff IMO
   #
   if [ "$xcodebuild" = "xctool"  -a "${schemename}" = ""  ]
   then
      if [ "$targetname" != "" ]
      then
         schemename="${targetname}"
         targetname=
      else
         echo "Please specify a scheme to compile in ${BOOTSTRAP_SUBDIR}/${name}/SCHEME for xctool" >& 2
         echo "and be sure that this scheme exists and is shared." >& 2
         echo "Or just delete ${HOME}/.mulle-bootstrap/xcodebuild and use xcodebuild (preferred)" >& 2
         exit 1
      fi
   fi

   local key
   local aux
   local value
   local keys

   aux=
   keys=`all_build_flag_keys "${name}"`
   for key in ${keys}
   do
      value=`read_build_setting "${name}" "${key}"`
      aux="${aux} ${key}=${value}"
   done

   # now don't load any settings anymoe
   local owd
   local command

   if [ "$MULLE_BOOTSTRAP_DRY" != "" ]
   then
      command=-showBuildSettings
   else
      command=install
   fi

      #
      # headers are complicated, the preference is to get it uniform into
      # dependencies/include/libraryname/..
      #

   local public_headers
   local private_headers
   local default

   default="/include/${name}"
   public_headers="`fixup_header_path "PUBLIC_HEADERS_FOLDER_PATH" "xcode_public_headers" "${name}" "${default}" ${arguments}`"
   default="/include/${name}/private"
   private_headers="`fixup_header_path "PRIVATE_HEADERS_FOLDER_PATH" "xcode_private_headers" "${name}" "${default}" ${arguments}`"


   local logfile

   mkdir_if_missing "${BUILDLOG_SUBDIR}"

   logfile="`build_log_name "${name}" "xcodebuild" "${configuration}" "${targetname}" "${schemename}" "${sdk}"`"
   log_info "Build log will be in ${C_WHITE}${logfile}${C_INFO}"

   set -f

   arguments=""
   if [ ! -z "${projectname}" ]
   then
      arguments="${arguments} -project \"${projectname}\""
   fi
   if [ ! -z "${sdk}" ]
   then
      arguments="${arguments} -sdk \"${sdk}\""
   fi
   if [ ! -z "${schemename}" ]
   then
      arguments="${arguments} -scheme \"${schemename}\""
   fi
   if [ ! -z "${targetname}" ]
   then
      arguments="${arguments} -target \"${targetname}\""
   fi
   if [ ! -z "${mapped}" ]
   then
      arguments="${arguments} -configuration \"${mapped}\""
   fi

   owd=`pwd`
   exekutor cd "${srcdir}" || exit 1


      logfile="${owd}/${logfile}"
      if [ "$MULLE_BOOTSTRAP_DRY_RUN" = "YES" ]
      then
         logfile="/dev/null"
      fi

      # manually point xcode to our headers and libs
      # this is like manually doing xcode-setup
      local dependencies_framework_search_path
      local dependencies_header_search_path
      local dependencies_lib_search_path
      local inherited
      local path
      local escaped

      #
      # TODO: need to figure out the correct mapping here
      #
      inherited="`xcode_get_setting HEADER_SEARCH_PATHS ${arguments}`" || exit 1
      path=`combined_escaped_search_path \
"${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${HEADER_DIR_NAME}" \
"/usr/local/include"`
      if [ -z "${inherited}" ]
      then
         dependencies_header_search_path="${path}"
      else
         dependencies_header_search_path="${path} ${inherited}"
      fi

      inherited="`xcode_get_setting LIBRARY_SEARCH_PATHS ${arguments}`" || exit 1
      path=`combined_escaped_search_path \
"${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${LIBRARY_DIR_NAME}/${mapped}" \
"${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${LIBRARY_DIR_NAME}" \
"/usr/local/lib"`
      if [ ! -z "$sdk" ]
      then
         escaped="`escaped_spaces "${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${LIBRARY_DIR_NAME}/${mapped}"'-$(EFFECTIVE_PLATFORM_NAME)'`"
         path="${escaped} ${path}" # prepend
      fi
      if [ -z "${inherited}" ]
      then
         dependencies_lib_search_path="${path}"
      else
         dependencies_lib_search_path="${path} ${inherited}"
      fi


      inherited="`xcode_get_setting FRAMEWORK_SEARCH_PATHS ${arguments}`" || exit 1
      path=`combined_escaped_search_path \
"${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${mapped}" \
"${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}"`
      if [ ! -z "$sdk" ]
      then
         escaped="`escaped_spaces "${owd}/${REFERENCE_DEPENDENCY_SUBDIR}/${FRAMEWORK_DIR_NAME}/${mapped}"'-$(EFFECTIVE_PLATFORM_NAME)'`"
         path="${escaped} ${path}" # prepend
      fi
      if [ -z "${inherited}" ]
      then
         dependencies_framework_search_path="${path}"
      else
         dependencies_framework_search_path="${path} ${inherited}"
      fi

      if [ ! -z "${public_headers}" ]
      then
         arguments="${arguments} PUBLIC_HEADERS_FOLDER_PATH='${public_headers}'"
      fi
      if [ ! -z "${private_headers}" ]
      then
         arguments="${arguments} PRIVATE_HEADERS_FOLDER_PATH='${private_headers}'"
      fi

      # if it doesn't install, probably SKIP_INSTALL is set
      cmdline="\"${xcodebuild}\" \"${command}\" ${arguments} \
ARCHS='\${ARCHS_STANDARD_32_64_BIT}' \
DSTROOT='${owd}/${BUILD_DEPENDENCY_SUBDIR}' \
INSTALL_PATH='/${LIBRARY_DIR_NAME}${suffix}' \
SYMROOT='${owd}/${builddir}/' \
OBJROOT='${owd}/${builddir}/obj' \
ONLY_ACTIVE_ARCH=NO \
${skip_install} \
HEADER_SEARCH_PATHS='${dependencies_header_search_path}' \
LIBRARY_SEARCH_PATHS='${dependencies_lib_search_path}' \
FRAMEWORK_SEARCH_PATHS='${dependencies_framework_search_path}'"

      logging_eval_exekutor "${cmdline}" >> "${logfile}" \
      || build_fail "${logfile}" "xcodebuild"

      set +f

   exekutor cd "${owd}"

   collect_and_dispense_product "${name}" "${suffix}" "YES" || exit 1
}


build_xcodebuild_schemes_or_target()
{
   local builddir
   local name
   local project

   builddir="$3"
   name="$5"
   project="$7"

   if [ -d "${builddir}" -a "${CLEAN_BEFORE_BUILD}" = "YES" ]
   then
      log_fluff "Cleaning build directory \"${builddir}\""
      rmdir_safer "${builddir}"
   fi

   local scheme
   local schemes

   schemes=`read_repo_setting "${name}" "schemes"`

   local old

   old="${IFS:-" "}"
   IFS="
"
   for scheme in $schemes
   do
      IFS="$old"
      log_fluff "Building scheme \"${scheme}\" of \"${project}\" ..."
      build_xcodebuild "$@" "${scheme}" ""
   done
   IFS="${old}"

   local target
   local targets

   targets=`read_repo_setting "${name}" "targets"`

   old="$IFS"
   IFS="
"
   for target in $targets
   do
      IFS="${old}"
      log_fluff "Building target \"${target}\" of \"${project}\" ..."
      build_xcodebuild "$@" "" "${target}"
   done
   IFS="${old}"

   if [ "${targets}" = "" -a "${schemes}" = "" ]
   then
      log_fluff "Building project \"${project}\"..."
      build_xcodebuild "$@"
   fi
}


build_script()
{
   local script

   script="$1"
   shift

   local configuration
   local srcdir
   local builddir
   local relative
   local name
   local sdk
   local project
   local schemename
   local targetname

   configuration="$1"
   srcdir="$2"
   builddir="$3"
   relative="$4"
   name="$5"
   sdk="$6"

   local logfile

   mkdir_if_missing "${BUILDLOG_SUBDIR}"
   logfile="${BUILDLOG_SUBDIR}/${name}-${configuration}-${sdk}.script.log"

   log_info "Build log will be in ${C_WHITE}${logfile}${C_INFO}"

   local owd

   owd=`pwd`
   exekutor cd "${srcdir}" || exit 1

      logfile="${owd}/${logfile}"
      if [ "$MULLE_BOOTSTRAP_DRY_RUN" = "YES" ]
      then
         logfile="/dev/null"
      fi

      log_info "Running build script for ${C_MAGENTA}${configuration}${C_INFO}"
      run_log_script "${owd}/${script}" \
         "${configuration}" \
         "${owd}/${srcdir}" \
         "${owd}/${builddir}" \
         "${owd}/${BUILD_DEPENDENCY_SUBDIR}" \
         "${name}" \
         "${sdk}" >> "${logfile}" \
      || build_fail "${logfile}" "build.sh"

   exekutor cd "${owd}"

   local suffix

   suffix="`determine_suffix "${configuration}" "${sdk}"`"
   collect_and_dispense_product "${name}" "${suffix}" || internal_fail "collect failed silently"

   return $rval
}



build()
{
   local srcdir

   srcdir="$1"

   local name

   name=`basename "${srcdir}"`
   [ "${name}" != "${CLONES_SUBDIR}" ] || internal_fail "missing repo argument (${srcdir})"

   local preferences
   local configurations

   #
   # repo may override how it wants to be build
   #
   preferences="`read_build_setting "${name}" "build_preferences"`"
   if [ -z "${preferences}" ]
   then
      preferences="`read_config_setting "build_preferences" "script
xcodebuild
cmake
configure"`"
   fi

   configurations="`read_build_root_setting "configurations" "Debug
Release"`"

   local xcodebuild
   local cmake

   xcodebuild=`which "xcodebuild"`
   cmake=`which "cmake"`

   local sdk
   local sdks

   # need uniform SDK for our builds
   sdks=`read_build_root_setting "sdks" "Default"`
   [ ! -z "${sdks}" ] || fail "setting \"sdks\" must at least contain \"Default\" to build anything"

   local builddir
   local relative
   local hasbuilt
   local configuration
   local preference

   for sdk in ${sdks}
   do
      for configuration in ${configurations}
      do
         if [ "$/{configuration}" = "/${LIBRARY_DIR_NAME}" -o "/${configuration}" = "${HEADER_DIR_NAME}" -o "/${configuration}" = "${FRAMEWORK_DIR_NAME}" ]
         then
            fail "You are just asking for trouble."
         fi

         if [ "${configuration}" = "lib" -o "${configuration}" = "include" -o "${configuration}" = "Frameworks" ]
         then
            fail "You are just asking for major trouble."
         fi

         builddir="${CLONESBUILD_SUBDIR}/${configuration}/${name}"
         relative="${CLONESBUILD_RELATIVE}/../.."

         hasbuilt=no
         for preference in ${preferences}
         do
            if [ "${preference}" = "script" ]
            then
               local script

               script="`find_build_setting_file "${name}" "bin/build.sh"`"
               if [ -x "${script}" ]
               then
                  build_script "${script}" "${configuration}" "${srcdir}" "${builddir}" "${relative}" "${name}" "${sdk}" || exit 1
                  hasbuilt=yes
                  break
               else
                  [ ! -e "${script}" ] || fail "script ${script} is not executable"
               fi
            fi

            if [ "${preference}" = "xcodebuild" -a -x "${xcodebuild}" ]
            then
               project=`(cd "${srcdir}" ; find_xcodeproj "${name}")`

               if [ "$project" != "" ]
               then
                  build_xcodebuild_schemes_or_target "${configuration}" "${srcdir}" "${builddir}" "${relative}" "${name}" "${sdk}" "${project}"  || exit 1
                  hasbuilt=yes
                  break
               fi
            fi

            if [ "${preference}" = "configure"  ]
            then
               if [ ! -f "${srcdir}/configure"  ]
               then
                  # try for autogen if installed (not coded yet)
                  :
               fi
               if [ -x "${srcdir}/configure" ]
               then
                  build_configure "${configuration}" "${srcdir}" "${builddir}" "${relative}" "${name}" "${sdk}"  || exit 1
                  hasbuilt=yes
                  break
               fi
            fi

            if [ "${preference}" = "cmake" -a -x "${cmake}" ]
            then
               if [ -f "${srcdir}/CMakeLists.txt" ]
               then
                  build_cmake "${configuration}" "${srcdir}" "${builddir}" "${relative}" "${name}" "${sdk}"  || exit 1
                  hasbuilt=yes
                  break
               fi
            fi
         done

         if [ "$hasbuilt" != "yes" ]
         then
            fail "Don't know how to build ${name}"
         fi
      done
   done
}


#
# ${DEPENDENCY_SUBDIR} is split into
#
#  REFERENCE_DEPENDENCY_SUBDIR and
#  BUILD_DEPENDENCY_SUBDIR
#
# above this function, noone should access ${DEPENDENCY_SUBDIR}
#
build_wrapper()
{
   local dstdir
   local name

   dstdir="$1"
   name="$2"


   REFERENCE_DEPENDENCY_SUBDIR="${DEPENDENCY_SUBDIR}"
   BUILD_DEPENDENCY_SUBDIR="${DEPENDENCY_SUBDIR}/tmp"

   DEPENDENCY_SUBDIR="WRONG_DONT_USE_DEPENDENCY_SUBDIR_DURING_BUILD"

   log_fluff "Setting up BUILD_DEPENDENCY_SUBDIR as \"${BUILD_DEPENDENCY_SUBDIR}\""

   if [ -d "${BUILD_DEPENDENCY_SUBDIR}" ]
   then
      log_info "Cleaning up orphaned \"${BUILD_DEPENDENCY_SUBDIR}\""
      rmdir_safer "${BUILD_DEPENDENCY_SUBDIR}"
   fi

   export BUILD_DEPENDENCY_SUBDIR
   export REFERENCE_DEPENDENCY_SUBDIR
   #
   # move dependencies we have so far away into safety,
   # need that path for includes though
   #

   run_repo_settings_script "${dstdir}" "${name}" "pre-build" "$@" || exit 1

   build "${dstdir}" || exit 1

   run_repo_settings_script "${dstdir}" "${name}" "post-build" "$@" || exit 1

   log_fluff "Remove \"${BUILD_DEPENDENCY_SUBDIR}\""

   rmdir_safer "${BUILD_DEPENDENCY_SUBDIR}"

   DEPENDENCY_SUBDIR="${REFERENCE_DEPENDENCY_SUBDIR}"

   REFERENCE_DEPENDENCY_SUBDIR="WRONG_DONT_USE_REFERENCE_DEPENDENCY_SUBDIR_AFTER_BUILD"
   BUILD_DEPENDENCY_SUBDIR="WRONG_DONT_USE_BUILD_DEPENDENCY_SUBDIR_AFTER_BUILD"
}


build_if_readable()
{
   local dstdir
   local name

   dstdir="$1"
   name="$2"

   local xdone
   if [ ! -r "${dstdir}" ]
   then
      echo "Ignoring orphaned repo ${name}" >&2
   else
      xdone="`/bin/echo "${BUILT}" | grep -x "${name}"`"
      if [ "$xdone" = "" ]
      then
         build_wrapper "${dstdir}" "${name}"
         BUILT="${name}
${BUILT}"
      else
         log_fluff "Ignoring \"${name}\". (Either in \"build_ignore\" or already built)"
      fi
   fi
}


build_clones()
{
   local clone
   local xdone
   local name
   local dstdir

   for clone in ${CLONES_SUBDIR}/*.failed
   do
      if [ -d "${clone}" ]
      then
         fail "failed checkout $clone detected, can't continue"
      fi
   done

   run_build_root_settings_script "pre-build" "$@"

   #
   # build order is there, because we want to have gits
   # and maybe later hgs
   #
   BUILT=
   export BUILT

   if [ "$#" -eq 0 ]
   then
      BUILT="`read_build_root_setting "build_ignore"`"

      for clone in `read_build_root_setting "build_order"`
      do
         name="`canonical_clone_name "${clone}"`"
         dstdir="${CLONES_SUBDIR}/${name}"

         if [ -d "${dstdir}" ]
         then
            build_if_readable "${dstdir}" "${name}"  || exit 1
         else
            fail "build_order contains unknown repo \"${clone}\" (\"${dstdir}\")"
         fi
      done

      #
      # otherwise compile in gits order
      #
      clones="`read_fetch_setting "gits"`"
      if [ "${clones}" != "" ]
      then
         for clone in ${clones}
         do
            name="`canonical_clone_name "${clone}"`"
            dstdir="${CLONES_SUBDIR}/${name}"

            if [ -d "${dstdir}" ]
            then
               build_if_readable "${dstdir}" "${name}" || exit  1
            else
               fail "repo for \"${clone}\" not found (\"${dstdir}\") ($PWD)"
            fi
         done
      fi
   else
      for name in "$@"
      do
         dstdir="${CLONES_SUBDIR}/${name}"

         if [ -d "${dstdir}" ]
         then
            build_if_readable "${dstdir}" "${name}" || exit 1
         else
            fail "unknown repo ${name}"
         fi
      done
   fi

   run_build_root_settings_script "post-build" "$@"
}


install_tars()
{
   local tarballs
   local tar


   tarballs=`read_fetch_setting "tarballs" | sort | sort -u`
   if [ "${tarballs}" != "" ]
   then
      local old

      old="${IFS:-" "}"
      IFS="
"
      for tar in ${tarballs}
      do
         if [ ! -f "$tar" ]
         then
            fail "tarball \"$tar\" not found"
         else
            log_info "Installing tarball ${C_WHITE}${tar}${C_INFO}"
            exekutor tar -xz -C "${DEPENDENCY_SUBDIR}" -f "${tar}" || fail "failed to extract ${tar}"
         fi
      done
      IFS="${old}"
   fi
}


main()
{
   local  clean

   log_fluff "::: build :::"

   #
   # START
   #
   if [ ! -d "${CLONES_SUBDIR}" ]
   then
      log_info "No repos fetched, so nothing to build."
      return 0
   fi

   if [ $# -eq 0 ]
   then
      log_fluff "Setting up dependencies directory as \"${DEPENDENCY_SUBDIR}\""
      clean="`read_config_setting "clean_dependencies_before_build" "YES"`"
      if [ "${clean}" = "YES" ]
      then
         rmdir_safer "${DEPENDENCY_SUBDIR}"
      fi
   else
      log_fluff "Keeping \"${DEPENDENCY_SUBDIR}\" intact, as this is a partial build."
   fi

   # if present then we didnt't want to clean and we do nothing special
   if [ ! -d "${DEPENDENCY_SUBDIR}" ]
   then
      mkdir_if_missing "${DEPENDENCY_SUBDIR}/usr/local/include"
      exekutor ln -s "usr/local/include" "${DEPENDENCY_SUBDIR}/include" || fail "failed to symlink future usr/local/include"
      install_tars "$@"
   else
      log_warning "Tars have not been installed, as ${C_WHITE}${DEPENDENCY_SUBDIR}${C_WARNING} already exists."
   fi

   build_clones "$@"

   if [ $# -eq 0 ]
   then
      if [ "${clean}" = "YES" -a -d "${DEPENDENCY_SUBDIR}" ]
      then
         log_info "Write-protecting ${C_WHITE}${DEPENDENCY_SUBDIR}${C_INFO} to avoid spurious header edits"
         exekutor chmod -R a-w "${DEPENDENCY_SUBDIR}"
      fi
   fi
}

main "$@"
