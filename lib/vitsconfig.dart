import 'package:flutter/material.dart';
import 'storage.dart';
import 'utils.dart';
import 'i18n.dart';

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
        title: Text(I18n.t('voice_config')),
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
            ListTile(
              title: Text(I18n.t('base_config'),
                  style: const TextStyle(
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
                    decoration: InputDecoration(labelText: I18n.t('api_url')),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ]
              )
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(I18n.t('emotion_params'),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child:  Column(
                children: [
                  _buildSlider(I18n.t('happy'), _happy, (val) => setState(() => _happy = val)),
                  _buildSlider(I18n.t('sad'), _sad, (val) => setState(() => _sad = val)),
                  _buildSlider(I18n.t('angry'), _angry, (val) => setState(() => _angry = val)),
                  _buildSlider(I18n.t('afraid'), _afraid, (val) => setState(() => _afraid = val)),
                  _buildSlider(I18n.t('disgusted'), _disgusted, (val) => setState(() => _disgusted = val)),
                  _buildSlider(I18n.t('melancholic'), _melancholic, (val) => setState(() => _melancholic = val)),
                  _buildSlider(I18n.t('surprised'), _surprised, (val) => setState(() => _surprised = val)),
                  _buildSlider(I18n.t('calm'), _calm, (val) => setState(() => _calm = val)),
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