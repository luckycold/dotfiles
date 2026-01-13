netbird-login() {
  if [[ -z $1 ]]
  then
    echo "ERROR: Missing environment argument!"
    echo "USAGE: `basename $0` [d|s|p]"
    return 0
  fi

  cwd=`pwd`
  cd ~/hydra/operations/support-environment && source ./login.sh $1
  ## these commands print to confirm netbird is on the right connection
  netbird status | grep FQDN
  netbird status | grep IP
  echo "Trying to sign your ssh key with vault"
  vault write -field=signed_key ssh-ca/sign/default public_key="$(pass-cli item view --vault-name Main --item-title Main --field public_key)" > $HOME/.ssh/id_ed25519-cert-$HH_ENV.pub

  if [[ $? -eq 0 ]]
  then
    echo "Success: Signed your key with vault"
  else
    echo "ERROR: Could not sign your key with vault, check permissions~"
  fi
  cd $cwd
}
