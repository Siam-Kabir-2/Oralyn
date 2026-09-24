import 'package:flutter/material.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/api_settings_service.dart';
import '../../widgets/common/app_components.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _settings = ApiSettingsService();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final predictionUrl = await _settings.getPredictionUrl();
    if (!mounted) return;
    _controller.text = predictionUrl;
    setState(() => _loading = false);
  }

  String? _validate(String? value) {
    try {
      ApiSettingsService.normalizePredictionUrl(value ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final savedUrl = await _settings.savePredictionUrl(_controller.text);
      if (!mounted) return;
      _controller.text = savedUrl;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screening server URL updated.')),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The server URL could not be saved. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    await _settings.resetPredictionUrl();
    if (!mounted) return;
    setState(() => _controller.text = ApiConfig.predictionUri.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Default server URL restored.')),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Screening Server')),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                    children: [
                      const AppHeader(
                        title: 'Update the API URL',
                        subtitle:
                            'Paste the new Cloudflare URL here whenever your Quick Tunnel changes.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _controller,
                        validator: _validate,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Prediction endpoint URL',
                          hintText: 'https://example.trycloudflare.com/predict',
                          prefixIcon: Icon(Icons.cloud_outlined),
                        ),
                        onFieldSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2F6),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.blue,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Paste the tunnel base URL or the full endpoint. Oralyn uses /predict and automatically corrects Swagger links containing /docs or /docs/predict.',
                                style: TextStyle(fontSize: 13, height: 1.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Save Server URL',
                        onPressed: _save,
                        loading: _saving,
                        icon: Icons.save_outlined,
                      ),
                      const SizedBox(height: 10),
                      SecondaryButton(
                        label: 'Restore Default URL',
                        onPressed: _saving ? null : _reset,
                        icon: Icons.restore_rounded,
                      ),
                    ],
                  ),
                ),
        ),
      );
}
