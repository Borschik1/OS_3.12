#!/bin/bash

print_help() {
    echo 'backup.sh create [object path] [object extension] [output path] ([number of backups])'
    echo '  creates a backup of all files in the [object path] with the [object extension] in the [output path]'
    echo '  If [number of backups] is specified, then if the number of archives at the [output path] has exceeded [number of backups]'
    echo '  then the oldest archives are deleted until the number of archives equals [number of backups]'
    echo 
    echo 'backup.sh period [interval] [object path] [object extension] [output path] ([number of backups])'
    echo '  once in a [interval] minutes will make a backup about the specified path'
    echo
    echo 'backup.sh check [object path]'
    echo '  checks all archives in the [object path]'
}

create_backup() {
    if [[ $1 == '' ]] || [[ $2 == '' ]] || [[ $3 == '' ]]; then
        echo "ERROR. Wrong arguments." >&2
        exit 1
    fi

    if [[ $4 != '' ]] && ([[ ! $4 =~ ^[0-9]+$ ]] || [[ $4 -lt 1 ]]); then
        echo "[number of backups] must be a positive number" >&2
        exit 1
    fi

    if [[ $(echo -n "${1: -1}") == '/' ]]; then
        Object="$1"
    else
        Object="$1"'/'
    fi

    if [[ ! -d $Object ]]; then
        echo "Object directory ${Object} not exists" >&2
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

    BackupFiles=$(ls $Object*${Ext} 2>/dev/null) 
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

    Sum=("$(shasum $Output)")
    echo "Checksum is ${Sum}"
    
    mv $Output $OutDir$Sum'.tar.gz'

    echo "Output: ${OutDir}${Sum}.tar.gz"

    Max="$4"
    if [[ $Max != '' ]]; then
        while [[ $(ls $OutDir*'.tar.gz' | wc -l) -gt $Max ]]; do
            Oldest=("$(ls $OutDir*'.tar.gz' -tr)")
            echo "Removing ${Oldest}"
            rm $Oldest
        done
    fi
}

period() {
    if [[ $1 == '' ]]; then
        echo "You must input [interval]" >&2
        exit 1
    fi

    if [[ ! $1 =~ ^[0-9]+$ ]] || [[ $1 -lt 1 ]]; then
        echo "[interval] must be a positive number" >&2
        exit 1
    fi

    Interval="$1"
    while true; do
        create_backup "$2" "$3" "$4" "$5"
        sleep $(($Interval * 60))
    done
}

check() {
    if [[ $1 == '' ]]; then
        echo "You must input [object path]" >&2
        exit 1
    fi

    if [[ $(echo -n "${1: -1}") == '/' ]]; then
        Object="$1"
    else
        Object="$1"'/'
    fi

    if [[ ! -d $Object ]]; then
        echo "Object directory ${Object} not exists" >&2
        exit 1
    fi

    Archives=$(ls $Object*".tar.gz" 2>/dev/null)
    if [[ $Archives == '' ]]; then
        echo "Nothing to check in ${Object}" >&2
        exit 1
    fi

    Passed=0
    Total=0
    for arch in $Archives; do
        echo "$(basename $arch '.tar.gz')""  ${arch}" | shasum -c 2>/dev/null
    done              
}

if [[ $1 == "--help" ]]; then
    print_help
    exit
fi

if [[ $1 == "create" ]]; then
    create_backup "$2" "$3" "$4" "$5"
    exit
fi

if [[ $1 == "check" ]]; then
    check "$2"
    exit
fi

if [[ $1 == "period" ]]; then
    period "$2" "$3" "$4" "$5" "$6"
    exit 
fi

exit 1
