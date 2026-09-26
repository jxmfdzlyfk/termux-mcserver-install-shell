# Termux Minecraft 服务端一键安装脚本

在 Android 手机上用 Termux 一键搭建 Minecraft Java 版 / 基岩版服务器。

## ✨ 特性

- 支持 **Paper / Fabric / Vanilla / Nukkit** 四种服务端
- 自动匹配 Java 版本（17 / 21）
- 从官方 API 动态获取下载链接，永不失效
- 自动生成适合手机的优化配置
- 完整的安装日志，出问题可追溯

## 📱 环境要求

- Android 手机（建议 4GB 内存以上）
- [Termux](https://f-droid.org/packages/com.termux/)（**必须从 F-Droid 安装**）
- 存储空间 ≥ 2GB

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
```

选择类型 → 输入版本号（如 `1.21.1`）→ 脚本自动下载和配置。

### 启动服务器

```bash
cd ~/mcserver_paper_1.21.1
./start.sh
```

### 停止服务器

在服务器控制台输入 `stop` 并回车。

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
- 关闭手机省电模式，否则服务器会被系统杀掉
- 安装日志保存在 `~/.mcserver_installer/`

## 🐛 反馈

遇到问题请提交 [Issue](https://github.com/jxmfdzlyfk/termux-mcserver-install-shell/issues)。

## 📜 开源协议

MIT License

