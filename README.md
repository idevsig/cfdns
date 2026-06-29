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
docker run --rm idevsig/cfdns:latest cfspeedtest.sh -a user@example.com -k api_key -d example.com -p cf -s 5 -n -o

# gcore
docker run --rm idevsig/cfdns:latest cfspeedtest.sh -a user@example.com -k api_key -d example.com -p cf -s 5 -n -o -i gc -u https://hk2-speedtest.tools.gcore.com/speedtest-backend/garbage.php?ckSize=1000
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
      - CLOUDFLARE_EMAIL=user@example.com
      - CLOUDFLARE_API_KEY=api_key
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
  ./cfspeedtest.sh -a user@example.com -k api_key -d example.com -p cf -s 2 -n -o

e.g.:
  export CLOUDFLARE_API_KEY="api_key"
  export CLOUDFLARE_EMAIL="user@example.com"
  ./cfspeedtest.sh -d example.com -p cf -s 2 -n -o
```

或
```bash
export CLOUDFLARE_API_KEY="api_key"
export CLOUDFLARE_EMAIL="user@example.com"

cd $(mktemp -d) && curl -L https://fastfile.asfd.cn/https://raw.githubusercontent.com/idevsig/cfdns/refs/heads/dev/scripts/cfspeedtest.sh -O && chmod +x cfspeedtest.sh
DEBUG=1 ./cfspeedtest.sh -d 222029.xyz -p xf -n -r -i cf
```

---

## 帮助

```sh
usage: ./cfspeedtest.sh [ options ]

  -h, --help                           print help
  -a, --account <account>              set Cloudflare account
  -k, --key <key>                      set API key
  -t, --type <type>                    set zone type
  -d, --domain <domain>                set domain
  -p, --prefix <prefix>                set prefix
  -s, --speed <speed>                  set download speed (default: 2)
  -c, --cdn <cdn>                      set cdn url
  -i, --ipurl <ip_url>                 set ip url (cf,gc,ct,aws)
  -u, --url <url>                      set speed test url
  -P, --port <port>                    set speed test port
  -q, --quantity <quantity>            set record quantity
  -e, --extend <string>                set extend string
  -r, --refresh                        refresh result.csv
  -n, --dns                            update DNS records 
  -o, --only                           only refresh one host
```

> `-h` / `--help`:             帮助信息   
> `-a` / `--account`:          Cloudflare 账号   
> `-k` / `--key`:              Cloudflare API 密钥   
> `-t` / `--type`:             域名主机名类型   
> `-d` / `--domain`:           域名   
> `-p` / `--prefix`:           域名前缀   
> `-s` / `--speed`:            下载速度下限，单位 **`M`**，低于此速度则不记录（默认为 `2`）     
> `-c` / `--cdn`:              CDN URL，更新脚本时不需再扶梯     
> `-i` / `--ipurl`:            [`IP 数据源`](https://www.cloudflare.com/ips-v4) URL（以支持 [`GCore`](https://api.gcore.com/cdn/public-ip-list), [`CloudFront`](https://d7uri8nf7uskq.cloudfront.net/tools/list-cloudfront-ips), [`AWS`](https://ip-ranges.amazonaws.com/ip-ranges.json)，可使用 (`cf,gc,ct,aws`)）   
> `-P` / `--port`:             速度测试端口   
> `-u` / `--url`:              速度测试 URL   
> `-q` / `--quantity`:         记录至 Cloudflare 解析记录的条数   
> `-e` / `--extend`:           扩展参数字符串   
> `-r` / `--refresh`:          强制刷新 result.csv    
> `-n` / `--dns`:              更新 DNS 解析记录   
> `-o` / `--only`:             只刷新一条主机前缀记录   

- `key`, **CLOUDFLARE_EMAIL** 为 CloudFlare 账号
- `account`, [**CLOUDFLARE_API_KEY**](https://dash.cloudflare.com/profile/api-tokens)-> `API Keys` -> `Global API Key`   

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
   export CLOUDFLARE_API_KEY="api_key"
   export CLOUDFLARE_EMAIL="user@example.com"

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

---

## 仓库镜像

[MyCode](https://git.jetsung.com/idev/cfdns) ● [AtomGit](https://atomgit.com/idev/cfdns) ● [GitHub](https://github.com/idevsig/cfdns)

