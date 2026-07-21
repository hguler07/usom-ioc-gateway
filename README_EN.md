<div align="center">

# USOM IOC Gateway

**A Docker-based IOC gateway that synchronizes USOM threat indicators and publishes ready-to-use TXT feeds for security products.**

<p>
  <img alt="Docker" src="https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white">
  <img alt="PostgreSQL" src="https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Windows-2F3437">
</p>

<p>
  <a href="./README.md">
    <img alt="Türkçe" src="https://img.shields.io/badge/Dil-T%C3%BCrk%C3%A7e-E30A17">
  </a>
  <a href="./README_EN.md">
    <img alt="English" src="https://img.shields.io/badge/Language-English-1F6FEB">
  </a>
</p>

</div>

<p align="center">
  <img src="./usom-ioc-gateway-dashboard.png" alt="USOM IOC Gateway web interface" width="100%">
</p>

## What is it?

USOM IOC Gateway periodically synchronizes domain, IPv4, IPv6, and URL indicators published by USOM. It provides a web interface for management and publishes TXT feeds that can be consumed by firewalls, SIEM platforms, and security gateways.

## Features

- Domain, IPv4, IPv6, and URL synchronization
- Parallel processing with dedicated workers
- Web-based management and status monitoring
- TXT feed generation and publishing
- Persistent PostgreSQL storage
- Automated installation for Ubuntu and Windows

## Installation

### Ubuntu

Run on a clean Ubuntu server:

```bash
curl -fsSL https://raw.githubusercontent.com/hguler07/usom-ioc-gateway/main/bootstrap-ubuntu.sh -o bootstrap-ubuntu.sh
chmod +x bootstrap-ubuntu.sh
sudo ./bootstrap-ubuntu.sh
```

### Windows 10 / 11

Open PowerShell **as Administrator** and run:

```powershell
irm "https://raw.githubusercontent.com/hguler07/usom-ioc-gateway/main/install-windows.ps1?v=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" | iex
```

The installers check the required components. An administrator password is generated automatically and displayed when installation completes.

## Access

| Environment | Management interface | Feed directory |
|---|---|---|
| Ubuntu | `http://SERVER_IP_ADDRESS` | `http://SERVER_IP_ADDRESS/feeds/` |
| Windows | `http://localhost:8080` | `http://localhost:8080/feeds/` |

Default username: `admin`

## System Requirements

| CPU | Memory | Disk |
|---:|---:|---:|
| 2 vCPU | 4 GB | 40 GB |

## Basic Commands

Open the project directory:

```bash
cd /opt/usom-ioc-gateway
```

On Windows:

```powershell
Set-Location "C:\USOM\usom-ioc-gateway"
```

Check service status:

```bash
docker compose ps
```

Follow live logs:

```bash
docker compose logs -f
```

Pull images and restart services:

```bash
docker compose pull
docker compose up -d --remove-orphans
```

> The `.env` file contains passwords and secrets and must not be committed to GitHub.
