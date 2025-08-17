import 'proxinet_local_store.dart';

abstract class ProxinetMatchApi {
  Future<void> uploadTokens(List<String> tokens);
}

class ProxinetMatchApiStub implements ProxinetMatchApi {
  final ProxinetLocalStore _store;
  ProxinetMatchApiStub(this._store);

  @override
  Future<void> uploadTokens(List<String> tokens) async {
    // For now, persist locally; backend integration to be added later
    await _store.saveTokens(tokens);
  }
}
