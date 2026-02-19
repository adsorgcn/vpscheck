# vpscheck — VPS 全能检测脚本

<div align="center">

![Version](https://img.shields.io/badge/version-3.1.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![System](https://img.shields.io/badge/system-CentOS%20|%20Ubuntu%20|%20Debian-orange.svg)
![Shell](https://img.shields.io/badge/shell-bash-89e051.svg)

**一键检测 VPS 流媒体解锁 / AI服务 / IP质量 / 三网测速 / 回程路由**

适合 Linux 新手，自动安装依赖，开箱即用

[快速开始](#-快速开始) · [功能特性](#-功能特性) · [菜单说明](#-菜单说明) · [常见问题](#-常见问题) · [技术支持](#-技术支持)

</div>

---

## 📖 项目介绍

vpscheck 是一个专为 VPS 用户设计的综合检测脚本，帮助你快速了解一台服务器的全貌：

- **流媒体解锁**：Netflix / Disney+ / HBO Max / Hulu / Spotify / YouTube 等 20+ 平台
- **AI 服务检测**：ChatGPT / Claude / Gemini / Copilot / Grok / Mistral 等 11 个平台
- **IP 质量分析**：类型识别（家宽/机房/移动/VPN）/ 欺诈风险评分 / 黑名单检测
- **回程路由检测**：电信 / 联通 / 移动 / 教育网 / 广电 — 五网直连检测，识别绕路
- **服务器性能**：系统信息 / 磁盘 I/O / 三网测速 / UnixBench 跑分
- **网络质量**：延迟测试 / IPv6 检测

## ✨ 功能特性

### 🎬 流媒体检测（20+ 平台）

| 分类 | 平台 |
|------|------|
| **全球流媒体** | Netflix · Disney+ · Prime Video · Apple TV+ · HBO Max · Hulu · Paramount+ · Peacock |
| **亚太流媒体** | HotStar · Bahamut動畫瘋 · AbemaTV · NicoNico · TVBAnywhere+ |
| **音乐短视频** | Spotify · YouTube Premium · YouTube CDN · TikTok |
| **体育英国** | DAZN · F1 TV · BBC iPlayer |
| **工具** | Steam 货币区检测 |

### 🤖 AI 服务检测（11 个平台）

ChatGPT · OpenAI API · Google Gemini · Claude · Microsoft Copilot · Grok · Perplexity · Mistral · Character.AI · Poe · Sora

### 🔍 IP 质量分析

- IP 类型识别：🏠 家宽 / 🏢 机房 / 📱 移动 / 🔒 VPN
- 欺诈风险评分（Scamalytics + AbuseIPDB）
- 综合评级：S / A / B / C / D

### 🗺️ 回程路由检测（五网）

| 运营商 | 代表节点 | 识别线路 |
|------|---------|---------|
| 🔴 中国电信 | 上海 + 成都 | CN2 GIA (AS4809) / 163骨干 (AS4134) |
| 🟡 中国联通 | 上海 + 北京 | 精品网 (AS9929) / 169骨干 (AS4837) |
| 🟢 中国移动 | 上海 + 广州 | CMI (AS58453) / 骨干 (AS9808) |
| 🔵 中国教育网 | 北京CERNET + 清华TUNA | CERNET / CERNET2 |
| 🟣 中国广电 | 北方 + 南方骨干 | AS56048 |

自动识别绕路（如亚洲节点却绕路美国/欧洲），显示完整逐跳路由。

### ⚡ 性能测试

- **系统信息**：CPU / 内存 / 磁盘 / 虚拟化类型 / TCP 算法
- **磁盘 I/O**：顺序读写 + 4K 随机写，自动识别 SSD/HDD
- **三网测速**：电信 / 联通 / 移动 共 29 个节点（Ookla Speedtest）
- **UnixBench**：CPU 综合跑分，横向对比服务器算力

### 🛡️ 其他特性

- ✅ 启动时自动检测并安装缺失依赖
- ✅ IP 地址自动打码保护隐私
- ✅ 支持历史检测结果对比
- ✅ 支持保存纯文本报告（-o 参数）
- ✅ 支持指定代理检测（-P 参数）
- ✅ 支持指定出口网卡（-I 参数）

## 🚀 快速开始

### 一键运行

```bash
bash <(curl -sL https://raw.githubusercontent.com/adsorgcn/vpscheck/main/vpscheck.sh)
```

或使用 wget：

```bash
wget -O vpscheck.sh https://raw.githubusercontent.com/adsorgcn/vpscheck/main/vpscheck.sh && bash vpscheck.sh
```

### 下载后运行

```bash
wget -O vpscheck.sh https://raw.githubusercontent.com/adsorgcn/vpscheck/main/vpscheck.sh
chmod +x vpscheck.sh
bash vpscheck.sh
```

> ⚠️ 需要 root 权限运行

## 📋 菜单说明

```
╔══════════════════════════════════════════════════════════════╗
║              VPS 全能检测脚本  vpscheck  v3.1.0             ║
║  流媒体解锁 / AI服务 / IP分析 / 三网测速 / 回程路由        ║
║  系统信息 / 磁盘IO / UnixBench / IPv6 / 延迟测试           ║
╠══════════════════════════════════════════════════════════════╣
║  作者: 静水流深   网站: 中国站长   https://cnwebmasters.com ║
╚══════════════════════════════════════════════════════════════╝

  1.  全部检测 (推荐)
  2.  全球流媒体
  3.  亚太流媒体
  4.  音乐 & 短视频
  5.  AI 服务
  6.  体育 & 英国
  7.  工具类
  8.  延迟测试
  9.  IPv6 检测
  10. 系统信息
  11. 磁盘 I/O 测试
  12. 三网测速（全节点）
  13. 三网快速测速
  14. 综合基准
  15. UnixBench CPU 跑分
  16. 回程路由检测（五网）

  u.  仅显示已解锁项目
  0.  退出
```

## 🎯 命令行参数

```bash
# 直接运行全部检测
bash vpscheck.sh -r 1

# 只检测 AI 服务
bash vpscheck.sh -r 5

# 只显示已解锁项目（方便截图）
bash vpscheck.sh -r 1 -u

# 保存检测报告到文件
bash vpscheck.sh -r 1 -o /root/report.txt

# 通过代理检测
bash vpscheck.sh -P socks5://127.0.0.1:1080 -r 1

# 指定出口网卡
bash vpscheck.sh -I eth0 -r 2
```

| 参数 | 说明 |
|------|------|
| `-r <1-16>` | 直接运行指定项目 |
| `-u` | 只显示已解锁服务 |
| `-o <文件>` | 保存报告到文件 |
| `-P <代理>` | 指定代理 |
| `-I <网卡>` | 指定出口网卡 |
| `-h` | 查看帮助 |

## ❓ 常见问题

<details>
<summary><b>Q1: 需要什么系统？</b></summary>

支持：
- Ubuntu 16.04+
- Debian 8+
- CentOS 7/8
- Alpine Linux

需要 root 权限运行。
</details>

<details>
<summary><b>Q2: 脚本会自动安装什么依赖？</b></summary>

启动时自动检测并安装：
- `curl` — IP 查询 / 流媒体检测
- `wget` — 下载 speedtest-cli
- `traceroute` — 回程路由检测
- `awk` — 数据处理

支持 apt / yum / dnf / apk 四种包管理器。
</details>

<details>
<summary><b>Q3: 三网测速需要很久？</b></summary>

- 全节点测速（选项12）：约 15-20 分钟，29 个节点
- 快速测速（选项13）：约 3-5 分钟，推荐日常使用

首次运行会自动下载 Ookla speedtest-cli（约 10MB）。
</details>

<details>
<summary><b>Q4: UnixBench 需要注意什么？</b></summary>

- 耗时约 10-30 分钟
- 运行时 CPU 会满载
- 建议配合 screen 使用防止 SSH 断线：

```bash
screen -S bench
bash vpscheck.sh -r 15
# Ctrl+A+D 挂后台
screen -r bench  # 重新连接
```
</details>

<details>
<summary><b>Q5: 回程路由全是 ? 正常吗？</b></summary>

正常。部分运营商骨干节点屏蔽 ICMP 探测包，显示 `?` 不代表网络不通，只是无法追踪路由。
</details>

<details>
<summary><b>Q6: 综合评级怎么计算的？</b></summary>

评级仅基于 **IP 类型 + 欺诈风险分**，不含路由与延迟。
因为路由质量取决于机房配置，用户本地 ISP 不同体验也会不同，所以路由信息单独展示、仅供参考。

| 评级 | 说明 |
|------|------|
| S | 极佳，家宽/原生 IP |
| A | 良好，大部分平台可解锁 |
| B | 中等，部分平台可解锁 |
| C | 较差，仅少数平台可解锁 |
| D | 极差，大部分平台屏蔽 |
</details>

## 🔄 更新日志

### v3.1.0 (2026-02-20)
- ✅ 新增回程路由检测（电信/联通/移动/教育网/广电 五网）
- ✅ 启动时自动检测并安装缺失依赖
- ✅ 回程路由摘要自动展示在 IP 分析报告中
- ✅ 线路质量识别（CN2 GIA / AS9929 精品网 / CMI 等）
- ✅ 绕路自动标记与告警

### v3.0.0 (2026-01-15)
- ✅ 新增三网测速（电信/联通/移动 29 个节点）
- ✅ 新增系统信息、磁盘 I/O、UnixBench 跑分
- ✅ 新增 7 个 AI 服务（Copilot / Grok / Perplexity / Mistral / Character.AI / Poe / Sora）
- ✅ 新增 IP 类型识别与风险评分
- ✅ 新增历史检测对比

### v2.0.0 (2025-12-01)
- ✅ 初始版本发布
- ✅ 流媒体 + AI 服务检测

## 📞 技术支持

- **作者：** 静水流深
- **网站：** [中国站长](https://cnwebmasters.com)
- **问题反馈：** [GitHub Issues](https://github.com/adsorgcn/vpscheck/issues)

## 📜 开源协议

本项目采用 MIT 协议开源

---

<div align="center">

**如果这个项目对你有帮助，请给个 ⭐ Star 支持一下！**

Made with ❤️ by [静水流深](https://cnwebmasters.com)

</div>
