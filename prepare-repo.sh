#!/bin/bash

# This script will prepare / create a github repository and is invoked from the makefile.
# Usage:
# prepare-repo.sh REPO GITHUB_USER_ORG
# where REPO is the name of repository to create and GITHUB_USER_ORG is the github user
# or organization (typically company name).
#
# GITHUB_TOKEN environment variable must be set in order to communicate with github.
# Set PRIVATE_REPO=true environment variable to use private github repos.

set -e
# for debugging
# set -x

BRANCH=master
REPO=$1
GITHUB_USER_ORG=$2

# Set PRIVATE_REPO=true to use private (vs public) github repos.
PRIVATE_REPO=${PRIVATE_REPO:=false}

if [[ -z ${REPO} ]]
then
    echo "missing REPO on command line"
    exit 1
fi

if [[ -z ${GITHUB_USER_ORG} ]]
then
    echo "missing GITHUB_USER_ORG on command line"
    exit 1
fi

if [[ -z ${GITHUB_TOKEN} ]]
then
    echo "missing GITHUB_TOKEN env var"
    exit 1
fi

# Split repo parts with '-'. Don't use dashes in service name.
IFS='-' read -ra REPO_PARTS <<<"${REPO}"
MAIN_REPO_DIR=${REPO_PARTS[1]}
REPO_LANG=${REPO_PARTS[2]}

if [[ -z ${MAIN_REPO_DIR} || -z ${REPO_LANG} ]]
then
    echo "invalid REPO. expeted format X-Y-Z"
    exit 1
fi


function hasGitChanges() {
    test -n "$(git status -s .)"
}

function githubRepoExists() {
    test ${REPO} == `curl -s -H "Authorization: token ${GITHUB_TOKEN}" https://api.github.com/repos/${GITHUB_USER_ORG}/${REPO} | jq -r .name`
}

if githubRepoExists
then
    true
    # echo repo ${REPO} already exists
else
    echo need to create repo ${REPO}
# todo maybe check if we should use org endpoint
#    CURL_OUTPUT=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" https://api.github.com/orgs/${GITHUB_USER_ORG}/repos --data @- << EOF
    CURL_OUTPUT=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" https://api.github.com/user/repos --data @- << EOF
{
    "name": "${REPO}",
    "description": "Automatically generated ${REPO_LANG} files for ${MAIN_REPO_DIR}",
    "private": ${PRIVATE_REPO}
}
EOF
)

    NEW_REPO_NAME=$(echo ${CURL_OUTPUT} | jq -r .name)
    if [[ "${NEW_REPO_NAME}" != "${REPO}" ]]
    then
        echo "failed to create repo ${REPO} output was: ${CURL_OUTPUT}"
        exit 1
    fi
fi


if [[ ! -d ${REPO}/.git ]]
then
    echo missing ${REPO}/.git
    rm -rf ${REPO}
    git clone git@github.com:${GITHUB_USER_ORG}/${REPO}.git
fi

cd ${REPO}
if [[ ! -r README.md ]]
then
    cat > README.md << EOF
# ${REPO}
Automatically generated ${REPO_LANG} files for ${MAIN_REPO_DIR}
EOF
    git add README.md
    git commit README.md -m "add readme"
    git push origin
fi

# make sure repo is clean
if hasGitChanges
then
    git clean -fx
fi

git fetch --all --quiet
git checkout ${BRANCH} --quiet
git reset --hard origin/${BRANCH} --quiet

if [[ ${REPO_LANG} == "go" ]]
then
    if [[ ! -r go.mod ]]
    then
        go mod init github.com/${GITHUB_USER_ORG}/${REPO}
    fi
fi
