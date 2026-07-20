# RAID Monitor Module

## Description

The RAID module monitors Linux software RAID arrays (mdadm) and detects degraded, failed or recovering arrays.

## Features

- Linux mdadm monitoring
- Degraded array detection
- Failed disk detection
- Recovery notifications
- Duplicate alert suppression
- systemd timer integration

## Requirements

- mdadm

## Configuration

```
/etc/lsm/modules/raid.conf
```

## Installed Files

```
/opt/lsm/modules/raid/check_raid.sh

/etc/systemd/system/lsm-raid.service

/etc/systemd/system/lsm-raid.timer

/etc/lsm/modules/raid.conf
```

## Default Schedule

Every 5 minutes.
