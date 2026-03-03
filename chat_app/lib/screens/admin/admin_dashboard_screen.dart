import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:jhol_jhal_chat/api_services/services.dart';
import 'package:jhol_jhal_chat/services/user_presence_service.dart';
import 'package:jhol_jhal_chat/theme/jj_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'jholjhalchatdb',
  );
  final Services _services = Services();
  static const String _bubblesCollection = 'bubbles';
  late final TabController _tabController;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    UserPresenceService.markOnline(uid);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JjTheme.deep,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [TextButton(onPressed: _logout, child: const Text('Logout'))],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Approvals'),
            Tab(text: 'Users'),
            Tab(text: 'Online'),
            Tab(text: 'Bubbles'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildStatsStrip(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildApprovalsTab(),
                    _buildAllUsersTab(),
                    _buildOnlineUsersTab(),
                    _buildBubblesTab(),
                  ],
                ),
              ),
            ],
          ),
          if (_isUpdating)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x55000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsStrip() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        int pendingCount = 0;
        int onlineCount = 0;
        int approvedCount = 0;
        for (final doc in docs) {
          final data = doc.data();
          if (data['isAdmin'] == true) {
            continue;
          }
          if (data['isOnline'] == true) {
            onlineCount++;
          }
          if (data['chatApproved'] == true) {
            approvedCount++;
          } else {
            pendingCount++;
          }
        }

        return Container(
          color: JjTheme.deep,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: _statCard(
                  'Pending',
                  '$pendingCount',
                  const Color(0xFFE74C3C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard('Approved', '$approvedCount', JjTheme.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  'Online',
                  '$onlineCount',
                  const Color(0xFF2ECC71),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: JjTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: JjTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: JjTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('users')
          .where('chatApproved', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = (snapshot.data?.docs ?? const [])
            .where((doc) => doc.data()['isAdmin'] != true)
            .toList();
        if (docs.isEmpty) {
          return const Center(child: Text('No pending approvals'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          itemCount: docs.length,
          separatorBuilder: (_, separatorIndex) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final name = (data['displayName'] ?? '').toString().trim();
            final email = (data['email'] ?? '').toString().trim();
            return Container(
              decoration: BoxDecoration(
                color: JjTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: JjTheme.border),
              ),
              child: ListTile(
                title: Text(name.isNotEmpty ? name : doc.id),
                subtitle: Text(email.isNotEmpty ? email : 'No email'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () =>
                          _updateApproval(doc.id, approve: false, data: data),
                      child: const Text('Reject'),
                    ),
                    FilledButton(
                      onPressed: () => _approveWithBubble(doc.id, data),
                      child: const Text('Approve'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAllUsersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          itemCount: docs.length,
          separatorBuilder: (_, separatorIndex) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final isAdmin = data['isAdmin'] == true;
            final approved = data['chatApproved'] == true;
            final isOnline = data['isOnline'] == true;
            final name = (data['displayName'] ?? '').toString().trim();
            final email = (data['email'] ?? '').toString().trim();
            final bubbleIds = _extractBubbleIds(data);
            final bubbleLabel = bubbleIds.isEmpty ? '' : bubbleIds.join(', ');
            final status = isAdmin
                ? 'admin'
                : approved
                ? 'approved'
                : 'pending';
            return Container(
              decoration: BoxDecoration(
                color: JjTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: JjTheme.border),
              ),
              child: ListTile(
                title: Text(name.isNotEmpty ? name : docs[index].id),
                subtitle: Text(
                  '${email.isNotEmpty ? email : docs[index].id}'
                  '${bubbleLabel.isNotEmpty ? '\nBubbles: $bubbleLabel' : ''}',
                ),
                isThreeLine: bubbleLabel.isNotEmpty,
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!isAdmin)
                      TextButton(
                        onPressed: () =>
                            _setBubbleForUser(docs[index].id, data),
                        child: const Text('Manage bubbles'),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0x1A2ECC71)
                            : const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: JjTheme.border),
                      ),
                      child: Text(
                        '${isOnline ? 'online' : 'offline'} | $status',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBubblesTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection(_bubblesCollection).snapshots(),
      builder: (context, bubblesSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('users').snapshots(),
          builder: (context, usersSnapshot) {
            if (bubblesSnapshot.connectionState == ConnectionState.waiting ||
                usersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final users = usersSnapshot.data?.docs ?? const [];
            final bubbleDocs = bubblesSnapshot.data?.docs ?? const [];

            final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
            grouped = {};
            for (final bubbleDoc in bubbleDocs) {
              grouped.putIfAbsent(bubbleDoc.id.trim(), () => []);
            }
            grouped.putIfAbsent('unassigned', () => []);

            for (final userDoc in users) {
              final userData = userDoc.data();
              if (userData['isAdmin'] == true) {
                continue;
              }
              final bubbleIds = _extractBubbleIds(userData);
              if (bubbleIds.isEmpty) {
                grouped.putIfAbsent('unassigned', () => []);
                grouped['unassigned']!.add(userDoc);
                continue;
              }
              for (final bubbleId in bubbleIds) {
                grouped.putIfAbsent(bubbleId, () => []);
                grouped[bubbleId]!.add(userDoc);
              }
            }

            final keys = grouped.keys.toList()..sort();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Manage bubbles and assign users to multiple bubbles',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _createBubble,
                        icon: const Icon(Icons.add),
                        label: const Text('Create bubble'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount: keys.length,
                    separatorBuilder: (_, separatorIndex) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final bubbleId = keys[index];
                      final members = grouped[bubbleId]!;
                      return Container(
                        decoration: BoxDecoration(
                          color: JjTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: JjTheme.border),
                        ),
                        child: ExpansionTile(
                          title: Text('Bubble: $bubbleId'),
                          subtitle: Text('${members.length} member(s)'),
                          trailing: bubbleId == 'unassigned'
                              ? null
                              : IconButton(
                                  tooltip: 'Rename bubble',
                                  onPressed: () => _renameBubble(bubbleId),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          children: members.map((doc) {
                            final data = doc.data();
                            final name = (data['displayName'] ?? '')
                                .toString()
                                .trim();
                            final email = (data['email'] ?? '')
                                .toString()
                                .trim();
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(name.isNotEmpty ? name : doc.id),
                              subtitle: Text(email.isNotEmpty ? email : doc.id),
                              trailing: TextButton(
                                onPressed: () =>
                                    _setBubbleForUser(doc.id, data),
                                child: const Text('Manage'),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOnlineUsersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('users')
          .where('isOnline', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Center(child: Text('No users are online'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          itemCount: docs.length,
          separatorBuilder: (_, separatorIndex) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final name = (data['displayName'] ?? '').toString().trim();
            final email = (data['email'] ?? '').toString().trim();
            return Container(
              decoration: BoxDecoration(
                color: JjTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: JjTheme.border),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.circle,
                  color: Colors.green,
                  size: 14,
                ),
                title: Text(name.isNotEmpty ? name : docs[index].id),
                subtitle: Text(email.isNotEmpty ? email : docs[index].id),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateApproval(
    String userRef, {
    required bool approve,
    required Map<String, dynamic> data,
    String bubbleId = '',
  }) async {
    setState(() => _isUpdating = true);
    try {
      final previousBubbleIds = _extractBubbleIds(data);
      final nextBubbleIds = approve
          ? _normalizeBubbleIds([bubbleId])
          : <String>[];
      final nextPrimaryBubbleId = nextBubbleIds.isEmpty
          ? ''
          : nextBubbleIds.first;
      for (final id in nextBubbleIds) {
        await _ensureBubbleExists(id);
      }
      await _firestore.collection('users').doc(userRef).set({
        'chatApproved': approve,
        'verificationStatus': approve ? 'approved' : 'rejected',
        'bubbleId': nextPrimaryBubbleId,
        'bubbleIds': nextBubbleIds,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final previousSet = previousBubbleIds.toSet();
      final nextSet = nextBubbleIds.toSet();
      for (final removedId in previousSet.difference(nextSet)) {
        await _removeMemberFromBubble(removedId, userRef);
      }
      for (final addedId in nextSet.difference(previousSet)) {
        await _addMemberToBubble(addedId, userRef);
      }

      await _services.api.sendMessagePush(
        recipientRef: userRef,
        senderRef: FirebaseAuth.instance.currentUser?.uid ?? 'admin',
        conversationId: 'admin_approval',
        messageId:
            'approval_result_${DateTime.now().millisecondsSinceEpoch}_$userRef',
        title: approve ? 'Account approved' : 'Account verification update',
        body: approve
            ? 'Your account is now verified. You can use chat.'
            : 'Your account is not approved yet. Contact support.',
        data: {
          'type': 'approval_result',
          'status': approve ? 'approved' : 'rejected',
          'user_ref': userRef,
          'user_email': (data['email'] ?? '').toString(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update user status: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _approveWithBubble(
    String userRef,
    Map<String, dynamic> data,
  ) async {
    final selectedBubble = await _askBubbleId(
      currentValue: _extractBubbleIds(data).isEmpty
          ? ''
          : _extractBubbleIds(data).first,
    );
    if (!mounted || selectedBubble == null) return;
    await _updateApproval(
      userRef,
      approve: true,
      data: data,
      bubbleId: selectedBubble,
    );
  }

  Future<String?> _askBubbleId({String currentValue = ''}) async {
    final existingBubbleIds = await _loadBubbleIds();
    if (!mounted) return null;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _BubblePickerDialog(
        existingBubbleIds: existingBubbleIds,
        initialValue: currentValue,
      ),
    );
    return result;
  }

  Future<void> _setBubbleForUser(
    String userRef,
    Map<String, dynamic> data,
  ) async {
    final existingBubbleIds = await _loadBubbleIds();
    if (!mounted) return;
    final currentBubbles = _extractBubbleIds(data);
    final nextBubbles = await showDialog<List<String>>(
      context: context,
      builder: (_) => _BubbleMultiPickerDialog(
        existingBubbleIds: existingBubbleIds,
        initialSelectedIds: currentBubbles,
      ),
    );
    if (!mounted || nextBubbles == null) return;
    final normalizedNextBubbles = _normalizeBubbleIds(nextBubbles);
    if (_sameBubbleSets(currentBubbles, normalizedNextBubbles)) return;

    setState(() => _isUpdating = true);
    try {
      for (final bubbleId in normalizedNextBubbles) {
        await _ensureBubbleExists(bubbleId);
      }
      await _firestore.collection('users').doc(userRef).set({
        'bubbleId': normalizedNextBubbles.isEmpty
            ? ''
            : normalizedNextBubbles.first,
        'bubbleIds': normalizedNextBubbles,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final currentSet = currentBubbles.toSet();
      final nextSet = normalizedNextBubbles.toSet();
      for (final removedId in currentSet.difference(nextSet)) {
        await _removeMemberFromBubble(removedId, userRef);
      }
      for (final addedId in nextSet.difference(currentSet)) {
        await _addMemberToBubble(addedId, userRef);
      }

      if (data['chatApproved'] == true) {
        final body = normalizedNextBubbles.isEmpty
            ? 'Your chat bubbles were cleared.'
            : 'Your chat bubbles are now "${normalizedNextBubbles.join(', ')}"';
        await _services.api.sendMessagePush(
          recipientRef: userRef,
          senderRef: FirebaseAuth.instance.currentUser?.uid ?? 'admin',
          conversationId: 'admin_approval',
          messageId:
              'bubble_change_${DateTime.now().millisecondsSinceEpoch}_$userRef',
          title: 'Bubbles updated',
          body: body,
          data: {
            'type': 'bubble_change',
            'bubble_ids': normalizedNextBubbles.join(','),
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update bubble: $e')));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _createBubble() async {
    final bubbleId = await _askBubbleId();
    if (!mounted || bubbleId == null) return;
    setState(() => _isUpdating = true);
    try {
      await _ensureBubbleExists(bubbleId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bubble "$bubbleId" created')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create bubble: $e')));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _renameBubble(String oldBubbleId) async {
    final newBubbleId = await _askBubbleId(currentValue: oldBubbleId);
    if (!mounted || newBubbleId == null || newBubbleId == oldBubbleId) return;

    setState(() => _isUpdating = true);
    try {
      await _ensureBubbleExists(newBubbleId);
      final usersInBubble = await _firestore
          .collection('users')
          .where('bubbleIds', arrayContains: oldBubbleId)
          .where('isAdmin', isEqualTo: false)
          .get();
      for (final userDoc in usersInBubble.docs) {
        final userData = userDoc.data();
        final bubbles = _extractBubbleIds(userData).map((id) {
          if (id == oldBubbleId) return newBubbleId;
          return id;
        }).toList();
        final normalized = _normalizeBubbleIds(bubbles);
        await userDoc.reference.set({
          'bubbleId': normalized.isEmpty ? '' : normalized.first,
          'bubbleIds': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _addMemberToBubble(newBubbleId, userDoc.id);
      }

      final legacyUsersInBubble = await _firestore
          .collection('users')
          .where('bubbleId', isEqualTo: oldBubbleId)
          .where('isAdmin', isEqualTo: false)
          .get();
      for (final userDoc in legacyUsersInBubble.docs) {
        final userData = userDoc.data();
        final bubbles = _extractBubbleIds(userData).map((id) {
          if (id == oldBubbleId) return newBubbleId;
          return id;
        }).toList();
        final normalized = _normalizeBubbleIds(bubbles);
        await userDoc.reference.set({
          'bubbleId': normalized.isEmpty ? '' : normalized.first,
          'bubbleIds': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _addMemberToBubble(newBubbleId, userDoc.id);
      }

      await _firestore.collection(_bubblesCollection).doc(oldBubbleId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bubble renamed to "$newBubbleId"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to rename bubble: $e')));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<List<String>> _loadBubbleIds() async {
    try {
      final snapshot = await _firestore.collection(_bubblesCollection).get();
      final ids =
          snapshot.docs
              .map((doc) => doc.id.trim())
              .where((id) => id.isNotEmpty)
              .toList()
            ..sort();
      return ids;
    } catch (_) {
      return <String>[];
    }
  }

  List<String> _extractBubbleIds(Map<String, dynamic> data) {
    final bubbleIds = <String>{};
    final rawIds = data['bubbleIds'];
    if (rawIds is List) {
      for (final value in rawIds) {
        final normalized = value.toString().trim().toLowerCase();
        if (normalized.isNotEmpty) {
          bubbleIds.add(normalized);
        }
      }
    }
    final legacyBubbleId = (data['bubbleId'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (legacyBubbleId.isNotEmpty) {
      bubbleIds.add(legacyBubbleId);
    }
    return bubbleIds.toList()..sort();
  }

  List<String> _normalizeBubbleIds(List<String> input) {
    final values = <String>{};
    for (final value in input) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isNotEmpty) {
        values.add(normalized);
      }
    }
    return values.toList()..sort();
  }

  bool _sameBubbleSets(List<String> a, List<String> b) {
    final setA = a.toSet();
    final setB = b.toSet();
    if (setA.length != setB.length) return false;
    for (final value in setA) {
      if (!setB.contains(value)) return false;
    }
    return true;
  }

  Future<void> _ensureBubbleExists(String bubbleId) async {
    final normalized = bubbleId.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final bubbleRef = _firestore.collection(_bubblesCollection).doc(normalized);
    final bubbleDoc = await bubbleRef.get();
    await bubbleRef.set({
      'name': normalized,
      'description': bubbleDoc.data()?['description'] ?? '',
      'isEncrypted': bubbleDoc.data()?['isEncrypted'] ?? false,
      'isModerated': bubbleDoc.data()?['isModerated'] ?? true,
      'memberIds': bubbleDoc.data()?['memberIds'] ?? <String>[],
      'createdAt':
          bubbleDoc.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy':
          bubbleDoc.data()?['createdBy'] ??
          (FirebaseAuth.instance.currentUser?.uid ?? ''),
    }, SetOptions(merge: true));
  }

  Future<void> _addMemberToBubble(String bubbleId, String userRef) async {
    final normalized = bubbleId.trim().toLowerCase();
    if (normalized.isEmpty || userRef.trim().isEmpty) return;
    await _ensureBubbleExists(normalized);
    await _firestore.collection(_bubblesCollection).doc(normalized).set({
      'memberIds': FieldValue.arrayUnion([userRef.trim()]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _removeMemberFromBubble(String bubbleId, String userRef) async {
    final normalized = bubbleId.trim().toLowerCase();
    if (normalized.isEmpty || userRef.trim().isEmpty) return;
    await _firestore.collection(_bubblesCollection).doc(normalized).set({
      'memberIds': FieldValue.arrayRemove([userRef.trim()]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _logout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await UserPresenceService.markOffline(uid);
    if (mounted) {
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
    await FirebaseAuth.instance.signOut();
  }
}

class _BubblePickerDialog extends StatefulWidget {
  final List<String> existingBubbleIds;
  final String initialValue;

  const _BubblePickerDialog({
    required this.existingBubbleIds,
    required this.initialValue,
  });

  @override
  State<_BubblePickerDialog> createState() => _BubblePickerDialogState();
}

class _BubblePickerDialogState extends State<_BubblePickerDialog> {
  late final TextEditingController _controller;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Bubble'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.existingBubbleIds.isNotEmpty) ...[
            const Text('Existing bubbles'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.existingBubbleIds.map((bubbleId) {
                return ActionChip(
                  label: Text(bubbleId),
                  onPressed: () {
                    setState(() {
                      _controller.text = bubbleId;
                      _validationError = null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Bubble ID',
              hintText: 'e.g. bubble_a',
              errorText: _validationError,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim().toLowerCase();
            if (value.isEmpty) {
              setState(() {
                _validationError = 'Bubble ID is required';
              });
              return;
            }
            Navigator.of(context, rootNavigator: true).pop(value);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _BubbleMultiPickerDialog extends StatefulWidget {
  final List<String> existingBubbleIds;
  final List<String> initialSelectedIds;

  const _BubbleMultiPickerDialog({
    required this.existingBubbleIds,
    required this.initialSelectedIds,
  });

  @override
  State<_BubbleMultiPickerDialog> createState() =>
      _BubbleMultiPickerDialogState();
}

class _BubbleMultiPickerDialogState extends State<_BubbleMultiPickerDialog> {
  final TextEditingController _controller = TextEditingController();
  late final Set<String> _selectedIds;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initialSelectedIds
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTypedBubble() {
    final value = _controller.text.trim().toLowerCase();
    if (value.isEmpty) {
      setState(() {
        _validationError = 'Bubble ID is required';
      });
      return;
    }
    setState(() {
      _selectedIds.add(value);
      _validationError = null;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedSelected = _selectedIds.toList()..sort();
    return AlertDialog(
      title: const Text('Manage Bubbles'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.existingBubbleIds.isNotEmpty) ...[
                const Text('Existing bubbles'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.existingBubbleIds.map((bubbleId) {
                    final selected = _selectedIds.contains(bubbleId);
                    return FilterChip(
                      label: Text(bubbleId),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedIds.add(bubbleId);
                          } else {
                            _selectedIds.remove(bubbleId);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'Add bubble ID',
                        hintText: 'e.g. bubble_a',
                        errorText: _validationError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _addTypedBubble,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (sortedSelected.isNotEmpty) ...[
                const Text('Selected bubbles'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sortedSelected.map((bubbleId) {
                    return InputChip(
                      label: Text(bubbleId),
                      onDeleted: () {
                        setState(() {
                          _selectedIds.remove(bubbleId);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final values = _selectedIds.toList()..sort();
            Navigator.of(context, rootNavigator: true).pop(values);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
