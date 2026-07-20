# Fail2Ban Monitor Module

## Description

The Fail2Ban module monitors active bans and jail states.

## Features

- Active jail monitoring
- Banned IP detection
- Ban notifications
- Duplicate event suppression
- systemd timer integration


## Requirements

- fail2ban


## Configuration

```
/etc/lsm/modules/fail2ban.conf
```


## Installed Files

```
/opt/lsm/modules/fail2ban/check_fail2ban.sh

/etc/systemd/system/lsm-fail2ban.service

/etc/systemd/system/lsm-fail2ban.timer

/etc/lsm/modules/fail2ban.conf
```

## Default Schedule

Every 5 minutes.
