import 'package:flutter/material.dart';
import 'utils.dart' show Message;

class MsgEditor extends StatefulWidget {
  final List<Message> msgs;
  const MsgEditor({super.key, required this.msgs});

  @override
  MsgEditorState createState() => MsgEditorState();
}

class MsgEditorState extends State<MsgEditor> {
  late List<bool> selected;
  int lastSwipe = -1;

  @override
  void initState() {
    selected = List.filled(widget.msgs.length, false, growable: true);
    super.initState();
  }

  String typeDesc(int type){
    switch(type){
      case Message.user: return "用户";
      case Message.assistant: return "角色";
      case Message.system: return "系统";
      case Message.timestamp: return "时间";
      case Message.image: return "图像";
      default: return "? ";
    }
  }

  Future<void> _editMessage(int index) async {
    final TextEditingController controller = TextEditingController(text: widget.msgs[index].message);
    final newMessage = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑消息'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(hintText: '消息内容'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, controller.text);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (newMessage != null && newMessage.isNotEmpty) {
      setState(() {
        widget.msgs[index].message = newMessage;
      });
    }
  }

  void _moveItem(int oldIndex, int newIndex) {
    setState(() {
      final Message item = widget.msgs.removeAt(oldIndex);
      widget.msgs.insert(newIndex, item);

      final bool selectedState = selected.removeAt(oldIndex);
      selected.insert(newIndex, selectedState);
    });
  }

  void _cycleType(int index) {
    setState(() {
      final msg = widget.msgs[index];
      if (msg.type == Message.user) {
        msg.type = Message.assistant;
      } else if (msg.type == Message.assistant) {
        msg.type = Message.system;
      } else if (msg.type == Message.system) {
        msg.type = Message.timestamp;
      } else {
        msg.type = Message.user;
      }
    });
  }

  void _addMessage() {
    setState(() {
      widget.msgs.add(Message(message: "",type: Message.system));
      selected.add(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息编辑器'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context, widget.msgs);
            }, 
            icon: const Icon(Icons.save),
          )
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  lastSwipe = -1;
                  setState(() {
                    selected.fillRange(0, selected.length, true);
                  });
                },
                child: const Text('全选'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  lastSwipe = -1;
                  setState(() {
                    selected.fillRange(0, selected.length, false);
                  });
                },
                child: const Text('全不选'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addMessage,
                child: const Text('添加'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    // Create a list of items to remove to avoid concurrent modification issues
                    final List<Message> toRemove = [];
                    for (int i = 0; i < selected.length; i++) {
                      if (selected[i]) {
                        toRemove.add(widget.msgs[i]);
                      }
                    }
                    widget.msgs.removeWhere((msg) => toRemove.contains(msg));
                    selected.removeWhere((isSelected) => isSelected);
                  });
                },
                child: const Text('删除'),
              ),
            ],
          )
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.msgs.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  key: ValueKey(widget.msgs[index]),
                  child: Card(
                    child: ListTile(
                      leading: InkWell(
                        onTap: () => _cycleType(index),
                        child: CircleAvatar(
                          child: Text(typeDesc(widget.msgs[index].type).trim()),
                        ),
                      ),
                      selected: selected[index],
                      title: Text(widget.msgs[index].message,maxLines: 2,overflow: TextOverflow.ellipsis,),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: index > 0 ? () => _moveItem(index, index - 1) : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward),
                            onPressed: index < widget.msgs.length - 1 ? () => _moveItem(index, index + 1) : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editMessage(index),
                          ),
                        ],
                      ),
                    ),
                  ),
                  onHorizontalDragEnd: (details) {
                    debugPrint(details.velocity.pixelsPerSecond.dx.toString());
                    if (details.velocity.pixelsPerSecond.dx != 0) {
                      if (lastSwipe != -1) {
                        if (lastSwipe != index) {
                          setState(() {
                            if (lastSwipe<index){
                              selected.fillRange(lastSwipe, index+1, true);
                            } else{
                              selected.fillRange(index, lastSwipe+1, true);
                            }
                          });
                          lastSwipe = -1;
                        }
                      }
                      lastSwipe = index;
                    }
                  },
                  onTap: () {
                    lastSwipe = index;
                    setState(() {
                      selected[index] = !selected[index];
                    });
                  },
                );
              },
            ),
          ),
        ]
      )
    );
  }
  
}