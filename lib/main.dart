import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
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
import 'formatconfig.dart';
import 'vitsconfig.dart';
import 'vits.dart';
import 'aidrawconfig.dart';

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
      title: 'MoeTalk',
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

class MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isListViewMode = true; // true for list view, false for single view
  int _singleViewIndex = 0;
  
  // Chat page variables
  final fn = FocusNode();
  final textController = TextEditingController();
  final scrollController = ScrollController();
  final notification = NotificationHelper();
  late String studentName;
  late String avatar;
  late String userName;
  late DecorationImage backgroundImage;
  Config config = Config(name: "", baseUrl: "", apiKey: "", model: "");
  String userMsg = "";
  bool inputLock = false;
  bool keyboardOn = false;
  bool isForeground = true;
  bool isAutoNotification = false;
  bool _isToolsExpanded = false;
  String? _characterStatus = "暂无状态";
  List<Message> messages = [];
  List<Message>? lastMessages;
  List<List<String>> historys = [];
  List<List<String>> students = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getUserName().then((name) {
      userName = name;
    });
    getStudentName().then((name){
        studentName = name;
      });
    getAvatar().then((avt){
      avatar = avt;
      backgroundImage = DecorationImage(
        image: (avatar.isNotEmpty && avatar.startsWith('http'))
            ? NetworkImage(avatar)
            : const AssetImage("assets/avatar.png") as ImageProvider,
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(
          Colors.white.withOpacity(0.8),
          BlendMode.dstATop,
        ),
      );
    });
    getOriginalMsg().then((originalMsg) {
      for(var m in originalMsg.split("\\")) {
        messages.add(Message(message: m, type: Message.assistant));
      }
      setState(() {
        _singleViewIndex = messages.isNotEmpty ? messages.length - 1 : 0;
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
    getStudents().then((List<List<String>> results) {
      setState(() {
        students = results;
        students.sort((a, b) => a[0].compareTo(b[0]));
      });
      if(results.isEmpty){
        rootBundle.loadString("assets/chara.json").then((string) {
          restoreFromJson(string);
        });
      }
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
    final bottom = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
    if(bottom>10 && !keyboardOn){
      debugPrint("keyboard on");
      keyboardOn = true;
      if(ModalRoute.of(context)?.isCurrent != true){
        return;
      }
    } else if(bottom<10 && keyboardOn){
      debugPrint("keyboard off");
      keyboardOn = false;
    }
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
          String var1="$studentName：",var2="$userName：";
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
        if(edited=="DELETE"){
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
      imagePopup(context, details, (int edited){
        if (edited == 0) {
          setState(() {
            backgroundImage = DecorationImage(
              image: NetworkImage(messages[index].message),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.white.withOpacity(0.8),
                BlendMode.dstATop,
              ),
            );
          });
        }
        if(edited==2){
          launchUrlString(messages[index].message);
        } 
        if(edited==1){
          setState(() {
            messages.removeAt(index);
          });
        }
      });
    }
  }

  void loadHistory(String msg) {
    List<Message> msgs = jsonToMsg(msg);
    setState(() {
      messages.clear();
      messages.addAll(msgs);
      _singleViewIndex = messages.isNotEmpty ? messages.length - 1 : 0;
      _isListViewMode = true; // Show list view when loading history
    });
  }

  void updateResponse(String response) {
    setState(() {
      response = response.replaceAll(RegExp(r'[\\]+'), r'\'); // make all \\ count as 1
      for(var m in response.split("\\")) {
        messages.add(Message(message: m, type: Message.assistant));
      }
    });
  }

  void clearMsg() {
    lastMessages = null;
    setState(() {
      messages.clear();
      getUserName().then((name) {
        userName = name;
      });
      getStudentName().then((name){
        studentName = name;
      });
      getAvatar().then((avt){
        avatar = avt;      
        setState(() {
          backgroundImage = DecorationImage(
            image: (avatar.isNotEmpty && avatar.startsWith('http'))
                ? NetworkImage(avatar)
                : const AssetImage("assets/avatar.png") as ImageProvider,
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.8),
              BlendMode.dstATop,
            ),
          );
        });
      });
      getOriginalMsg().then((originalMsg) {
        for(var m in originalMsg.split("\\")) {
          messages.add(Message(message: m, type: Message.assistant));
        }
        setState(() {
          _singleViewIndex = messages.isNotEmpty ? messages.length - 1 : 0;
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
            userMsg = textController.text;
            messages.add(Message(message: userMsg, type: Message.user));
          }
          textController.clear();
        });
        debugPrint(userMsg);
        setState(() {
          _singleViewIndex = messages.isNotEmpty ? messages.length - 1 : 0;
        });
        if(!realSend){return;}
      }
      userMsg = "";
    }
    setState(() {
      inputLock = true;
      debugPrint("inputLocked");
    });
    List<List<String>> msg = parseMsg(await getStartPrompt(), await getPrompt(), messages, await getEndPrompt());
    logMsg(msg);
    try {
      String response = "";
      await completion(config, msg, 
        (String resp) async {
          resp = resp.replaceAll(RegExp(r'[\n\\]+'), r'\');
          resp = randomizeBackslashes(resp);
          response += resp;
        }, () async {
          updateResponse(response.replaceAll(RegExp(await getResponseRegex()), ''));
          debugPrint("done.");
          setState(() {
            inputLock = false;
          });
          debugPrint("inputUnlocked");
          setTempHistory(msgListToJson(messages));
          lastMessages = null;
        }, (err){
          setState(() {
            inputLock = false;
          });
          debugPrint("inputUnlocked");
          errDialog(err.toString());
        });
    } catch (e) {
      setState(() {
        inputLock = false;
      });
      debugPrint("inputUnlocked");
      debugPrint(e.toString());
      if(!mounted) return;
      errDialog(e.toString());
    }
  }

  Future<void> getVoice() async {
    final TextEditingController controller = TextEditingController();
    List<List<String>> msg = parseMsg(await getStartPrompt(), await getPrompt(), messages, await getEndPrompt());
      msg.add(["user", "system instruction:暂停角色扮演，根据上下文，以$studentName的口吻用一句话回复$userName。"]);
      String result = "";
      for (var m in msg) {
        debugPrint("${m[0]}: ${m[1]}");
      }
      debugPrint("model: ${config.model}");
      controller.text = "生成中...";
      await completion(config, msg, (chunk) async {
        result += chunk;
        controller.text = result.replaceAll(RegExp(await getResponseRegex()), '');
      }, () async {
        debugPrint("done.");
      }, (e) {
        snackBarAlert(context, e.toString());
      });
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        title: const Text('创建语音'),
        content: TextField(
          maxLines: null,
          minLines: 1,
          controller: controller,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isEmpty) {
                snackBarAlert(context, "语音内容不能为空");
                return;
              }
              queryAndPlayAudio(context,controller.text).then((_) {
                // ignore: use_build_context_synchronously
                snackBarAlert(context, "语音创建成功");
              }).catchError((e) {
                // ignore: use_build_context_synchronously
                snackBarAlert(context, "语音创建失败: $e");
              });
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      );
    });
  }

  Future<void> getMsg() async {
    List<List<String>> msg = parseMsg(await getStartPrompt(), await getPrompt(), messages, await getEndPrompt());
    msg.add(["user", "system instruction:暂停角色扮演，根据上下文，以$userName的口吻用一句话回复$studentName。生成3个不同风格的候选回复，用||分隔。"]);
    
    String result = "";
    for (var m in msg) {
      debugPrint("${m[0]}: ${m[1]}");
    }
    debugPrint("model: ${config.model}");
    
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在生成候选回复'),
            ],
          ),
        );
      },
    );

    try {
      await completion(config, msg, (chunk) async {
        result += chunk;
      }, () async {
        debugPrint("done.");
        Navigator.of(context).pop(); // 关闭加载对话框
        
        // 解析生成的候选项
        List<String> candidates = result
            .replaceAll(RegExp(await getResponseRegex()), '')
            .split('||')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        
        if (candidates.isEmpty) {
          candidates = [result.replaceAll(RegExp(await getResponseRegex()), '').trim()];
        }
        
        // 显示候选项选择对话框
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('选择回复'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    return Card(
                      child: ListTile(
                        title: Text(
                          '选项 ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(candidates[index]),
                        onTap: () {
                          textController.text = candidates[index];
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    // 重新生成
                    Navigator.of(context).pop();
                    getMsg();
                  },
                  child: const Text('重新生成'),
                ),
              ],
            );
          },
        );
      }, (e) {
        Navigator.of(context).pop(); // 关闭加载对话框
        snackBarAlert(context, e.toString());
      });
    } catch (e) {
      Navigator.of(context).pop(); // 关闭加载对话框
      snackBarAlert(context, e.toString());
    }
  }

  Future<void> getDraw() async {
    List<List<String>> msg = parseMsg(await getStartPrompt(), await getPrompt(), messages, await getEndPrompt());
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiDraw(msg:msg, config: config)
      )
    ).then((imageUrl){
      if(imageUrl!=null){
        setState(() {
          backgroundImage = DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.8),
              BlendMode.dstATop,
            ),
          );
        });
        setState(() {
          messages.add(Message(message: imageUrl, type: Message.image));
        });
        setTempHistory(msgListToJson(messages));
      }
    });
  }

  void _showStatusDialog(){
    // 编辑器
    final controller = TextEditingController(text: _characterStatus);
    // 显示状态信息对话框
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$studentName的状态'),
            content: SingleChildScrollView(
            child: MarkdownBody(
              data: _characterStatus!,
            ),
          ),
          actions: [
            // 编辑按钮
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('编辑状态'),
                    content: TextField(
                      maxLines: null,
                      minLines: 1,
                      controller: controller,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          controller.clear();
                        },
                        child: const Text('清空'),
                      ),
                      TextButton(
                        onPressed: () {
                          if(controller.text.isNotEmpty){
                            setState(() {
                              _characterStatus = controller.text;
                            });
                          }
                          Navigator.of(context).pop();
                          _showStatusDialog();
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('编辑'),
            ),            
            // 重新查询
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                getStatus(forceGet: true);
              },
              child: const Text('查询'),
            ),
            // 关闭按钮
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('关闭'),
            ),
          ],
          
        );
      },
    );
  }

  Future<void> getStatus({bool forceGet=false}) async {
    if (forceGet || _characterStatus == null || _characterStatus == "暂无状态") {
      List<List<String>> msg = parseMsg(await getStartPrompt(), await getPrompt(), messages, await getEndPrompt());
      msg.add(["user", "system instruction:之前的状态是$_characterStatus。${await getStatusPrompt()}"]);
      
      String result = "";
      for (var m in msg) {
        debugPrint("${m[0]}: ${m[1]}");
      }
      debugPrint("model: ${config.model}");
      
      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在分析角色状态'),
              ],
            ),
          );
        },
      );

      try {
        await completion(config, msg, (chunk) async {
          result += chunk;
        }, () async {
          debugPrint("done.");
          Navigator.of(context).pop(); // 关闭加载对话框
          if (result.isNotEmpty) {
            String cleanResult = result.replaceAll(RegExp(await getResponseRegex()), '');
            _characterStatus = cleanResult;
          }
          _showStatusDialog();
        }, (e) {
          Navigator.of(context).pop(); // 关闭加载对话框
          snackBarAlert(context, "获取状态失败: $e");
        });
      } catch (e) {
        Navigator.of(context).pop(); // 关闭加载对话框
        snackBarAlert(context, "获取状态失败: $e");
      }
    }
    else{
      _showStatusDialog();
    }
  }

  String getTimeStr(int index) {
    int timeStamp = int.parse(historys[index][1]);
    DateTime t = DateTime.fromMillisecondsSinceEpoch(timeStamp);
    const weekday = ["", "一", "二", "三", "四", "五", "六", "日"];
    return "${t.year}年${t.month}月${t.day}日星期${weekday[t.weekday]}"
        "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
  }

