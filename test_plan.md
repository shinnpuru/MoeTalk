Wait, if `_isAutoVoice` is evaluated when `_singleViewIndex` increments, what about auto drawing?
"make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
So the existing draw button should become a toggle, `_isAutoDraw`. When the assistant finishes a reply, it should automatically start the drawing process.
Let's trace when the assistant finishes a reply.
In `sendMsg()` inside `lib/main.dart`:

```dart
        () async {
          updateResponse(response.replaceAll(RegExp(await getResponseRegex()), ''));
          debugPrint("done.");
          setState(() {
            inputLock = false;
          });
          debugPrint("inputUnlocked");
          setTempHistory(msgListToJson(messages));
        }
```
If we add `if (_isAutoDraw) getDraw();` there, it will trigger the drawing process after every assistant response.

But what about the second requirement:
"make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result"

Currently, in `AiDrawState.makeRequest()`, it sets `sdBusy = true`, stays on screen, and polls `civitaiClient!.image.create(..., wait: true)`.
If we want the dialog to disappear immediately upon clicking start:
1. When user clicks "Start" (or "开始" `I18n.t('start')`), `makeRequest()` is called.
2. If we pop the dialog immediately, `AiDrawState` will be unmounted and `makeRequest` will crash because it calls `setState` after completion, or if it doesn't crash, the UI where the image is previewed will be gone.
Wait, "do not change the preview of the illustration result".
Does the user mean:
When "Start" is clicked, don't show the generating dialog/log, but instead hide it. Wait, if it disappears, where is the preview shown?

Maybe the prompt means: "make aidraw dialog disappear after click 开始 (start drawing toggle in the chat?), but do not change the preview of the illustration result (in the chat view?)".
No, the button "开始" in the AiDraw dialog:
```dart
                      ElevatedButton(
                        onPressed: gptBusy || promptController.text.isEmpty
                            ? null
                            : () {
                                makeRequest().catchError((e) {
                                  snackBarAlert(context, "${I18n.t('error')} $e");
                                  setState(() {
                                    sdBusy = false;
                                  });
                                });
                              },
                        child: Text(I18n.t('start')),
                      ),
```
"make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result"
This wording is tricky. If the dialog disappears, how can the preview NOT change?
Maybe the preview of the illustration result is already there... no, the preview only appears *after* `imageUrl` is set.
Wait, if we make the dialog disappear when clicking "Start", then the background process must still run, and *then* either show a notification, or automatically append the image to the chat and background without the user needing to click "use".
Ah! "but do not change the preview of the illustration result" might mean "the image preview inside the dialog should still work the same if you open it"? No, "disappear after click 开始" means the dialog closes.

Let's re-read:
1. make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once
2. make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result

"开始绘图" button is `I18n.t('draw')` in Chinese.
`'draw': '开始绘图'`
In `_buildToolButton`, it is called "开始绘图". The prompt says to make this button control a boolean flag to make illustration instantly after reply.

But then in requirement 2: "make aidraw dialog disappear after click 开始"
In the `AiDraw` dialog, the button is "开始" (`I18n.t('start')`).
If it disappears after clicking "开始", how do we see the result?
Wait, if `AiDraw` was triggered by `_isAutoDraw`, `getDraw()` is called, which shows the dialog.
If it shows the dialog, the dialog still has the "开始" button.
Maybe the user wants the dialog to NOT appear at all?
"make aidraw dialog disappear after click 开始"
Or maybe when they click "开始" in the dialog, it closes, and when it's done, it just appends it? But wait, "do not change the preview of the illustration result" - this implies we *do* show a preview?

Wait! If `getDraw()` is called, it `showDialog` and waits for it to pop with an `imageUrl`.
```dart
  Future<void> getDraw() async {
    List<List<String>> msg = await parseMsg(
...
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AiDraw(msg: msg, config: config)
    ).then((imageUrl) {
      if (imageUrl != null) {
        setState(() {
          backgroundImage = DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
            ...
          );
        });
        setState(() {
          messages.add(Message(message: imageUrl, type: Message.image));
        });
        setTempHistory(msgListToJson(messages));
      }
    });
  }
```

