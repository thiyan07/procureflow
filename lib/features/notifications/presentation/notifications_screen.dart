import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/providers.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/utils/date_utils.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref){
    final authAsync = ref.watch(_authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: authAsync.when(
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,s)=> ErrorState(message: e.toString()),
        data: (user){
          if (user==null) return const EmptyState(title: 'No user', subtitle: 'Login first', icon: Icons.notifications_off);
          final notifs = ref.watch(_notifsProvider(user.id));
          return notifs.when(
            loading: ()=> const Center(child: CircularProgressIndicator()),
            error: (e,s)=> ErrorState(message: e.toString()),
            data: (list)=> list.isEmpty? const EmptyState(title: 'No notifications', subtitle: 'You are all caught up', icon: Icons.notifications_none)
              : ListView.separated(padding: const EdgeInsets.all(12), itemCount: list.length, separatorBuilder: (_,__)=> const SizedBox(height:8), itemBuilder: (c,i){
                final n = list[i];
                return AppCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)), child: Icon(_iconFor(n.type), color: const Color(0xFF2E7D32), size:20)),
                  const SizedBox(width:10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                    Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize:13)),
                    Text(n.body, style: const TextStyle(fontSize:12, color: Colors.black54)),
                    const SizedBox(height:4),
                    Text(AppDateUtils.timeAgo(n.createdAt), style: const TextStyle(fontSize:11, color: Colors.black45)),
                  ])),
                  if (!n.isRead) Container(width:8,height:8,decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle)),
                ]));
              }),
          );
        },
      ),
    );
  }
  IconData _iconFor(String t){
    if (t=='queue') return Icons.groups;
    if (t=='slot_confirmed') return Icons.check_circle;
    if (t=='payment') return Icons.payments;
    return Icons.notifications;
  }
}
final _authProvider = FutureProvider((ref)=> ref.watch(authRepositoryProvider).getCurrentUser());
final _notifsProvider = FutureProvider.family((ref, String fid) => ref.watch(notificationRepositoryProvider).getNotifications(fid));
