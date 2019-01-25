#!/bin/bash
kubectl create -f ./service_account.yml
kubectl create -f ./service_role_binding.yml
