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

#
# this script installs the proper git clones into "clones"
# it does not to git subprojects.
# You can also specify a list of "brew" dependencies. That
# will be third party libraries, you don't tag or debug
#
. mulle-bootstrap-local-environment.sh
. mulle-bootstrap-brew.sh
. mulle-bootstrap-scm.sh
. mulle-bootstrap-scripts.sh
. mulle-bootstrap-auto-update.sh


usage()
{
   cat <<EOF
usage: fetch <install|nonrecursive|update>
   install      : clone or symlink non-exisiting repositories and other resources
   nonrecursive : like above, but ignore .bootstrap folders of repositories
   update       : pull in fetched repositories

   You can specify the names of the repositories to update.
   Currently available names are:
EOF
   (cd "${CLONESFETCH_SUBDIR}" ; ls -1 ) 2> /dev/null
}


check_and_usage_and_help()
{
   case "$COMMAND" in
      install)
         ;;
      nonrecursive)
        COMMAND=install
        DONT_RECURSE="YES"
         ;;
         update)
         ;;
      *)
         usage >&2
         exit 1
         ;;
   esac
}


if [ "$1" = "-h" -o "$1" = "--help" ]
then
   COMMAND=help
else
   if [ -z "${COMMAND}" ]
   then
      COMMAND=${1:-"install"}
      [ $# -eq 0 ] || shift
   fi

   if [ "${MULLE_BOOTSTRAP}" = "mulle-bootstrap" ]
   then
      COMMAND="install"
   fi
fi

check_and_usage_and_help


#
# Use brews for stuff we don't tag
#
install_taps()
{
   local tap
   local taps
   local old

   log_fluff "Looking for taps"

   taps=`read_fetch_setting "taps" | sort | sort -u`
   if [ "${taps}" != "" ]
   then
      local old

      fetch_brew_if_needed

      old="${IFS:-" "}"
      IFS="
"
      for tap in ${taps}
      do
         IFS="${old}"
         exekutor brew tap "${tap}" > /dev/null || exit 1
      done
      IFS="${old}"
   else
      log_fluff "No taps found"
   fi
}


install_brews()
{
   local brew
   local brews

   install_taps

   log_fluff "Looking for brews"

   brews=`read_fetch_setting "brews" | sort | sort -u`
   if [ "${brews}" != "" ]
   then
      local old

      old="${IFS:-" "}"
      IFS="
"
      for brew in ${brews}
      do
         IFS="${old}"
         if [ "`which "${brew}"`" = "" ]
         then
            brew_update_if_needed "${brew}"

            log_fluff "brew ${COMMAND} \"${brew}\""
            exekutor brew "${COMMAND}" "${brew}" || exit 1
         else
            log_info "\"${brew}\" is already installed."
         fi
      done
      IFS="${old}"
   else
      log_fluff "No brews found"
   fi
}


#
# future, download tarballs...
# we check for existance during fetch, but install during build
#
check_tars()
{
   local tarballs
   local tar

   log_fluff "Looking for tarballs"

   tarballs="`read_fetch_setting "tarballs" | sort | sort -u`"
   if [ "${tarballs}" != "" ]
   then
      local old

      old="${IFS:-" "}"
      IFS="
"
      for tar in ${tarballs}
      do
         IFS="${old}"
         if [ ! -f "$tar" ]
         then
            fail "tarball \"$tar\" not found"
         fi
         log_fluff "tarball \"$tar\" found"
      done
      IFS="${old}"
   else
      log_fluff "No tarballs found"
   fi
}


#
# Use gems for stuff we don't tag
#
install_gems()
{
   local gems
   local gem

   log_fluff "Looking for gems"

   gems="`read_fetch_setting "gems" | sort | sort -u`"
   if [ "${gems}" != "" ]
   then
      local old

      old="${IFS:-" "}"
      IFS="
"
      for gem in ${gems}
      do
         IFS="${old}"
         log_fluff "gem install \"${gem}\""

         echo "gem needs sudo to install ${gem}" >&2
         exekutor sudo gem install "${gem}" || exit 1
      done
      IFS="${old}"
   else
      log_fluff "No gems found"
   fi
}


#
# Use pips for stuff we don't tag
#
install_pips()
{
   local pips
   local pip

   log_fluff "Looking for pips"

   pips="`read_fetch_setting "pips" | sort | sort -u`"
   if [ "${pips}" != "" ]
   then
      local old

      old="${IFS:-" "}"
      IFS="
"
      for pip in ${pips}
      do
         IFS="${old}"
         log_fluff "pip install \"${gem}\""

         echo "pip needs sudo to install ${pip}" >&2
         exekutor sudo pip install "${pip}" || exit 1
      done
      IFS="${old}"
   else
      log_fluff "No pips found"
   fi
}


#
###
#
link_command()
{
   local src
   local dst
   local tag

   src="$1"
   dst="$2"
   tag="$3"

   local dstdir
   dstdir="`dirname -- "${dst}"`"

   if [ ! -e "${dstdir}/${src}" ]
   then
      fail "\"${dstdir}/${src}${C_ERROR} does not exist ($PWD)"
   fi

   if [ "${COMMAND}" = "install" ]
   then
      #
      # relative paths look nicer, but could fail in more complicated
      # settings, when you symlink something, and that repo has symlinks
      # itself
      #
      if read_yes_no_config_setting "absolute_symlinks" "NO"
      then
         local real

         real="`( cd "${dstdir}" ; realpath "${src}")`"
         log_fluff "Converted symlink \"${src}\" to \"${real}\""
         src="${real}"
      fi

      log_info "Symlinking ${C_MAGENTA}${C_BOLD}`basename -- ${src}`${C_INFO} ..."
      exekutor ln -s -f "$src" "$dst" || fail "failed to setup symlink \"$dst\" (to \"$src\")"

      if [ "$tag" != "" ]
      then
         local name

         name="`basename -- "${dst}"`"
         log_warning "tag ${tag} will be ignored, due to symlink" >&2
         log_warning "if you want to checkout this tag do:" >&2
         log_warning "${C_RESET}(cd .repos/${name}; git ${GITFLAGS} checkout \"${tag}\" )${C_WARNING}" >&2
      fi
   fi

   # when we link, we assume that dependencies are there
}


ask_symlink_it()
{
   local  clone

   clone="$1"
   if [ ! -d "${clone}" ]
   then
      fail "You need to check out ${clone} yourself, as it's not there."
   fi

   #
   # check if checked out
   #
   if [ -d "${clone}"/.git ]
   then
       # if bare repo, we can only clone anyway
      if git_is_bare_repository "${clone}"
      then
         log_info "${clone} is a bare git repository. So cloning"
         log_info "is the only way to go."
         return 1
      fi

      flag=1  # mens clone it
      if [ "${SYMLINK_FORBIDDEN}" != "YES" ]
      then
         user_say_yes "Should ${clone} be symlinked instead of cloned ?
   You usually say NO to this, even more so, if tag is set (tag=${tag})"
         flag=$?
      fi
      [ $flag -eq 0 ]
      return $?
   fi

   # can only symlink because not a .git repo yet
   if [ "${SYMLINK_FORBIDDEN}" != "YES" ]
   then
      log_info "${clone} is not a git repository (yet ?)"
      log_info "So symlinking is the only way to go."
      return 0
   fi

   fail "Can't symlink"
}



log_fetch_action()
{
   local dstdir
   local url

   url="$1"
   dstdir="$2"

   local info

   if [ -L "${url}" ]
   then
      info=" symlinked "
   else
      info=" "
   fi

   log_fluff "Perform ${COMMAND}${info}${url} in ${dstdir} ..."
}


search_git_repo_in_parent_directory()
{
   local name
   local branch

   name="$1"
   branch="$2"

   local found

   if [ ! -z "${branch}" ]
   then
      found="../${name}.${branch}"
      if [ -d "${found}" ]
      then
         echo "${found}"
         return
      fi
   fi

   found="../${name}"
   if [ -d "${found}" ]
   then
      echo "${found}"
      return
   fi

   found="../${name}.git"
   if [ -d "${found}" ]
   then
      echo "${found}"
      return
   fi
}



checkout()
{
   local url
   local name
   local dstdir
   local branch
   local tag

   name="$1"
   url="$2"
   dstdir="$3"
   branch="$4"
   tag="$5"

   [ ! -z "$name" ]   || internal_fail "name is empty"
   [ ! -z "$url" ]    || internal_fail "url is empty"
   [ ! -z "$dstdir" ] || internal_fail "dstdir is empty"

   local relative
   local name2

   relative="`dirname -- "${dstdir}"`"
   relative="`compute_relative "${relative}"`"
   if [ ! -z "${relative}" ]
   then
      relative="${relative}/"
   fi
   name2="`basename -- "${url}"`"  # only works for git really

   local scmflagsdefault

   #
   # this implicitly ensures, that these folders are
   # movable and cleanable by mulle-bootstrap
   # so ppl can't really use  src mistakenly

   if [ -e "${DEPENDENCY_SUBDIR}" -o -e "${CLONESBUILD_SUBDIR}" ]
   then
      # if this is a "refetch" don't bother to warn
      if [ ! -e "${BOOTSTRAP_SUBDIR}.auto" ]
      then
         log_error "Stale folders \"${DEPENDENCY_SUBDIR}\" and/or \"${CLONESBUILD_SUBDIR}\" found."
         log_error "Please remove them before continuing."
         log_info  "Suggested command: ${C_RESET_BOLD}mulle-bootstrap clean output${C_INFO}"
         exit 1
      fi
   fi

   local operation
   local map

   map="`read_fetch_setting "${name}.scm"`"
   case "${map}" in
      git|"" )
         operation="git_clone"
         scmflagsdefault="--recursive"
         ;;
      svn)
         operation="svn_checkout"
         ;;

      *)
         fail "unknown scm system ${map}"
         ;;
   esac

   local found
   local src
   local script

   src="${url}"
   script="`find_repo_setting_file "${name}" "bin/${COMMAND}.sh"`"

   if [ ! -z "${script}" ]
   then
      run_script "${script}" "$@"
   else
      case "${url}" in
         /*)
            if git_is_bare_repository "${url}"
            then
               :
            else
               ask_symlink_it "${src}"
               if [ $? -eq 0 ]
               then
                  operation=link_command
               fi
            fi
         ;;

         ../*|./*)
            if git_is_bare_repository "${url}"
            then
               :
            else
               ask_symlink_it "${src}"
               if [ $? -eq 0 ]
               then
                  operation=link_command
                  src="${relative}${url}"
               fi
            fi
         ;;

         *)
            found="`search_git_repo_in_parent_directory "${name}" "${branch}"`"
            if [ -z "${found}" ]
            then
               found="`search_git_repo_in_parent_directory "${name2}" "${branch}"`"
            fi

            if [ ! -z "${found}" ]
            then
               user_say_yes "There is a ${found} folder in the parent
directory of this project.
Use it ?"
               if [ $? -eq 0 ]
               then
                  src="${found}"

                  if git_is_bare_repository "${src}"
                  then
                     :
                  else
                     ask_symlink_it "${src}"
                     if [ $? -eq 0 ]
                     then
                        operation=link_command
                        src="${relative}${found}"
                     fi
                  fi
               fi
            fi

         ;;
      esac

      local scmflags

      scmflags="`read_repo_setting "${name}" "checkout" "${scmflagsdefault}"`"
      "${operation}" "${src}" "${dstdir}" "${branch}" "${tag}" "${scmflags}"
      mulle-bootstrap-warn-scripts.sh "${dstdir}/.bootstrap" "${dstdir}" || fail "Ok, aborted"  #sic
   fi
}


ensure_clone_branch_is_correct()
{
   local dstdir
   local branch

   dstdir="${1}"
   branch="${2}"

   local actual

   if [ ! -z "${branch}" ]
   then
      actual="`git_get_branch "${dstdir}"`"
      if [ "${actual}" != "${branch}" ]
      then
         fail "Repository \"${dstdir}\" checked-out branch is \"${actual}\".
But \"${branch}\" is specified.
Suggested fix:
   mulle-bootstrap clean dist
   mulle-bootstrap"
      fi
   fi
}

#
# Use git clones for stuff that gets tagged
# if you specify ../ it will assume you have
# checked it out yourself, If there is something
# checked out already it will use it, or ask
# convention: .git suffix == repo to clone
#          no .git suffix, try to symlink
#
checkout_repository()
{
   local dstdir
   local name
   local flag
   local url
   local branch
   local tag

   name="$1"
   url="$2"
   dstdir="$3"
   branch="$4"
   tag="$5"

   if [ ! -e "${dstdir}" ]
   then
      checkout "$@"
      flag=1

      if [ "${COMMAND}" = "install" -a "${DONT_RECURSE}" = "" ]
      then
         local old

         old="${BOOTSTRAP_SUBDIR}"

         BOOTSTRAP_SUBDIR="${dstdir}/.bootstrap"
         install_embedded_repositories "${dstdir}/"
         BOOTSTRAP_SUBDIR="${old}"

         bootstrap_auto_update "${name}" "${url}" "${dstdir}"
         flag=$?
      fi

      run_build_settings_script "${name}" "${url}" "${dstdir}" "post-${COMMAND}" "$@"

      # means we recursed and should start fetch from top
      if [ ${flag} -eq 0 ]
      then
         return 1
      fi
   else
      ensure_clone_branch_is_correct "${dstdir}" "${branch}"

      log_fluff "Repository \"${dstdir}\" already exists"
   fi
   return 0
}


clone_repository()
{
   local name
   local url
   local branch

   name="$1"
   url="$2"
   branch="$3"

   local tag
   local dstdir
   local flag

   tag="`read_repo_setting "${name}" "tag"`" #repo (sic)
   dstdir="${CLONESFETCH_SUBDIR}/${name}"
   log_fetch_action "${name}" "${dstdir}"

   # mark the checkout progress, so that we don't do incomplete fetches and
   # later on happily build

   checkout_repository "${name}" "${url}" "${dstdir}" "${branch}" "${tag}"
   flag=$?

   return $flag
}


did_clone_repository()
{
   local name
   local url
   local branch

   name="$1"
   url="$2"
   branch="$3"

   local dstdir

   dstdir="${CLONESFETCH_SUBDIR}/${name}"
   run_build_settings_script "${name}" "${url}" "${dstdir}" "did-install" "${dstdir}" "${name}"
}


clone_repositories()
{
   local stop
   local clones
   local clone
   local old
   local name
   local url
   local fetched
   local match
   local branch

   old="${IFS:-" "}"

   fetched=""

   stop=0
   while [ $stop -eq 0 ]
   do
      stop=1

      clones="`read_fetch_setting "repositories"`"
      if [ "${clones}" != "" ]
      then
         ensure_clones_directory

         IFS="
"
         for clone in ${clones}
         do
            IFS="${old}"

            # avoid superflous updates
            match="`echo "${fetched}" | grep -x "${clone}"`"
            # could remove prefixes here https:// http://

            if [ "${match}" != "${clone}" ]
            then
               fetched="${fetched}
${clone}"

               name="`canonical_name_from_clone "${clone}"`"
               url="`url_from_clone "${clone}"`"
               branch="`branch_from_clone "${clone}"`"

               clone_repository "${name}" "${url}" "${branch}"

               if [ $? -eq 1 ]
               then
                  stop=0
                  break
               fi
            fi
         done
      fi
   done

   IFS="
"
   for clone in ${fetched}
   do
      IFS="${old}"
      name="`canonical_name_from_clone "${clone}"`"
      url="`url_from_clone "${clone}"`"
      did_clone_repository "${name}" "${url}" "${branch}"
   done

   IFS="${old}"
}


install_embedded_repositories()
{
   local dstprefix

   dstprefix="$1"

   local clones
   local clone
   local old
   local name
   local url
   local dstdir
   local branch

   old="${IFS:-" "}"

   MULLE_BOOTSTRAP_SETTINGS_NO_AUTO="YES"
   export MULLE_BOOTSTRAP_SETTINGS_NO_AUTO

   clones="`read_fetch_setting "embedded_repositories"`"
   if [ "${clones}" != "" ]
   then
      IFS="
"
      for clone in ${clones}
      do
         IFS="${old}"
         name="`canonical_name_from_clone "${clone}"`"
         url="`url_from_clone "${clone}"`"
         branch="`branch_from_clone "${clone}"`"

         tag="`read_repo_setting "${name}" "tag"`" #repo (sic)
         dstdir="${dstprefix}${name}"
         log_fetch_action "${name}" "${dstdir}"

         if [ ! -d "${dstdir}" ]
         then
            #
            # embedded_repositories are just cloned, no symlinks,
            #
            local old

            old="${SYMLINK_FORBIDDEN}"

            SYMLINK_FORBIDDEN="YES"
            checkout "${name}" "${url}" "${dstdir}" "${branch}" "${tag}"
            SYMLINK_FORBIDDEN="$old"

            if read_yes_no_config_setting "update_gitignore" "YES"
            then
               if [ -d .git ]
               then
                  append_dir_to_gitignore_if_needed "${dstdir}"
               fi
            fi

            # memo that we did this with a symlink
            # store it inside the possibly recursed dstprefix dependency
            local symlinkcontent
            local symlinkdir
            local symlinkrelative

            symlinkrelative=`compute_relative "${CLONESFETCH_SUBDIR}/.embedded"`
            symlinkdir="${dstprefix}${CLONESFETCH_SUBDIR}/.embedded"
            mkdir_if_missing "${symlinkdir}"
            symlinkcontent="${symlinkrelative}/${dstdir}"

            log_fluff "Remember embedded repository \"${name}\" via \"${symlinkdir}/${name}\""
            exekutor ln -s "${symlinkcontent}" "${symlinkdir}/${name}"

            run_build_settings_script "${name}" "${url}" "${dstdir}" "post-${COMMAND}" "$@"
         else
            ensure_clone_branch_is_correct "${dstdir}" "${branch}"

           log_fluff "Repository \"${dstdir}\" already exists"
         fi
      done
   fi

   IFS="${old}"

   MULLE_BOOTSTRAP_SETTINGS_NO_AUTO=
}


update()
{
   local name
   local url
   local branch
   local tag
   local dstdir

   name="$1"
   url="$2"
   dstdir="$3"
   branch="$4"
   tag="$5"

   [ ! -z "$url" ]           || internal_fail "url is empty"
   exekutor [ -d "$dstdir" ] || internal_fail "dstdir \"${dstdir}\" is wrong ($PWD)"
   [ ! -z "$name" ]          || internal_fail "name is empty"

   local map
   local operation

   map="`read_fetch_setting "${name}.scm"`"
   case "${map}" in
      git|"" )
         operation="git_pull"
         ;;
      svn)
         operation="svn_update"
         ;;

      *)
         fail "unknown scm system ${map}"
         ;;
   esac

   local script

   if [ ! -L "${dstdir}" ]
   then
      run_repo_settings_script "${name}" "${dstdir}" "pre-update" "$@"

      script="`find_repo_setting_file "${name}" "bin/update.sh"`"
      if [ ! -z "${script}" ]
      then
         run_script "${script}" "$@"
      else
         "${operation}" "${dstdir}" "${branch}" "${tag}"
      fi

      run_repo_settings_script "${name}" "${dstdir}" "post-update" "$@"
   else
      ensure_clone_branch_is_correct "${dstdir}" "${branch}"
      log_fluff "Repository \"${name}\" exists, so not updated."
      return 1
   fi
}


update_repository()
{
   local name
   local url
   local branch

   name="$1"
   url="$2"
   branch="$3"

   local name
   local tag
   local dstdir

   tag="`read_repo_setting "${name}" "tag"`" #repo (sic)

   dstdir="${CLONESFETCH_SUBDIR}/${name}"
   exekutor [ -e "${dstdir}" ] || fail "You need to fetch \"${name}\" first, before updating"
   exekutor [ -x "${dstdir}" ] || fail "\"${name}\" is not anymore in \"repositories\""

   log_fetch_action "${url}" "${dstdir}"

   update "${name}" "${url}" "${dstdir}" "${branch}" "${tag}"

   #update will return 1 if repo is symlinked

   if [ $? -eq 0 -a "${DONT_RECURSE}" = "" ]
   then
      local old
      local oldfetch

      old="${BOOTSTRAP_SUBDIR}"
      oldfetch="${CLONESFETCH_SUBDIR}"

      BOOTSTRAP_SUBDIR="${dstdir}/.bootstrap"
#      CLONESFETCH_SUBDIR="${dstdir}/.repos"

      update_embedded_repositories "${dstdir}/"

      BOOTSTRAP_SUBDIR="${old}"
#      CLONESFETCH_SUBDIR="${oldfetch}"
   fi

   ensure_clone_branch_is_correct "${dstdir}" "${branch}"
}


did_update_repository()
{
   local name
   local url

   name="$1"
   url="$2"

   local dstdir

   dstdir="${CLONESFETCH_SUBDIR}/${name}"

   run_build_settings_script "${name}" "${url}" "${dstdir}" "did-update" "${dstdir}" "${name}"
}


#
# Use git clones for stuff that gets tagged
# if you specify ../ it will assume you have
# checked it out yourself, If there is something
# checked out already it will use it, or ask
# convention: .git suffix == repo to clone
#          no .git suffix, try to symlink
#
update_repositories()
{
   local clones
   local clone
   local name
   local i
   local old

   old="${IFS:-" "}"

   if [ $# -ne 0 ]
   then
      IFS="
"
      for name in "$@"
      do
         IFS="${old}"
         update_repository "${name}" "${CLONESFETCH_SUBDIR}/${name}"
      done

      IFS="
"
      for name in "$@"
      do
         IFS="${old}"
         did_update_repository "${name}" "${CLONESFETCH_SUBDIR}/${name}"
      done
   else
      clones="`read_fetch_setting "repositories"`"
      if [ "${clones}" != "" ]
      then
         IFS="
"
         for clone in ${clones}
         do
            IFS="${old}"
            name="`canonical_name_from_clone "${clone}"`"
            url="`url_from_clone "${clone}"`"
            branch="`branch_from_clone "${clone}"`"

            update_repository "${name}" "${url}" "${branch}"
         done

         # reread because of auto
         IFS="
"
         clones="`read_fetch_setting "repositories"`"
         for clone in ${clones}
         do
            IFS="${old}"
            name="`canonical_name_from_clone "${clone}"`"
            url="`url_from_clone "${clone}"`"
            branch="`branch_from_clone "${clone}"`"

            did_update_repository "${name}" "${url}" "${branch}"
         done
      fi
   fi

   IFS="${old}"
}


update_embedded_repositories()
{
   local dstprefix

   dstprefix="$1"

   local clones
   local clone
   local old
   local name
   local url
   local branch

   MULLE_BOOTSTRAP_SETTINGS_NO_AUTO="YES"
   export MULLE_BOOTSTRAP_SETTINGS_NO_AUTO

   old="${IFS:-" "}"

   clones="`read_fetch_setting "embedded_repositories"`"
   if [ "${clones}" != "" ]
   then
      IFS="
"
      for clone in ${clones}
      do
         IFS="${old}"
         name="`canonical_name_from_clone "${clone}"`"
         url="`url_from_clone "${clone}"`"
         branch="`branch_from_clone "${clone}"`"

         tag="`read_repo_setting "${name}" "tag"`" #repo (sic)
         dstdir="${dstprefix}${name}"
         log_fetch_action "${name}" "${dstdir}"

         update "${name}" "${url}" "${dstdir}" "${branch}" "${tag}"
      done
   fi

   IFS="${old}"
   MULLE_BOOTSTRAP_SETTINGS_NO_AUTO=
}


append_dir_to_gitignore_if_needed()
{
   grep -s -x "$1/" .gitignore > /dev/null 2>&1
   if [ $? -ne 0 ]
   then
      exekutor echo "$1/" >> .gitignore || fail "Couldn\'t append to .gitignore"
      log_info "Added \"$1/\" to \".gitignore\""
   fi
}


main()
{
   log_fluff "::: fetch :::"

   SYMLINK_FORBIDDEN="`read_config_setting "symlink_forbidden"`"
   export SYMLINK_FORBIDDEN

   if [ "${COMMAND}" = "install" ]
   then
      if [ $# -ne 0 ]
      then
         log_error  "Additional parameters not allowed for install"
         usage >&2
         exit 1
      fi
   fi

   ensure_consistency
   create_file_if_missing "${CLONESFETCH_SUBDIR}/.fetch_update_started"

   #
   # Run prepare scripts if present
   #
   if [ "${COMMAND}" = "install" ]
   then

      clone_repositories

      install_embedded_repositories
      install_brews
      install_gems
      install_pips
      check_tars

   else
      update_repositories "$@"

      update_embedded_repositories
   fi

   #
   # Run prepare scripts if present
   #
   run_fetch_settings_script "post-${COMMAND}" "$@"

   remove_file_if_present "${CLONESFETCH_SUBDIR}/.fetch_update_started"

   if read_yes_no_config_setting "update_gitignore" "YES"
   then
      if [ -d .git ]
      then
         append_dir_to_gitignore_if_needed "${BOOTSTRAP_SUBDIR}.auto"
         append_dir_to_gitignore_if_needed "${BOOTSTRAP_SUBDIR}.local"
         append_dir_to_gitignore_if_needed "${DEPENDENCY_SUBDIR}"
         append_dir_to_gitignore_if_needed "${CLONES_SUBDIR}"
      fi
   fi
}

main "$@"
