import 'package:flutter/material.dart';
import 'utils.dart' show Message;
import 'i18n.dart';

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
      case Message.user: return I18n.t('user');
      case Message.assistant: return I18n.t('assistant');
      case Message.system: return I18n.t('system');
      case Message.timestamp: return I18n.t('time');
      case Message.image: return I18n.t('image');
      default: return "${I18n.t('unknown')} ";
    }
  }

  Future<void> _editMessage(int index) async {
    final TextEditingController controller = TextEditingController(text: widget.msgs[index].message);
    final newMessage = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(I18n.t('msg_editor')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: InputDecoration(hintText: I18n.t('msg_content')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(I18n.t('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, controller.text);
            },
            child: Text(I18n.t('save')),
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
        title: Text(I18n.t('msg_editor')),
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
                child: Text(I18n.t('select_all')),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  lastSwipe = -1;
                  setState(() {
                    selected.fillRange(0, selected.length, false);
                  });
                },
                child: Text(I18n.t('deselect_all')),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addMessage,
                child: Text(I18n.t('add')),
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
                child: Text(I18n.t('delete')),
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