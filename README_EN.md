<div align="center">

# USOM IOC Gateway

**A Docker-based IOC gateway that synchronizes USOM threat indicators and publishes ready-to-use TXT feeds for security products.**

<p>
  <img alt="Docker" src="https://img.shields.io/badge/Docker-Ready-0D1117?style=flat-square&logo=docker&logoColor=2496ED&labelColor=0D1117">
  <img alt="PostgreSQL" src="https://img.shields.io/badge/PostgreSQL-16-0D1117?style=flat-square&logo=postgresql&logoColor=4169E1&labelColor=0D1117">
  <img alt="Linux" src="https://img.shields.io/badge/Linux-Supported-0D1117?style=flat-square&logo=linux&logoColor=FCC624&labelColor=0D1117">
  <img alt="Windows" src="https://img.shields.io/badge/Windows-10%20%7C%2011-0D1117?style=flat-square&labelColor=0D1117&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI%2BPHBhdGggZmlsbD0iI0ZGRkZGRiIgZD0iTTIgMy41IDEwLjUgMi4zdjguMkgyVjMuNVptOS41LTEuMzVMMjIgMC43djkuOEgxMS41VjIuMTVaTTIgMTEuNWg4LjV2OC4yTDIgMTguNXYtN1ptOS41IDBIMjJ2OS44bC0xMC41LTEuNDVWMTEuNVoiLz48L3N2Zz4%3D">
</p>

<p>
  <a href="./README.md">Türkçe</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="./README_EN.md"><strong>English</strong></a>
</p>

</div>

<p align="center">
  <img src="./usom-ioc-gateway-dashboard.png" alt="USOM IOC Gateway management interface" width="100%">
</p>

<p align="center">
  <sub>Web management interface and service status overview</sub>
</p>

<h2 align="center">What Is USOM IOC Gateway?</h2>

<p align="center">
It periodically synchronizes threat indicators published by USOM, manages them through
a centralized web interface, and publishes TXT feeds that can be consumed by firewalls,
SIEM platforms, and security gateways.
</p>

<h2 align="center">Key Features</h2>

<p align="center">
  • Periodically synchronizes domain, IPv4, IPv6, and URL IOC records.<br>
  • Processes each data type independently through dedicated worker services.<br>
  • Presents IOC search, change history, and synchronization status in one interface.<br>
  • Generates clean TXT feeds that security products can consume directly.<br>
  • Stores data centrally and persistently in PostgreSQL.<br>
  • Provides fast deployment on Linux and Windows with Docker Compose.
</p>

<h2 align="center">Installation</h2>

### Linux

The application can run on modern Linux distributions that support Docker and Docker Compose. **Ubuntu Server 22.04 or 24.04 LTS Minimal** is recommended for automated installation.

```bash
curl -fsSL https://raw.githubusercontent.com/hguler07/usom-ioc-gateway/main/bootstrap-ubuntu.sh -o bootstrap-ubuntu.sh
chmod +x bootstrap-ubuntu.sh
sudo ./bootstrap-ubuntu.sh
```

### Windows 10 / 11

Before installation, make sure **Docker Desktop is installed and running**. Then open PowerShell **as Administrator** and run:

```powershell
irm "https://raw.githubusercontent.com/hguler07/usom-ioc-gateway/main/install-windows.ps1?v=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" | iex
```

The installer checks the required components. An administrator password is generated automatically and displayed when installation completes.

<h2 align="center">Access</h2>

<table align="center">
  <thead>
    <tr>
      <th align="center">Environment</th>
      <th align="center">Management Interface</th>
      <th align="center">Feed Directory</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td align="center"><strong>Linux</strong></td>
      <td align="center"><code>http://SERVER_IP_ADDRESS</code></td>
      <td align="center"><code>http://SERVER_IP_ADDRESS/feeds/</code></td>
    </tr>
    <tr>
      <td align="center"><strong>Windows</strong></td>
      <td align="center"><code>http://localhost:8080</code></td>
      <td align="center"><code>http://localhost:8080/feeds/</code></td>
    </tr>
  </tbody>
</table>

<p align="center">
  Default username: <code>admin</code>
</p>

<h2 align="center">Minimum System Requirements</h2>

<p align="center">
  <img alt="CPU" src="https://img.shields.io/badge/CPU-2%20vCPU-0D1117?style=flat-square&labelColor=0D1117">
  <img alt="Memory" src="https://img.shields.io/badge/Memory-4%20GB-0D1117?style=flat-square&labelColor=0D1117">
  <img alt="Disk" src="https://img.shields.io/badge/Disk-40%20GB-0D1117?style=flat-square&labelColor=0D1117">
</p>

<p align="center">
  <sub>
    Developed by Hüseyin Güler · © 2026<br>
    Designed and published for organizations to run within their own infrastructure.
  </sub>
</p>
