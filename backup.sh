#!/bin/bash

print_help() {
    echo 'Usage:'
    echo '   bckp.sh create <target path> <target ext> <output path> [max count]'
    echo '     -- creates backup in <output path> of all files in <target path> with ext <target ext>'
    echo '     -- if [max count] is specified, oldest backups will be deleted'
    echo '        until overall backup count will not be greater than [max count]'
    echo '     -- <target ext> supports wildcard use'
    echo
    echo '   Example:'
    echo '       - bckp.sh create data/users/ .txt backup/users/ 16'
    echo
    echo '   bckp.sh validate <target path>'
    echo '     -- validates all archives in <target path>'
    echo
    echo '   Example:'
    echo '        - bckp.sh validate backup/users/ or bckp.sh validate backup/users'
    echo
    echo '   bckp.sh auto <interval in minutes> [args]'
    echo '     -- every <interval> minutes will perform <action> with passed [args]'
    echo
    echo '   Example:'
    echo '        - bckp.sh auto 60 data/ .docx backup/hourly/'
}

create_backup() {
    if [[ $1 == '' ]]; then
        echo "You must specify <target path>" >&2
        exit 1
    fi

    if [[ $2 == '' ]]; then
        echo "You must specify <target ext>" >&2
        exit 1
    fi

    if [[ $3 == '' ]]; then
        echo "You must specify <output path>" >&2
        exit 1
    fi

    if [[ $4 != '' ]] && ([[ ! $4 =~ ^[0-9]+$ ]] || [[ $4 -lt 1 ]]); then
        echo "[max count] must be a positive number" >&2
        exit 1
    fi

    if [[ $(echo -n "${1: -1}") == '/' ]]; then
        Target="$1"
    else
        Target="$1"'/'
    fi

    if [[ ! -d $Target ]]; then
        echo "Target directory ${Target} not exists" >&2
        exit 1
    fi

    if [[ $(echo -n "${2:0:1}") == '.' ]]; then
        Ext="$2"
    else
        Ext='.'"$2"
    fi

    if [[ $(echo -n "${3: -1}") == '/' ]]; then
        OutDir="$3"
    else
        OutDir="$3"'/'
    fi

    BackupFiles=$(ls $Target*${Ext} 2>/dev/null) 
    if [[ $BackupFiles == "" ]]; then
        echo "No files with extension ${Ext}" >&2
        exit 1
    fi

    ArchName='temp.tar.gz'
    Output=$OutDir$ArchName

    if [[ ! -d $OutDir ]]; then
        mkdir -p $OutDir
    fi

    tar --totals -czf $Output $BackupFiles

    echo "Calculating checksum ..."
    read Sum=("$(shasum $Output)")
    echo "Checksum is ${Sum}"
    
    mv $Output $OutDir$Sum'.tar.gz'

    echo "Output: ${OutDir}${Sum}.tar.gz"

    Max="$4"
    if [[ $Max != '' ]]; then
        while [[ $(ls $OutDir*'.tar.gz' | wc -l) -gt $Max ]]; do
            read Oldest=("$(ls $OutDir*'.tar.gz' -tr)")
            echo "Removing ${Oldest}"
            rm $Oldest
        done
    fi
}

validate() {
    if [[ $1 == '' ]]; then
        echo "You must specify <target path>" >&2
        exit 1
    fi

    if [[ $(echo -n "${1: -1}") == '/' ]]; then
        Target="$1"
    else
        Target="$1"'/'
    fi

    if [[ ! -d $Target ]]; then
        echo "Target directory ${Target} not exists" >&2
        exit 1
    fi

    Archives=$(ls $Target*".tar.gz" 2>/dev/null)
    if [[ $Archives == '' ]]; then
        echo "Nothing to validate in ${Target}" >&2
        exit 1
    fi

    Passed=0
    Total=0
    for arch in $Archives; do
        echo "$(basename $arch '.tar.gz')""  ${arch}" | shasum -c 2>/dev/null)
    done              
}

auto() {
    if [[ $1 == '' ]]; then
        echo "You must specify <interval>" >&2
        exit 1
    fi

    if [[ ! $1 =~ ^[0-9]+$ ]] || [[ $1 -lt 1 ]]; then
        echo "<interval> must be a positive number" >&2
        exit 1
    fi

    Interval="$1"
    while true; do
        create_backup "$2" "$3" "$4" "$5"
        sleep $(($Interval * 60))
    done
}

if [[ $1 == "--help" ]]; then
    print_usage
    exit
fi

if [[ $1 == "create" ]]; then
    create_backup "$2" "$3" "$4" "$5"
    exit
fi

if [[ $1 == "validate" ]]; then
    validate "$2"
    exit
fi

if [[ $1 == "auto" ]]; then
    auto "$2" "$3" "$4" "$5" "$6"
    exit 
fi

echo "Try 'bckp.sh --help' for more information" >&2
exit 1