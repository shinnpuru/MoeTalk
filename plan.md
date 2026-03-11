# Plan

1. **Add Auto Draw toggle**
   - Add a `bool _isAutoDraw = false;` state in `MainPageState` in `lib/main.dart` (similar to `_isAutoVoice`).
   - Add new translation strings in `lib/i18n.dart`: `'auto_draw': 'Auto Draw'`, `'manual_draw': 'Manual Draw'` (and their 'zh' equivalents).
   - Change the `I18n.t('draw')` button in the tools expanded menu to a toggle button that toggles `_isAutoDraw`.
   - We might need to keep a separate button for "Draw now" or just let the user toggle auto draw and draw right after reply. The user requested: "make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once". So the "开始绘图" (draw) button itself should become a toggle for auto-draw. Wait, let's keep it simple: change the behavior of the existing `draw` button (which currently calls `getDraw()`) to toggle `_isAutoDraw` and change its icon based on state (like `_isAutoVoice`). Wait, user said "make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once". So the button should be a toggle.

2. **Trigger Auto Draw on reply**
   - When `_isAutoDraw` is true, after getting an assistant's response, we should automatically call `getDraw()`.
   - In `sendMsg()`'s `onSuccess` callback (`() async { ... }`), after updating response, check if `_isAutoDraw` is true, and if so, call `getDraw()`. Note: maybe we just want to call `getDraw()` without showing the dialog, or maybe show the dialog?
   - Actually, wait, the user's second request says: "make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result".

3. **Modify `AiDraw` dialog behavior**
   - In `lib/aidraw.dart`, the `AiDraw` widget is a dialog. When the user clicks the 'start' button (or `开始`), it currently sets `sdBusy = true` and shows a log, keeping the dialog open while it waits.
   - The user wants the dialog to disappear after clicking "start", but still generate the image and append it to the chat.
   - If the dialog is closed, where does the preview of the illustration result show up? The request says "but do not change the preview of the illustration result".
   - "preview of the illustration result" might refer to the fact that currently when generation finishes, the image is shown in the dialog, and you can click "use" to append it to the chat and set as background.
   - BUT if the dialog disappears, how can they see the preview and click "use"? Or maybe the image should just be appended to the chat directly when it finishes in the background, OR the dialog should show up when the image is ready?
   - Wait, if `AiDraw` is closed, the state and the request are destroyed if we just `Navigator.pop(context)` unless we detach the request from the dialog or handle it at a higher level, but `makeRequest()` is inside `AiDrawState`.
   - Let's read `lib/aidraw.dart` and `lib/main.dart` carefully.
