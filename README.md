<div align="center">
  <img src="Logo1.png" alt="Логотип проекта" width="200" height="200">
</div>
![Version](https://img.shields.io/badge/version-0.1.0--alpha-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Ubuntu%20%7C%20Debian-orange)
![Shell](https://img.shields.io/badge/bash-5.x-lightgrey)
# Lite Server Monitor (LSM)

> Lightweight, modular monitoring and security toolkit for Ubuntu and Debian servers.

**Lite Server Monitor (LSM)** is an open-source project designed to monitor Linux servers without requiring Docker, databases, web interfaces, or heavy monitoring platforms.

The project focuses on simplicity, low resource usage, and reliable unattended operation.

Once installed, LSM continuously monitors your server, sends notifications when issues occur, and generates a daily health report.

---

# Features

## System Monitoring

- Disk space monitoring
- SMART health monitoring
- RAID monitoring
- CPU usage monitoring
- Memory usage monitoring
- CPU temperature monitoring
- UPS monitoring (APC / apcupsd)
- Daily server health report

---

## Security

- SSH login monitoring
- Successful login statistics
- Failed login detection
- Fail2Ban integration
- Banned IP statistics
- Daily security summary

---

## Notifications

Supported notification methods:

- Telegram
- Email (SMTP / msmtp)

All notifications are handled by a unified notification module, providing consistent formatting and simplified maintenance.

---

# Why Lite Server Monitor?

Unlike enterprise monitoring platforms, Lite Server Monitor does **not** require:

- Docker
- Kubernetes
- PostgreSQL
- MySQL
- Redis
- Web UI
- Monitoring agents
- Complex initial configuration

The project follows a simple philosophy:

> **Install → Configure → Forget.**

After installation, everything runs automatically using **systemd timers**.

---

# Perfect For

Lite Server Monitor is ideal for:

- Home servers
- NAS devices
- Print servers
- Video surveillance servers
- Virtual machines
- Small office servers
- Dedicated Linux servers

---

# What This Project Is NOT

Lite Server Monitor is **not** intended to replace:

- Zabbix
- Prometheus
- Grafana
- Netdata

It is designed for reliable monitoring of one or several Linux servers without deploying a complete enterprise monitoring infrastructure.

---

# Supported Operating Systems

Currently supported:

- Ubuntu Server 22.04 LTS
- Ubuntu Server 24.04 LTS
- Debian 12

Additional distributions may be supported in future releases.

---

# Architecture

Lite Server Monitor is built using a modular architecture.

Each module performs a single task and can be installed or removed independently.

Core components include:

- `lsm` command-line interface
- Modular installer
- Shared library
- Independent monitoring modules
- Unified notification system
- systemd services and timers

---

# Modules

## Monitoring

- Disk Monitor
- SMART Monitor
- RAID Monitor
- System Monitor
- Temperature Monitor
- UPS Monitor
- Daily Health Report

## Security

- Login Monitor
- Fail2Ban Monitor

## Notifications

- Telegram
- Email

---

# Installation

After the first stable release, installation will require only a single command:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/<username>/Lite-Server-Monitor/main/bootstrap.sh)
```

The installation wizard will guide you through:

- selecting monitoring modules;
- configuring Telegram notifications;
- configuring Email notifications;
- choosing predefined configuration templates;
- or performing manual configuration.

---

# Project Structure

```text
Lite-Server-Monitor/

├── bootstrap.sh
│
├── installer/
│   ├── install.sh
│   ├── update.sh
│   └── uninstall.sh
│
├── bin/
│   └── lsm
│
├── lib/
│
├── scripts/
│   ├── monitoring/
│   ├── security/
│   └── notifications/
│
├── templates/
│
├── docs/
│
└── tests/
```

---

# Installation Layout

The following directories are used after installation.

| Directory | Purpose |
|------------|----------|
| `/opt/lsm` | Application files |
| `/etc/lsm` | Configuration files |
| `/var/lib/lsm` | State files |
| `/var/log/lsm` | Log files |
| `/run/lsm` | Runtime lock files |
| `/usr/local/bin/lsm` | Command-line interface |

For a complete description, see **INSTALLATION_LAYOUT.md**.

---

# Command Line Interface

After installation, all operations are performed through a single command:

```bash
lsm install
lsm update
lsm uninstall
lsm doctor
lsm status
lsm report
lsm version
```

---

# Documentation

The **docs/** directory contains:

- PROJECT_SPECIFICATION
- DESIGN_PRINCIPLES
- INSTALLATION_LAYOUT

Documentation is available in both English and Russian.

---

# License

This project is released under the **MIT License**.

---

# Project Status

Current version:

```text
0.1.0-alpha
```

The project is under active development.

Breaking changes may occur before the first stable **1.0** release.
