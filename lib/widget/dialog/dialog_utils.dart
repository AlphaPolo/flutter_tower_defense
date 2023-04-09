import 'package:flutter/material.dart';

Future<String?> showInputDialog(BuildContext context, {String? title, String? hint, String? initValue}) async {
  const localizations = DefaultMaterialLocalizations();
  final controller = TextEditingController();

  if(initValue != null) controller.text = initValue;

  final String? result = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: title == null ? null : const Text('請輸入名稱'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hint),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text), child: Text(localizations.okButtonLabel)),
            TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(localizations.cancelButtonLabel)),
          ],
        );
      });
  controller.dispose();
  return (result ?? '').isEmpty ? null : result;
}

void showLoadingDialog(BuildContext context) {
  AlertDialog alert = AlertDialog(
    content: Row(
      children: [
        const CircularProgressIndicator(),
        Container(
          margin: const EdgeInsets.only(left: 7),
          child: const Text("Loading..."),
        ),
      ],
    ),
  );
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
    routeSettings: const RouteSettings(name: 'loading'),
  );
}
