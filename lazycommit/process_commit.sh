#!/bin/bash

# Script to process AI-generated commit messages
# Takes the selected commit message as an argument and handles the commit flow

commit_suggestions="$1"

# Create a temporary file for the commit message
commit_msg_file=$(mktemp)

# Clean the suggestions and save them to the file
cleaned_suggestions=$(echo "$commit_suggestions" | \
  sed 's/```[a-zA-Z]*//g' | \
  sed 's/```//g' | \
  sed 's/^[ \t]*//g' | \
  sed 's/[ \t]*$//g')

# Write the suggestions to the temporary file
echo "$cleaned_suggestions" > "$commit_msg_file"

# Saves the initial modification timestamp of the file
initial_timestamp=$(stat -c %Y "$commit_msg_file" 2>/dev/null || \
  stat -f %m "$commit_msg_file")

# Opens the commit message editor and captures the exit code
${EDITOR:-vim} "$commit_msg_file"
editor_exit=$?

# Gets the new modification timestamp
new_timestamp=$(stat -c %Y "$commit_msg_file" 2>/dev/null || \
  stat -f %m "$commit_msg_file")

# Checks if the editor exited normally and if the file was saved
if [ $editor_exit -ne 0 ]; then
    echo "Editor exited abnormally, commit aborted."
elif [ "$initial_timestamp" != "$new_timestamp" ]; then
    # The file was saved (timestamp has changed)
    selected_msg=$(grep -v "^#" "$commit_msg_file" | grep -v "^$" | \
      head -n 1)

    if [ -n "$selected_msg" ]; then
        echo "Creating commit with message: $selected_msg"
        git commit -m "$selected_msg"
    else
        echo "No commit message selected, commit aborted."
    fi
else
    echo "File was not saved, commit aborted."
fi

# Clean temp files
rm -f "$commit_msg_file"