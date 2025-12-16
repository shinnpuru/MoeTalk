import 'package:flutter/material.dart';
import 'i18n.dart';

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
      PopupMenuItem(value: 0, child: Text(I18n.t('voice'))),
      PopupMenuItem(value: 1, child: Text(I18n.t('edit'))),
      PopupMenuItem(value: 2, child: Text(I18n.t('delete'))),
    ],
  ).then((value) {
    if (value == 1) {
      showDialog(context: context, builder: (context) {
        return AlertDialog(
          title: Text(I18n.t('edit')),
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
              child: Text(I18n.t('clear')),
            ),
            TextButton(
              onPressed: () {
                onEdited(controller.text);
                Navigator.of(context).pop();
              },
              child: Text(I18n.t('confirm')),
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
      PopupMenuItem(value: 1, child: Text(I18n.t('edit'))),
      PopupMenuItem(value: 2, child: Text(I18n.t('resend')))
    ],
  ).then((value) {
    if (value == 1) {
      showDialog(context: context, builder: (context) {
        return AlertDialog(
          title: Text(I18n.t('edit')),
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
              child: Text(I18n.t('clear')),
            ),
            TextButton(
              onPressed: () {
                onEdited(controller.text, false);
                Navigator.of(context).pop();
              },
              child: Text(I18n.t('confirm')),
            ),
            TextButton(
              onPressed: () {
                onEdited(controller.text, true);
                Navigator.of(context).pop();
              },
              child: Text(I18n.t('confirm_resend')),
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
      title: Text(I18n.t('edit_system_instruction')),
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
          child: Text(I18n.t('clear')),
        ),
        TextButton(
          onPressed: () {
            onEdited(controller.text,false);
            Navigator.of(context).pop();
          },
          child: Text(I18n.t('confirm')),
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
      PopupMenuItem(value: 1, child: Text(I18n.t('edit'))),
      PopupMenuItem(value: 2, child: Text(I18n.t('turn_to_system_instruction')))
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
      PopupMenuItem(value: 1, child: Text(I18n.t('remove'))),
      PopupMenuItem(value: 2, child: Text(I18n.t('save'))),
      PopupMenuItem(value: 0, child: Text(I18n.t('set_background')))
    ],
  ).then((value) {
    onEdited(value!);
  });
}
