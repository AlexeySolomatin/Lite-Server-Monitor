# Login Monitor Module

## Description

The Login module monitors user login activity on Linux systems.

## Features

- SSH login detection
- Failed authentication detection
- User activity tracking
- Notification support
- Duplicate event prevention


## Requirements

No additional packages.


## Configuration

```
/etc/lsm/modules/login.conf
```

## Installed Files

```
/opt/lsm/modules/login/check_login.sh

/etc/systemd/system/lsm-login.service

/etc/systemd/system/lsm-login.timer

/etc/lsm/modules/login.conf
```

## Default Schedule

Every minute.
