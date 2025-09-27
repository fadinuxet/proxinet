import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebasePostsRepo {
  final _db = FirebaseFirestore.instance;
  final _cache = <String, Map<String, dynamic>>{};

  Future<String> create(Map<String, dynamic> post) async {
    final ref = await _db.collection('posts').add(post);
    _cache[ref.id] = post..['id'] = ref.id;
    return ref.id;
  }

  Future<void> update(String postId, Map<String, dynamic> data) async {
    await _db
        .collection('posts')
        .doc(postId)
        .set(data, SetOptions(merge: true));
    final prev = _cache[postId] ?? {};
    _cache[postId] = {...prev, ...data, 'id': postId};
  }

  Stream<List<Map<String, dynamic>>> myPostsStream(String userId) {
    
    return _db
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true) // Use createdAt instead of startAt for better ordering
        .snapshots()
        .map((snapshot) {
          
          final posts = snapshot.docs.map((doc) {
            final data = doc.data();
            final post = {'id': doc.id, ...data};
            // print('Post data: ${post.toString()}'); // Removed print statement
            return post;
          }).toList();
          
          return posts;
        })
        .handleError((error) {
          
          return <Map<String, dynamic>>[];
        });
  }

  // Debug method to get all posts
  Stream<List<Map<String, dynamic>>> allPostsStream() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();
        })
        .handleError((error) {
          
          return <Map<String, dynamic>>[];
        });
  }

  // Method to get a single post by ID
  Future<Map<String, dynamic>?> getPost(String postId) async {
    try {
      final doc = await _db.collection('posts').doc(postId).get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
      return null;
    } catch (e) {
      
      return null;
    }
  }
}

class FirebaseAvailabilityRepo {
  final _db = FirebaseFirestore.instance;
  Future<void> setAvailability(String userId, Map<String, dynamic> data) async {
    await _db
        .collection('availability')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }
}

class FirebaseReferralsRepo {
  final _db = FirebaseFirestore.instance;
  Future<void> increment(String userId,
      {int credits = 1, int invited = 1}) async {
    await _db.collection('referrals').doc(userId).set({
      'credits': FieldValue.increment(credits),
      'invitedCount': FieldValue.increment(invited),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class FirebasePresenceRepo {
  final _db = FirebaseFirestore.instance;
  Future<void> setCity(String userId, String city, String country) async {
    await _db.collection('presence_city').doc(userId).set({
      'city': city,
      'country': country,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setGeo(
      String userId, double lat, double lng, double precisionM) async {
    await _db.collection('presence_geo').doc(userId).set({
      'lat': lat,
      'lng': lng,
      'precisionM': precisionM,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class FirebaseDeviceRepo {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  Future<void> upsertDeviceToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    final user = _auth.currentUser;
    if (token == null || user == null) return;
    await _db.collection('device_tokens').doc('${user.uid}_$token').set({
      'userId': user.uid,
      'token': token,
      'platform': 'mobile',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
