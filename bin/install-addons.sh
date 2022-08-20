#!/bin/bash
set -e
wowroot=$1
if ! [ -d "$wowroot" ]
then
  echo "$wowroot is not a directory"
  exit 1
fi
addonroot="$(dirname "$(dirname "$(readlink -f "$0")")")/addon"
function install() {
  wowproduct="$1"
  addonproduct="$2"
  wowdir="$wowroot/$wowproduct/Interface/AddOns"
  if [ -d "$wowdir" ]
  then
    echo "installing in $wowproduct"
    ln -sf "$addonroot/universal/Wowless" "$wowdir"
    ln -sf "$addonroot/perproduct/$addonproduct/WowlessData" "$wowdir"
  fi
}
install _retail_ wow
install _ptr_ wowt
install _classic_ wow_classic
install _classic_beta_ wow_classic_beta
install _classic_era_ wow_classic_era
install _classic_era_ptr_ wow_classic_era_ptr
install _classic_ptr_ wow_classic_ptr