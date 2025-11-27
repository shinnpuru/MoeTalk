<div align="center">
  <img src="web/favicon.png" width="128" height="128" alt="MoeTalk Logo">
  
</div>

<div align="center">
<a href="README.md">中文</a> | <a href="README_EN.md">English</a>
</div>

# MoeTalk - 你的随身 AI 伴侣

**将你最喜欢的角色带入现实！** 

MoeTalk 是一款使用 Flutter 构建的开源、注重隐私的聊天应用程序，可让你与 AI 人物进行对话。由用于对话的大语言模型 (LLM) 和用于图像和语音合成的扩散模型提供支持，你的对话将比以往任何时候都更具沉浸感。

## 📱 使用方法

只需点击 [MoeTalk](https://talk.shinnpuru.online) 网站即可立即使用！

MoeTalk 是一个渐进式 Web 应用 (PWA)，这意味着你可以将其“安装”在你喜欢的设备上，以获得类似原生的全屏体验。这适用于桌面和移动平台。

**在桌面端 (Windows, macOS, Linux):**
1. 在基于 Chromium 的浏览器（如 Google Chrome 或 Microsoft Edge）中打开 [MoeTalk 网站](https://talk.shinnpuru.online)。
2. 在地址栏中寻找“安装”图标（通常看起来像一个带有向下箭头的屏幕）。
3. 点击它并按照提示将 MoeTalk 添加到你的桌面。

**在移动端:**
- **安卓:** 在 Chrome 中打开网站，点击三点菜单，然后选择“安装应用”或“添加到主屏幕”。
- **iOS (iPhone/iPad):** 在 Safari 中打开网站，点击“分享”按钮，然后向下滚动选择“添加到主屏幕”。

在开始聊天之前，请导航到应用内的 **设置** 页面来配置你的 AI 模型 API（LLM、绘画、语音）。

## ✨ 功能

- **🤖 智能聊天:** 进行动态的、具有上下文感知能力的对话。
- **🎭 角色管理:** 轻松创建、自定义和切换不同的 AI 角色。
- **💾 聊天记录:** 保存、加载和管理你的对话历史。
- **🎨 AI 驱动的工具:**
    - **状态分析:** 获取角色当前状态和情绪的摘要。
    - **AI 绘画:** 根据对话内容生成图像。
    - **语音合成:** 为你的角色的消息创建语音片段。
    - **回复建议:** 为你的下一条消息获取 AI 生成的建议。
- **🔧 高度可配置:**
    - 连接到任何兼容的 LLM API 端点。
    - 自定义系统提示、角色性格和响应格式。
- **🔒 隐私优先:** 你的所有数据，包括对话和配置
- **☁️ 备份与恢复:** 使用 WebDAV 备份和同步你的配置及聊天记录。

## 🚀 构建
<details>
<summary>步骤</summary>

1.  **克隆仓库:**
    ```sh
    git clone https://github.com/shinnpuru/MoeTalk.git
    cd MoeTalk
    ```

2.  **安装依赖:**
    ```sh
    flutter pub get
    ```

3.  **运行应用:**
    ```sh
    flutter run web
    ```

4.  **托管应用:**

    ```sh
    flutter build web
    docker build -t MoeTalk .
    docker run -d -p 80:80 MoeTalk
    ```

</details>

## 🤝 贡献

欢迎贡献！如果你有关于新功能、错误修复或改进的想法，请随时提出 issue 或提交 pull request。

## 💖 感谢

本软件基于[MisonoTalk](https://github.com/k96e/MisonoTalk)进行二次开发，使用了[DiffuseCraft](https://huggingface.co/spaces/r3gm/DiffuseCraft)和[IndexTTS](https://huggingface.co/spaces/IndexTeam/IndexTTS-2-Demo)作为后端。样例声音来自[つくよみちゃん](https://tyc.rei-yumesaki.net/material/voice/sample-voice/)。

## 📄 许可证

该项目根据 [MIT](LICENSE) 许可证的条款进行许可。