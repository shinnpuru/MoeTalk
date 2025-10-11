# 💖 MoeTalk - Your AI Companion Anywhere

**Bring your favorite characters to life!** MoeTalk is an open-source, privacy-first chat application built with Flutter that lets you converse with AI personalities. Powered by large language models (LLMs) for dialogue and diffusion models for image and voice synthesis, your conversations will be more immersive than ever.

### Use now by just clicking the [MoeTalk](https://talk.shinnpuru.online) website!

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

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)

### Installation

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

### Configuration

Before you start chatting, navigate to the **Settings** page within the app to configure your AI model APIs (LLM, Drawing, Voice).

## 🤝 Contributing

Contributions are welcome! If you have ideas for new features, bug fixes, or improvements, feel free to open an issue or submit a pull request.

## 📄 License

This project is licensed under the terms of the [MIT](LICENSE) licence.