If we close the dialog immediately on "开始", we would pop `null` (since image isn't generated yet). Then we generate it in the background, and *then* append it. But if we do that, we skip the preview step! The preview step in `AiDraw` is where the user sees the generated image and decides to click "重绘" (redraw) or "使用" (use) or "返回" (back).
If "make aidraw dialog disappear after click 开始, but do not change the preview of the illustration result" means... wait.
What if the dialog DOESN'T disappear immediately, but *while it is generating*, the dialog disappears, and then when it's done, it shows the preview?
No, "make aidraw dialog disappear after click 开始" means clicking "Start" makes it disappear.

Let's reread "but do not change the preview of the illustration result"
Maybe it means "keep the preview of the illustration result feature unchanged"?
Like, "Don't change the way the illustration result is previewed (in the dialog)"?
If the dialog disappears, it means it should pop and return the generation process to the background, AND THEN maybe when it finishes, it shows the preview?
Wait! If the dialog disappears, the generation continues in the background. Does it pop up the preview dialog when finished?
Or does it just apply the image directly?
"make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result"
If the image is appended to the chat, it IS a preview.
Actually, if it says "but do not change the preview of the illustration result", it might mean "it still shows the preview dialog when the generation is complete" OR "the dialog turns into a preview window".

Wait, let's look at what "开始" button currently does.
```dart
ElevatedButton(
  onPressed: gptBusy || promptController.text.isEmpty
      ? null
      : () {
          makeRequest().catchError((e) {
            snackBarAlert(context, "${I18n.t('error')} $e");
            setState(() {
              sdBusy = false;
            });
          });
        },
  child: Text(I18n.t('start')),
),
```
Currently, when you click "Start", `sdBusy = true`, `showLog = true`, and the dialog STAYS OPEN.
`AiDraw` dialog UI:
```dart
            if (imageUrl == null) ...[
              TextField(
                controller: promptController,
...
              const SizedBox(height: 8),
              if (sdBusy || showLog)
                TextField(
                  controller: logController,
...
            ] else ...[
              Expanded(
                child: GestureDetector(
                  onLongPress: () {
                    launchUrlString(imageUrlRaw ?? imageUrl!);
                  },
                  child: ClipRRect(
...
                    child: Image.network(
```
Ah! When `imageUrl != null`, the UI shows the preview inside the dialog!
"do not change the preview of the illustration result" means:
Leave the preview UI intact.
If the dialog disappears after "开始" (Start), how can we show the preview?
Maybe when you click "Start", it hides the dialog or hides itself, and when it finishes, it *re-appears*? Or maybe it just silently runs and then pops up the preview?
OR, does "开始绘图" button mean the button in the toolbox?
Toolbox button: "开始绘图" `I18n.t('draw')`
"1.make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
So "开始绘图" in the toolbox is a toggle.
"2. make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result"
Wait, if it's "aidraw dialog disappear after click 开始", "开始" in Chinese is `I18n.t('start')` (which is '开始').
If the dialog disappears, maybe the image should just be added to the chat immediately when it finishes? BUT the prompt says "do not change the preview of the illustration result". So the preview MUST still be shown.
If the dialog is closed, we could just show the preview dialog again once the image is ready?
Or maybe, "hide the input and logs part during generation, so only a small loading or completely hidden until preview"? No, "disappear".

Wait, maybe "开始绘图" in the tools expanded menu is `I18n.t('draw')`.
If it's a toggle:
```dart
                      _buildToolButton(
                        icon: _isAutoDraw ? Icons.draw : Icons.draw_outlined,
                        label: _isAutoDraw ? I18n.t('auto_draw') : I18n.t('manual_draw'),
                        onTap: () {
                          setState(() {
                            _isAutoDraw = !_isAutoDraw;
                            _isToolsExpanded = false;
                          });
                        },
                      ),
```
If we do this, how does the user manually trigger a draw? They can't, unless we keep the old button and add a new one, or if they change the toggle, does it also trigger? The user said "make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once". This directly implies changing the behavior of the existing "开始绘图" button.

Let's read the second instruction:
"2. make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result"
If they click "开始" (Start) inside `AiDraw`, the dialog disappears. But wait, if it disappears, where does the preview of the illustration result go?
Ah! If the dialog disappears, they don't see the preview unless we show it. "do not change the preview of the illustration result" means "when the result is ready, STILL show the preview of the illustration result (i.e. the dialog with the image)".
So:
1. User clicks "Start".
2. The dialog disappears (so they can continue chatting or whatever).
3. The image generation runs in the background.
4. When the image is generated, the `AiDraw` preview pops up, showing the image, and the user can click "Use", "Redraw", etc., exactly as it was before!

Yes! This makes perfect sense. The dialog disappears during generation so it doesn't block the screen, and pops up again when the image is ready. Or maybe the dialog *itself* becomes a background process, and when done, it `showDialog`s again with the preview.

Let's check how we can do this.
If `AiDraw` is closed, the `State` might be disposed. If it is disposed, the `cancelToken` might cancel the request? No, `cancelToken` is only cancelled explicitly. However, if the widget is disposed, calling `setState` will throw an error. Also, if we `Navigator.pop(context)` in `AiDraw`, `getDraw()`'s `then((imageUrl)` will trigger with `null`.
Then `getDraw()` will do nothing.
When the generation finishes, who will show the preview?
We need to decouple the generation from the `AiDraw` dialog, OR we can just hide the `AiDraw` dialog without popping it (e.g. using `Offstage` or `Visibility`? No, a `Dialog` is a route, you can't just hide a route without popping it, unless you make the dialog transparent and ignore pointer events, but then it still blocks the screen or is weird).

Wait, the easiest way to make it disappear is to pop it, but before popping, we start the background task. The background task can be in `MainPageState` or a global service.
When the background task finishes, it can call `showDialog` to show the preview!
But wait, if we pop the dialog when they click "开始", and show it again later, we can separate the "Prompt generation & tweaking" dialog from the "Preview" dialog.
Actually, `AiDraw` is one stateful widget. What if `makeRequest` is in `MainPageState`?
Or maybe `AiDraw` takes an optional `initialImageUrl`?
Currently `AiDraw` has `String? imageUrl;` which is set when the image is ready.
If we pass `imageUrl` to a new `AiDrawPreview` dialog, it would be identical to the second half of `AiDraw`.

Let's see:
```dart
class AiDraw extends StatefulWidget {
  final List<List<String>>? msg;
  final Config config;
  const AiDraw({super.key, required this.msg, required this.config});
```
We can modify `AiDraw` so that when the user clicks "Start", we call `Navigator.pop(context, "PENDING")` (or something), and then the caller (`getDraw()`) will handle the waiting and show the preview when done?
But wait! `AiDraw` currently contains the `promptController.text`, `sdConfig`, etc. `civitaiClient` logic is all inside `AiDrawState`.
If we move the API call outside, we'd have to return the `finalPrompt` and `sdConfig` to `getDraw()`.
Let's look at `makeRequest()` in `AiDrawState`:
It does:
- initialize `civitaiClient`
- apply prompt and LoRA
- `civitaiClient!.image.create(..., wait: true)`
- When done, `setState(() { imageUrl = url; ... })`
If we want the dialog to close during `makeRequest()`, we can do:

```dart
      ElevatedButton(
        onPressed: gptBusy || promptController.text.isEmpty
            ? null
            : () {
                // Return the prompt and let the main page handle the generation
                Navigator.pop(context, {'action': 'start', 'prompt': promptController.text});
              },
```

Then in `getDraw()`:
```dart
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AiDraw(msg: msg, config: config)
    ).then((result) async {
      if (result is Map && result['action'] == 'start') {
         // Start generation in background
         String prompt = result['prompt'];
         // Wait for generation
         String? finalImageUrl = await generateImageInBackground(prompt);
         if (finalImageUrl != null) {
            // Show preview dialog
            showDialog(
               context: context,
               builder: (context) => AiDrawPreview(imageUrl: finalImageUrl)
            ).then((useUrl) {
               if (useUrl != null) { ... }
            });
         }
      }
      else if (result is String) { // imageUrl from normal use
         ...
      }
    });
```
Wait, if `AiDraw` is also supposed to handle "Redraw" (`redraw`), and "Use" (`use`), moving the preview into `AiDraw` but skipping the prompt part is easy: we just pass `initialImageUrl` to `AiDraw`.

Let's look at `AiDraw` again.
If we add `final String? initialImageUrl;` to `AiDraw` constructor.
Wait! "make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result"
If the dialog disappears, and later reappears, that's one interpretation.
Another interpretation: The user doesn't want the prompt tweaking UI to stay on screen, BUT the user still wants the PREVIEW to show up seamlessly.
Actually, if the user turns on "Auto Draw" (which happens automatically after a reply), calling `getDraw()` will show the `AiDraw` dialog. `AiDraw` automatically generates the prompt and waits for the user to click "Start".
If they want it to be *fully* automatic, maybe they don't even want to click "Start"?
"make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
If it makes illustration *instantly* after reply, it should skip the "Start" click?
"instantly after reply" implies that after the assistant's reply, it immediately starts making the illustration.
Wait! If `_isAutoDraw` is true, after reply, we can call a function `doAutoDraw()`.
In `doAutoDraw()`, we generate the prompt and then generate the image in the background, without showing ANY dialog until the image is ready. When the image is ready, it shows the preview dialog (or just appends it to chat? "do not change the preview of the illustration result" -> implies we should still show the preview).

Let's read carefully:
"1.make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
"2. make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result"

If I'm using the app:
I click "开始绘图" (Draw) in the tools. It used to open the `AiDraw` dialog. Now, it toggles `_isAutoDraw`.
If `_isAutoDraw` is toggled ON, then every time the assistant replies, it automatically generates an illustration.
But wait! What about the manual draw? If "开始绘图" is just a toggle, how do I draw manually?
Maybe the button is now a toggle, and its text becomes "自动绘图" / "手动绘图" (Auto Draw / Manual Draw).
Then where is the manual draw?
Maybe they don't care about manual draw anymore, or maybe there's a different way, or maybe the toggle itself still does manual draw?
Wait, if `_isAutoVoice` changes "手动语音" to "自动语音", it doesn't trigger voice immediately, it just changes the state. To trigger voice manually, you have to long press a message and click "语音" (Voice).
For Draw, if they change the button to a toggle, it means they want to turn Auto Draw on/off.
If we look at `_buildToolButton`:
```dart
                      _buildToolButton(
                        icon: _isAutoVoice ? Icons.volume_up : Icons.volume_off,
                        label: _isAutoVoice ? I18n.t('auto_voice') : I18n.t('manual_voice'),
                        onTap: () {
...
```
I should add `_isAutoDraw` and update the existing draw button.
```dart
                      _buildToolButton(
                        icon: _isAutoDraw ? Icons.draw : Icons.draw_outlined, // or just Icons.draw for both?
                        label: _isAutoDraw ? I18n.t('auto_draw') : I18n.t('manual_draw'), // Wait, I18n.t('auto_draw') doesn't exist, I need to add it.
                        onTap: () {
                          setState(() {
                            _isAutoDraw = !_isAutoDraw;
                            _isToolsExpanded = false;
                          });
                        },
                      ),
```
If we do this, the manual draw is gone from the tools menu. Is that what the user wants?
"make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
This EXACTLY means they want the button to be a toggle.

Wait, if we do this, what if they want to make an illustration manually?
They can't, unless they turn it on and send a message. But that's exactly what the prompt asks: "to control whether make illustration instantly after reply rather than make illustration only once".
So the button used to "make illustration only once" (manual). Now it should "control whether make illustration instantly after reply" (toggle).

Let's add `_isAutoDraw` to `MainPageState`:
```dart
  bool _isAutoDraw = false;
```

In `sendMsg()`, after reply is done:
```dart
        () async {
          updateResponse(response.replaceAll(RegExp(await getResponseRegex()), ''));
          debugPrint("done.");
          setState(() {
            inputLock = false;
          });
          debugPrint("inputUnlocked");
          setTempHistory(msgListToJson(messages));
          if (_isAutoDraw) {
            getDraw();
          }
        }
```
If `getDraw()` is called, it currently pops up the `AiDraw` dialog.
Then in `AiDraw`, the user sees the generated prompt and has to click "开始" (Start).
Requirement 2: "make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result"
So when the user clicks "Start" inside the `AiDraw` dialog, the dialog should *disappear*.
BUT when the illustration is ready, the preview must still be shown.

How to make it disappear and show preview later?
We can change `AiDraw` so that when "Start" is clicked, we return the generated prompt and `sdConfig`? No, wait. `AiDraw` handles its own state for `civitaiClient` and job polling.
If we just `Navigator.pop(context)` in `AiDraw`, the `AiDraw` widget is removed from the screen, and its state might be disposed. If it's disposed, the `pollInterval` might still run if it's not cancelled? `civitaiClient!.image.create` is an async function. If `dispose()` is called, the async function continues running unless cancelled.
However, `setState` inside the async function will throw a "setState() called after dispose()" error.
So we cannot just pop and let `AiDrawState` handle the background task.

We have a few options:
**Option A**: Move the API logic into `lib/aidraw.dart` but completely decoupled from the UI, e.g., a static method or separate class, or in `MainPageState`.
**Option B**: Keep the dialog open but invisible? (No, that's hacky and blocks input).
**Option C**: Change the `AiDraw` dialog to a non-blocking overlay?
**Option D**: The `AiDraw` dialog's "Start" button pops with `{'action': 'start', 'prompt': promptController.text}`. Then `MainPageState` calls a background function that does the same API calls, and when finished, calls `showDialog(context: context, builder: (context) => AiDrawPreview(imageUrl: url))`.
But wait, `AiDraw` has the `sdConfig` loaded. `MainPageState` would need to duplicate the logic.
Wait, what if `AiDraw` is refactored?
Let's look at `makeRequest()` in `AiDrawState`.
It takes `sdConfig`, `civitaiClient`, `promptController.text`, `lora`.
This logic is ~80 lines.
If we move it to a helper function:
```dart
Future<String?> generateImageTask(String promptText, SdConfig sdConfig) async {
    // ... all the logic ...
    return url;
}
```
Then `getDraw()` could look like:
```dart
  Future<void> getDraw() async {
    List<List<String>> msg = await parseMsg(
      messages, currentStory != null ? jsonToMsg(currentStory![2]) : [], [Message(message: await getDrawPrompt(), type: Message.system)]
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AiDraw(msg: msg, config: config)
    ).then((result) async {
      if (result is Map && result['action'] == 'start') {
         String prompt = result['prompt'];
         // Start background generation
         try {
             String? imageUrl = await generateImageTask(prompt);
             if (imageUrl != null && mounted) {
                 showDialog(
                   context: context,
                   builder: (context) => AiDraw(msg: null, config: config, initialImageUrl: imageUrl)
                 ).then((finalImageUrl) {
                    if (finalImageUrl != null && finalImageUrl is String) {
                        setState(() { ... background and messages ... });
                    }
                 });
             }
         } catch(e) { ... }
      } else if (result is String) {
         // handle normal use (if any)
         ...
      }
    });
  }
```

Wait! If `_isAutoDraw` is on, does the user even want to click "Start"?
"make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
If it makes illustration *instantly* after reply, it should completely skip the user having to click "Start" or edit the prompt, right?
If it instantly starts, then `_isAutoDraw` means "Generate prompt AND start generation in the background automatically".
Then when the illustration is ready, show the preview.
Let's read again: "make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
"2. make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result"

If the first point means it *automatically* generates it without any dialog, then the second point ("make aidraw dialog disappear after click 开始") applies to *manual* drawing? Or maybe to the prompt dialog that pops up *even* during auto draw?
If `getDraw()` is called, it pops up the `AiDraw` dialog. The dialog automatically generates the prompt (`gptBusy = true`). When done, it waits for the user to click "Start".
If the user wants it to be instant, maybe `AiDraw` should auto-start?
"make aidraw dialog disappear after click 开始"
This suggests the user *does* click "开始" (Start).
Wait, if `_isAutoDraw` means "it happens instantly after reply", why would they need to click "开始"?
Maybe the prompt generation happens instantly after reply, the dialog pops up, they click "开始", it disappears, and then shows preview later?
OR maybe "instantly after reply" means exactly that it automatically does the whole thing without clicking?
"make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
"make illustration only once" refers to the current behavior: you click "开始绘图", it generates an illustration for the *current* state of the conversation.
If you change it to "control whether make illustration instantly after reply", you click it, it becomes a toggle. Then every time there is a reply, it makes an illustration.
But what about the second point? "make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result"
This could mean: if the user (or the auto-draw) triggers the illustration, the dialog that normally stays open while `sdBusy = true` should disappear, and only show the preview later.
Wait, if I change `AiDraw` so that clicking "Start" hides the UI, I can use a Stack or Offstage!
If I wrap the content of `AiDraw` in `Offstage(offstage: sdBusy, child: ...)`
If `sdBusy` is true, the dialog is still open, but we show... nothing? If we return `SizedBox.shrink()` it will be an empty dialog. A tiny box in the middle of the screen.
That doesn't "disappear".
To truly disappear, we must `Navigator.pop`.

Let's refactor the generation logic out of `AiDrawState` to a helper in `aidraw.dart` or keep it inside `AiDrawState` but run it outside the dialog? No, state is disposed.
It's very easy to just move `makeRequest` logic out.
Let's see the dependencies of `makeRequest`:
`sdConfig` (can be fetched via `getSdConfig()`)
`promptController.text`
`getDrawCharPrompt()`
`getDrawLora()`
`CivitaiClient`
`isForeground` (for notifications)
`NotificationHelper`

Let's write `generateImageTask` in `aidraw.dart`:

```dart
Future<String?> generateImageTask({
  required String promptText,
  required SdConfig sdConfig,
  required BuildContext context,
}) async {
  try {
    if (sdConfig.civitaiApiToken == null || sdConfig.civitaiApiToken!.isEmpty) {
      throw Exception('Civitai API token is not configured');
    }

    final civitaiClient = CivitaiClient(apiToken: sdConfig.civitaiApiToken!);

    String prompt = sdConfig.prompt;
    if(!prompt.contains("CHAR")){
      prompt += ", CHAR";
    }
    if(!prompt.contains("VERB")){
      prompt += ", VERB";
    }
    String? charPrompt = await getDrawCharPrompt();
    String finalPrompt = prompt
        .replaceAll("VERB", promptText)
        .replaceAll("CHAR", charPrompt);

    String? lora = await getDrawLora();
    Map<String, dynamic>? additionalNetworks;
    if (lora != null && lora.isNotEmpty) {
      final loraPattern = RegExp(r'<([^:]+):([0-9.]+)>');
      final matches = loraPattern.allMatches(lora);
      if (matches.isNotEmpty) {
        additionalNetworks = {};
        for (var match in matches) {
          String airUrn = match.group(1)!;
          double weight = double.tryParse(match.group(2)!) ?? 1.0;
          additionalNetworks[airUrn] = {'strength': weight};
        }
      } else {
        additionalNetworks = {
          lora: {'strength': 1.0},
        };
      }
    }

    final input = ImageInput(
      model: sdConfig.model,
      params: ImageParams(
        prompt: finalPrompt,
        negativePrompt: sdConfig.negativePrompt,
        width: sdConfig.width ?? 1024,
        height: sdConfig.height ?? 1600,
        steps: sdConfig.steps ?? 28,
        cfgScale: (sdConfig.cfg ?? 7).toDouble(),
        scheduler: sdConfig.sampler,
        seed: sdConfig.seed,
        clipSkip: sdConfig.clipSkip,
      ),
      additionalNetworks: additionalNetworks,
    );

    final response = await civitaiClient.image.create(
      input: input,
      wait: true,
      timeout: const Duration(minutes: 10),
      pollInterval: const Duration(seconds: 2),
    );

    if (response.jobs.isNotEmpty) {
      for (var job in response.jobs) {
        final url = job.imageUrl;
        if (url != null && url.isNotEmpty) {
          // Send notification if not foreground
          // But we don't have isForeground here easily unless we pass it.
          // Actually we can just show notification anyway or ignore it for now.
          return url;
        }
      }
    }
    return null;
  } catch (e) {
    rethrow;
  }
}
```

Wait, if we do this, the logs won't be visible to the user. "do not change the preview of the illustration result" doesn't say anything about logs, but the user explicitly requested "make aidraw dialog disappear after click 开始". So hiding logs during generation is completely expected (since the dialog is gone!).
When the user clicks "Start", we do:
```dart
  Navigator.pop(context, {'action': 'start', 'prompt': promptController.text, 'sdConfig': sdConfig});
```

Then in `lib/main.dart`'s `getDraw()`:
```dart
  Future<void> getDraw() async {
    List<List<String>> msg = await parseMsg(
      messages, currentStory != null ? jsonToMsg(currentStory![2]) : [], [Message(message: await getDrawPrompt(), type: Message.system)]
    );
    var result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AiDraw(msg: msg, config: config)
    );

    if (result is Map && result['action'] == 'start') {
      String prompt = result['prompt'];
      SdConfig sdConfig = result['sdConfig'];

      // show a snackbar to indicate it started
      snackBarAlert(context, I18n.t('generating')); // or '开始绘图...'

      try {
        String? finalUrl = await generateImageTask(
          promptText: prompt,
          sdConfig: sdConfig,
        );

        if (finalUrl != null && mounted) {
           if (!isForeground) {
              notification.showNotification(
                title: '绘画',
                body: '绘画完成！',
                showAvator: false
              );
           }

           // Show the preview dialog
           var previewResult = await showDialog(
             context: context,
             barrierDismissible: false,
             builder: (context) => AiDraw(msg: null, config: config, initialImageUrl: finalUrl)
           );

           if (previewResult is String) {
             setState(() {
               backgroundImage = DecorationImage(
                 image: NetworkImage(previewResult),
                 fit: BoxFit.cover,
                 colorFilter: ColorFilter.mode(
                   Colors.white.withOpacity(0.8),
                   BlendMode.dstATop,
                 ),
               );
               messages.add(Message(message: previewResult, type: Message.image));
             });
             setTempHistory(msgListToJson(messages));
           } else if (previewResult is Map && previewResult['action'] == 'redraw') {
              // They clicked redraw!
              // Oh wait, if they click redraw, we need to generate again.
              // We should probably just let `AiDraw` handle its own redraw.
              // Wait, if `AiDraw` is just a preview, how does it redraw?
           }
        }
      } catch (e) {
        if (mounted) snackBarAlert(context, "${I18n.t('error')} $e");
      }
    } else if (result is String) {
      // Direct result
      setState(() {
        backgroundImage = DecorationImage(
          image: NetworkImage(result),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.white.withOpacity(0.8),
            BlendMode.dstATop,
          ),
        );
        messages.add(Message(message: result, type: Message.image));
      });
      setTempHistory(msgListToJson(messages));
    }
  }
```

Wait, if they click "Redraw" (`重绘`) from the preview dialog, it used to just clear `imageUrl` and run `makeRequest()` again inside `AiDrawState`.
If we pop the dialog and recreate it for preview, we don't have the original prompt to redraw!
Ah. The `AiDraw` dialog had `promptController.text` and could redraw with the same prompt.
If we use `generateImageTask` in `MainPageState`, we would need a loop.
```dart
  Future<void> handleDrawTask(String prompt, SdConfig sdConfig) async {
    while (true) {
      try {
        String? finalUrl = await generateImageTask(promptText: prompt, sdConfig: sdConfig);
        if (finalUrl != null && mounted) {
          if (!isForeground) { ... }
          var previewResult = await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AiDraw(msg: null, config: config, initialImageUrl: finalUrl, promptForRedraw: prompt)
          );
          if (previewResult == 'redraw') {
             snackBarAlert(context, I18n.t('generating'));
             continue; // loop again
          } else if (previewResult is String) {
             // apply image
             setState({ ... });
             break;
          } else {
             // canceled
             break;
          }
        } else {
          break;
        }
      } catch (e) { ... break; }
    }
  }
```

This is getting complex, but it perfectly separates the waiting from the dialog.

Wait, what if `_isAutoDraw` is true? The prompt generation (`gptBusy`) STILL happens in the dialog?
If the dialog pops up every time the assistant replies, to generate the prompt and then the user clicks "Start", it defeats the purpose of "auto draw" if it waits for user interaction!
"make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
"Instantly after reply" implies the user DOES NOT click "Start". It just happens.
If `_isAutoDraw` is true, after reply, we skip the UI and just generate the prompt in the background, then generate the image in the background, then pop up the preview!
If `_isAutoDraw` is false (manual), the user clicks "开始绘图" (no, it's a toggle now), wait, if it's a toggle, how do they manually draw?
Maybe the toggle *replaces* the manual draw button, so they turn it on to auto-draw.
What if they want to manually draw? Maybe they turn it on, and then turn it off?
Wait, if they turn it on, does it immediately draw for the current conversation?
Usually a toggle like "Auto Voice" doesn't voice the current message, it just voices the NEXT messages.
But for "Auto Draw", if it replaces the manual draw button, the user loses the ability to draw manually!
Unless the prompt meant: "make 开始绘图 button to control whether make illustration instantly after reply" AND keep its old functionality? No, "rather than make illustration only once".
"rather than" means *replace* the old behavior with the new behavior!
So the button becomes a pure toggle!
Let's add the translations:
```dart
'auto_draw': '自动绘图',
'manual_draw': '手动绘图',
'auto_draw': 'Auto Draw',
'manual_draw': 'Manual Draw',
```
In `lib/main.dart` `_buildToolButton`:
```dart
                      _buildToolButton(
                        icon: _isAutoDraw ? Icons.brush : Icons.brush_outlined,
                        label: _isAutoDraw ? I18n.t('auto_draw') : I18n.t('manual_draw'),
                        onTap: () {
                          setState(() {
                            _isAutoDraw = !_isAutoDraw;
                            _isToolsExpanded = false;
                          });
                        },
                      ),
```
Now, if `_isAutoDraw` is true, what happens after reply?
In `sendMsg()`'s done callback:
```dart
        () async {
          updateResponse(response.replaceAll(RegExp(await getResponseRegex()), ''));
          debugPrint("done.");
          setState(() {
            inputLock = false;
          });
          debugPrint("inputUnlocked");
          setTempHistory(msgListToJson(messages));

          if (_isAutoDraw) {
            // Trigger automatic background drawing
            doAutoDrawInBackground();
          }
        }
```

Wait! If `doAutoDrawInBackground` runs automatically, what does it do?
It should generate the prompt using the LLM, then generate the image using Civitai, all in the background, and then show the preview!
BUT wait! The second requirement:
"2. make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result"
This requirement specifically mentions "click 开始".
If Auto Draw skips clicking "开始", then who is clicking "开始"?
Ah!!!
Maybe Auto Draw is NOT purely background. Maybe Auto Draw means: automatically POP UP the `AiDraw` dialog after a reply!
If Auto Draw just automatically opens the `AiDraw` dialog, the user still sees it, waits for prompt, and clicks "开始" (Start).
"make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
If it just pops up the dialog, it's not exactly "make illustration instantly". But it does "start the process of making illustration instantly".
Wait, if it pops up the dialog, the user has to click "Start". Then after clicking "Start", the dialog disappears (Requirement 2).
Let's reconsider. If Auto Draw skips the prompt dialog and directly makes the illustration:
If they turn on Auto Draw, it generates everything in background.
Then why does Requirement 2 say "make aidraw dialog disappear after click 开始"?
Because `AiDraw` dialog is STILL used for manual drawing?
If the button "开始绘图" was changed to a toggle, how do they manually open the dialog?
Maybe the toggle is a separate button?
"make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
This means changing the existing button to a toggle.
If they change the existing button to a toggle, they can't manually open the dialog unless there is another button, or clicking the toggle when it's already on triggers it?
Wait, if `_isAutoDraw` is true, after reply it automatically runs the drawing process.
What if `_isAutoDraw` is false? They don't draw.
How do they draw? They turn `_isAutoDraw` to true, and then next reply it draws.
But what if they want to draw for the *current* conversation?
Maybe they can long press a message and click "Draw"? Currently long press doesn't have "Draw".
Actually, maybe I should NOT replace the button, but change the button's ON TAP behavior to toggle `_isAutoDraw`, OR maybe just add a new button for auto draw?
But the prompt explicitly says: "make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
This is a direct instruction: CHANGE the "开始绘图" button so it acts as a toggle "rather than" a one-time trigger.
Okay, I will change the button to a toggle.

Wait, if it's a toggle, where do they click "开始"?
Ah! If Auto Draw is on, `doAutoDrawInBackground()` generates the prompt, but maybe it STILL needs to show the prompt to the user so they can edit it, and they click "开始" to proceed?
If Auto Draw means "Automatically open the AiDraw dialog", then:
1. `_isAutoDraw` is true.
2. After reply, it calls `getDraw()`.
3. `getDraw()` shows the `AiDraw` dialog.
4. The user sees the prompt generating, and clicks "开始" (Start).
5. The dialog disappears, and generates in background.
6. When done, preview shows up.

Wait, if Auto Draw requires user to click "Start", it's not fully automatic.
What if "Auto Draw" means it DOES fully automatically draw in the background?
But then where does the user click "开始"?
Maybe the user wants Auto Draw to be fully automatic, BUT the user *also* uses the app in a way where they sometimes see the `AiDraw` dialog.
Wait! If I change the "开始绘图" button to a toggle, is there ANY other way to open the `AiDraw` dialog?
Maybe by long pressing a message?
No, the codebase doesn't have `getDraw()` anywhere else except `onTap` of that tool button!
If I change it to a toggle, they will NEVER see the `AiDraw` dialog's prompt generation screen, UNLESS the auto-draw process still shows the dialog, OR I keep the manual draw and add auto draw as a long press?
"make 开始绘图 button to control..."
Maybe clicking it toggles the state, and if toggled ON, it immediately triggers `getDraw()`?
No, "whether make illustration instantly after reply".

Let me read it again.
"1.make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
Maybe the toggle itself is the "开始绘图" button.
When you click it, it just toggles the state.

If I make it a toggle, and it automatically draws *without* showing the prompt dialog, then the user never sees "开始" to click it.
Unless `_isAutoDraw` being true means: after reply, call `getDraw()`.
If I just call `getDraw()` after reply, it pops up the dialog. The user still clicks "开始". This fits perfectly!
"instantly after reply" -> "make illustration instantly after reply" could mean "start the process of making the illustration".
Wait, if it says "make illustration instantly", maybe it means generating without clicking "开始"?
If it generates without clicking "开始", then Requirement 2 ("make aidraw dialog disappear after click 开始") could refer to the manual process, BUT the manual process is removed by Requirement 1!
Wait, what if Requirement 1 means:
Change the existing button to a toggle. If true, after reply, we do NOT show the prompt dialog, but just go straight to generating!
Then where does "click 开始" come from?
Maybe it comes from the `AiDraw` dialog... wait, if there's no way to open `AiDraw` dialog manually, then the "开始" button is never seen!
Unless they mean "when the dialog is opened"? How is it opened?
Maybe I should KEEP the manual draw, and just add the toggle?
No, "make 开始绘图 button to control whether... rather than...". This means replacing it.
Wait! If the button is a toggle, what if the user clicks it? It turns on.
What if `getDraw()` is changed so that it skips the "Start" button if `_isAutoDraw` is true?
If I read the prompt literally:
"make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once"
"instantly after reply" = generate it automatically.
"rather than make illustration only once" = instead of doing it only once when clicked.
So the "开始绘图" button's function is fundamentally changed.

But what if the button has TWO actions? `onTap` and `onLongPress`?
Like the `send` button: `onPressed: () => sendMsg(true), onLongPress: () => getMsg()`
For the draw button:
```dart
                      _buildToolButton(
                        icon: Icons.draw,
                        label: _isAutoDraw ? '自动绘图' : '手动绘图',
                        onTap: () {
                          // toggle
                        },
                      ),
```
If I just make it a toggle, what about "aidraw dialog disappear after click 开始"?
Ah, maybe they mean when `AiDraw` DOES pop up (e.g. if they trigger it somehow, or if Auto Draw opens the dialog), clicking "开始" hides it.
Let's just make the "开始绘图" button a toggle. And when toggled on, it automatically calls `getDraw()` after a reply.
Wait! If `getDraw()` is called, it opens the `AiDraw` dialog. The prompt generates, then the user clicks "Start". Then the dialog disappears, generates in background, then pops up the preview.
This exactly satisfies BOTH requirements!
1. Button controls whether to start the drawing process after reply.
2. The dialog disappears when you click "Start".

But "make illustration instantly after reply" might mean it shouldn't ask for "Start"! It should just DO it.
If it just does it, then clicking "Start" is never needed. Why would the user ask to "make aidraw dialog disappear after click 开始" if they never see "开始"?
Unless they want to KEEP manual draw!
Maybe the tool button is NOT a toggle, but just a normal button. But if it's a normal button, how does it "control whether make illustration instantly after reply rather than make illustration only once"?
A button that says "开始绘图" (Start Drawing).
If you click it, it toggles `_isAutoDraw`.
If you want to draw manually, you can't?
Actually, what if the label of the button REMAINS "开始绘图" (`I18n.t('draw')`), but its behavior is changed to a toggle? And when it's ON, it's highlighted?
Let's do this:
The tool button `_buildToolButton` for draw:
```dart
                      _buildToolButton(
                        icon: _isAutoDraw ? Icons.draw : Icons.draw_outlined,
                        label: _isAutoDraw ? I18n.t('auto_draw') : I18n.t('draw'),
                        onTap: () {
                          setState(() {
                            _isAutoDraw = !_isAutoDraw;
                            _isToolsExpanded = false;
                          });
                        },
                      ),
```
And add 'auto_draw' to i18n: `'auto_draw': '自动绘图'` (zh) and `'Auto Draw'` (en).
Then in `sendMsg` completion:
```dart
          if (_isAutoDraw) {
            getDraw();
          }
```
This means after reply, it opens `AiDraw`.
BUT what if "instantly" means it shouldn't open the dialog at all, but rather just click "Start" automatically?
If it clicks "Start" automatically, the dialog would appear and immediately disappear. That's weird.
If it doesn't open the dialog, then requirement 2 ("disappear after click 开始") must be for manual drawing. Where is manual drawing? Maybe I should add manual drawing to long press!
```dart
                      _buildToolButton(
                        icon: _isAutoDraw ? Icons.draw : Icons.draw_outlined,
                        label: _isAutoDraw ? I18n.t('auto_draw') : I18n.t('draw'),
                        onTap: () {
                          setState(() {
                            _isAutoDraw = !_isAutoDraw;
                            _isToolsExpanded = false;
                          });
                        },
                      ),
```
If I add `onLongPress` to `_buildToolButton` to trigger `getDraw()`, I can preserve manual drawing. But `_buildToolButton` only takes `onTap`.
Let me add `onLongPress` to `_buildToolButton`!
```dart
  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
...
```
Then for the draw button:
```dart
                      _buildToolButton(
                        icon: _isAutoDraw ? Icons.draw : Icons.draw_outlined,
                        label: _isAutoDraw ? I18n.t('auto_draw') : I18n.t('draw'),
                        onTap: () {
                          setState(() {
                            _isAutoDraw = !_isAutoDraw;
                            _isToolsExpanded = false;
                          });
                        },
                        onLongPress: () {
                          getDraw();
                          setState(() {
                            _isToolsExpanded = false;
                          });
                        },
                      ),
```
Wait! The user said: "make 开始绘图 button to control whether make illustration instantly after reply rather than make illustration only once".
If the button toggles `_isAutoDraw`, and `_isAutoDraw` means "instantly after reply", then when it's on, does it skip the prompt dialog?
If we skip the prompt dialog, we need a silent version of `getDraw()` that auto-generates the prompt and auto-starts the generation, and then shows the preview.
Let's look at `getDraw()`:
```dart
  Future<void> autoDrawTask() async {
    // silently generate prompt
    List<List<String>> msg = await parseMsg(
      messages, currentStory != null ? jsonToMsg(currentStory![2]) : [], [Message(message: await getDrawPrompt(), type: Message.system)]
    );

    // We need to run completion to get the prompt
    String promptText = '';
    final Config? aidrawCfg = await getAidrawApiConfig();
    final Config configToUse = aidrawCfg ?? config;

    await completion(configToUse, msg,
      (String data) async {
        promptText += data.replaceAll("\n", " ");
      },
      () async {
        String finalPromptText = promptText.split('||').last.replaceAll(RegExp(await getResponseRegex()), '');
        SdConfig sdConfig = await getSdConfig();
        // start background task
        try {
           String? url = await generateImageTask(promptText: finalPromptText, sdConfig: sdConfig);
           if (url != null && mounted) {
              // show preview
              var previewResult = await showDialog(
                 context: context,
                 barrierDismissible: false,
                 builder: (context) => AiDraw(msg: null, config: config, initialImageUrl: url, promptForRedraw: finalPromptText)
              );
              if (previewResult is String) {
                // handle result
              }
           }
        } catch (e) {
           if (mounted) snackBarAlert(context, "${I18n.t('error')} $e");
        }
      },
      (err) {
         if (mounted) snackBarAlert(context, "${I18n.t('error')} $err");
      }
    );
  }
```
If we do this, it's TRULY instant and background!
AND the second requirement "make aidraw dialog disappear after click 开始，but do not change the preview of the illustration result" would apply to MANUAL drawing (e.g. if they somehow trigger manual drawing, like maybe they still can by clicking? Wait!)

If they click the button, it changes state. What if they DO want to manually draw?
"rather than make illustration only once"
This literally means: The button NO LONGER makes illustration only once. It ONLY controls the toggle.
If so, they can NO LONGER do manual draw. Which means "aidraw dialog disappear after click 开始" MUST apply to the Auto Draw flow!
Which means the Auto Draw flow STILL pops up the `AiDraw` dialog, waits for prompt to generate, and then WAITS for the user to click "开始"!
If it WAITS for the user to click "开始", then Auto Draw just means "Automatically open the dialog".
Let's re-read carefully: "make illustration instantly after reply"
If it opens a dialog and WAITS for the user, it is NOT making it instantly.
So "instantly" must mean it auto-generates!
Then why would they ask to "make aidraw dialog disappear after click 开始"?
Because maybe they STILL open the dialog via some other means? Or maybe they modify the prompt and click start?
Ah!!! What if `AiDraw` Dialog pops up, generates the prompt, and automatically clicks "开始"??
If it automatically clicks "开始", then it disappears immediately, and the image generates in the background.
If that's what they mean, we can just do:
1. `_isAutoDraw` true -> calls `getDraw()` after reply.
2. `getDraw()` opens `AiDraw`.
3. `AiDraw` generates prompt.
4. When prompt generation finishes (`gptBusy = false`), if `_isAutoDraw` is true, it AUTOMATICALLY triggers `makeRequest()`!
Wait, if it automatically triggers `makeRequest()`, then the user never clicked "开始". But the requirement says "after click 开始".
So the user STILL CLICKS "开始".
So "Auto Draw" just means: after reply, automatically open the `AiDraw` dialog! "make illustration instantly after reply" -> "start the illustration process instantly after reply".
Let's assume this:
1. The button toggles `_isAutoDraw`.
2. When `_isAutoDraw` is true, after reply, we call `getDraw()`.
3. `getDraw()` opens `AiDraw` dialog.
4. User clicks "开始" (Start).
5. The dialog pops (disappears), and the generation continues in the background.
6. When generation finishes, it shows the preview.

This perfectly explains both requirements without introducing new hidden logic!
Let's implement this.
