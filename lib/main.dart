import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:momotalk/aidrawconfig.dart';
import 'package:url_launcher/url_launcher_string.dart' show launchUrlString;
import 'dart:io' show Platform;
import 'chatview.dart';
import 'configpage.dart';
import 'notifications.dart';
import 'popups.dart';
import 'prompteditor.dart';
import 'theme.dart';
import 'history.dart';
import 'openai.dart';
import 'storage.dart';
import 'utils.dart';
import 'webdav.dart';
import 'msgeditor.dart';
import 'aidraw.dart';


main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationHelper notificationHelper = NotificationHelper();
  await notificationHelper.initialize();
  runApp(const MomotalkApp());
}

class MomotalkApp extends StatelessWidget {
  const MomotalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MomoTalk',
      home: const MainPage(),
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> with WidgetsBindingObserver{
  final fn = FocusNode();
  final textController = TextEditingController();
  final scrollController = ScrollController();
  final notification = NotificationHelper();
  late String studentName;
  late String avatar;
  Config config = Config(name: "", baseUrl: "", apiKey: "", model: "");
  String userMsg = "";
  int splitCount = 0;
  bool inputLock = false;
  bool keyboardOn = false;
  bool isForeground = true;
  bool isAutoNotification = false;
  List<Message> messages = [];
  List<Message>? lastMessages;
  List<List<String>> historys = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getStudentName().then((name){
        studentName = name;
      });
    getAvatar().then((avt){
      avatar = avt;
    });
    getOriginalMsg().then((originalMsg) {
      setState(() {
        messages.add(Message(message: originalMsg, type: Message.assistant));
      });
    });
    getTempHistory().then((msg) {
      if (msg != null) {
        loadHistory(msg);
      }
    });
    getApiConfigs().then((configs) {
      if (configs.isNotEmpty) {
        config = configs[0];
      }
    });
    getHistorys().then((List<List<String>> results) {
      setState(() {
        historys = results;
        historys.sort((a, b) => int.parse(b[1]).compareTo(int.parse(a[1])));
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    super.didChangeAppLifecycleState(state);
    if(state == AppLifecycleState.resumed){
      isForeground = true;
      if(isAutoNotification){
        isAutoNotification = false;
        notification.cancelAll();
      }
    } else {
      isForeground = false;
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if(!Platform.isAndroid){
      return;
    }
    final bottom = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
    if(bottom>10 && !keyboardOn){
      debugPrint("keyboard on");
      keyboardOn = true;
      if(ModalRoute.of(context)?.isCurrent != true){
        return;
      }
      Future.delayed(const Duration(milliseconds: 200), () => setScrollPercent(1.0));
    } else if(bottom<10 && keyboardOn){
      debugPrint("keyboard off");
      keyboardOn = false;
    }
  }

  double getScrollPercent() {
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    final percent = currentScroll / maxScroll;
    debugPrint("scroll percent: $percent");
    return percent;
  }

  void setScrollPercent(double percent) {
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = maxScroll * percent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollController.animateTo(currentScroll,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  void updateConfig(Config c){
    config = c;
    debugPrint("update config: ${c.toString()}");
  }

  void onMsgPressed(int index,LongPressStartDetails details){
    HapticFeedback.heavyImpact();
    if(messages[index].type == Message.assistant){
      assistantPopup(context, messages[index].message, details, studentName, (String edited){
        debugPrint("edited: $edited");
        edited = edited.replaceAll("\n", "\\");
        if(edited=="FORMAT"){
          String msg = messages[index].message.replaceAll(":", "：");
          String var1="$studentName：",var2="Sensei：";
          List<String> msgs = splitString(msg, [var1,var2]);
          debugPrint("msgs: $msgs");
          setState(() {
            messages.removeAt(index);
            for(int i=0;i<msgs.length;i++){
              if(msgs[i].startsWith(var1)){
                messages.insert(index+i, Message(
                  message: msgs[i].substring(var1.length), 
                  type: Message.assistant));
              } else if(msgs[i].startsWith(var2)){
                messages.insert(index+i, Message(
                  message: msgs[i].substring(var2.length).replaceAll("\\\\", "\\"), 
                  type: Message.user));
              }
            }
          });
          return;
        }
        if(edited.isEmpty){
          setState(() {
            messages.removeRange(index, messages.length);
          });
          return;
        }
        setState(() {
          messages[index].message = edited;
        });
      });
    } else if(messages[index].type == Message.user){
      userPopup(context, messages[index].message, details, (String edited,bool isResend){
        debugPrint("edited: $edited");
        edited = edited.replaceAll("\n", "\\");
        if(edited.isEmpty){
          setState(() {
            messages.removeRange(index, messages.length);
          });
          return;
        }
        setState(() {
          messages[index].message = edited;
        });
        if(isResend){
          textController.clear();
          lastMessages = messages.sublist(index+1,messages.length);
          messages.removeRange(index+1, messages.length);
          sendMsg(true);
        }
      });
    } else if(messages[index].type == Message.timestamp){
      timePopup(context, int.parse(messages[index].message), details, (bool ifTransfer, DateTime? newTime){
        if(ifTransfer){
          setState(() {
            messages[index].type = Message.system;
            messages[index].message = timestampToSystemMsg(messages[index].message);
          });
        } else {
          debugPrint(newTime.toString());
          setState(() {
            messages[index].message = newTime!.millisecondsSinceEpoch.toString();
          });
        }
      });
    } else if(messages[index].type == Message.system){
      systemPopup(context, messages[index].message, (String edited,bool isSend){
        debugPrint("edited: $edited");
        if(edited.isEmpty){
          setState(() {
            messages.removeAt(index);
          });
        } else {
          setState(() {
            messages[index].message = edited;
          });
          if(isSend){
            messages.removeRange(index+1, messages.length);
            sendMsg(true,forceSend: true);
          }
        }
      });
    } else if(messages[index].type == Message.image){
      imagePopup(context, details, (bool edited){
        if(edited){
          launchUrlString(messages[index].message);
        } else {
          setState(() {
            messages.removeAt(index);
          });
        }
      });
    }
  }

  void sdWorkflow() async {
    TextEditingController controller = TextEditingController();
    showDialog(context: context, builder: (context){
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text("绘图提示词"),
          content: TextField(
            maxLines: null,
            minLines: 1,
            controller: controller,
            decoration: const InputDecoration(
              hintText: "请输入提示词...",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
              child: const Text('继续'),
            ),
            TextButton(
              onPressed: () async {
                  controller.text = "正在生成...";
                  String prompt = "";
                  List<List<String>> msg = parseMsg(await getPrompt(), messages);
                  msg.add(["user", "system instruction:暂停角色扮演，根据上下文，详细描述$studentName现在的状态。"]);
                  completion(config, msg, (resp){
                    const String a="我无法继续作为",b="代替玩家言行";
                    prompt += resp;
                    if(prompt.startsWith(a) && prompt.contains(b)){
                      prompt = prompt.replaceAll(RegExp('^$a.*?$b'), "");
                    }
                    controller.text = prompt;
                  }, (){
                    debugPrint("done.");
                  }, (err){
                    errDialog(err.toString(),canRetry: false);
                  });
              },
              child: const Text('生成'),
            ),
          ],
        );
      });
    }).then((res){
      debugPrint("res: $res");
      if(controller.text.isEmpty){
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AiDraw(msg:res, config: config)
        )
      ).then((imageUrl){
        if(imageUrl!=null){
          setState(() {
            messages.add(Message(message: imageUrl, type: Message.image));
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setScrollPercent(1.0);
          });
        }
      });
    });
  }

  void loadHistory(String msg) {
    List<Message> msgs = jsonToMsg(msg);
    setState(() {
      messages.clear();
      messages.addAll(msgs);
    });
  }

  void updateResponse(String response) {
    setState(() {
      if (messages.last.type != Message.assistant) {
        splitCount = 0;
        messages.add(Message(message: response, type: Message.assistant));
      } else {
        const String a="我无法继续作为",b="代替玩家言行";
        if(response.startsWith(a) && response.contains(b)){
          response = response.replaceAll(RegExp('^$a.*?$b'), "");
        }
        messages.last.message = response;
      }
    });
    var currentSplitCount = response.split("\\").length;
    if (splitCount != currentSplitCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setScrollPercent(1.0);
      });
      splitCount = currentSplitCount;
    }
  }

  void clearMsg() {
    lastMessages = null;
    setState(() {
      messages.clear();
      getStudentName().then((name){
        studentName = name;
      });
      getAvatar().then((avt){
        avatar = avt;
      });
      getOriginalMsg().then((originalMsg) {
        setState(() {
          messages.add(Message(message: originalMsg, type: Message.assistant));
        });
      });
      setTempHistory(msgListToJson(messages));
    });
  }

  void logMsg(List<List<String>> msg) {
    for (var m in msg) {
      debugPrint("${m[0]}: ${m[1]}");
    }
    debugPrint("model: ${config.model}");
  }

  void errDialog(String content,{bool canRetry=true}){
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
          if(canRetry) TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              sendMsg(true,forceSend: true);
            },
            child: const Text('重试'),
          ),
        ],
      ),
    ).then((val){
      if(val==null&&lastMessages!=null){
        setState(() {
          messages.addAll(lastMessages!);
        });
      }
    });
  }

  Future<void> sendMsg(bool realSend,{bool forceSend=false}) async {
    if (inputLock) {
      return;
    }
    if(!forceSend){
      if((!realSend)||(realSend&&textController.text.isNotEmpty)){
        setState(() {
          if(messages.last.type == Message.user){
            userMsg = "$userMsg\\${textController.text}";
            messages.last.message = userMsg;
          } else {
            if (messages.length==1) {
              messages.add(Message(message: DateTime.now().millisecondsSinceEpoch.toString(), type: Message.timestamp));
            }
            userMsg = textController.text;
            messages.add(Message(message: userMsg, type: Message.user));
          }
          textController.clear();
        });
        debugPrint(userMsg);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setScrollPercent(1.0);
        });
        if(!realSend){return;}
      }
      userMsg = "";
    }
    setState(() {
      inputLock = true;
      debugPrint("inputLocked");
    });
    List<List<String>> msg = parseMsg(await getPrompt(), messages);
    logMsg(msg);
    bool notificationSent= false;
    try {
      String response = "";
      await completion(config, msg, 
        (String resp){
          resp = resp.replaceAll(RegExp(r'[\n\\]+'), r'\');
          resp = randomizeBackslashes(resp);
          response += resp;
          updateResponse(response);
          if(!isForeground && !notificationSent && response.contains("\\")){
            List<String> msgs = response.split("\\");
            for(int i=0;i<msgs.length;i++){
              if(msgs[i].isEmpty || msgs[i].startsWith("*")||
                msgs[i].startsWith("（")||msgs[i].startsWith("我无法继续")){
                continue;
              }
              if(i!=msgs.length-1){
                notification.showNotification(title: studentName, body: msgs[i]);
                isAutoNotification = true;
                notificationSent = true;
                break;
              }
            }
          }
        }, (){
          debugPrint("done.");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setScrollPercent(1.0);
          });
          setState(() {
            inputLock = false;
          });
          debugPrint("inputUnlocked");
          if(messages.last.message.contains("\\")){
            setTempHistory(msgListToJson(messages));
          }
          if(!isForeground && !notificationSent){
            isAutoNotification = true;
            notificationSent = true;
            notification.showNotification(title: "Done", body: "" ,showAvator: false);
          }
          lastMessages = null;
        }, (err){
          setState(() {
            inputLock = false;
          });
          debugPrint("inputUnlocked");
          errDialog(err.toString());
          if(!isForeground){
            isAutoNotification = true;
            notification.showNotification(title: "Error", body: "", showAvator: false);
          }
        });
    } catch (e) {
      setState(() {
        inputLock = false;
      });
      debugPrint("inputUnlocked");
      debugPrint(e.toString());
      if(!mounted) return;
      errDialog(e.toString());
      if(!isForeground){
        isAutoNotification = true;
        notification.showNotification(title: "Error", body: "", showAvator: false);
      }
    }
  }

  String getTimeStr(int index) {
    int timeStamp = int.parse(historys[index][1]);
    DateTime t = DateTime.fromMillisecondsSinceEpoch(timeStamp);
    const weekday = ["", "一", "二", "三", "四", "五", "六", "日"];
    return "${t.year}年${t.month}月${t.day}日星期${weekday[t.weekday]}"
        "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu),
                color: Colors.white,
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
          title: const SizedBox(
              height: 22,
              child: Image(
                  image: AssetImage("assets/momotalk.webp"),
                  fit: BoxFit.scaleDown)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              color: Color(0xfff2a0ac)
            ),
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.refresh),
              color: Colors.white,
              onPressed: () {
                clearMsg();
              },
            ),
            IconButton(
              icon: const Icon(Icons.save),
              color: Colors.white,
              onPressed: () async {
                  String prompt = await getPrompt();
                  if(!context.mounted) return;
                  String? value = await namingHistory(context, "", config, studentName, parseMsg(prompt, messages));
                  if (value != null) {
                    debugPrint(value);
                    addHistory(msgListToJson(messages),value);
                    if(!context.mounted) return;
                    snackBarAlert(context, "已保存");
                    getHistorys().then((List<List<String>> results) {
                      setState(() {
                        historys = results;
                        historys.sort((a, b) => int.parse(b[1]).compareTo(int.parse(a[1])));
                      });
                    });
                  } else {
                    debugPrint("cancel");
                  }
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.edit,
                color: Colors.white,
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'Time',
                  child: Text('时间戳'),
                ),
                const PopupMenuItem(
                  value: 'System',
                  child: Text('系统消息'),
                ),
                const PopupMenuItem(
                  value: 'Msgs',
                  child: Text('编辑消息'),
                ),
              ],
              onSelected: (String value) async {
                if (value == 'Time') {
                  if(messages.isEmpty){
                    return;
                  }
                  if(messages.last.type != Message.timestamp){
                    setState(() {
                      messages.add(Message(message: DateTime.now().millisecondsSinceEpoch.toString(), type: Message.timestamp));
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setScrollPercent(1.0);
                    });
                  }
                } else if (value == 'System') {
                  systemPopup(context, "", (String edited,bool isSend){
                    setState(() {
                      if(edited.isNotEmpty){
                        messages.add(Message(message: edited, type: Message.system));
                        if(isSend){
                          sendMsg(true,forceSend: true);
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setScrollPercent(1.0);
                        });
                      }
                    });
                  });
                }else if (value == 'Msgs') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MsgEditor(msgs: messages)
                    )
                  ).then((msgs){setState(() {});});
                }
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Color(0xfff2a0ac),
                ),
                child: SizedBox(
                  height: 50, // Set fixed height
                  child: Text(
                    'MisonoTalk',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              // History button
              ExpansionTile(
                leading: const Icon(Icons.history),
                title: const Text('历史记录'),
                children: historys.map((history) {
                  int index = historys.indexOf(history);
                  return ListTile(
                    title: Text(getTimeStr(index)),
                    subtitle: Text(history[0]),
                    onTap: () {
                      loadHistory(history[2]);
                      Navigator.pop(context);
                    },
                    onLongPress: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('删除历史记录'),
                        content: const Text('你确定要删除这条历史记录吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              deleteHistory("history_${history[1]}");
                              setState(() {
                                historys.removeAt(index);
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
// Customize button
              ListTile(
                leading: const Icon(Icons.accessibility),
                title: const Text('角色设置'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PromptEditor(),
                    ),
                  );
                },
              ),
              // Backup button
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('备份设置'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WebdavPage(
                        currentMessages: msgListToJson(messages),
                        onRefresh: loadHistory,
                      ),
                    ),
                  );
                },
              ),
              // Settings button
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('模型设置'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConfigPage(updateFunc: updateConfig, currentConfig: config),
                    ),
                  );
                },
              ),
              // SdConfig button
              ListTile(
                leading: const Icon(Icons.draw),
                title: const Text('绘图配置'), 
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FutureBuilder(
                        future: getSdConfig(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          } else {
                            return SdConfigPage(sdConfig: snapshot.data!);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
              // About button
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('关于'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('关于 MisonoTalk'),
                      content: const Text('MisonoTalk 是一个基于Flutter的聊天应用，使用OpenAI的API进行对话生成。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        body: GestureDetector(
          onTap: () {
            fn.unfocus();
          },
          child: Column(
            children: [
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: SingleChildScrollView(
                          controller: scrollController,
                          child: ListView.builder(
                            itemCount: messages.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              if (index == 0) {
                                return Column(
                                  children: [
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onLongPressStart: (LongPressStartDetails details) {
                                        onMsgPressed(index, details);
                                      },
                                      child: ChatElement(
                                        message: message.message,
                                        type: message.type,
                                        stuName: studentName,
                                        avatar: avatar,
                                      )
                                    )
                                  ],
                                );
                              }
                              return GestureDetector(
                                onLongPressStart: (LongPressStartDetails details) {
                                  onMsgPressed(index, details);
                                  fn.unfocus();
                                },
                                child: ChatElement(
                                    message: message.message, 
                                    type: message.type,
                                    stuName: studentName,
                                    avatar: avatar,
                                  )
                                );
                            },
                          )))),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                child: Row(
                  children: [
                    // text input field
                    Expanded(
                        child: TextField(
                            focusNode: fn,
                            controller: textController,
                            // enabled: !inputLock,
                            onEditingComplete: (){
                              if(textController.text.isEmpty && userMsg.isNotEmpty){
                                sendMsg(true);
                              } else if(textController.text.isNotEmpty){
                                sendMsg(false);
                              }
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              fillColor: const Color(0xffff899e),
                              isCollapsed: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              hintText: inputLock ? '回复中' : '请输入您的消息...',
                            ))),
                    const SizedBox(width: 5),
                    // drawing button
                    IconButton(
                      onPressed: () => sdWorkflow(),
                      icon: const Icon(Icons.draw),
                      color: const Color(0xffff899e),
                    ),
                    const SizedBox(width: 5),
                    // send button
                    IconButton(
                      onPressed: () => sendMsg(true),
                      onLongPress: () async {
                        List<List<String>> msg = parseMsg(await getPrompt(), messages);
                        msg.add(["user", "system instruction:暂停角色扮演，根据上下文，以user的口吻用一句话回复$studentName。"]);
                        String result = "";
                        for (var m in msg) {
                          debugPrint("${m[0]}: ${m[1]}");
                        }
                        debugPrint("model: ${config.model}");
                        textController.text = "生成中...";
                        await completion(config, msg, (chunk) {
                          result += chunk;
                          textController.text = result;
                        }, () {
                          snackBarAlert(context, "完成");
                        }, (e) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Error"),
                              content: Text(e.toString()),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('确定'),
                                ),
                              ],
                            ),
                          );
                        });
                      },
                      icon: const Icon(Icons.send),
                      color: const Color(0xffff899e),
                    )
                  ],
                ),
              )
            ],
          ),
        ));
  }
}
