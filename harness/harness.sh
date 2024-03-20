#!/bin/bash

# Author: Ben Chacko
#
# Harness API helper to make calling the API easier!
#
# Reference: https://apidocs.harness.io/
#

HARNESS_ACCT=<HARNESS_ACCT>
HARNESS_KEY=<HARNESS_API_KEY>

ORG=$1
PROJECT=$2

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Please pass in org and project ex: $ > harness.sh default-org default-project"
  exit 1
fi



get_secrets () {
  curl -s https://app.harness.io/v1/orgs/$ORG/projects/$PROJECT/secrets \
	-H "Harness-Account: $HARNESS_ACCT" \
	-H "x-api-key: $HARNESS_KEY" | jq '.[].secret.name'
}

get_projects () {
  curl -s https://app.harness.io/v1/orgs/$ORG/projects \
	-H "Harness-Account: $HARNESS_ACCT" \
	-H "x-api-key: $HARNESS_KEY" | jq '.[].project.identifier'
}

get_connectors () {
  string=$(curl -s "https://app.harness.io/ng/api/connectors/catalogue?accountIdentifier=$HARNESS_ACCT&orgIdentifier=$ORG" \
	  -H "x-api-key: $HARNESS_KEY" | jq -r '.data.catalogue[].category')
  local index=1
  readarray -t array <<<"$string"
  echo
  for i in "${array[@]}"; do
   echo "$index:  $i"
   ((index++))
  done
  echo
  echo
  echo "Select connector category:"
  read choice
  string=$(curl -s "https://app.harness.io/ng/api/connectors/catalogue?accountIdentifier=$HARNESS_ACCT&orgIdentifier=$ORG" \
          -H "x-api-key: $HARNESS_KEY" | jq -r ".data.catalogue[] | select(.category==\"${array[$choice - 1]}\").connectors[]")
  echo
  index=1
  readarray -t array <<<"$string"
  echo
  for i in "${array[@]}"; do
   echo "$index:  $i"
   ((index++))
  done
  echo
  echo "Select connector type:"
  read choice
  echo
  curl -s "https://app.harness.io/ng/api/connectors?accountIdentifier=$HARNESS_ACCT&orgIdentifier=$ORG&projectIdentifier=$PROJECT&type=${array[$choice - 1]}" \
    -H "x-api-key: $HARNESS_KEY" | jq '.data.content[].connector'
}

while true; do
  echo
  echo "----- Available Harness commands: ------"
  echo
  echo "  1 - Get secrets"
  echo "  2 - Get projects"
  echo "  3 - Get connectors"
  echo
  echo "Selection:"
  read choice

  case $choice in
    1) get_secrets
       ;;
    2) get_projects
       ;;
    3) get_connectors
       ;;
    *) echo "This choice is not valid"
  esac
done
