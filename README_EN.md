<div align="center">
  <img src="web/favicon.png" width="128" height="128" alt="MoeTalk Logo">

</div>

<div align="center">
<a href="README.md">中文</a> | <a href="README_EN.md">English</a>
</div>


# MoeTalk - Your AI Companion Anywhere

**Bring your favorite characters to life!** MoeTalk is an open-source, privacy-first chat application built with Flutter that lets you converse with AI personalities. Powered by large language models (LLMs) for dialogue and diffusion models for image and voice synthesis, your conversations will be more immersive than ever.

## 📱 Usage

Use now by just clicking the [MoeTalk](https://talk.shinnpuru.online) website! MoeTalk is a Progressive Web App (PWA), which means you can 'install' it on your favorite devices for a native-like, full-screen experience. This works across desktop and mobile platforms.

**On Desktop (Windows, macOS, Linux):**
1. Open the [MoeTalk website](https://talk.shinnpuru.online) in a Chromium-based browser (like Google Chrome or Microsoft Edge).
2. Look for an 'Install' icon in the address bar (it often looks like a screen with a downward arrow).
3. Click it and follow the prompts to add MoeTalk to your desktop.

**On Mobile:**
- **Android:** Open the website in Chrome, tap the three-dot menu, and select 'Install app' or 'Add to Home screen'.
- **iOS (iPhone/iPad):** Open the website in Safari, tap the 'Share' button, and scroll down to select 'Add to Home Screen'.

Before you start chatting, navigate to the **Settings** page within the app to configure your AI model APIs (LLM, Drawing, Voice).

## ✨ Features

- **🤖 Intelligent Chat:** Engage in dynamic, context-aware conversations.
- **🎭 Character Management:** Easily create, customize, and switch between different AI characters.
- **💾 Chat History:** Save, load, and manage your conversation history.
- **🎨 AI-Powered Tools:**
    - **Status Analysis:** Get a summary of your character's current state and mood.
    - **AI Drawing:** Generate images based on the conversation context.
    - **Voice Synthesis:** Create voice clips for your character's messages.
    - **Reply Suggestions:** Get AI-generated ideas for your next message.
- **🔧 Highly Configurable:**
    - Connect to any compatible LLM API endpoint.
    - Customize system prompts, character personalities, and response formatting.
- **🔒 Privacy First:** All your data, including conversations and configurations, is stored locally on your device.
- **☁️ Backup & Restore:** Use WebDAV to back up and sync your configurations and chat history.

## 🚀 Build
<details>
<summary>Steps</summary>

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/shinnpuru/MoeTalk.git
    cd MoeTalk
    ```

2.  **Install dependencies:**
    ```sh
    flutter pub get
    ```

3.  **Run the app:**
    ```sh
    flutter run web
    ```

4.  **Host the app:**

    ```sh
    flutter build web
    docker build -t MoeTalk .
    docker run -d -p 80:80 MoeTalk
    ```

</details>

## 🤝 Contributing

Contributions are welcome! If you have ideas for new features, bug fixes, or improvements, feel free to open an issue or submit a pull request.

## 💖 Thanks

This software is developed based on [MisonoTalk](https://github.com/k96e/MisonoTalk). Sample voice is from [つくよみちゃん](https://tyc.rei-yumesaki.net/material/voice/sample-voice/).

## 📄 License

This project is licensed under the terms of the [MIT](LICENSE) licence.