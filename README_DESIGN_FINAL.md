<div align="center">

# USOM IOC Gateway

**USOM IOC verilerini senkronize eden ve güvenlik ürünleri için kullanıma hazır TXT feed'leri yayımlayan Docker tabanlı IOC Gateway.**

<p>
  <img alt="Docker" src="https://img.shields.io/badge/Docker-Ready-0D1117?style=flat-square&logo=docker&logoColor=2496ED&labelColor=0D1117">
  <img alt="PostgreSQL" src="https://img.shields.io/badge/PostgreSQL-16-0D1117?style=flat-square&logo=postgresql&logoColor=4169E1&labelColor=0D1117">
  <img alt="Linux" src="https://img.shields.io/badge/Linux-Supported-0D1117?style=flat-square&logo=linux&logoColor=FCC624&labelColor=0D1117">
  <img alt="Windows" src="https://img.shields.io/badge/Windows-10%20%7C%2011-0D1117?style=flat-square&labelColor=0D1117&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI%2BPHBhdGggZmlsbD0iI0ZGRkZGRiIgZD0iTTIgMy41IDEwLjUgMi4zdjguMkgyVjMuNVptOS41LTEuMzVMMjIgMC43djkuOEgxMS41VjIuMTVaTTIgMTEuNWg4LjV2OC4yTDIgMTguNXYtN1ptOS41IDBIMjJ2OS44bC0xMC41LTEuNDVWMTEuNVoiLz48L3N2Zz4%3D">
</p>

<p>
  <a href="./README.md"><strong>Türkçe</strong></a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="./README_EN.md">English</a>
</p>

</div>

<p align="center">
  <img src="./usom-ioc-gateway-dashboard.png" alt="USOM IOC Gateway yönetim paneli" width="100%">
</p>

<p align="center">
  <sub>Web yönetim paneli ve servis durumu görünümü</sub>
</p>

<h2 align="center">USOM IOC Gateway Nedir?</h2>

<p align="center">
USOM tarafından yayımlanan tehdit göstergelerini düzenli olarak senkronize eder,
merkezi bir web paneli üzerinden yönetir ve firewall, SIEM veya güvenlik ağ geçitlerinin
kullanabileceği TXT feed'leri halinde sunar.
</p>

<h2 align="center">Öne Çıkan Özellikler</h2>

<p align="center">
  • Domain, IPv4, IPv6 ve URL IOC kayıtlarını düzenli olarak senkronize eder.<br>
  • Her veri türünü ayrı worker servisleriyle bağımsız ve paralel olarak işler.<br>
  • IOC arama, değişiklik geçmişi ve senkronizasyon durumunu tek panelde gösterir.<br>
  • Güvenlik ürünlerinin doğrudan kullanabileceği sade TXT feed'leri üretir.<br>
  • Verileri PostgreSQL üzerinde kalıcı ve merkezi olarak saklar.<br>
  • Docker Compose yapısıyla Linux ve Windows ortamlarında hızlı kurulum sağlar.
</p>

<h2 align="center">Kurulum</h2>

### Linux

Uygulama, Docker ve Docker Compose destekleyen güncel Linux dağıtımlarında çalıştırılabilir. Otomatik kurulum için **Ubuntu Server 22.04 veya 24.04 LTS Minimal** önerilir.

```bash
curl -fsSL https://raw.githubusercontent.com/hguler07/usom-ioc-gateway/main/bootstrap-ubuntu.sh -o bootstrap-ubuntu.sh
chmod +x bootstrap-ubuntu.sh
sudo ./bootstrap-ubuntu.sh
```

### Windows 10 / 11

PowerShell'i **Yönetici olarak** açın ve aşağıdaki komutu çalıştırın:

```powershell
irm "https://raw.githubusercontent.com/hguler07/usom-ioc-gateway/main/install-windows.ps1?v=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" | iex
```

Kurulum aracı gerekli bileşenleri kontrol eder. Yönetici parolası otomatik oluşturulur ve işlem sonunda ekranda gösterilir.

<h2 align="center">Erişim</h2>

| Ortam | Yönetim paneli | Feed dizini |
|---|---|---|
| Linux | `http://SUNUCU_IP_ADRESI` | `http://SUNUCU_IP_ADRESI/feeds/` |
| Windows | `http://localhost:8080` | `http://localhost:8080/feeds/` |

<p align="center">
Varsayılan kullanıcı adı: <code>admin</code>
</p>

<h2 align="center">Önerilen Sistem</h2>

| Bileşen | Öneri |
|---|---|
| İşletim sistemi | Güncel Linux dağıtımı veya Windows 10/11 |
| Önerilen Linux | Ubuntu Server 22.04 / 24.04 LTS Minimal |
| CPU | 2 vCPU |
| RAM | 4 GB |
| Disk | 40 GB |

> Kurulum sırasında oluşturulan `.env` dosyası parola ve secret bilgileri içerir. GitHub'a yüklenmemelidir.

---

<p align="center">
  <sub>USOM IOC verilerini güvenlik ürünlerine daha sade, düzenli ve yönetilebilir biçimde ulaştırmak için geliştirilmiştir.</sub>
</p>
