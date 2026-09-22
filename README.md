# CloudflareDNS

依赖 [**CloudflareSpeedTest**](https://github.com/XIU2/CloudflareSpeedTest) 

## Docker 构建与拉取

### 本地构建

```sh
docker buildx bake
```

### 使用本项目提供的镜像

> **版本：** `latest`, `main`, `<TAG>`

| Registry                                                                                | Image                                              |
| --------------------------------------------------------------------------------------- | -------------------------------------------------- |
| [**Docker Hub**](https://hub.docker.com/r/idevsig/cfdns/)                               | `idevsig/cfdns`                                    |
| [**GitHub Container Registry**](https://github.com/idevsig/cfdns/pkgs/container/cfdns) | `ghcr.io/idevsig/cfdns`                           |
| **Tencent Cloud Container Registry（SG）**                                                | `sgccr.ccs.tencentyun.com/idevsig/cfdns`           |
| **Aliyun Container Registry（GZ）**                                                       | `registry.cn-guangzhou.aliyuncs.com/idevsig/cfdns` |

拉取镜像：

```sh
docker pull idevsig/cfdns:latest

# 或者
docker pull ghcr.io/idevsig/cfdns:latest
```

## 使用

### Docker 方式

运行命令：

```sh
docker run --rm idevsig/cfdns:latest cfspeedtest.sh -t api_token -d example.com -p cf -s 5 -n -o

# gcore
docker run --rm idevsig/cfdns:latest cfspeedtest.sh -t api_token -d example.com -p cf -s 5 -n -o -i gc -u https://hk2-speedtest.tools.gcore.com/speedtest-backend/garbage.php?ckSize=1000
```

#### `docker compose` 方式

1. `docker-compose.yml`

```yaml
services:
  cfdns:
    image: idevsig/cfdns:latest
    container_name: cfdns
    restart: unless-stopped
    environment:
      - CLOUDFLARE_API_TOKEN=api_token
      - TZ=Asia/Shanghai
    command: ["daemon"]
```

运行：

```sh
docker compose up -d
```

2. 设置定时计划：

```sh
# 添加定时计划
docker exec cfdns sh -c "echo '15 4 * * * cd /app; cfspeedtest.sh -d example.com -p cf -r -n' | crontab -"
# 启用
docker exec -d cfdns crond -b -l 8

# 停止计划任务
docker exec cfdns pkill crond
# 强制停止计划任务
docker exec cfdns killall crond

# 重启计划任务
docker exec cfdns pkill -HUP crond
# 或者
docker exec cfdns pkill crond && crond
```

### 脚本方式（位于文件夹 `scripts`）

```sh
e.g.:
  export CLOUDFLARE_API_TOKEN="api_token"
  ./cfspeedtest.sh -d example.com -p cf -s 2 -n -o
```

或
```bash
export CLOUDFLARE_API_TOKEN="api_token"

cd $(mktemp -d) && curl -L https://fastfile.asfd.cn/https://raw.githubusercontent.com/idevsig/cfdns/refs/heads/dev/scripts/cfspeedtest.sh -O && chmod +x cfspeedtest.sh
DEBUG=1 ./cfspeedtest.sh -d 222029.xyz -p xf -n -r -i cf
```

---

## 帮助

```sh
用法: ./cfspeedtest.sh [ 选项 ]

  -h, --help                           显示帮助信息
  -m, --man                            显示完整手册
  -t, --token <token>                  Cloudflare API Token
  -d, --domain <domain>                域名
  -p, --prefix <prefix>                域名前缀
  -y, --zone-type <type>               记录类型 (alias: --type)
  -s, --min-speed <speed>              最低下载速度，单位 M（默认: 2）(alias: --speed)
  -q, --quantity <quantity>            记录至 DNS 的条数
  -n, --update-dns                     更新 DNS 解析记录 (alias: --dns)
  -o, --only                           只刷新一条主机前缀记录
  -i, --ip-url <ip_url>                IP 数据源 (cf,gc,ct,aws 或 URL) (alias: --ipurl)
  -u, --speed-url <url>                测速 URL (alias: --url)
  -P, --port <port>                    测速端口
  -c, --cdn <cdn>                      CDN URL（更新脚本时免代理）
  -e, --extend <string>                传递给 cfst 的扩展参数
  -r, --refresh                        强制刷新 result.csv

e.g.:
  export CLOUDFLARE_API_TOKEN="api_token"
  ./cfspeedtest.sh -d example.com -p cf -s 2 -n -o                      # 单条记录
  ./cfspeedtest.sh -d example.com -p cf -s 4 -n -q 3 -r                 # 多条记录 + 强制刷新

more: ./cfspeedtest.sh -m / --man
```

> `-h` / `--help`:             帮助信息   
> `-m` / `--man`:              完整手册（含全部测速 URL 与使用示例）   
> `-t` / `--token`:            [Cloudflare API Token](https://dash.cloudflare.com/profile/api-tokens)   
> `-d` / `--domain`:           域名   
> `-p` / `--prefix`:           域名前缀   
> `-y` / `--zone-type`:        域名主机名类型（别名 `--type`）   
> `-s` / `--min-speed`:        下载速度下限，单位 **`M`**，低于此速度则不记录（默认为 `2`，别名 `--speed`）     
> `-q` / `--quantity`:         记录至 Cloudflare 解析记录的条数   
> `-n` / `--update-dns`:       更新 DNS 解析记录（别名 `--dns`）   
> `-o` / `--only`:             只刷新一条主机前缀记录   
> `-i` / `--ip-url`:           [`IP 数据源`](https://www.cloudflare.com/ips-v4)（支持 `cf,gc,ct,aws` 或自定义 URL，别名 `--ipurl`，数据源详见 [`GCore`](https://api.gcore.com/cdn/public-ip-list), [`CloudFront`](https://d7uri8nf7uskq.cloudfront.net/tools/list-cloudfront-ips), [`AWS`](https://ip-ranges.amazonaws.com/ip-ranges.json)）   
> `-u` / `--speed-url`:        速度测试 URL（别名 `--url`，完整列表见下方章节）   
> `-P` / `--port`:             速度测试端口   
> `-c` / `--cdn`:              CDN URL，更新脚本时不需再扶梯   
> `-e` / `--extend`:           扩展参数字符串   
> `-r` / `--refresh`:          强制刷新 result.csv   

- `token`, [**CLOUDFLARE_API_TOKEN**](https://dash.cloudflare.com/profile/api-tokens) 为 Cloudflare API 令牌

---

## 示例说明

1. **更新 DNS 记录**：参数 `-n` 存在时，结果将更新到域名解析记录中。

2. **过滤下载速度**：若不带 `-o` 参数，从 `result.csv` 中筛选下载速度大于 `-s` 指定的速度并更新 DNS。
   例如：

   ```sh
   # result.csv
    IP 地址,已发送,已接收,丢包率,平均延迟,下载速度 (MB/s)
    104.18.31.111,4,4,0.00,169.69,6.36
    103.21.244.82,4,4,0.00,182.95,4.63
    104.19.84.89,4,4,0.00,184.91,3.82
   ```

   ```sh
   export CLOUDFLARE_API_TOKEN="api_token"

   ./cfspeedtest.sh -d example.com -p cf -s 4 -n
   # 将 104.18.31.111 A 记录到 cf1.example.com
   # 将 103.21.244.82 A 记录到 cf2.example.com

   ./cfspeedtest.sh -d example.com -p cf -s 4 -n -o
   # 仅将 104.18.31.111 A 记录到 cf.example.com
   ```

3. **扩展参数**：CloudflareSpeedTest 支持通过 `-e` 参数传递额外的设置。

4. **IP 数据源格式**：每行一个数据，如：

   ```txt
   173.245.48.0/20
   ```

---

## cfdns.sh 使用文档

`cfdns.sh` 是 Cloudflare DNS 管理工具，支持记录的查询、创建、更新、删除等操作。

### 前置条件

- 依赖：`bash`、`curl`、`jq`
- 需要 [Cloudflare API Token](https://dash.cloudflare.com/profile/api-tokens)，权限至少包含目标域名的 `Zone > DNS > Edit`

### 认证方式

仅支持 **API Token**（不支持 Global API Key + Email 方式）：

```sh
# 方式一：环境变量（推荐）
export CLOUDFLARE_API_TOKEN="api_token"

# 方式二：命令行参数
./cfdns.sh -t api_token -ac zones
```

### 命令行参数

```sh
usage: ./cfdns.sh [ options ]
  -h, --help                           print help
  -t, --token <token>                  set API token
  -zi, --zone_id <zone_id>             set zone ID
  -ri, --record_id <record_id>         set record ID
  -zy, --zone_type <zone_type>         set zone type
  -ct, --content <content>             set content
  -rn, --record_name <record_name>     set record name
  -pr, --proxied                       enable proxied
  -ac, --action <action>               set action
```

| 参数 | 说明 |
| --- | --- |
| `-h` / `--help` | 帮助信息 |
| `-t` / `--token` | Cloudflare API Token，未指定时读取环境变量 `CLOUDFLARE_API_TOKEN` |
| `-zi` / `--zone_id` | 域名（Zone）ID |
| `-ri` / `--record_id` | 解析记录 ID |
| `-zy` / `--zone_type` | 记录类型（如 `A`、`AAAA`、`CNAME`、`TXT`） |
| `-ct` / `--content` | 记录内容（如 IP 地址、目标域名） |
| `-rn` / `--record_name` | 记录主机名（如 `cf` 表示 `cf.example.com`） |
| `-pr` / `--proxied` | 启用 Cloudflare 代理（橙色云朵），仅创建记录时有效 |
| `-ac` / `--action` | 执行的动作（见下表） |

### 支持的动作（`-ac`）

| 动作 | 说明 | 必需参数 |
| --- | --- | --- |
| `user_token_verify` | 验证 Token 有效性 | 无 |
| `accounts` | 列出账户 | 无 |
| `zones` | 列出域名（返回 `zone_id zone_name`） | 无 |
| `zones_records` | 列出域名下的解析记录 | `-zi`，可选 `-zy` 过滤类型 |
| `get_record` | 获取单条记录详情 | `-zi`、`-ri` |
| `export_record` | 导出全部记录（BIND 格式） | `-zi` |
| `create_record` | 创建记录 | `-zi`、`-zy`、`-rn`、`-ct`，可选 `-pr` |
| `update_record` | 更新记录内容 | `-zi`、`-ri`、`-ct` |
| `delete_record` | 删除记录 | `-zi`、`-ri` |
| `upsert_record` | 记录存在则更新，不存在则创建 | `-zi`、`-zy`、`-rn`、`-ct` |
| `set_record` | 通过域名/主机名智能设置记录（自动查 Zone ID 与记录 ID） | `-zn`、`-zy`、`-rn`、`-ct` |

### 使用示例

```sh
# 验证 Token
./cfdns.sh -ac user_token_verify

# 列出所有域名
./cfdns.sh -ac zones

# 列出某域名下的所有 A 记录
./cfdns.sh -zi <zone_id> -zy A -ac zones_records

# 获取单条记录
./cfdns.sh -zi <zone_id> -ri <record_id> -ac get_record

# 创建 A 记录（开启代理）
./cfdns.sh -zi <zone_id> -zy A -rn cf -ct 104.18.31.111 -pr -ac create_record

# 更新记录内容
./cfdns.sh -zi <zone_id> -ri <record_id> -ct 104.18.31.111 -ac update_record

# 删除记录
./cfdns.sh -zi <zone_id> -ri <record_id> -ac delete_record

# 存在则更新，不存在则创建
./cfdns.sh -zi <zone_id> -zy A -rn cf -ct 104.18.31.111 -ac upsert_record

# 通过域名/主机名智能设置（无需手动查 zone_id / record_id）
./cfdns.sh -zn example.com -zy A -rn cf -ct 104.18.31.111 -ac set_record
```

### Docker 方式

```sh
docker run --rm -e CLOUDFLARE_API_TOKEN=api_token idevsig/cfdns:latest \
    cfdns -zn example.com -zy A -rn cf -ct 104.18.31.111 -ac set_record
```

### 调试模式

设置 `DEBUG=1` 输出每次请求的方法与 URL（不输出 Token），错误信息一律输出到 stderr：

```sh
DEBUG=1 ./cfdns.sh -ac zones
```

---

## 速度测试 URL（`-u` 或 `--url` 参数）

**CloudFlare（`cfst` 已默认。若无下载速度，可使用此）**

```bash
https://speed.cloudflare.com/__down?bytes=25000000
```

**GCore**

* 香港：

```bash
https://hk2-speedtest.tools.gcore.com/speedtest-backend/garbage.php?ckSize=1000
```

* 日本：

```bash
https://cc1-speedtest.tools.gcore.com/speedtest-backend/garbage.php?ckSize=1000
```

* 新加坡：

```bash
https://sg1-speedtest.tools.gcore.com/speedtest-backend/garbage.php?ckSize=1000
```

> `ckSize` 为文件大小，可以自行修改。

**CacheFly**

```bash
https://cachefly.cachefly.net/100mb.test
```

**AWS S3（CloudFront / AWS IP 数据源）**

> CloudFront 无公开通用测速节点，可使用 S3 官方文件：

```bash
https://s3.amazonaws.com/aws-cli/awscli-bundle.zip
```

---

## 仓库镜像

[MyCode](https://git.jetsung.com/idev/cfdns) ● [AtomGit](https://atomgit.com/idev/cfdns) ● [GitHub](https://github.com/idevsig/cfdns)

