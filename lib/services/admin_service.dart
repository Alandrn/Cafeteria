import 'package:cloud_functions/cloud_functions.dart';

class AdminService {
  Future<void> makeAdmin(String email) async {
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    final callable = functions.httpsCallable('setAdmin');

    final result = await callable.call({'email': email});
    print(result.data);
  }
}