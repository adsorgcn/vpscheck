# VPS 全能检测脚本 · vpscheck

<div align="center">

![Version](https://img.shields.io/badge/version-3.2.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![System](https://img.shields.io/badge/system-CentOS%20|%20Ubuntu%20|%20Debian%20|%20Alpine-orange.svg)

**一键检测 VPS 流媒体解锁 / AI服务 / IP风险 / 三网测速 / 回程路由**

支持 Netflix · Disney+ · ChatGPT · Gemini · Claude · DeepSeek · Kimi · 三网测速 · UnixBench · 回程路由

[快速开始](#-快速开始) · [功能特性](#-功能特性) · [使用说明](#-使用说明) · [常见问题](#-常见问题)

</div>

---

## 📖 项目介绍

vpscheck 是一款面向中国用户的 VPS 全能检测脚本，涵盖流媒体解锁、AI 服务可用性、IP 风险分析、三网回程路由、服务器性能基准等 16 项检测模块，一条命令即可全面了解你的 VPS 节点质量。

**核心优势：**
- ✅ 流媒体覆盖最全，涵盖全球 20+ 主流平台
- ✅ AI 服务检测，ChatGPT / Gemini / Claude / Grok / DeepSeek / Kimi 一网打尽
- ✅ IP 风险评分，结合 AbuseIPDB + Scamalytics 双重评估
- ✅ 五网回程路由，识别 CN2 GIA / 精品网 / CMI 等线路质量
- ✅ 自动安装依赖，支持 apt / yum / dnf / apk 全包管理器
- ✅ 检测历史对比，直观呈现节点变化趋势
- ✅ 支持导出纯文本报告，方便分享存档

---

## ✨ 功能特性

### 📺 流媒体解锁检测

| 分类 | 平台 |
|------|------|
| **全球流媒体** | Netflix · Disney+ · HBO Max · Hulu · Prime Video · Apple TV+ · Paramount+ · Peacock |
| **亚太流媒体** | HotStar · Bahamut（動畫瘋）· AbemaTV · NicoNico · TVBAnywhere+ |
| **音乐 & 短视频** | Spotify · YouTube · TikTok |
| **体育 & 英国** | DAZN · F1 TV · BBC iPlayer |

### 🤖 AI 服务检测

ChatGPT · OpenAI API · Gemini · Claude · Copilot · Grok · Perplexity · Mistral · Character.AI · Poe · Sora · **DeepSeek** · **Kimi（月之暗面）**

### 🔍 IP 节点分析

- **IP 类型识别**：家庭宽带 / 机房IDC / 移动网络 / VPN代理 自动判断
- **风险评分**：0-100 分可视化进度条，结合 AbuseIPDB 举报记录
- **欺诈评分**：接入 Scamalytics 评分，综合判定节点安全等级
- **综合评级**：S / A / B / C / D 五档评级，一目了然

### 🚀 服务器性能测试

| 测试项 | 说明 |
|--------|------|
| **系统信息** | CPU 型号 / 核心数 / 内存 / 磁盘 / 虚拟化类型 / 系统负载 |
| **磁盘 I/O** | 顺序读写 + 4K 随机写，评估存储性能 |
| **三网测速** | 电信 / 联通 / 移动全节点测速 |
| **三网快速测速** | 每运营商取 2 个节点，快速评估带宽 |
| **UnixBench** | CPU 综合跑分，横向对比服务器算力 |
| **延迟测试** | Google / Cloudflare / Netflix CDN / OpenAI 等节点延迟 |

### 🗺️ 回程路由检测

支持五网回程路由追踪，精准识别线路类型：

| 运营商 | 精品线路 | 普通线路 |
|--------|---------|---------|
| 🔴 中国电信 | CN2 GIA (AS4809) | 163骨干 (AS4134) |
| 🟡 中国联通 | 精品网 (AS9929) | 169骨干 (AS4837) |
| 🟢 中国移动 | CMI (AS58453) | 移动骨干 (AS9808) |
| 🔵 教育网 | CERNET2 (AS24206) | CERNET (AS4538) |
| 🟣 广电 | 广电骨干 (AS56048) | — |

自动识别**绕路**（经美国/欧洲中转），延迟增加 100ms+ 会有明显警告提示。

---

## 🚀 快速开始

### 一键运行

```bash
bash <(curl -sL https://raw.githubusercontent.com/adsorgcn/vpscheck/main/vpscheck.sh)
```

使用 wget：

```bash
wget -O vpscheck.sh https://raw.githubusercontent.com/adsorgcn/vpscheck/main/vpscheck.sh && bash vpscheck.sh
```

### 命令行参数（进阶用法）

```bash
# 直接运行全部检测
bash vpscheck.sh -r 1

# 只检测 AI 服务
bash vpscheck.sh -r 5

# 全部检测并保存报告
bash vpscheck.sh -r 1 -o /tmp/report.txt

# 使用代理检测
bash vpscheck.sh -P socks5://127.0.0.1:1080 -r 1

# 指定出口网卡
bash vpscheck.sh -I eth0 -u -r 2

# 仅显示已解锁项目
bash vpscheck.sh -u
```

### 参数说明

| 参数 | 说明 |
|------|------|
| `-r <编号>` | 直接运行指定检测项（见下方菜单编号） |
| `-I <网卡>` | 指定出口网卡，如 `eth0` |
| `-P <代理>` | 使用代理，格式 `socks5://host:port` |
| `-u` | 仅显示已解锁的服务 |
| `-o <文件>` | 将检测结果保存为纯文本报告 |
| `-h` | 显示帮助 |

---

## 📋 菜单说明

```
╔══════════════════════════════════════════════════════════════╗
║              VPS 全能检测脚本  vpscheck  v3.2.0             ║
║  流媒体解锁 / AI服务 / IP分析 / 三网测速 / 回程路由        ║
║  系统信息 / 磁盘IO / UnixBench / IPv6 / 延迟测试           ║
╠══════════════════════════════════════════════════════════════╣
║  作者: 静水流深   网站: 中国站长   https://cnwebmasters.com ║
╚══════════════════════════════════════════════════════════════╝

  1.  全部检测 (推荐)
  2.  全球流媒体   Netflix / Disney+ / HBO / Hulu / Prime ...
  3.  亚太流媒体   HotStar / 動畫瘋 / AbemaTV / NicoNico ...
  4.  音乐 & 短视频  Spotify / YouTube / TikTok
  5.  AI 服务  ChatGPT / Gemini / Claude / Copilot / Grok / DeepSeek / Kimi ...
  6.  体育 & 英国  DAZN / F1 TV / BBC iPlayer
  7.  工具类  Steam 货币区
  8.  延迟测试  各大 CDN 节点延迟
  9.  IPv6 检测  IPv6 可用性 & 流媒体

  ── 服务器性能 ────────────────────────────────────
  10. 系统信息  CPU / 内存 / 磁盘 / 虚拟化 / 负载
  11. 磁盘 I/O 测试  顺序读写 + 4K 随机写
  12. 三网测速  电信 / 联通 / 移动 全节点
  13. 三网快速测速  每运营商 2 个节点，速度快
  14. 综合基准  系统信息 + 磁盘 I/O + 快速三网测速
  15. UnixBench CPU 跑分  耗时约 10-30 分钟
  16. 回程路由检测  检测到中国三网是否直连或绕路

  u.  仅显示已解锁项目    0. 退出
```

---

## ❓ 常见问题

<details>
<summary><b>Q1: 需要 root 权限吗？</b></summary>

部分功能（如安装依赖、UnixBench 跑分）需要 root 权限，建议使用 root 用户运行：

```bash
sudo bash vpscheck.sh
```
</details>

<details>
<summary><b>Q2: 检测结果不准确怎么办？</b></summary>

流媒体检测结果可能受以下因素影响：

- **IP 归属地**：同一 IP 不同时间段结果可能不同
- **平台更新**：流媒体平台可能随时更新解锁策略
- **网络波动**：建议重复检测 2-3 次取平均值

使用 `-u` 参数可只显示已解锁项目，更便于截图分享。
</details>

<details>
<summary><b>Q3: 回程路由检测很慢怎么办？</b></summary>

完整回程路由检测（选项 16）需追踪 10 条路径，预计耗时 5-15 分钟，这是正常现象。

启动时的 **IP 分析面板** 已包含五网回程路由摘要，无需单独运行选项 16 也能快速了解线路质量。
</details>

<details>
<summary><b>Q4: 如何保存检测报告？</b></summary>

```bash
bash vpscheck.sh -r 1 -o /root/vps-report.txt
```

报告为纯文本格式（已去除颜色代码），方便在论坛、群组分享。
</details>

<details>
<summary><b>Q5: 支持哪些系统？</b></summary>

支持所有主流 Linux 发行版：Debian / Ubuntu（apt）· CentOS / RHEL（yum）· Fedora（dnf）· Alpine Linux（apk）

脚本启动时会自动检测并安装缺失依赖。
</details>

<details>
<summary><b>Q6: 综合评级 S/A/B/C/D 怎么算？</b></summary>

综合评级基于 **IP类型** 和 **欺诈风险分** 计算，不含路由与延迟因素：

| 评级 | 含义 |
|------|------|
| **S** | 极佳：家宽/原生IP，解锁能力强 |
| **A** | 良好：大部分平台可解锁 |
| **B** | 中等：部分平台可解锁 |
| **C** | 较差：仅少数平台可解锁 |
| **D** | 极差：大部分平台屏蔽 |

</details>

---

## 🔄 更新日志

### v3.2.0 (2026-02-21)
- 🆕 新增 DeepSeek 检测（含 API 可达性验证）
- 🆕 新增 Kimi（月之暗面）检测（含 API 可达性验证）
- 🔧 修复 Bahamut Cookie 文件无进程隔离问题，防止多进程并发冲突
- 🔧 修复 ip-api.com 429 限速无处理，触发后等待 10 秒自动重试
- 🔧 修复 gawk 依赖检测逻辑，正确区分 mawk 与 GNU awk
- 🔧 修复 Speedtest 备用镜像为 GitHub 地址导致国内下载失败，替换为国内可用镜像
- 🔧 新增 Bash 4.0+ 版本检测，老系统启动时给出明确提示

### v3.1.0 (2026-02-19)
- 🎉 首次公开发布
- ✅ 流媒体检测覆盖 20+ 全球主流平台
- ✅ AI 服务检测覆盖 11 个主流平台
- ✅ IP 风险评分接入 AbuseIPDB + Scamalytics 双引擎
- ✅ 五网回程路由检测，支持线路质量识别（CN2 GIA / 精品网 / CMI）
- ✅ 自动检测绕路节点（经美国/欧洲中转自动警告）
- ✅ 检测历史记录与对比功能
- ✅ 支持代理 / 指定网卡 / 仅显示解锁 / 导出报告等参数
- ✅ 自动安装依赖，兼容 apt / yum / dnf / apk

---

## 📞 技术支持

- **QQ 群：** 615298
- **作者：** 静水流深
- **网站：** [中国站长](https://cnwebmasters.com)
- **问题反馈：** [GitHub Issues](https://github.com/adsorgcn/vpscheck/issues)

## 📜 开源协议

本项目版权归作者所有，转载请注明出处。

---

<div align="center">

**如果这个项目对你有帮助，请给个 ⭐ Star 支持一下！**

👉 [GitHub](https://github.com/adsorgcn/vpscheck) · [Gitee](https://gitee.com/palmmedia/vpscheck)

Made with ❤️ by 静水流深

</div>
