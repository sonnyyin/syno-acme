# syno-acme

[English](README.md) | [中文](README.zh-CN.md)

---

群晖 NAS 自动化 Let's Encrypt 证书管理工具。基于 [acme.sh](https://github.com/acmesh-official/acme.sh)，通过 DNS 验证申请/续期泛域名证书，并自动安装到 DSM 及套件服务。

## 功能特性

- **泛域名证书**：支持 `*.yourdomain.com`，使用 DNS-01 验证
- **自动备份**：每次更新前自动备份当前证书
- **服务同步**：根据 DSM `INFO` 文件，将证书复制到所有服务（DSM、Drive、Gitea 等）
- **服务重载**：证书更新后自动重载 nginx 和 Apache
- **离线安装**：无网络时可使用本地 acme.sh 压缩包安装

## 环境要求

- 群晖 NAS（DSM 6.x / 7.x）
- Bash、Python 3
- `curl`、`tar`、`unzip`（用于 acme.sh 下载与解压）
- root 或 sudo 权限（访问证书路径及重载服务）

## 目录结构

```
syno-acme/
├── cert-up.sh      # 主脚本
├── config          # 配置文件（域名、DNS、API 密钥）
├── crt_cp.py       # 证书复制工具（读取 DSM INFO）
├── acme.sh/        # acme.sh 安装目录（首次运行后生成）
├── temp/           # 临时文件（acme 压缩包等）
└── backup/         # 证书备份（按时间戳命名）
```

## 配置说明

首次运行前编辑 `config` 文件：

### 必填项

| 变量        | 说明                         | 示例          |
|-------------|------------------------------|---------------|
| `DOMAIN`    | 主域名（不含 www）           | `example.com` |
| `DNS`       | DNS API 类型（见下方支持列表）| `dns_ali`     |
| `DNS_SLEEP` | DNS 生效等待时间（秒，60–900）| `120`         |

### DNS API 凭证

根据所用 DNS 服务商，取消注释并填写对应凭证：

**阿里云**
```bash
export DNS=dns_ali
export Ali_Key="你的AccessKey"
export Ali_Secret="你的SecretKey"
```

**Dnspod**
```bash
export DNS=dns_dp
export DP_Id="你的ID"
export DP_Key="你的Token"
```

**GoDaddy**
```bash
export DNS=dns_gd
export GD_Key="你的Key"
export GD_Secret="你的Secret"
```

**AWS Route53**
```bash
export DNS=dns_aws
export AWS_ACCESS_KEY_ID="你的Key"
export AWS_SECRET_ACCESS_KEY="你的Secret"
```

**Linode**
```bash
export DNS=dns_linode
export LINODE_API_KEY="你的API Key"
```

更多 DNS 提供商及参数见 [acme.sh DNS API](https://github.com/acmesh-official/acme.sh/wiki/dnsapi)。

## 使用方法

### 更新证书

申请或续期证书，并安装到 DSM 及服务：

```bash
./cert-up.sh update
```

执行流程：
1. 备份当前证书
2. 安装 acme.sh（若未安装）
3. 通过 Let's Encrypt 申请/续期证书（DNS-01）
4. 将证书复制到 DSM 归档及所有服务
5. 重载 nginx 及 Web 服务

### 恢复备份

从最新备份恢复证书：

```bash
./cert-up.sh revert
```

从指定备份恢复（使用 `backup/` 目录下的时间戳）：

```bash
./cert-up.sh revert 20260204110000
```

## 离线模式（本地 acme.sh）

当 NAS 无法访问 GitHub 时，可将 acme.sh 压缩包放入 `temp/` 目录：

1. 从 [acme.sh 发布页](https://github.com/acmesh-official/acme.sh/archive/master.tar.gz) 或 [master.zip](https://github.com/acmesh-official/acme.sh/archive/master.zip) 下载
2. 重命名为以 `acme.sh` 开头（如 `acme.sh-master.tar.gz`）
3. 放入 `temp/` 目录（如 `syno-acme/temp/acme.sh-master.tar.gz`）
4. 执行 `./cert-up.sh update`

脚本会检测本地压缩包，跳过下载并直接使用。安装成功后会自动删除该压缩包。

## 备份说明

备份保存在 `backup/<YYYYMMDDHHMMSS>/` 下：
- `certificate/`：DSM 系统证书
- `package_cert/`：套件证书（Drive、Gitea 等）

最新备份路径保存在 `backup/latest`。

## 日志格式

所有日志采用统一格式：

```
[YYYY-MM-DD HH:MM:SS] [INFO] 信息
[YYYY-MM-DD HH:MM:SS] [WARN] 警告
[YYYY-MM-DD HH:MM:SS] [ERROR] 错误
```

acme.sh 的输出保持其原始格式。

## 定时任务（可选）

可通过 cron 实现自动续期（例如每月 1 日凌晨 3 点）：

```bash
0 3 1 * * /path/to/syno-acme/cert-up.sh update
```

也可使用 DSM 任务计划定期执行脚本。

## 常见问题

| 问题 | 建议 |
|------|------|
| `[ERROR] Download failed` | 检查网络；使用离线模式配合本地 acme.sh 压缩包 |
| `[ERROR] Certificate issue/renewal failed` | 核对 DNS API 凭证和 `DNS_SLEEP`；确认 DNS 解析已生效 |
| `[WARN] Certificate copy script failed` | 检查 DSM `INFO` 文件：`/usr/syno/etc/certificate/_archive/INFO` |
| `[ERROR] Backup path not found` | 确保至少执行过一次成功的 `update` 后再使用 `revert` |

## 许可证

详见 [LICENSE](LICENSE) 文件。

---

如果你觉得项目还不错，给个 Star 吧。你的认可是我前进的动力！

![微信赞赏](img/WeChat-pay.png)
