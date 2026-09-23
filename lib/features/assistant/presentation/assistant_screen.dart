import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/booking.dart';
import '../../../models/payment.dart';
import '../../../core/storage/local_storage.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});
  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _ctrl = TextEditingController();
  final List<ChatMsg> _msgs = [
    ChatMsg(isUser: false, text: 'Namaste! I am your ProcureFlow assistant. Ask me:\n• Where is my token?\n• When should I reach?\n• Payment status?\n\nTry in English, Hindi or Tamil.'),
  ];
  bool _loading = false;

  @override
  void dispose(){ _ctrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(()=> _msgs.add(ChatMsg(isUser: true, text: q)));
    _ctrl.clear();
    setState(()=> _loading=true);
    try{
      final auth = await ref.read(authRepositoryProvider).getCurrentUser();
      Booking? booking;
      QueueState? queue;
      Payment? payment;
      if (auth!=null){
        booking = await ref.read(slotRepositoryProvider).getActiveBooking(auth.id);
        if (booking!=null){
          queue = await ref.read(queueRepositoryProvider).getQueueStatus(booking.id);
          try{ payment = await ref.read(paymentRepositoryProvider).getPayment(booking.id);}catch(_){}
        }
      }
      final lang = LocalStorage.instance.languageCode;
      final ans = await ref.read(aiRepositoryProvider).answerAssistant(q, languageCode: lang, activeBooking: booking, queueState: queue, payment: payment);
      setState(()=> _msgs.add(ChatMsg(isUser: false, text: ans)));
    }catch(e){
      setState(()=> _msgs.add(ChatMsg(isUser: false, text: 'Sorry, I could not answer. Try: Where is my token?')));
    }finally{ setState(()=> _loading=false); }
  }

  @override
  Widget build(BuildContext context){
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.assistant)),
      body: Column(children:[
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _msgs.length, itemBuilder: (c,i){
          final m = _msgs[i];
          return Align(
            alignment: m.isUser? Alignment.centerRight: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical:4),
              padding: const EdgeInsets.all(12),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width*0.78),
              decoration: BoxDecoration(color: m.isUser? const Color(0xFF2E7D32): Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E5DE))),
              child: Text(m.text, style: TextStyle(color: m.isUser? Colors.white: Colors.black87, fontSize:13)),
            ),
          );
        })),
        if (_loading) const LinearProgressIndicator(),
        Padding(padding: const EdgeInsets.all(12), child: Row(children:[
          Expanded(child: TextField(controller: _ctrl, decoration: InputDecoration(hintText: loc.howCanIHelp, suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: _send)), onSubmitted: (_)=> _send())),
          const SizedBox(width:8),
          FloatingActionButton.small(onPressed: _send, child: const Icon(Icons.send)),
        ])),
        Padding(padding: const EdgeInsets.only(bottom:8), child: Wrap(spacing:6, children:[
          _Chip('Where is my token?', _ctrl),
          _Chip('When should I reach?', _ctrl),
          _Chip('Payment status?', _ctrl),
          _Chip('मेरा टोकन क्या है?', _ctrl),
          _Chip('என்னோட டோக்கன் எத்தனை?', _ctrl),
        ])),
      ]),
    );
  }
}

class _Chip extends StatelessWidget{
  final String label; final TextEditingController ctrl;
  const _Chip(this.label, this.ctrl);
  @override
  Widget build(BuildContext context)=> ActionChip(label: Text(label, style: const TextStyle(fontSize:11)), onPressed: ()=> ctrl.text=label);
}
class ChatMsg{ final bool isUser; final String text; ChatMsg({required this.isUser, required this.text});}
