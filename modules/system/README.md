# System Monitor Module

## Description

The System module monitors basic Linux system health.

## Features

- CPU load monitoring
- Memory usage monitoring
- Filesystem usage monitoring
- Uptime reporting
- Alert and recovery notifications
- systemd timer integration


## Requirements

No additional packages.


## Configuration

/etc/lsm/modules/system.conf



## Installed Files


/opt/lsm/modules/system/check_system.sh

/etc/systemd/system/lsm-system.service

/etc/systemd/system/lsm-system.timer

/etc/lsm/modules/system.conf



## Default Schedule

Every 5 minutes
