# syno-acme

[English](README.md) | [中文](README.zh-CN.md)

---

Automated Let's Encrypt certificate management for Synology NAS. Uses [acme.sh](https://github.com/acmesh-official/acme.sh) to request/renew wildcard certificates via DNS validation, then installs them to DSM and package services.

## Features

- **Wildcard certificate**: Supports `*.yourdomain.com` via DNS-01 challenge
- **Auto backup**: Backs up current certificates before each update
- **Service sync**: Copies certificates to all DSM services (DSM, Drive, Gitea, etc.) via `INFO` file
- **Web service reload**: Reloads nginx and Apache after certificate update
- **Offline install**: Can use local acme.sh archive when network is unavailable

## Requirements

- Synology NAS (DSM 6.x / 7.x)
- Bash, Python 3
- `curl`, `tar`, `unzip` (for acme.sh download/extract)
- Root or sudo access (for certificate paths and service reload)

## Directory Structure

```
syno-acme/
├── cert-up.sh      # Main script
├── config          # Configuration (domain, DNS, API keys)
├── crt_cp.py      # Certificate copy utility (reads DSM INFO)
├── acme.sh/        # acme.sh installation (created on first run)
├── temp/           # Temporary files (acme archive, etc.)
└── backup/         # Certificate backups (timestamped)
```

## Configuration

Edit `config` before first run:

### Required

| Variable    | Description                                      | Example        |
|-------------|--------------------------------------------------|----------------|
| `DOMAIN`   | Your primary domain (without `www`)               | `example.com`  |
| `DNS`      | DNS API type (see supported providers below)     | `dns_ali`      |
| `DNS_SLEEP`| Seconds to wait for DNS propagation (60–900)    | `120`          |

### DNS API Credentials

Uncomment and fill in the credentials for your DNS provider:

**Aliyun (Aliyun DNS)**
```bash
export DNS=dns_ali
export Ali_Key="your_access_key"
export Ali_Secret="your_secret_key"
```

**Dnspod**
```bash
export DNS=dns_dp
export DP_Id="your_id"
export DP_Key="your_token"
```

**GoDaddy**
```bash
export DNS=dns_gd
export GD_Key="your_key"
export GD_Secret="your_secret"
```

**AWS Route53**
```bash
export DNS=dns_aws
export AWS_ACCESS_KEY_ID="your_key"
export AWS_SECRET_ACCESS_KEY="your_secret"
```

**Linode**
```bash
export DNS=dns_linode
export LINODE_API_KEY="your_api_key"
```

See [acme.sh DNS API](https://github.com/acmesh-official/acme.sh/wiki/dnsapi) for more providers and parameters.

## Usage

### Update Certificate

Request or renew certificate, then install to DSM and services:

```bash
./cert-up.sh update
```

Steps performed:
1. Backup current certificates
2. Install acme.sh (if not present)
3. Request/renew certificate via Let's Encrypt (DNS-01)
4. Copy certificate to DSM archive and all services
5. Reload nginx and web services

### Revert to Backup

Restore certificates from the latest backup:

```bash
./cert-up.sh revert
```

Restore from a specific backup (use timestamp from `backup/` folder):

```bash
./cert-up.sh revert 20260204110000
```

## Offline Mode (Local acme.sh)

When the NAS cannot access GitHub, place an acme.sh archive in the `temp/` directory:

1. Download from [acme.sh releases](https://github.com/acmesh-official/acme.sh/archive/master.tar.gz) or [master.zip](https://github.com/acmesh-official/acme.sh/archive/master.zip)
2. Rename to start with `acme.sh` (e.g. `acme.sh-master.tar.gz`)
3. Put it in `temp/` (e.g. `syno-acme/temp/acme.sh-master.tar.gz`)
4. Run `./cert-up.sh update`

The script will detect the local archive, skip the download, and use it for installation. The archive is removed after successful install.

## Backup

Backups are stored under `backup/<YYYYMMDDHHMMSS>/`:
- `certificate/` – DSM system certificates
- `package_cert/` – Package certificates (Drive, Gitea, etc.)

The path of the latest backup is saved in `backup/latest`.

## Log Format

All log lines use a consistent format:

```
[YYYY-MM-DD HH:MM:SS] [INFO] Message
[YYYY-MM-DD HH:MM:SS] [WARN] Warning message
[YYYY-MM-DD HH:MM:SS] [ERROR] Error message
```

acme.sh output keeps its original format.

## Scheduling (Optional)

To renew automatically, add a cron job (e.g. monthly):

```bash
# Run at 3:00 AM on the 1st of each month
0 3 1 * * /path/to/syno-acme/cert-up.sh update
```

Or use DSM Task Scheduler to run the script periodically.

## Troubleshooting

| Issue | Suggestion |
|-------|------------|
| `[ERROR] Download failed` | Check network; use offline mode with local acme.sh archive |
| `[ERROR] Certificate issue/renewal failed` | Verify DNS API credentials and `DNS_SLEEP`; ensure DNS records propagate |
| `[WARN] Certificate copy script failed` | Check DSM `INFO` file at `/usr/syno/etc/certificate/_archive/INFO` |
| `[ERROR] Backup path not found` | Ensure at least one successful `update` has run before `revert` |

## License

See [LICENSE](LICENSE) file.

---

If you find this project helpful, please give it a star. Your recognition is my motivation!

![WeChat Pay](img/WeChat-pay.png)
