import "package:data_table_2/data_table_2.dart";
import "package:flutter/material.dart";
import "package:flutter_localization/flutter_localization.dart";

import "src/routes.dart";
import "src/state.dart";
import "src/translations.dart";
import "src/widgets/common.dart";
import "src/widgets/home.dart";
import "src/widgets/login.dart";
import "src/widgets/payment.dart";
import "src/widgets/personal_info.dart";
import "src/widgets/qr.dart";
import "src/widgets/register.dart";
import "src/widgets/admin/change_password.dart";
import "src/widgets/admin/fees.dart";
import "src/widgets/admin/payments.dart";
import "src/widgets/admin/reg_queue.dart";
import "src/widgets/admin/residents.dart";
import "src/widgets/admin/rooms.dart";

class MainApplication extends StateAwareWidget {
  const MainApplication({super.key, required super.state});

  @override
  AbstractCommonState<MainApplication> createState() => _MainApplicationState();
}

class _MainApplicationState extends AbstractCommonState<MainApplication> {
  @override
  Widget build(BuildContext context) {
    String initialRoute = ApplicationRoute.login;
    if (state.loggedIn) {
      initialRoute = state.loggedInAsAdmin ? ApplicationRoute.adminRegisterQueue : ApplicationRoute.home;
    }

    return MaterialApp(
      title: AppLocale.ResidentManager.getString(context),
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          color: Colors.blue,
          elevation: 1.0,
        ),
      ),
      routes: {
        ApplicationRoute.login: (context) => LoginPage(state: state),
        ApplicationRoute.register: (context) => RegisterPage(state: state),
        ApplicationRoute.home: (context) => HomePage(state: state),
        ApplicationRoute.personalInfo: (context) => PersonalInfoPage(state: state),
        ApplicationRoute.payment: (context) => PaymentPage(state: state),
        ApplicationRoute.qr: (context) => QRPage(state: state),
        ApplicationRoute.adminRegisterQueue: (context) => RegisterQueuePage(state: state),
        ApplicationRoute.adminResidentsPage: (context) => ResidentsPage(state: state),
        ApplicationRoute.adminRoomsPage: (context) => RoomsPage(state: state),
        ApplicationRoute.adminFeesPage: (context) => FeeListPage(state: state),
        ApplicationRoute.adminPaymentsPage: (context) => PaymentListPage(state: state),
        ApplicationRoute.adminChangePassword: (context) => ChangePasswordPage(state: state),
      },
      initialRoute: initialRoute,
      localizationsDelegates: state.localization.localizationsDelegates,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: true,
        overscroll: false,
      ),
      supportedLocales: state.localization.supportedLocales,
      debugShowCheckedModeBanner: false,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  dataTableShowLogs = false;

  final state = ApplicationState();
  await state.prepare();

  runApp(MainApplication(state: state));
}
