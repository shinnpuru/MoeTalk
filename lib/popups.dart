import 'package:flutter/material.dart';

void assistantPopup(BuildContext context, String msg, LongPressStartDetails details,
                    String stuName, Function(String) onEdited) {
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
    Offset.zero & overlay.size,
  );
  TextEditingController controller = TextEditingController(text: msg);
  msg = msg.replaceAll(":", "：");
  showMenu(
    context: context,
    position: position,
    items: [
      const PopupMenuItem(value: 0, child: Text('语音')),
      const PopupMenuItem(value: 1, child: Text('编辑')),
      const PopupMenuItem(value: 2, child: Text('删除')),
    ],
  ).then((value) {
    if (value == 1) {
      showDialog(context: context, builder: (context) {
        return AlertDialog(
          title: const Text('编辑'),
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
                onEdited(controller.text);
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            )
          ],
        );
      });
    } else if (value == 2) {
      onEdited("DELETE");
    } else if (value == 0) {
      onEdited("VOICE");
    }
  });
}

void userPopup(BuildContext context, String msg, LongPressStartDetails details, Function(String,bool) onEdited) {
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
    Offset.zero & overlay.size,
  );
  TextEditingController controller = TextEditingController(text: msg);
  showMenu(
    context: context,
    position: position,
    items: [
      const PopupMenuItem(value: 1, child: Text('编辑')),
      const PopupMenuItem(value: 2, child: Text('重发'))
    ],
  ).then((value) {
    if (value == 1) {
      showDialog(context: context, builder: (context) {
        return AlertDialog(
          title: const Text('编辑'),
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
                onEdited(controller.text, false);
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
            TextButton(
              onPressed: () {
                onEdited(controller.text, true);
                Navigator.of(context).pop();
              },
              child: const Text('确定并重发'),
            )
          ],
        );
      });
    } else if (value == 2) {
      onEdited(msg, true);
    }
  });
}

void systemPopup(BuildContext context, String msg, Function(String,bool) onEdited) {
  TextEditingController controller = TextEditingController(text: msg);
  showDialog(context: context, builder: (context) {
    return AlertDialog(
      title: const Text('编辑系统指令'),
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
            onEdited(controller.text,false);
            Navigator.of(context).pop();
          },
          child: const Text('确定'),
        ),
      ],
    );
  });
}

// bool: true for transfer to system instruction, false for not
void timePopup(BuildContext context, int oldTime, LongPressStartDetails details, Function(bool,DateTime?) onEdited) {
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
    Offset.zero & overlay.size,
  );
  showMenu(
    context: context,
    position: position,
    items: [
      const PopupMenuItem(value: 1, child: Text('编辑')),
      const PopupMenuItem(value: 2, child: Text('转为系统指令'))
    ],
  ).then((value) {
    if (value == 1) {
      showDatePicker(
        context: context,
        initialDate: DateTime.fromMillisecondsSinceEpoch(oldTime),
        firstDate: DateTime(2021),
        lastDate: DateTime(2099),
      ).then((date) {
        if (date != null) {
          showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(oldTime)),
          ).then((time) {
            if (time != null) {
              DateTime newTime = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              onEdited(false, newTime);
            }
          });
        }
      });
    } else if (value == 2) {
      onEdited(true, null);
    }
  });
}

void imagePopup(BuildContext context, LongPressStartDetails details, Function(int) onEdited) {
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
    Offset.zero & overlay.size,
  );
  showMenu(
    context: context,
    position: position,
    items: [
      const PopupMenuItem(value: 1, child: Text('移除')),
      const PopupMenuItem(value: 2, child: Text('保存')),
      const PopupMenuItem(value: 0, child: Text('设为背景'))
    ],
  ).then((value) {
    onEdited(value!);
  });
}
