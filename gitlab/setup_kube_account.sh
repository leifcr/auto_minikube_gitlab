#!/bin/bash
SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
kubectl create -f $SCRIPTPATH/service_account.yml
kubectl create -f $SCRIPTPATH/service_role_binding.yml
