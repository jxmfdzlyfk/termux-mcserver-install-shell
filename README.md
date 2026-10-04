# Termux Minecraft 服务端一键安装脚本

在 Android 手机上用 Termux 一键搭建 Minecraft Java 版 / 基岩版服务器。

![Version](https://img.shields.io/badge/version-v1.3.1-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ 特性

- 支持 **Paper / Fabric / Vanilla / Nukkit** 四种服务端
- 自动匹配 Java 版本（17 / 21）
- **一键更新现有服务器**，保留世界和配置
- 从官方 API 动态获取下载链接，永不失效
- **智能内存分配**（读取 `/proc/meminfo` 实际可用内存）
- **动态 GC 线程**（自动根据 CPU 核心数调整）
- 下载文件自动校验，防止下载到错误页面
- 完整的安装日志，出问题可追溯

## 📱 环境要求

- Android 手机（建议 4GB 内存以上）
- [Termux](https://f-droid.org/packages/com.termux/)（**必须从 F-Droid 安装**）
- 存储空间 ≥ 2GB

## ⚠️ 版本限制

**本脚本仅支持 Minecraft 1.17.1 及以上版本。**

原因：1.16.5 及更老版本需要 Java 8/11/16，而现代 Termux 环境安装 Java 8 极其困难。

如需老版本，请参考 [proot-distro 方案](https://github.com/jxmfdzlyfk/termux-mcserver-install-shell/wiki)，或使用 PC 搭建。

## 🚀 快速开始

### 方式一：下载后审查再执行（推荐）

```bash
# 下载脚本
wget https://raw.githubusercontent.com/jxmfdzlyfk/termux-mcserver-install-shell/main/install_mc.sh

# （可选）先看一眼脚本内容
cat install_mc.sh

# 赋予执行权限并运行
chmod +x install_mc.sh
bash install_mc.sh
```

### 方式二：一键安装（方便但请信任来源）

```bash
curl -fsSL https://raw.githubusercontent.com/jxmfdzlyfk/termux-mcserver-install-shell/main/install_mc.sh | bash
```

## 📖 使用说明

运行后按提示操作：

```
  [1] Paper    - 高性能插件服务端 (推荐)
  [2] Fabric   - 模组服务端
  [3] Vanilla  - Mojang 原版服务端
  [4] Nukkit   - 基岩版服务端
  [5] 更新现有服务器
  [0] 退出
```

选择类型 → 输入版本号（如 `1.21.1`）→ 脚本自动下载和配置。

### 启动服务器

```bash
cd ~/mcserver_paper_1.21.1
./start.sh
```

### 停止服务器

在服务器控制台输入 `stop` 并回车。

### 更新服务器

重新运行脚本，选择 `[5] 更新现有服务器`，脚本会：
- 保留 `world/`、`server.properties`、`plugins/`、`mods/`
- 自动备份旧 `server.jar`
- 重新下载最新版本

### 客户端连接

- **Java 版**：端口 `25565`
- **基岩版**：端口 `19132`

## 📂 服务端对比

| 类型 | 插件 | 模组 | 推荐场景 |
|------|------|------|---------|
| Paper | ✅ | ❌ | 联机生存、插件服 |
| Fabric | ❌ | ✅ | 玩模组 |
| Vanilla | ❌ | ❌ | 纯净原版 |
| Nukkit | ✅ | ❌ | 基岩版联机 |

## ⚠️ 注意事项

- 首次使用建议先执行 `termux-setup-storage`
- **关闭手机省电模式**，否则服务器会被系统杀掉
- **不要直接关闭 Termux 窗口**，请在控制台输入 `stop` 后再退出
- 安装日志保存在 `~/.mcserver_installer/`

## 📋 更新日志


### v1.3.2 (2026-10-04)
- 🐛 修复目录重命名时可能因文件占用失败的问题（加 sleep 1 + 错误回退）
- ✨ 启动脚本备份时显示耗时提示和实际耗时
- ✨ Nukkit 下载加入 API 备用链接，避免主 URL 404 后无解
- ✨ 新增 `--check` 自检模式（脚本和 start.sh 都支持）
- ✨ 主菜单新增 [6] 环境自检
### v1.3.1 (2026-10-04)
- 🐛 修复跨版本更新后 start.sh 不更新的致命 Bug
- 🐛 修复 trap 与函数内错误处理重复报错的问题
- ✨ 更新服务器时自动重命名目录（版本号同步更新）
- ✨ 启动脚本自动备份世界（保留最近 3 份，备份前检查磁盘空间）
- ✨ 安装前检查磁盘可用空间，不足 1GB 时拒绝安装
- ♻️ update_server 使用 pushd/popd，避免目录切换副作用
### v1.3.0 (2026-10-04)
- ✨ 新增一键更新服务器功能
- ✨ 使用 `/proc/meminfo` 读取实际可用内存（更准确）
- ✨ 动态检测 CPU 核心数，自动调整 GC 线程
- ✨ 下载文件自动校验（防止下载到 HTML 错误页）
- ✨ 拒绝安装 1.17.1 以下版本，避免 Java 8 兼容性问题
- 🐛 修复变量引用未加引号的潜在问题
- 📝 完善输出提示和错误信息

### v1.1.0 (2026-09-25)
- 加入 `set -euo pipefail` 严格模式
- 添加版本号正则校验
- 增加安装日志功能
- 完善 JVM 参数

### v1.0.0 (2026-09-23)
- 首次发布
- 支持 Paper / Fabric / Vanilla / Nukkit

## 🐛 反馈

遇到问题请提交 [Issue](https://github.com/jxmfdzlyfk/termux-mcserver-install-shell/issues)，并附上 `~/.mcserver_installer/` 下的日志文件。

## 📜 开源协议

MIT License