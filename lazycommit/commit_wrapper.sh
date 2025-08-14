#!/bin/bash

# Wrapper script to safely pass commit messages to process_commit.sh
# This avoids shell quoting issues with special characters

commit_msg="$1"
printf '%s\n' "$commit_msg" | ~/.config/lazygit/lazycommit/process_commit.sh