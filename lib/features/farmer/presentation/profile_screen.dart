import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref){
    return FutureBuilder(
      future: ref.read(authRepositoryProvider).getCurrentUser(),
      builder: (context, snap){
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final user = snap.data!;
        final f = user.farmer;
        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(padding: const EdgeInsets.all(16), children:[
            AppCard(child: Row(children:[
              const CircleAvatar(radius:28, backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.person, color: Color(0xFF2E7D32), size:32)),
              const SizedBox(width:12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                Text(f?.fullName ?? user.mobile, style: const TextStyle(fontWeight: FontWeight.w700, fontSize:16)),
                Text(f?.farmerId ?? user.role, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize:12)),
                Text(user.mobile, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize:12)),
              ])),
            ])),
            const SizedBox(height:12),
            if (f!=null) AppCard(child: Column(children:[
              _Row(label: 'Village', value: f.village),
              const Divider(height:16),
              _Row(label: 'District', value: f.district),
              const Divider(height:16),
              _Row(label: 'Language', value: f.languageCode),
              const Divider(height:16),
              _Row(label: 'Commodity', value: f.primaryCommodity),
            ])),
            const SizedBox(height:12),
            AppCard(child: Column(children:[
              ListTile(leading: const Icon(Icons.settings), title: const Text('Settings'), trailing: const Icon(Icons.chevron_right), onTap: ()=> context.push('/settings')),
              const Divider(height:1),
              ListTile(leading: const Icon(Icons.store), title: const Text('Centres'), trailing: const Icon(Icons.chevron_right), onTap: ()=> context.push('/centres')),
              const Divider(height:1),
              ListTile(leading: const Icon(Icons.assistant), title: const Text('Assistant'), trailing: const Icon(Icons.chevron_right), onTap: ()=> context.push('/assistant')),
            ])),
            const SizedBox(height:16),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), icon: const Icon(Icons.logout), label: const Text('Logout'), onPressed: () async { await ref.read(authRepositoryProvider).logout(); if(context.mounted) context.go('/login'); }),
          ]),
        );
      },
    );
  }
}
class _Row extends StatelessWidget{ final String label; final String value; const _Row({required this.label, required this.value}); @override Widget build(BuildContext context)=> Row(children:[SizedBox(width:100, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize:12))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)))]); }
