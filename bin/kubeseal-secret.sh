#!/usr/bin/env bash

# Utility for deploying sealed secret
# Version: 1.0
# Author: Paul Carlton (mailto:paul.carlton@weave.works)

set -euo pipefail

export repo_dir=$(git rev-parse --show-toplevel)

function usage()
{
    echo "usage ${0} [--debug] [--pub-key <file>] [--secret-file <secret file>] <sealed secret file>"
    echo "<pub-key> is the path to the sealed secrets public key file, defaults to repository root pub-sealed-secrets.pem"
    echo "<secret-file> is the path to the secret yaml file, defaults to $HOME/info/$(basename $repo_dir)/<sealed secret file>"
    echo "Generates sealed secret yaml file and commits it to the repository"
}

function args() {
  export repo_dir=$(git rev-parse --show-toplevel)
  pub_key=${repo_dir}/pub-sealed-secrets.pem
  debug=""
  arg_list=( "$@" )
  arg_count=${#arg_list[@]}
  arg_index=0
  while (( arg_index < arg_count )); do
    case "${arg_list[${arg_index}]}" in
          "--pub-key") (( arg_index+=1 ));pub_key="${arg_list[${arg_index}]}";;
          "--secret-file") (( arg_index+=1 ));secret_tmpl="${arg_list[${arg_index}]}";;
          "--debug") set -x; debug="--debug";;
               "-h") usage; exit;;
           "--help") usage; exit;;
               "-?") usage; exit;;
        *) if [ "${arg_list[${arg_index}]:0:2}" == "--" ];then
               echo "invalid argument: ${arg_list[${arg_index}]}"
               usage; exit
           fi;
           break;;
    esac
    (( arg_index+=1 ))
  done
  sealed_secret_file="${arg_list[*]:$arg_index:$(( arg_count - arg_index + 1))}"
  if [ -z "${sealed_secret_file:-}" ] ; then
      usage; exit 1
  fi
  if [ -z "${secret_file:-}" ] ; then
      secret_file=$HOME/info/$(basename $repo_dir)/$(basename ${sealed_secret_file})
  fi
}

args "$@"

kubeseal --format=yaml --cert=${pub_key} < $secret_file > ${sealed_secret_file}

git -C ${repo_dir} add ${sealed_secret_file}
git -C ${repo_dir} commit -a -m "add sealed secret ${sealed_secret_file}"
git -C ${repo_dir} push
