import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../services/providers.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});
  @override
  ConsumerState<FeedbackScreen> createState()=> _FeedbackScreenState();
}
class _FeedbackScreenState extends ConsumerState<FeedbackScreen>{
  String _cat='delay';
  final _ctrl=TextEditingController();
  bool _sending=false;
  List<Map<String,dynamic>> _list=[];
  @override
  void initState(){ super.initState(); _load(); }
  Future<void> _load() async{
    try{
      final c = ref.read(apiClientProvider);
      final list = await c.getList('/api/v1/feedback');
      setState(()=> _list = list.cast<Map<String,dynamic>>());
    }catch(_){}
  }
  Future<void> _send() async{
    if(_ctrl.text.trim().length<5){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Description too short'))); return; }
    setState(()=> _sending=true);
    try{
      final c = ref.read(apiClientProvider);
      await c.post('/api/v1/feedback', body: {'category':_cat,'description':_ctrl.text.trim()});
      _ctrl.clear();
      await _load();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback submitted'))); 
    }catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally{ if(mounted) setState(()=> _sending=false); }
  }
  @override
  Widget build(BuildContext context)=> Scaffold(
    appBar: AppBar(title: const Text('Feedback / Grievance')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<String>(value:_cat, decoration: const InputDecoration(labelText: 'Category'), items: const [DropdownMenuItem(value:'delay',child: Text('Delay')), DropdownMenuItem(value:'quality',child: Text('Quality')), DropdownMenuItem(value:'payment',child: Text('Payment')), DropdownMenuItem(value:'other',child: Text('Other'))], onChanged: (v)=> setState(()=> _cat=v!)),
      const SizedBox(height:12),
      TextField(controller:_ctrl, maxLines:4, decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe issue…', border: OutlineInputBorder())),
      const SizedBox(height:12),
      FilledButton.icon(onPressed: _sending?null:_send, icon: _sending? const SizedBox(width:16,height:16,child: CircularProgressIndicator(strokeWidth:2)): const Icon(Icons.send), label: const Text('Submit')),
      const SizedBox(height:20),
      const Text('My feedback', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height:8),
      ..._list.map((m)=> Card(child: ListTile(title: Text(m['category']??''), subtitle: Text(m['description']??''), trailing: Text(m['status']??'', style: const TextStyle(fontSize:11))))),
      if(_list.isEmpty) const Text('No feedback yet', style: TextStyle(color: Colors.black45, fontSize:12)),
    ]),
  );
}