Widget _buildChatPage() {
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox(
            height: 22,
            child: Image(
                image: AssetImage("assets/moetalk.png"),
                fit: BoxFit.fitHeight)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xfff2a0ac)
          ),
        ),
        actions: <Widget>[
          // Reset
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            onPressed: () {
              clearMsg();
              snackBarAlert(context, "已重置");
            },
          ),
          // Save
          IconButton(
            icon: const Icon(Icons.save),
            color: Colors.white,
            onPressed: () async {
                if(!context.mounted) return;
                String? value = await namingHistory(context, "", config, studentName, parseMsg(await getStartPrompt(), await getPrompt(), messages, await getEndPrompt()));
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
                }
              } else if (value == 'System') {
                systemPopup(context, "", (String edited,bool isSend){
                  setState(() {
                    if(edited.isNotEmpty){
                      messages.add(Message(message: edited, type: Message.system));
                      if(isSend){
                        sendMsg(true,forceSend: true);
                      }
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
      body: Container(
        decoration: BoxDecoration(
          image: backgroundImage
        ),
        child: GestureDetector(
          onTap: () {
            fn.unfocus();
            setState(() {
              _isToolsExpanded = false;
            });
          },
          child: Column(
            children: [
              Expanded(
                child: _isListViewMode
                    ? Container(
                        color: Colors.black.withOpacity(0.3),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          controller: scrollController,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isListViewMode = false;
                                  _singleViewIndex = index;
                                  if (messages[_singleViewIndex].type == Message.image) {
                                    _singleViewIndex = _singleViewIndex == messages.length - 1
                                        ? _singleViewIndex - 1
                                        : _singleViewIndex + 1;
                                  }
                                });
                              },
                              onLongPressStart: (details) {
                                onMsgPressed(index, details);
                                fn.unfocus();
                              },
                              child: ChatElement(
                                message: message.message,
                                type: message.type,
                                userName: userName,
                                stuName: studentName,
                              ),
                            );
                          },
                        ),
                      )
                    : (messages.isEmpty
                        ? const Align(alignment: Alignment.bottomCenter,child: Text("No messages"))
                        : GestureDetector(
                            onTap: () {
                              setState(() {
                                if (messages.isNotEmpty) {
                                  _singleViewIndex = _singleViewIndex == messages.length - 1
                                      ? _singleViewIndex
                                      : _singleViewIndex + 1;
                                  if (messages[_singleViewIndex].type == Message.image) {
                                    _singleViewIndex = _singleViewIndex == messages.length - 1
                                        ? _singleViewIndex - 1
                                        : _singleViewIndex + 1;
                                  }
                                }
                              });
                            },
                            onLongPress: () {
                              setState(() {
                                _isListViewMode = true;
                              });
                            },
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ChatElement(
                                    message: messages[_singleViewIndex].message,
                                    type: messages[_singleViewIndex].type,
                                    userName: userName,
                                    stuName: studentName,
                                  ),
                                ),
                              ),
                            ),
                          )),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Theme.of(context).colorScheme.surfaceBright,
                child: Row(
                  children: [
                    // text input field
                    Expanded(
                        child: TextField(
                            focusNode: fn,
                            controller: textController,
                            onEditingComplete: (){
                              if(textController.text.isEmpty && userMsg.isNotEmpty){
                                sendMsg(true);
                              } else if(textController.text.isNotEmpty){
                                sendMsg(false);
                              }
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              isCollapsed: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              hintText: inputLock ? '回复中' : '请输入您的消息...',
                            ))),
                    const SizedBox(width: 5),
                    // tools button
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isToolsExpanded = !_isToolsExpanded;
                        });
                      },
                      icon: const Icon(Icons.add_circle),
                      color: const Color(0xffff899e),
                    ),
                    const SizedBox(width: 5),
                    // send button
                    IconButton(
                      onPressed: () => sendMsg(true),
                      icon: const Icon(Icons.send),
                      color: const Color(0xffff899e),
                    )
                  ],
                ),
              ),
              // 工具栏展开区域
              if (_isToolsExpanded)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceBright,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildToolButton(
                        icon: Icons.monitor_heart,
                        label: '状态',
                        onTap: () {
                          getStatus();
                          setState(() {
                            _isToolsExpanded = false;
                          });
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.draw,
                        label: '绘图',
                        onTap: () {
                          getDraw();
                          setState(() {
                            _isToolsExpanded = false;
                          });
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.speaker,
                        label: '语音',
                        onTap: () {
                          getVoice();
                          setState(() {
                            _isToolsExpanded = false;
                          });
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.auto_awesome,
                        label: '提示',
                        onTap: () {
                          getMsg();
                          setState(() {
                            _isToolsExpanded = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xffff899e),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // 分离历史记录页面
  Widget _buildHistoryPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录', style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xfff2a0ac)
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: historys.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text(getTimeStr(index)),
                subtitle: Text(historys[index][0]),
                onTap: () {
                  loadHistory(historys[index][2]);
                  setState(() {
                    _currentIndex = 0; // Switch to chat page
                  });
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
                          deleteHistory("history_${historys[index][1]}");
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
              ),
            ),
          );
        },
      ),
    );
  }

  // 分离角色页面
  Widget _buildStudentsPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('角色列表', style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xfff2a0ac)
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          const ListTile(
            title: Text('当前角色', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: avatar.isNotEmpty && avatar.startsWith('http')
                        ? NetworkImage(avatar)
                        : const AssetImage("assets/avatar.png") as ImageProvider,
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                  ),
                ),
                child: ListTile(
                  title: Text(studentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    messages.isNotEmpty ? messages.first.message : "",
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PromptEditor(),
                        ),
                      ).then((_) {
                        getStudents().then((List<List<String>> results) {
                          setState(() {
                            students = results;
                            students.sort((a, b) => a[0].compareTo(b[0]));
                          });
                        });
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('角色池', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: students.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Card(
                  elevation: 2,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: students[index][1].isNotEmpty && students[index][1].startsWith('http')
                            ? NetworkImage(students[index][1])
                            : const AssetImage("assets/avatar.png") as ImageProvider,
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                      ),
                    ),
                    child: ListTile(
                      title: Text(students[index][0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        students[index][2],
                        style: const TextStyle(color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setStudentName(students[index][0]);
                        setAvatar(students[index][1]);
                        setOriginalMsg(students[index][2]);
                        setPrompt(students[index][3]);
                        clearMsg();
                        setState(() {
                          _currentIndex = 0; // Switch to chat page
                        });
                      },
                      onLongPress: () => showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('删除角色'),
                          content: const Text('你确定要删除这个角色吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () {
                                deleteStudent("student_${students[index][4]}_${students[index][0]}");
                                setState(() {
                                  students.removeAt(index);
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Settings page
  Widget _buildSettingsPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xfff2a0ac)
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            child: ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('备份配置'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WebdavPage(
                      currentMessages: msgListToJson(messages),
                      onRefresh: (String jsonString) {
                        setState(() {
                          messages.clear();
                          messages.addAll(jsonToMsg(jsonString));
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('模型配置'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConfigPage(updateFunc: updateConfig, currentConfig: config),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            child: ListTile(
              leading: const Icon(Icons.format_shapes),
              title: const Text('格式配置'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FormatConfigPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            child: ListTile(
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
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            child: ListTile(
              leading: const Icon(Icons.speaker),
              title: const Text('语音配置'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FutureBuilder(
                      future: getVitsConfig(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        } else {
                          return VitsConfigPage(vitsConfig: snapshot.data!);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            child: ListTile(
              leading: const Icon(Icons.info),
              title: const Text('关于'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('关于'),
                    content: const Text("""MoeTalk 是一个基于Flutter的开源聊天应用，使用大语言模型进行对话生成，使用扩散模型进行语音和图像合成。
                    
您的数据完全存储在您的设备上，本应用不会收集任何个人信息。
                    
代码地址：https://github.com/shinnpuru/MoeTalk"""),
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget currentPage;
    switch (_currentIndex) {
      case 0:
        currentPage = _buildChatPage();
        break;
      case 1:
        currentPage = _buildHistoryPage();
        break;
      case 2:
        currentPage = _buildStudentsPage();
        break;
      case 3:
        currentPage = _buildSettingsPage();
        break;
      default:
        currentPage = _buildChatPage();
    }

    return Scaffold(
      body: currentPage,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xfff2a0ac),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: '聊天',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '历史',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: '角色',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}