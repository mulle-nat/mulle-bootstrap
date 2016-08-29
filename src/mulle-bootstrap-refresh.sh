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
. mulle-bootstrap-auto-update.sh
. mulle-bootstrap-dependency-resolve.sh


usage()
{
   cat <<EOF >&2
usage:
   mulle-bootstrap <refresh|nonrecursive>

   refresh      : update settings, remove unused repositories (default)
   nonrecursive : ignore .bootstrap folders of fetched repositories
EOF
}


while :
do
   if [ "$1" = "-h" -o "$1" = "--help" ]
   then
      usage >&2
      exit 1
   fi

   break
done


if [ -z "${COMMAND}" ]
then
   COMMAND=${1:-"refresh"}
   [ $# -eq 0 ] || shift
fi

if [ "${MULLE_BOOTSTRAP}" = "mulle-bootstrap" ]
then
   COMMAND="refresh"
fi


case "$COMMAND" in
   refresh)
      ;;
   nonrecursive)
     DONT_RECURSE="YES"
      ;;

   *)
      usage >&2
      exit 1
      ;;
esac

#
#
#

refresh_repositories_settings()
{
   local stop
   local clones
   local clone
   local old
   local stop
   local refreshed
   local match
   local dependency_map

   old="${IFS:-" "}"

   refreshed=""
   dependency_map=""

   stop=0
   while [ $stop -eq 0 ]
   do
      stop=1

      clones="`read_fetch_setting "repositories"`"
      if [ "${clones}" != "" ]
      then
         IFS="
"
         for clone in ${clones}
         do
            IFS="${old}"

            clone="`expanded_setting "${clone}"`"
            # avoid superflous updates
            match="`echo "${refreshed}" | grep -x "${clone}"`"
            # could remove prefixes here https:// http://

            if [ "${match}" != "${clone}" ]
            then
               refreshed="${refreshed}
${clone}"

               local name
               local url
               local tag
               local dstdir
               local flag

               name="`canonical_name_from_clone "${clone}"`"
               url="`url_from_clone "${clone}"`"
               tag="`read_repo_setting "${name}" "tag"`" #repo (sic)
               dstdir="${CLONESFETCH_SUBDIR}/${name}"

               #
               # dependency management, it could be nicer, but isn't
               # currently match only URLs
               #
               local sub_repos
               local filename

               filename="${dstdir}/${BOOTSTRAP_SUBDIR}/repositories"
               if [ -f "${filename}" ]
               then
                  sub_repos="`_read_setting "${filename}"`"
                  if [ ! -z "${sub_repos}" ]
                  then
                     dependency_map="`dependency_add "${dependency_map}" "**ROOT**" "${url}"`"
                     dependency_map="`dependency_add_array "${dependency_map}" "${url}" "${sub_repos}"`"
                     if [ "$MULLE_BOOTSTRAP_TRACE_SETTINGS" = "YES" -o "$MULLE_BOOTSTRAP_TRACE_MERGE" = "YES"  ]
                     then
                        log_trace2 "add \"${sub_repos}\" for ${url} to ${dependency_map}"
                     fi
                  fi
               else
                  log_fluff "${name} has no repositories"
               fi

               bootstrap_auto_update "${name}" "${url}" "${dstdir}"
               flag=$?

               if [ $flag -eq 0 ]
               then
                  stop=0
               fi
            fi
         done
      fi
   done

   IFS="${old}"

   #
   # output true repository dependencies
   #
   local repositories

   repositories="`dependency_resolve "${dependency_map}" "**ROOT**" | fgrep -v -x "**ROOT**"`"
   if [ ! -z "${repositories}" ]
   then
      if [ "$MULLE_BOOTSTRAP_TRACE_SETTINGS" = "YES" -o "$MULLE_BOOTSTRAP_TRACE_MERGE" = "YES"  ]
      then
         log_trace2 "----------------------"
         log_trace2 "resolved dependencies:"
         log_trace2 "----------------------"
         log_trace2 "${repositories}"
         log_trace2 "----------------------"
      fi
      echo "${repositories}" > "${BOOTSTRAP_SUBDIR}.auto/repositories"
   fi
}


# ----------------

#
# used to do this with chmod -h, alas Linux can't do that
# So we create a special directory .zombies
# and create files there
#
mark_all_repositories_zombies()
{
   local i
   local name

      # first mark all repos as stale
   if dir_has_files "${CLONESFETCH_SUBDIR}"
   then
      log_fluff "Marking all repositories as zombies for now"

      mkdir_if_missing "${CLONESFETCH_SUBDIR}/.zombies"

      for i in `ls -1d "${CLONESFETCH_SUBDIR}/"*`
      do
         if [ -d "${i}" -o -L "${i}" ]
         then
            name="`basename -- "${i}"`"
            exekutor touch "${CLONESFETCH_SUBDIR}/.zombies/${name}"
         fi
      done
   else
      log_fluff "No projects found in \"${CLONESFETCH_SUBDIR}\""
   fi
}


