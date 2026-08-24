# DeepSeek Balance（macOS 菜单栏 + 小鲸鱼挂件）

> 🐋 **改编自** [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)（MIT License），将原版的 Web 小鲸鱼余额挂件移植为 macOS 原生应用。鲸鱼素材 `assets/whale.png` 来自原仓库。

macOS 原生版 DeepSeek 余额小挂件：一只住在屏幕上的大肥鲸，帮你盯着 DeepSeek 账户余额。

![效果图](docs/screenshot.png)

## 功能

- 🐋 **小鲸鱼悬浮窗**（透明无边框，可拖拽，位置自动记忆）：大肥鲸 + 思考气泡（漫画思考泡链）
- ⏱️ 默认显示时间，**点击角色/气泡**触发随机俏皮台词（3 秒）→ 自动展示余额（5 秒）→ 回到时间
- 💰 余额模式：`DeepSeek 余额 ¥xx.xx` + `今日已用 ¥xx.xx`
- 📊 **今日已用**本地记账（余额差值累计，跨天自动归零）
- 🎹 点击 Q 弹动画（底部为轴的按压回弹，拖动不抖）
- 🖱️ 菜单栏项：左键点击切换 时间 ↔ 余额；右键菜单完整操作（刷新 / 显示模式 / API Key / API 地址 / 显示鲸鱼 / 开机自启 / 退出）
- 🔄 余额每 60 秒自动刷新，切换显示时数据超 30 秒立即刷新
- ✨ 首次启动弹窗设置 API Key：自动聚焦，支持 Cmd+V 粘贴，剪贴板有 sk- 开头的 key 自动预填

调用官方接口 `GET https://api.deepseek.com/user/balance`（`Authorization: Bearer <key>`），支持第三方中转 API 地址。

## 构建 & 安装

需要 Xcode Command Line Tools（`xcode-select --install`）。

```bash
./build.sh
```

自动编译 release、打包到 `~/Applications/DeepSeekBalance.app` 并启动（ad-hoc 签名）。

## 使用

1. 启动后弹出 API Key 输入框（Cmd+V 粘贴或自动预填）
2. 点鲸鱼或气泡：Q 弹 + 随机台词 → 余额 → 时间
3. 拖拽鲸鱼任意摆放，位置自动保存
4. 菜单栏左键切换 时间/余额；右键完整菜单
5. 余额异常时气泡显示 `余额!`，右键菜单看具体错误

## 配置

`~/.deepseek-balance/config.json`：

```json
{
  "apiKey": "sk-...",
  "mode": "time",          // "time" 或 "balance"
  "whalePos": "1577,721",  // 鲸鱼窗口位置
  "apiBase": "https://api.deepseek.com"
}
```

## 素材

`assets/whale.png` 来自原仓库（[MIT License](LICENSE)）的 `DSniang1.png`。

## 技术

纯 Swift + AppKit，无第三方依赖（macOS 13+，arm64/x86_64 均可）。

## 致谢

- [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)：原版 Web 挂件，气泡设计灵感与鲸鱼素材来源
