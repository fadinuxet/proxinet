import 'putrace_local_store.dart';

abstract class PutraceMatchApi {
  Future<void> uploadTokens(List<String> tokens);
}

class PutraceMatchApiStub implements PutraceMatchApi {
  final PutraceLocalStore _store;
  PutraceMatchApiStub(this._store);

  @override
  Future<void> uploadTokens(List<String> tokens) async {
    // For now, persist locally; backend integration to be added later
    await _store.saveTokens(tokens);
  }
}
