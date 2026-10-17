<div align="center">
  <img src="web/favicon.png" width="128" height="128" alt="MoeTalk Logo">
  <h1>MoeTalk</h1>
  <p>Chat with your favorite characters, with voices and images.</p>
  <p><a href="README.md">简体中文</a> | English</p>
</div>

MoeTalk is an open-source AI character chat app with character cards, conversation history, voice synthesis, AI drawing, and backup and restore. Configure each service separately; voice and drawing are optional if you only want to chat.

## Get started

- **Web:** Open [MoeTalk](https://talk.shinnpuru.site). Use “Install app” or “Add to Home Screen” if your browser supports it.
- **Android / Windows:** Download the appropriate package from the [latest GitHub release](https://github.com/shinnpuru/MoeTalk/releases/latest).
- **Check your version:** Open **Settings → About**. Versions use dates, such as `2026.10.12`.

On first launch, choose “Start Configuration.” Otherwise, open Settings to find Model Config, Voice Config, and Drawing Config.

## Configure chat

1. Open **Settings → Model Config** and select a preset or enter a new configuration.
2. Fill in the fields below. This example follows the app's DeepSeek preset; use a model name currently available from your provider.

   | Field | What to enter |
   | --- | --- |
   | Name | A preset name, such as `DeepSeek` |
   | API URL | `https://api.deepseek.com/v1` |
   | API Key | Your provider's API key; leave blank for a local service without authentication |
   | Model | For example, `deepseek-chat`; it must match the provider's model name |

3. Select **Test language model connection**. It tests the current fields without requiring a save. After a successful test, use the **save icon in the top-right corner** to apply your settings. “Save Preset” keeps the configuration for later selection.
4. Import a character card from Character List, or use the edit button beside Current Character to set a name, initial dialogue, and character instructions, then save.
5. Return to Chat and send a message.

**Thinking controls:** Below the Model field, choose a thinking mode (provider default, enabled, or disabled) and effort (default, low, medium, or high). Usually leave Thinking API format on Auto. For proxies or llama.cpp, select the format used by your service. Supported effort levels vary by model, and some models cannot disable thinking. Test again after changing these options and save with the top-right icon.

**API URLs:** Chat uses an OpenAI-compatible interface. Enter the API base URL without appending `/chat/completions`. For example, Gemini's compatible base URL is `https://generativelanguage.googleapis.com/v1beta/openai`.

## Configure voice

Voice needs both a **synthesis service** and **reference audio for the current character**.

### 1. Choose a synthesis service

Open **Settings → Voice Config** and select a backend.

| Backend | Configuration |
| --- | --- |
| Civitai | Enter your Civitai API Token and save with the top-right icon. If the voice token is blank, the app tries the token from Drawing Config. |
| audio.cpp | Use a running audio.cpp service with a voice model loaded. Enter its server URL, such as `http://127.0.0.1:8080`, and select “Test connection.” The app discovers and uses the first returned model. Save after a successful connection. |

### 2. Set the character's voice

1. Open **Character List → edit button beside Current Character** to enter Character Editor.
2. Under **Voice Reference**, enter a direct link to a WAV or MP3 audio file, rather than a webpage or a local file path. With Civitai, you may also use an audio resource URN available to that service.
3. Under **Voice Reference Text**, enter the words spoken in the recording, then save with the top-right icon. audio.cpp also allows this field to be blank and uses its synthesis mode without reference text.
4. Return to Chat and **long-press a character reply → Voice** to try one message. To enable automatic reading, open **＋ beside the input field** and switch Manual Voice to Auto Voice.

Use a short, clear recording with a single speaker. If an MP3 cannot be read, try WAV. For audio.cpp, reference audio must meet the app's 5 MiB size limit.

## Configure drawing

1. Open **Settings → Drawing Config**.
2. Under **Drawing Prompt LLM**, select a working chat preset to generate image descriptions from the conversation.
3. Choose a drawing backend and enter its connection settings.

   | Backend | Configuration |
   | --- | --- |
   | Civitai | Enter your Civitai API Token and a Model URN supported by the service, then test the connection. A Model URN is a resource identifier, rather than the URL of a model's webpage. |
   | sd.cpp | Use an sd.cpp service supporting the `/sdcpp/v1` API. Enter its server URL, such as `http://127.0.0.1:1234`, and test the connection. The model name is read automatically from the server. |

4. Set the sampler, image dimensions, steps, and CFG. You can keep the defaults for a first attempt. In the positive prompt, `CHAR` is replaced with the character's drawing prompt and `VERB` with the current image description. Save with the top-right icon.
5. In **Character Editor → Drawing Prompt**, describe the character's appearance, such as hair and clothing. Add a LoRA if needed, then save.
6. Return to Chat and **long-press a message → Draw**. Review or edit the image description in the drawing panel, then generate the image. For automatic drawing after replies, open **＋ beside the input field** and switch Manual Draw to Auto Draw.

Check drawing and voice progress or error details under **＋ beside the input field → Generation Queue**.

## Common questions

- **Thinking controls or the version in About are missing:** Update from the latest release. On the web, try a hard refresh first.
- **The chat connection fails:** Check that the API base URL, key, and model name match. If you changed Thinking, try restoring Provider Default before testing again.
- **A phone cannot reach a service on your computer:** `127.0.0.1` on the phone refers to the phone itself. Use the computer's reachable LAN address and make sure the service accepts connections from other devices.
- **The web app cannot reach a local service:** Browsers may restrict HTTP services from HTTPS pages or block cross-origin requests. Check HTTPS, cross-origin settings, and browser access permissions, or use the desktop client for local services.
- **Voice connects but does not speak:** The connection test checks the service and available models. Also check the current character's reference audio and transcript.
- **Moving to another device:** Export a local backup under **Settings → Backup Config**. Native clients also support WebDAV backup and restore.

Characters, conversation history, and settings are stored locally by default. Chat, voice, and drawing requests are sent to the services you configure.

## Feedback

Report problems or suggest features through [GitHub Issues](https://github.com/shinnpuru/MoeTalk/issues).

## Acknowledgments and license

MoeTalk is based on an open-source chat project by [k96e](https://github.com/k96e). Sample voice is from [つくよみちゃん](https://tyc.rei-yumesaki.net/material/voice/sample-voice/).

This project uses the [MIT license](LICENSE).
