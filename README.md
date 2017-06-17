# backupiso
Custom archiso setup with a backup script

## Requirements
To create a custom "Archlinux Live-ISO" a running Archlinux environment is required.
Additionally the package `archiso` is required to provide the build environment
of the livecd.

## Setup
First you need a archiso releng profile:

```shell
cp -r /usr/share/archiso/configs/releng/* archlive
```

Now we will customize the profile.

First we copy the package list required to run the backup script on the running
livecd-environment:

```shell
cp packages.x86_64 archlive/packages.x86_64
```

Then we copy the backup script with a small startup script:

``` shell
cp .welcome.sh rescue.sh archlive/airootfs/root/
```

Now we ajust the zsh startup script to run our custom small startup script:

``` shell
echo "~/.welcome.sh" >> archlive/airootfs/root/.zlogin
```

## Build
The directory tree in `airootfs` has to have the same permissions like the root
tree on the livecd-environment. So this should be entirely owned by root:

``` shell
chown -R root:root archlive/airootfs
```

Now create the `out` directory where the fresh iso file will be placed:

``` shell
mkdir archlive/out
```

Now move into the `archlive` directory and run the build script.

``` shell
mv archlive
./build.sh -v
```
