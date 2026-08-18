import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fark_tee_app/app.dart';
import 'package:fark_tee_app/core/api/api_client.dart';
import 'package:fark_tee_app/core/auth/auth_repository.dart';
import 'package:fark_tee_app/core/auth/token_storage.dart';
import 'package:fark_tee_app/features/auth/auth_controller.dart';

void main() {
  testWidgets('shows a loading indicator before auth state resolves', (
    tester,
  ) async {
    final tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);
    final authController = AuthController(
      apiClient: apiClient,
      authRepository: AuthRepository(apiClient),
      tokenStorage: tokenStorage,
    );

    // bootstrap() is intentionally not called - this checks the initial
    // "checking" state renders without touching secure storage or network.
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: authController, child: const App()),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
