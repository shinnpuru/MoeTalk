import 'package:flutter/material.dart';
import 'storage.dart';
import 'utils.dart';

class VitsConfigPage extends StatefulWidget {
  final VitsConfig vitsConfig;

  const VitsConfigPage({super.key, required this.vitsConfig});

  @override
  State<VitsConfigPage> createState() => _VitsConfigPageState();
}

class _VitsConfigPageState extends State<VitsConfigPage> {
  late TextEditingController _apiController;
  late double _happy;
  late double _sad;
  late double _angry;
  late double _afraid;
  late double _disgusted;
  late double _melancholic;
  late double _surprised;
  late double _calm;

  @override
  void initState() {
    super.initState();
    _apiController = TextEditingController();
    getVitsUrl().then((value) {
      if (mounted) {
        _apiController.text = value ?? '';
      }
    });

    final vitsConfig = widget.vitsConfig;
    _happy = vitsConfig.happy ?? 0.0;
    _sad = vitsConfig.sad ?? 0.0;
    _angry = vitsConfig.angry ?? 0.0;
    _afraid = vitsConfig.afraid ?? 0.0;
    _disgusted = vitsConfig.disgusted ?? 0.0;
    _melancholic = vitsConfig.melancholic ?? 0.0;
    _surprised = vitsConfig.surprised ?? 0.0;
    _calm = vitsConfig.calm ?? 0.0;
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语音配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              VitsConfig updatedConfig = VitsConfig(
                happy: _happy,
                sad: _sad,
                angry: _angry,
                afraid: _afraid,
                disgusted: _disgusted,
                melancholic: _melancholic,
                surprised: _surprised,
                calm: _calm,
              );
              setVitsConfig(updatedConfig);
              setVitsUrl(_apiController.text);
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const ListTile(
              title: Text("基础配置",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child:  Column(
                children: [
                  TextField(
                    controller: _apiController,
                    decoration: const InputDecoration(labelText: "API地址"),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ]
              )
            ),
            const SizedBox(height: 16),
            const ListTile(
              title: Text("情感参数",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child:  Column(
                children: [
                  _buildSlider("快乐", _happy, (val) => setState(() => _happy = val)),
                  _buildSlider("悲伤", _sad, (val) => setState(() => _sad = val)),
                  _buildSlider("愤怒", _angry, (val) => setState(() => _angry = val)),
                  _buildSlider("恐惧", _afraid, (val) => setState(() => _afraid = val)),
                  _buildSlider("厌恶", _disgusted, (val) => setState(() => _disgusted = val)),
                  _buildSlider("忧郁", _melancholic, (val) => setState(() => _melancholic = val)),
                  _buildSlider("惊讶", _surprised, (val) => setState(() => _surprised = val)),
                  _buildSlider("平静", _calm, (val) => setState(() => _calm = val)),
                ]
              )
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
      String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 50, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 40, child: Text(value.toStringAsFixed(1))),
      ],
    );
  }
}