_mark_repository_alive()
{
   local dstdir
   local name
   local zombie

   name="$1"
   dstdir="$2"
   zombie="$3"

   # mark as alive
   if [ -d "${dstdir}" -o -L "${dstdir}" ]
   then
      if [ -e "${zombie}" ]
      then
         log_fluff "Mark \"${dstdir}\" as alive"

         exekutor rm -f "${zombie}" || fail "failed to delete zombie ${zombie}"
      else
         log_fluff "Marked \"${dstdir}\" is already alive"
      fi
   else
      if [ -e "${dstdir}" ]
      then
         log_fail "\"${dstdir}\" is neither a symlink nor a directory"
      fi

      # repository should be there but hasn't been fetched yet
      # so not really a zmbie
      if [ -e "${zombie}" ]
      then
         log_fluff "\"${dstdir}\" is not there, so not a zombie"

         exekutor rm -f "${zombie}" || fail "failed to delete zombie ${zombie}"
      fi
   fi
}



mark_repository_alive()
{
   local dstdir
   local name

   name="$1"
   dstdir="$2"

   local zombie

   zombie="`dirname -- "${dstdir}"`/.zombies/${name}"

   _mark_repository_alive "${name}" "${dstdir}" "${zombie}"
}


bury_zombies()
{
   local i
   local name
   local dstdir
   local zombiepath
   local gravepath

      # first mark all repos as stale
   zombiepath="${CLONESFETCH_SUBDIR}/.zombies"
   if dir_has_files "${zombiepath}"
   then
      log_fluff "Burying zombies into graveyard"

      gravepath="${CLONESFETCH_SUBDIR}/.graveyard"
      mkdir_if_missing "${gravepath}"

      for i in `ls -1 "${zombiepath}/"*`
      do
         if [ -e "${i}" ]
         then
            name="`basename -- "${i}"`"
            dstdir="${CLONESFETCH_SUBDIR}/${name}"
            if [ -d "${dstdir}" ]
            then
               log_info "Removing unused repository ${C_MAGENTA}${C_BOLD}${name}${C_INFO} from \"`pwd`/${dstdir}\""

               if [ -e "${gravepath}/${name}" ]
               then
                  exekutor rm -rf "${gravepath}/${name}"
                  log_fluff "Made room for a new grave at \"${gravepath}/${name}\""
               fi

               exekutor mv "${dstdir}" "${gravepath}"
               exekutor rm "${i}"
            else
               log_fluff "\"${dstdir}\" zombie vanished or never existed"
            fi
         fi
      done
   fi

   if [ -d "${zombiepath}" ]
   then
      exekutor rm -rf "${zombiepath}"
   fi
}

#
# ###
#

mark_all_embedded_repositories_zombies()
{
   local i
   local name
   local symlink
   local path
   local zombiepath

   # first mark all repos as stale
   path="${CLONESFETCH_SUBDIR}/.embedded"
   if dir_has_files "${CLONESFETCH_SUBDIR}/.embedded"
   then
      log_fluff "Marking all embedded repositories as zombies for now"

      zombiepath="${CLONESFETCH_SUBDIR}/.embedded/.zombies"
      mkdir_if_missing "${zombiepath}"

      for symlink in `ls -1d "${path}/"*`
      do
         i="`readlink "$symlink"`"
         name="`basename "$i"`"
         exekutor touch "${zombiepath}/${name}"
      done
   else
      log_fluff "No files in \"${CLONESFETCH_SUBDIR}/.embedded\", hmm"
   fi
}


mark_embedded_repository_alive()
{
   local dstdir
   local name

   name="$1"
   dstdir="$2"

   local zombie

   zombie="${CLONESFETCH_SUBDIR}/.embedded/.zombies/${name}"

   _mark_repository_alive "${name}" "${dstdir}" "${zombie}"
}


