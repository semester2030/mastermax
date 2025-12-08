import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team_member.dart';

class TeamService {
  final FirebaseFirestore _firestore;
  final String companyId;

  TeamService({
    required this.companyId, FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _teamCollection =>
      _firestore.collection('companies').doc(companyId).collection('team_members');

  // إضافة عضو جديد للفريق
  Future<void> addTeamMember(TeamMember member) async {
    await _teamCollection.doc(member.id).set(member.toJson());
  }

  // تحديث بيانات عضو الفريق
  Future<void> updateTeamMember(TeamMember member) async {
    await _teamCollection.doc(member.id).update(member.toJson());
  }

  // حذف عضو من الفريق
  Future<void> removeTeamMember(String memberId) async {
    await _teamCollection.doc(memberId).delete();
  }

  // الحصول على قائمة أعضاء الفريق
  Stream<List<TeamMember>> getTeamMembers() {
    return _teamCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => TeamMember.fromJson(doc.data()))
          .toList();
    });
  }

  // تحديث صلاحيات عضو الفريق
  Future<void> updateMemberPermissions(
    String memberId,
    List<String> permissions,
  ) async {
    await _teamCollection.doc(memberId).update({'permissions': permissions});
  }

  // تغيير حالة نشاط عضو الفريق
  Future<void> toggleMemberStatus(String memberId, bool isActive) async {
    await _teamCollection.doc(memberId).update({'isActive': isActive});
  }
} 