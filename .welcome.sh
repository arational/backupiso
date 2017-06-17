#!/bin/sh

echo "Welcome!"
choice=
while [ -z "$choice" ]
do
    echo "What would you like to do?"
    echo "1) Store a backup."
    echo "2) Restore a backup."
    echo "3) Enter the command line."
    read -p "> " choice
    case $choice in
        1) ~/rescue.sh backup;;
        2) ~/rescue.sh restore;;
        3) echo "You can manually execute the script rescue.sh later.";;
        *) choice=
    esac
done
