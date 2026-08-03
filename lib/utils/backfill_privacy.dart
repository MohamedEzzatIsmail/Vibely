import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> backfillPrivacyField() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final posts = await FirebaseFirestore.instance
      .collection('Posts')
      .where('uid', isEqualTo: uid)
      .get();

  var fixed = 0;
  for (final doc in posts.docs) {
    if (doc.data()['privacy'] == null) {
      await doc.reference.update({'privacy': 'public'});
      fixed++;
    }
  }

  // ignore: avoid_print
  print('backfillPrivacyField: fixed $fixed post(s) for uid=$uid');
}
