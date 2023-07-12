#!/bin/bash
# This script is used to test the release action locally using ACT
# See: https://github.com/nektos/act
#
# gh is Githubs official command line tool.
# run 'gh auth login' first to authenticate with your github account.
# 
# Usage: ./test.sh

echo "Running act.."
act release -s GITHUB_TOKEN=$(gh auth token) -s PERSONAL_ACCESS_TOKEN=$(gh auth token) -e ./.github/act/release.json