bury_embedded_zombies()
{
   local dst

   dst="$1"

   local i
   local name
   local dstdir
   local path
   local zombiepath
   local gravepath
   local path2

      # first mark all repos as stale
   zombiepath="${CLONESFETCH_SUBDIR}/.embedded/.zombies"
   if dir_has_files "${zombiepath}"
   then
      log_fluff "Burying embedded zombies into graveyard"

      gravepath="${CLONESFETCH_SUBDIR}/.embedded/.graveyard"
      mkdir_if_missing "${gravepath}"

      for i in `ls -1 "${zombiepath}/"*`
      do
         if [ -f "${i}" ]
         then
            name="`basename -- "${i}"`"
            dstdir="${dst}${name}"

            if [ -d "${dstdir}" -o -L "${dstdir}" ]
            then
               if [ -e "${gravepath}/${name}" ]
               then
                  exekutor rm -rf "${gravepath}/${name}"
                  log_fluff "Made for a new grave at \"${gravepath}/${name}\""
               fi

               if [ -d "${dstdir}"  ]
               then
                  exekutor mv "${dstdir}" "${gravepath}"
               else
                  exekutor rm "${dstdir}"
               fi

               exekutor rm "${i}"
               exekutor rm "${CLONESFETCH_SUBDIR}/.embedded/${name}"
               log_info "Removed unused embedded repository ${C_MAGENTA}${C_BOLD}${name}${C_INFO} from \"${dstdir}\""
            else
               log_fluff "\"${dstdir}\" embedded zombie vanished or never existed ($PWD)"
            fi
         fi
      done
   fi

   if [ -d "${zombiepath}" ]
   then
      exekutor rm -rf "${zombiepath}"
   fi
}

#
# ###
#

refresh_repositories()
{
   local clones
   local clone
   local old
   local name
   local url
   local dstdir

   mark_all_repositories_zombies

   old="${IFS:-" "}"

   clones="`read_fetch_setting "repositories"`"
   if [ "${clones}" != "" ]
   then
      ensure_clones_directory

      IFS="
"
      for clone in ${clones}
      do
         IFS="${old}"

         clone="`expanded_setting "${clone}"`"

         name="`canonical_name_from_clone "${clone}"`"
         dstdir="${CLONESFETCH_SUBDIR}/${name}"

         # if it's not there it's not fetched yet, that's OK
         mark_repository_alive "${name}" "${dstdir}"
      done
   fi

   IFS="${old}"

   bury_zombies
}


_refresh_embedded_repositories()
{
   local dstprefix

   dstprefix="$1"

   local clones
   local clone
   local old
   local name
   local dstdir

   old="${IFS:-" "}"

   clones="`read_fetch_setting "embedded_repositories"`"
   if [ "${clones}" != "" ]
   then
      IFS="
"
      for clone in ${clones}
      do
         IFS="${old}"

         clone="`expanded_setting "${clone}"`"

         ensure_clones_directory

         name="`canonical_name_from_clone "${clone}"`"
         dstdir="${dstprefix}${name}"
         mark_embedded_repository_alive "${name}" "${dstdir}"
      done
   fi

   IFS="${old}"
}


refresh_embedded_repositories()
{
   mark_all_embedded_repositories_zombies

   _refresh_embedded_repositories "$@"

   bury_embedded_zombies "$@"
}


refresh_deeply_embedded_repositories()
{
   local clones
   local clone
   local old
   local name
   local url
   local dstprefix
   local previous_bootstrap
   local previous_clones

   old="${IFS:-" "}"

   clones="`read_fetch_setting "repositories"`"
   if [ "${clones}" != "" ]
   then
      IFS="
"
      for clone in ${clones}
      do
         IFS="${old}"
         name="`canonical_name_from_clone "${clone}"`"
         dstprefix="${CLONESFETCH_SUBDIR}/${name}/"

         if [ ! -L "${CLONESFETCH_SUBDIR}/${name}" ]
         then
            previous_bootstrap="${BOOTSTRAP_SUBDIR}"
            previous_clones="${CLONESFETCH_SUBDIR}"
            BOOTSTRAP_SUBDIR="${dstprefix}.bootstrap"
            CLONESFETCH_SUBDIR="${dstprefix}${CLONESFETCH_SUBDIR}"

            refresh_embedded_repositories "${dstprefix}"

            BOOTSTRAP_SUBDIR="${previous_bootstrap}"
            CLONESFETCH_SUBDIR="${previous_clones}"
         else
            log_fluff  "Don't refresh embedded repositories of symlinked \"${name}\""
         fi
      done
   fi

   IFS="${old}"
}



# -------------------

main()
{
   log_fluff "::: refresh :::"

   #
   # remove .auto because it's contents are stale now
   #
   if [ -d "${BOOTSTRAP_SUBDIR}.auto" ]
   then
      exekutor rm -rf "${BOOTSTRAP_SUBDIR}.auto"
   fi

   if [ "${DONT_RECURSE}" = "" ]
   then
      log_fluff "Refreshing repository settings"
      refresh_repositories_settings
   fi

   log_fluff "Detect zombie repositories"
   refresh_repositories

   log_fluff "Detect embedded zombie repositories"
   refresh_embedded_repositories

   if [ "${DONT_RECURSE}" = "" ]
   then
      log_fluff "Detect deeply embedded zombie repositories"
      refresh_deeply_embedded_repositories
   fi
}

main "$@"