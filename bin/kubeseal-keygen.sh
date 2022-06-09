#!/usr/bin/env bash

# Utility for deploying sealed secret keys
# Version: 1.0
# Author: Paul Carlton (mailto:paul.carlton@weave.works)

set -euo pipefail

export repo_dir=$(git rev-parse --show-toplevel)

function usage()
{
    echo "usage ${0} [--debug] [--key-dir <directory>] "
    echo "<key-dir> is the path of the local directory to store keys in, defaults to $HOME/info/$(basename $repo_dir)"
    echo "key directory will be created if not present"
    echo "Creates public and private keys, deploys private key to cluster and commits public key to repository"
}

function args() {
  keys_dir=$HOME/info/$(basename $repo_dir)
  debug=""
  arg_list=( "$@" )
  arg_count=${#arg_list[@]}
  arg_index=0
  while (( arg_index < arg_count )); do
    case "${arg_list[${arg_index}]}" in
          "--key-dir") (( arg_index+=1 ));key_dir="${arg_list[${arg_index}]}";;
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
}

args "$@"

mkdir -p $keys_dir

echo "Generating the sealed secrets private key and certificate..."
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/" \
    -keyout "${keys_dir}/sealed-secrets-key" \
    -out "${keys_dir}/sealed-secrets-cert.crt"
cp ${keys_dir}/sealed-secrets-cert.crt ${repo_dir}/pub-sealed-secrets.pem
git -C ${repo_dir} add pub-sealed-secrets.pem
git -C ${repo_dir} commit -a -m "add sealed secret public key"
git -C ${repo_dir} push

${repo_dir}/bin/kubeseal-keys-deploy.sh ${debug} --privatekey-file ${keys_dir}/sealed-secrets-key --pubkey-file ${keys_dir}/sealed-secrets-cert.crt