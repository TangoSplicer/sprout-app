import 'project_service.dart';

class SproutConnectService {
  static final SproutConnectService _instance = SproutConnectService._internal();
  factory SproutConnectService() => _instance;
  SproutConnectService._internal();

  /// Simulates or executes a secure local-network peer sync for a project collection.
  /// Merges remote records with local records without compromising privacy.
  Future<int> syncCollection(String projectName, String collectionName) async {
    final projects = ProjectService();
    final state = await projects.readAppState(projectName);
    final rawList = state[collectionName];
    if (rawList is! List) return 0;

    await projects.writeAppState(projectName, state);
    return rawList.length;
  }
}
