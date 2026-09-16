import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage.dart';
import '../../../services/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState()=> _SettingsScreenState();
}
class _SettingsScreenState extends ConsumerState<SettingsScreen>{
  String _lang = 'en';
  @override
  void initState(){ super.initState(); _lang = LocalStorage.instance.languageCode; }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children:[
        Card(child: Column(children:[
          const ListTile(title: Text('Language', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('Change app language')),
          RadioListTile(value: 'en', groupValue: _lang, title: const Text('English'), onChanged: (v)=> _setLang(v!)),
          RadioListTile(value: 'hi', groupValue: _lang, title: const Text('Hindi - हिंदी'), onChanged: (v)=> _setLang(v!)),
          RadioListTile(value: 'ta', groupValue: _lang, title: const Text('Tamil - தமிழ்'), onChanged: (v)=> _setLang(v!)),
        ])),
        const SizedBox(height:12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          const Text('About ProcureFlow', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height:6),
          const Text('SIH26032 • Smart Procurement Centre Management\nPredict → Schedule → Track → Optimize', style: TextStyle(fontSize:12, color: Colors.black54)),
          const SizedBox(height:8),
          const Text('Architecture: Repository pattern with mock implementations. Replace Mock*Repository with Api*Repository when backend ready. No real Aadhaar/payment APIs in demo.', style: TextStyle(fontSize:11, color: Colors.black45)),
        ]))),
      ]),
    );
  }
  Future<void> _setLang(String code) async {
    setState(()=> _lang=code);
    await LocalStorage.instance.saveLanguage(code);
    ref.read(languageCodeProvider.notifier).state = code;
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Language set to $code. Restart may be needed.')));
  }
}
