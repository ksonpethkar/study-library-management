import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/features/search/data/repositories/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository();
});
