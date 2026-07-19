# Disk Monitor Module

## Description

The Disk module monitors disk usage and sends notifications when the configured threshold is exceeded.

## Features

- Disk usage monitoring
- Configurable warning threshold
- Recovery notifications
- Duplicate alert suppression
- File locking (flock)
- Configurable ignored mount points
- systemd timer support

## Configuration

Configuration file:

```
/etc/lsm/modules/disk.conf
```

Example:

```ini
WARNING=80
CRITICAL=90

IGNORE_MOUNTS="/snap /boot /boot/efi"
```

## Installed Files

```
/opt/lsm/modules/disk/check_disk.sh

/etc/systemd/system/lsm-disk.service

/etc/systemd/system/lsm-disk.timer
```

## Timer

Default interval:

```
Every 5 minutes
```
