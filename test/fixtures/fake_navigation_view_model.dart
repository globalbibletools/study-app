import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/ui/home/common/navigation_view_model.dart';

class FakeNavigationViewModel extends Fake implements NavigationViewModel {
  final navigatedReferences = <Reference>[];

  @override
  void navigateTo(
    Reference ref, {
    bool persist = true,
    bool animated = false,
    bool hard = true,
  }) {
    navigatedReferences.add(ref);
  }
}
