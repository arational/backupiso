#!/bin/sh
targetmount=mnt

confirm() {
    while true
    do
        read -p "Continue (y/n)? " answer
        case "$answer" in
            y|Y) return 0;;
            n|N) return 1;;
        esac
    done
}

new_password() {
    while true
    do
        read -s -p "Encryption passphrase > " pass
        echo
        read -s -p "Retype passphrase > " pass_confirm
        echo
        if [ "$pass" = "$pass_confirm" ]
        then
            return 0
        else
            echo "Phrases don't match!"
        fi
    done
}

prepare_samba() {
    mkdir -p "$targetmount"
    echo "Which samba share should I mount?"
    read -p "> " smbservice
    # TODO: check whether already mounted
    mount.cifs "$smbservice" "$targetmount"
}

cleanup() {
    if [ -d "$targetmount" ]
    then
        # TODO: check whether mounted first
        umount "$targetmount" && rmdir "$targetmount"
    fi
}

backup() {
    echo "Where on the samba share should I store the backup?"
    read -p "> " target
    target="$targetmount/$target/$(date +%Y%m%d)"
    if [ -d "$target" ]
    then
        echo "The directory for the backup target already exists!"
        echo "Target directory: $target"
        confirm || return 1
    fi

    echo "Which ext partition should I backup?"
    read -p "> " source

    # TODO: check whether device exists
    size=$(blockdev --getsize64 $source)
    # TODO: check available free space

    new_password

    echo
    echo "Summary"
    echo "======="
    echo "Source device: $source"
    echo "Target directory: $target"
    echo "Device size: $(($size / 1048576)) MiB"
    confirm || return 1

    echo "Checking source device ..."
    e2fsck -f $source

    echo "Preparing the target directory ..."
    mkdir -p "$target" || return 1

    echo "Saving device information ..."
    fdisk -l $source > "$target/fdisk.info" || return 1
    {
        echo "$pass"
        echo "$size"
    } | \
        scrypt enc -P - > "$target/blockdev.size64" || \
        return 1

    echo "Storing backup ..."
    image="$target/image.e2i.bz2"
    tmpdir=$(mktemp -d)
    pipe=$tmpdir/sha256sum.pipe
    mkfifo $pipe
    sha256sum < $pipe > $tmpdir/checksum & pid=$!
    e2image -ra -p $source - | \
        pbzip2 -1 -c | { \
            echo "$pass"
            tee
        } | \
        scrypt enc -P - | \
        tee $pipe | \
        split -a3 -d -b100M - \
              "$image" || \
        return 1
    wait $pid
    checksum="$(cat $tmpdir/checksum)"
    rm -rf $tmpdir

    echo "Checking the stored data of the new backup ..."
    if [ "$(cat $image* | sha256sum)" = "$checksum" ]
    then
        echo "The checksums match!"
    else
        echo "The checksums don't match!"
        return 1
    fi

    echo "Done!"
}

restore() {
    echo "Where on the samba share can I find the backup?"
    read -p "> " source
    source="$targetmount/$source"
    image="$source/image.e2i.bz2"
    ls "$image"* > /dev/null || return 1

    echo "Which device should I restore?"
    read -p "> " target
    if [ ! -b "$target" ]
    then
        echo "The specified target is not a block device!"
        return 1
    fi

    read -s -p "Decryption passphrase > " pass
    echo
    size=$(echo "$pass" | scrypt dec -P "$source/blockdev.size64") || return 1
    [ $size -gt 0 ] || \
        echo "Warning: Could not get the size of the restoring data!"

    echo
    echo "Summary"
    echo "======="
    echo "Source directory: $source"
    echo "Target device: $target"
    echo "Restore amount: $(($size / 1048576)) MiB"
    confirm || return 1

    echo "Restoring backup ..."
    { \
        echo "$pass"
        cat $image*
    } | \
        scrypt dec -P - | \
        pbunzip2 -c | \
        pv -s $size | \
        dd of=$target bs=1M || \
        return 1

    echo "Checking restored target device ..."
    e2fsck -f $target || return 1

    echo "Done!"
}

case $1 in
    backup)
        prepare_samba && backup
        cleanup
        ;;
    restore)
        prepare_samba && restore
        cleanup
        ;;
    *)
        echo "Usage: $0 {backup|restore}"
        echo
        echo "Only ext2/ext3/ext4 partitions are supported."
        echo "Only samba shares for the backup storage are supported."
        exit 2
esac
