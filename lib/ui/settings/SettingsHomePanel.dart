/*
 * Copyright 2020 Board of Trustees of the University of Illinois.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:illinois/service/AppNavigation.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/BluetoothServices.dart';
import 'package:illinois/service/Connectivity.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/LocationServices.dart';
import 'package:illinois/service/Organizations.dart';
import 'package:illinois/ui/onboarding/OnboardingLoginPhoneVerifyPanel.dart';
import 'package:illinois/ui/settings/SettingsFamilyMembersPanel.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/FlexUI.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/UserProfile.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/ui/WebPanel.dart';
import 'package:illinois/ui/settings/SettingsQrCodePanel.dart';
import 'package:illinois/ui/settings/SettingsRolesPanel.dart';
import 'package:illinois/ui/settings/SettingsPersonalInfoPanel.dart';
import 'package:illinois/ui/debug/DebugHomePanel.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/ui/widgets/RibbonButton.dart';
import 'package:illinois/utils/Covid19.dart';
import 'package:illinois/utils/Crypt.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:package_info/package_info.dart';
import 'package:pointycastle/export.dart' as PointyCastle;


class SettingsHomePanel extends StatefulWidget {
  @override
  _SettingsHomePanelState createState() => _SettingsHomePanelState();
}

class _SettingsHomePanelState extends State<SettingsHomePanel> implements NotificationsListener {

  static BorderRadius _bottomRounding = BorderRadius.only(bottomLeft: Radius.circular(5), bottomRight: Radius.circular(5));
  static BorderRadius _topRounding = BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5));
  static BorderRadius _allRounding = BorderRadius.all(Radius.circular(5));
  
  String _versionName = "";

  // Covid19
  bool _refreshingHealthUser;

  bool _healthUserKeysPaired;
  bool _checkingHealthUserKeysPaired;

  bool _loadingHealthUserKeys;
  bool _scanningHealthUserKeys;
  bool _resetingHealthUserKeys;

  bool _permissionsRequested;

  GlobalKey _qrCodeButtonKey = GlobalKey();
  Size _qrCodeProgressSize = Size(20, 20);
  Size _qrCodeButtonSize;

  @override
  void initState() {

    super.initState();

    NotificationService().subscribe(this, [
      Auth.notifyUserPiiDataChanged,
      UserProfile.notifyProfileUpdated,
      Health.notifyUserUpdated,
      Health.notifyRefreshing,
      FirebaseMessaging.notifySettingUpdated,
      FlexUI.notifyChanged,
    ]);

    _loadVersionInfo();
    _refreshHealthUser();

  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == Auth.notifyUserPiiDataChanged) {
      _updateState();
    } else if (name == UserProfile.notifyProfileUpdated){
      _updateState();
    } else if (name == Health.notifyUserUpdated) {
      _verifyHealthUserKeys();
    } else if (name == Health.notifyRefreshing) {
      _updateState();
    } else if (name == FirebaseMessaging.notifySettingUpdated) {
      _updateState();
    } else if (name == FlexUI.notifyChanged) {
      _updateState();
    }
  }

  @override
  Widget build(BuildContext context) {
    
    List<Widget> contentList = [];
    List<Widget> actionsList = [];

    List<dynamic> codes = FlexUI()['settings'] ?? [];

    for (String code in codes) {
      if (code == 'user_info') {
        contentList.add(_buildUserInfo());
      }
      else if (code == 'connect') {
        contentList.add(_buildConnect());
      }
      else if (code == 'customizations') {
        contentList.add(_buildCustomizations());
      }
      else if (code == 'connected') {
        contentList.add(_buildConnected());
      }
      else if (code == 'notifications') {
        contentList.add(_buildNotifications());
      }
      else if (code == 'covid19') {
        contentList.add(_buildCovid19Settings());
      }
      else if (code == 'privacy') {
        contentList.add(_buildPrivacy());
      }
      else if (code == 'account') {
        contentList.add(_buildAccount());
      }
      else if (code == 'feedback') {
        contentList.add(_buildFeedback(),);
      }
    }

    if (!kReleaseMode || Organizations().isDevEnvironment) {
      contentList.add(_buildDebug());
      actionsList.add(_buildHeaderBarDebug());
    }

    contentList.add(_buildVersionInfo());
    
    contentList.add(Container(height: 12,),);

    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: _DebugContainer(
            child: Container(
//          height: 40,
          child: Padding(
            //PS I know it is ugly..
            padding: EdgeInsets.only(top: 10),
            child: Text(
              Localization().getStringEx("panel.settings.home.settings.header", "Settings"),
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        )),
        actions: actionsList,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: SafeArea( 
                child: Container(
                  color: Styles().colors.background,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: contentList,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Styles().colors.background,
    );
  }

  // UserProfile Info

  String get _greeting {
    switch (AppDateTime.timeOfDay()) {
      case AppTimeOfDay.Morning:   return Localization().getStringEx("logic.date_time.greeting.morning", "Good morning");
      case AppTimeOfDay.Afternoon: return Localization().getStringEx("logic.date_time.greeting.afternoon", "Good afternoon");
      case AppTimeOfDay.Evening:   return Localization().getStringEx("logic.date_time.greeting.evening", "Good evening");
    }
    return Localization().getStringEx("logic.date_time.greeting.day", "Good day");
  }

  Widget _buildUserInfo() {
    String fullName = Auth().fullUserName ?? '';
    bool hasFullName =  AppString.isStringNotEmpty(fullName);
    String welcomeMessage = AppString.isStringNotEmpty(fullName)
        ? _greeting + ","
        : Localization().getStringEx("panel.settings.home.user_info.title.sufix", "Welcome to Illinois");
    return
      Semantics( container: true,
        child: Container(
          width: double.infinity,
          child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(welcomeMessage, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20)),
                Visibility(
                  visible: hasFullName,
                    child: Text(fullName, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 28))
                ),
              ]))));
  }


  // Connect

  Widget _buildConnect() {
    List<Widget> contentList = [];
    contentList.add(Padding(
        padding: EdgeInsets.only(left: 8, right: 8, top: 12, bottom: 2),
        child: Text(
          Localization().getStringEx("panel.settings.home.connect.not_logged_in.title", "Connect to Illinois"),
          style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20),
        ),
      ),
    );

    List<dynamic> codes = FlexUI()['settings.connect'] ?? [];
    for (String code in codes) {
      if (code == 'netid') {
          contentList.add(Padding(
            padding: EdgeInsets.all(10),
            child: new RichText(
              textScaleFactor: MediaQuery.textScaleFactorOf(context),
              text: new TextSpan(
                style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
                children: <TextSpan>[
                  new TextSpan(text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.netid.description.part_1", "Are you a ")),
                  new TextSpan(
                      text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.netid.description.part_2", "student"),
                      style: TextStyle(color: Styles().colors.fillColorPrimary, fontFamily: Styles().fontFamilies.bold)),
                  new TextSpan(text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.netid.description.part_3", " or ")),
                  new TextSpan(
                      text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.netid.description.part_4", "faculty member"),
                      style: TextStyle(color: Styles().colors.fillColorPrimary, fontFamily: Styles().fontFamilies.bold)),
                  new TextSpan(
                      text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.netid.description.part_5",
                          "? Log in with your NetID."))
                ],
              ),
            )),);
          contentList.add(RibbonButton(
            height: null,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            borderRadius: _allRounding,
            label: Localization().getStringEx("panel.settings.home.connect.not_logged_in.netid.title", "Connect your NetID"),
            onTap: _onConnectNetIdClicked),);
      }
      else if (code == 'phone') {
          contentList.add(Padding(
            padding: EdgeInsets.all(10),
            child: new RichText(
              textScaleFactor: MediaQuery.textScaleFactorOf(context),
              text: new TextSpan(
                style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
                children: <TextSpan>[
                  new TextSpan(
                      text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.phone.description.part_1", "Don't have a NetID? "),
                      style: TextStyle(color: Styles().colors.fillColorPrimary, fontFamily: Styles().fontFamilies.bold)),
                  new TextSpan(
                      text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.phone.description.part_2",
                          "Verify your phone number.")),
                ],
              ),
            )),);
          contentList.add(RibbonButton(
            borderRadius: _allRounding,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            label: Localization().getStringEx("panel.settings.home.connect.not_logged_in.phone.title", "Verify Your Phone Number"),
            onTap: _onPhoneVerClicked),);
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentList),
    );
  }

  void _onConnectNetIdClicked() {
    Analytics.instance.logSelect(target: "Connect netId");
    if (Connectivity().isNotOffline) {
      Auth().authenticateWithShibboleth();
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onPhoneVerClicked() {
    Analytics.instance.logSelect(target: "Phone Verification");
    if (Connectivity().isNotOffline) {
      Navigator.push(context, CupertinoPageRoute(settings: RouteSettings(), builder: (context) => OnboardingLoginPhoneVerifyPanel(onFinish: _didPhoneVer,)));
    } else {
      AppAlert.showOfflineMessage(context, Localization().getStringEx('panel.settings.label.offline.phone_ver', 'Verify Your Phone Number is not available while offline.'));
    }
  }

  void _didPhoneVer(_) {
    Navigator.of(context)?.popUntil((Route route) {
      return AppNavigation.routeRootWidget(route, context: context)?.runtimeType == widget.runtimeType;
    });
  }

  // Customizations

  Widget _buildCustomizations() {
    List<Widget> customizationOptions = [];
    List<dynamic> codes = FlexUI()['settings.customizations'] ?? [];
    for (int index = 0; index < codes.length; index++) {
      String code = codes[index];
      
      BorderRadius borderRadius = _borderRadiusFromIndex(index, codes.length);
      
      if (code == 'roles') {
        customizationOptions.add(RibbonButton(
            height: null,
            borderRadius: borderRadius,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            label: Localization().getStringEx("panel.settings.home.customizations.role.title", "Who you are"),
            onTap: _onWhoAreYouClicked));
      }
    }

    return _OptionsSection(
      title: Localization().getStringEx("panel.settings.home.customizations.title", "Customizations"),
      widgets: customizationOptions,);

  }

  void _onWhoAreYouClicked() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Who are you");
      Navigator.push(context, CupertinoPageRoute(builder: (context) => SettingsRolesPanel()));
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  // Connected

  Widget _buildConnected() {
    List<Widget> contentList = [];

    List<dynamic> codes = FlexUI()['settings.connected'] ?? [];
    for (String code in codes) {
      if (code == 'netid') {
        contentList.add(_OptionsSection(
          title: Localization().getStringEx("panel.settings.home.net_id.title", "Illinois NetID"),
          widgets: _buildConnectedNetIdLayout()));
      }
      else if (code == 'phone') {
        contentList.add(_OptionsSection(
          title: Localization().getStringEx("panel.settings.home.phone_ver.title", "Phone Verification"),
          widgets: _buildConnectedPhoneLayout()));
      }
    }
    return Column(children: contentList,);

  }

  List<Widget> _buildConnectedNetIdLayout() {
    List<Widget> contentList = [];

    List<dynamic> codes = FlexUI()['settings.connected.netid'] ?? [];
    for (int index = 0; index < codes.length; index++) {
      String code = codes[index];
      BorderRadius borderRadius = _borderRadiusFromIndex(index, codes.length);
      if (code == 'info') {
        contentList.add(
          Semantics( container: true,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(borderRadius: borderRadius, border: Border.all(color: Styles().colors.surfaceAccent, width: 0.5)),
              child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(Localization().getStringEx("panel.settings.home.net_id.message", "Connected as "),
                        style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16)),
                    Text(Auth().fullUserName ?? '',
                        style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20)),
                  ])))));
      }
      else if (code == 'connect') {
        contentList.add(RibbonButton(
            height: null,
            borderRadius: borderRadius,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            label: Localization().getStringEx("panel.settings.home.net_id.button.connect", "Connect your NetID"),
            onTap: _onConnectNetIdClicked));
      }
      else if (code == 'disconnect') {
        contentList.add(RibbonButton(
            height: null,
            borderRadius: borderRadius,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            label: Localization().getStringEx("panel.settings.home.net_id.button.disconnect", "Disconnect your NetID"),
            onTap: _onDisconnectNetIdClicked));
      }
    }

    return contentList;
  }

  List<Widget> _buildConnectedPhoneLayout() {
    List<Widget> contentList = [];

    String fullName = Auth().fullUserName ?? '';
    bool hasFullName = AppString.isStringNotEmpty(fullName);

    List<dynamic> codes = FlexUI()['settings.connected.phone'] ?? [];
    for (int index = 0; index < codes.length; index++) {
      String code = codes[index];
      BorderRadius borderRadius = _borderRadiusFromIndex(index, codes.length);
      if (code == 'info') {
        contentList.add(Container(
          width: double.infinity,
          decoration: BoxDecoration(borderRadius: borderRadius, border: Border.all(color: Styles().colors.surfaceAccent, width: 0.5)),
          child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(Localization().getStringEx("panel.settings.home.phone_ver.message", "Verified as "),
                    style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16)),
                Visibility(visible: hasFullName, child: Text(fullName ?? "", style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20)),),
                Text(Auth().phoneToken?.phone ?? "", style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20)),
              ]))));
      }
      else if (code == 'verify') {
        contentList.add(RibbonButton(
            borderRadius: borderRadius,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            label: Localization().getStringEx("panel.settings.home.phone_ver.button.connect", "Verify Your Phone Number"),
            onTap: _onPhoneVerClicked));
      }
      else if (code == 'disconnect') {
        contentList.add(RibbonButton(
            height: null,
            borderRadius: borderRadius,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            label: Localization().getStringEx("panel.settings.home.phone_ver.button.disconnect","Disconnect your Phone",),
            onTap: _onDisconnectNetIdClicked));
      }
    }
    return contentList;
  }

  void _onDisconnectNetIdClicked() {
    if(Auth().isShibbolethLoggedIn) {
      Analytics.instance.logSelect(target: "Disconnect netId");
    } else {
      Analytics.instance.logSelect(target: "Disconnect phone");
    }
    showDialog(context: context, builder: (context) => _buildLogoutDialog(context));
  }

  Widget _buildLogoutDialog(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              Localization().getStringEx("app.title", "Safer Illinois"),
              style: TextStyle(fontSize: 24, color: Colors.black),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Text(
                Localization().getStringEx("panel.settings.home.logout.message", "Are you sure you want to sign out?"),
                textAlign: TextAlign.left,
                style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Colors.black),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                    onPressed: () {
                      Analytics.instance.logAlert(text: "Sign out", selection: "Yes");
                      Navigator.pop(context);
                      Auth().logout();
                    },
                    child: Text(Localization().getStringEx("panel.settings.home.logout.button.yes", "Yes"))),
                TextButton(
                    onPressed: () {
                      Analytics.instance.logAlert(text: "Sign out", selection: "No");
                      Navigator.pop(context);
                    },
                    child: Text(Localization().getStringEx("panel.settings.home.logout.no", "No")))
              ],
            ),
          ],
        ),
      ),
    );
  }

  // NotificationsOptions

  Widget _buildNotifications() {
    List<Widget> contentList = [];

    List<dynamic> codes = FlexUI()['settings.notifications'] ?? [];
    for (int index = 0; index < codes.length; index++) {
      String code = codes[index];
      BorderRadius borderRadius = _borderRadiusFromIndex(index, codes.length);
      if (code == 'covid19') {
        contentList.add(ToggleRibbonButton(
          height: null,
          borderRadius: borderRadius,
          label: Localization().getStringEx("panel.settings.home.notifications.covid19", "COVID-19 notifications"),
          toggled: FirebaseMessaging().notifyCovid19,
          context: context,
          onTap: _onCovid19Toggled));
      }
    }

    return _OptionsSection(
      title: Localization().getStringEx("panel.settings.home.notifications.title", "Notifications"),
      widgets: contentList);
  }

  void _onCovid19Toggled() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "COVID-19 notifications");
      FirebaseMessaging().notifyCovid19 = !FirebaseMessaging().notifyCovid19;
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  void _refreshHealthUser() {
    setState(() {
      _refreshingHealthUser = true;
    });
    Health().refreshUser().then((_) {
      if (mounted) {
        setState(() {
          _refreshingHealthUser = false;
        });
        _verifyHealthUserKeys();
      }
    });
  }

  void _updateHealthUser({bool consentTestResults, bool consentVaccineInformation, bool consentExposureNotification}){
    setState(() {
      _refreshingHealthUser = true;
    });
    Health().loginUser(consentTestResults: consentTestResults, consentVaccineInformation: consentVaccineInformation, consentExposureNotification: consentExposureNotification).then((_) {
      if (mounted) {
        setState(() {
          _refreshingHealthUser = false;
        });
      }
    });
  }

  void _verifyHealthUserKeys() {
    if ((Health().userPrivateKey != null) && (Health().user?.publicKey != null)) {
      setState(() {
        _checkingHealthUserKeysPaired = true;
      });
      RsaKeyHelper.verifyRsaKeyPair(PointyCastle.AsymmetricKeyPair<PointyCastle.PublicKey, PointyCastle.PrivateKey>(Health().user?.publicKey, Health().userPrivateKey)).then((bool result) {
        if (mounted) {
          setState(() {
            _healthUserKeysPaired = result;
            _checkingHealthUserKeysPaired = false;
          });
        }
      });
    }
  }

  void _refreshHealthUserKeys() {
    setState(() {
      _resetingHealthUserKeys = true;
    });
    Health().resetUserKeys().then((keyPair) {
      if (mounted) {
        if (keyPair != null) {
          setState(() {
            _resetingHealthUserKeys = false;
          });
          _verifyHealthUserKeys();
        }
        else {
          setState(() {
            _resetingHealthUserKeys = false;
          });
          AppAlert.showDialogResult(context, Localization().getStringEx('panel.settings.home.covid19.alert.reset.failed', 'Failed to reset the COVID-19 Secret QRcode'));
        }
      }
    });

  }

  

  Widget _buildCovid19Settings() {
    List<Widget> contentList = [];

    if (Auth().isLoggedIn) {
      if ((_refreshingHealthUser == true) || Health().refreshingUser) {
        contentList.add(Container(
          padding: EdgeInsets.all(16),
          child: Center(child:
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
          ,),
        ));
      }
      else if (Health().user == null) {
        contentList.add(Container(
          padding: EdgeInsets.only(left: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(height: 10,),
              Text(Localization().getStringEx('panel.settings.home.covid19.text.user.fail', 'Unable to retrieve user COVID-19 settings.') , style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16)),
              Container(height: 10,),
                Column(children: [
                  ScalableRoundedButton(
                    label: Localization().getStringEx('panel.settings.home.covid19.button.retry.title', 'Retry'),
                    backgroundColor: Styles().colors.background,
                    fontSize: 16.0,
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    textColor: Styles().colors.fillColorPrimary,
                    borderColor: Styles().colors.fillColorPrimary,
                    onTap: _onTapCovid19Login
                  ),
                  Container(height: 10,),
                ],
              ),
          ],)
        ));
      }
      else {
        List<dynamic> codes = FlexUI()['settings.covid19'] ?? [];
        for (int index = 0; index < codes.length; index++) {
          String code = codes[index];
          BorderRadius borderRadius = _borderRadiusFromIndex(index, codes.length);
          if (code == 'exposure_notifications') {
            contentList.add(ToggleRibbonButton(
                height: null,
                borderRadius: borderRadius,
                label: Localization().getStringEx("panel.settings.home.covid19.exposure_notifications", "Exposure Notifications"),
                toggled: (Health().user?.consentExposureNotification == true),
                context: context,
                onTap: _onConsentExposureNotifications));
          }
          else if (code == 'provider_test_result') {
            contentList.add(ToggleRibbonButton(
                height: null,
                borderRadius: borderRadius,
                label: Localization().getStringEx("panel.settings.home.covid19.provider_test_result", "Health Provider Test Results"),
                toggled: (Health().user?.consentTestResults == true),
                context: context,
                onTap: _onConsentTestResult));
          }
          else if (code == 'provider_vaccine_info') {
            contentList.add(ToggleRibbonButton(
                height: null,
                borderRadius: borderRadius,
                label: Localization().getStringEx("panel.settings.home.covid19.provider_vaccine_info", "Health Provider Vaccine Information"),
                toggled: (Health().user?.consentVaccineInformation == true),
                context: context,
                onTap: _onConsentVaccineInfo));
          }
          else if (code == 'qr_code') {
            contentList.add(Padding(padding: EdgeInsets.only(left: 8, top: 16), child: _buildCovid19KeysSection(),));
          }
        }
      }
    }

    return (0 < contentList.length) ?
      _OptionsSection(
        title: Localization().getStringEx("panel.settings.home.covid19.title", "COVID-19"),
        widgets: contentList) :
      Container();
  }

  Widget _buildCovid19KeysSection() {
    if ((_refreshingHealthUser == true) || (_checkingHealthUserKeysPaired == true)) {
      return Text(Localization().getStringEx('panel.settings.home.covid19.text.keys.checking', 'Checking COVID-19 keys...'), style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16),);
    }
    else {
      String statusText, descriptionText;
      List<Widget> buttons;
      if (Health().user?.publicKey == null) {
        if (_qrCodeButtonSize == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _evalQrCodeButtonSize();
          });
        }
        statusText = Localization().getStringEx('panel.settings.home.covid19.text.keys.missing.public', 'Missing COVID-19 public key');
        descriptionText = Localization().getStringEx('panel.settings.home.covid19.text.keys.reset', 'Reset the COVID-19 keys pair.');
        buttons =  <Widget>[
          Expanded(child: Container()),
          Container(width: 8,),
          Expanded(child: Container()),
          Container(width: 8,),
          Expanded(child: _buildCovid19ResetKeysButton()),
        ];
      }
      else if ((Health().userPrivateKey == null) || (_healthUserKeysPaired != true)) {
        if (_qrCodeButtonSize == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _evalQrCodeButtonSize();
          });
        }
        statusText = (Health().userPrivateKey == null) ?
          Localization().getStringEx('panel.settings.home.covid19.text.keys.missing.private', 'Missing COVID-19 private key') :
          Localization().getStringEx('panel.settings.home.covid19.text.keys.mismatch', 'COVID-19 keys not paired');
        descriptionText = Localization().getStringEx('panel.settings.home.covid19.text.keys.transfer_or_reset', 'Transfer the COVID-19 private key from your other phone or reset the COVID-19 keys pair.');
        buttons =  <Widget>[
          Expanded(child: _buildCovid19LoadQrCodeButton()),
          Container(width: 8,),
          Expanded(child: _buildCovid19ScanQrCodeButton()),
          Container(width: 8,),
          Expanded(child: _buildCovid19ResetKeysButton()),
        ];
      }
      else {
        statusText = Localization().getStringEx('panel.settings.home.covid19.text.keys.paired', 'COVID-19 keys valid and paired');
        descriptionText = Localization().getStringEx('panel.settings.home.covid19.text.keys.qr_code', 'Show your COVID-19 secret QR code.');
        buttons =  <Widget>[
          Expanded(child: Container()),
          Container(width: 8,),
          Expanded(child: Container()),
          Container(width: 8,),
          Expanded(child: _buildCovid19ShowQrCodeButton())
        ];
      }

      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(statusText, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold)),
            Container(height: 4,),
            Text(descriptionText, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.regular)),
            Container(height: 8,),
            Row(children: buttons)
        ],
      );
    }
  }

  Widget _buildCovid19ShowQrCodeButton() {
    return ScalableRoundedButton(
      label: Localization().getStringEx('panel.settings.home.covid19.button.qr_code.title', 'QR Code'),
      backgroundColor: Styles().colors.background,
      fontSize: 16.0,
      textColor: Styles().colors.fillColorPrimary,
      borderColor: Styles().colors.fillColorPrimary,
      onTap: _onTapShowCovid19QrCode);
  }

  Widget _buildCovid19LoadQrCodeButton() {
    Size buttonSize = _qrCodeButtonSize ?? Size((MediaQuery.of(context).size.width - 32) / 3, 42);
    return Stack(children: <Widget>[
      ScalableRoundedButton(
            label: Localization().getStringEx('panel.settings.home.covid19.button.load.title', 'Load'),
            backgroundColor: Styles().colors.background,
            fontSize: 16.0,
            textColor: Styles().colors.fillColorPrimary,
            borderColor: Styles().colors.fillColorPrimary,
            onTap: _onTapLoadCovid19QrCode),
      Visibility(visible: (_loadingHealthUserKeys == true), child:
        Padding(padding: EdgeInsets.only(top: (buttonSize.height - _qrCodeProgressSize.width) / 2, left: (buttonSize.width - _qrCodeProgressSize.height) / 2), child:
          Container(width: _qrCodeProgressSize.width, height: _qrCodeProgressSize.height, child:
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
          ),
        ),
      ),
    ],);
  }

  Widget _buildCovid19ScanQrCodeButton() {
    Size buttonSize = _qrCodeButtonSize ?? Size((MediaQuery.of(context).size.width - 32) / 3, 42);
    return Stack(children: <Widget>[
      ScalableRoundedButton(
            label: Localization().getStringEx('panel.settings.home.covid19.button.scan.title', 'Scan'),
            backgroundColor: Styles().colors.background,
            fontSize: 16.0,
            textColor: Styles().colors.fillColorPrimary,
            borderColor: Styles().colors.fillColorPrimary,
            onTap: _onTapScanCovid19QrCode),
      Visibility(visible: (_scanningHealthUserKeys == true), child:
        Padding(padding: EdgeInsets.only(top: (buttonSize.height - _qrCodeProgressSize.width) / 2, left: (buttonSize.width - _qrCodeProgressSize.height) / 2), child:
          Container(width: _qrCodeProgressSize.width, height: _qrCodeProgressSize.height, child:
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
          ),
        ),
      ),
    ],);
  }

  Widget _buildCovid19ResetKeysButton() {
    Size buttonSize = _qrCodeButtonSize ?? Size((MediaQuery.of(context).size.width - 32) / 3, 42);
    return Stack(children: <Widget>[
      ScalableRoundedButton(
        buttonKey: _qrCodeButtonKey,
        label: Localization().getStringEx('panel.settings.home.covid19.button.reset.title', 'Reset'),
        backgroundColor: Styles().colors.background,
        fontSize: 16.0,
        textColor: Styles().colors.fillColorPrimary,
        borderColor: Styles().colors.fillColorPrimary,
        onTap: _onTapCovid19ResetKeys,
      ),
      Visibility(visible: (_resetingHealthUserKeys == true), child:
        Padding(padding: EdgeInsets.only(top: (buttonSize.height - _qrCodeProgressSize.width) / 2, left: (buttonSize.width - _qrCodeProgressSize.height) / 2), child:
          Container(width: _qrCodeProgressSize.width, height: _qrCodeProgressSize.height, child:
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
          ),
        ),
      ),
    ],);
  }

  void _evalQrCodeButtonSize() {
    try {
      final RenderObject renderBox = _qrCodeButtonKey?.currentContext?.findRenderObject();
      final Size renderSize = (renderBox is RenderBox) ? renderBox.size : null;
      if (renderSize != null) {
        setState(() { _qrCodeButtonSize = renderSize; });
      }
    } on Exception catch (e) {
      print(e.toString());
    }
  }

  
  void _onConsentExposureNotifications() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Exposure Notifications");
      bool consentExposureNotification = Health().user?.consentExposureNotification ?? false;
      if (Platform.isIOS && (consentExposureNotification != true) && (_permissionsRequested != true)) {
        _permissionsRequested = true;
        _requestPermisions().then((_) {
          _updateHealthUser(consentExposureNotification: !consentExposureNotification);
        });
      }
      else {
        _updateHealthUser(consentExposureNotification: !consentExposureNotification);
      }
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  Future<void> _requestPermisions() async {
    if (BluetoothServices().status == BluetoothStatus.PermissionNotDetermined) {
      await BluetoothServices().requestStatus();
    }

    if (await LocationServices().status == LocationServicesStatus.PermissionNotDetermined) {
      await LocationServices().requestPermission();
    }
  }

  void _onConsentTestResult() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Consent Test Results");
      bool consentTestResults = Health().user?.consentTestResults ?? false;
      _updateHealthUser(consentTestResults: !consentTestResults);
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onConsentVaccineInfo() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Consent Vaccine Information");
      bool consentVaccineInformation = Health().user?.consentVaccineInformation ?? false;
      _updateHealthUser(consentVaccineInformation: !consentVaccineInformation);
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }
  

  void _onTapCovid19Login() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Retry");
      _refreshHealthUser();
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapCovid19ResetKeys() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Reset");
      String message = Localization().getStringEx(
          'panel.settings.home.covid19.alert.reset.prompt', 'Doing this will provide you a new COVID-19 Secret QRcode but your previous COVID-19 event history will be lost, continue?');
      if (_resetingHealthUserKeys != true) {
        showDialog(
            context: context,
            builder: (BuildContext buildContext) {
              return AlertDialog(
                content: Text(message, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold)),
                actions: <Widget>[
                  TextButton(
                      child: Text(
                          Localization().getStringEx("dialog.yes.title", "Yes"), style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold)),
                      onPressed: () {
                        Analytics.instance.logAlert(text: message, selection: "Yes");
                        Navigator.pop(buildContext, true);
                      }
                  ),
                  TextButton(
                      child: Text(Localization().getStringEx("dialog.no.title", "No"), style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold)),
                      onPressed: () {
                        Analytics.instance.logAlert(text: message, selection: "No");
                        Navigator.pop(buildContext, false);
                      }
                  ),
                ],
              );
            }
        ).then((result) {
          if (result == true) {
            _refreshHealthUserKeys();
          }
        });
      }
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapShowCovid19QrCode() {
    Analytics.instance.logSelect(target: "Show COVID-19 Secret QRcode");
    Navigator.push(context, CupertinoPageRoute(builder: (context) => SettingsQrCodePanel()));
  }

  void _onTapLoadCovid19QrCode() {
    Analytics.instance.logSelect(target: "Load COVID-19 Secret QRcode");
    Covid19Utils.loadQRCodeImageFromPictures().then((String qrCodeString) {
      if (qrCodeString != null) {
        setState(() { _loadingHealthUserKeys = true; });
        _onCovid19QrCodeScanSucceeded(qrCodeString);
      }
    });
  }

  void _onTapScanCovid19QrCode() {
    Analytics.instance.logSelect(target: "Scan COVID-19 Secret QRcode");
    BarcodeScanner.scan().then((result) {
      // barcode_scan plugin returns 8 digits when it cannot read the qr code. Prevent it from storing such values
      if (AppString.isStringEmpty(result?.rawContent) || ((result?.rawContent?.length ?? 0) <= 8)) {
        AppAlert.showDialogResult(context, Localization().getStringEx('panel.settings.home.covid19.alert.qr_code.scan.failed.msg', 'Failed to read QR code.'));
      }
      else {
        setState(() { _scanningHealthUserKeys = true; });
        _onCovid19QrCodeScanSucceeded(result?.rawContent);
      }
    });
  }

  void _onCovid19QrCodeScanSucceeded(String result) {
    RsaKeyHelper.decompressRsaPrivateKey(result).then((PointyCastle.PrivateKey privateKey) {
      if (mounted) {
        if (privateKey != null) {
          RsaKeyHelper.verifyRsaKeyPair(PointyCastle.AsymmetricKeyPair<PointyCastle.PublicKey, PointyCastle.PrivateKey>(Health().user?.publicKey, privateKey)).then((bool result) {
            if (mounted) {
              if (result == true) {
                Health().setUserPrivateKey(privateKey).then((success) {
                  if (mounted) {
                    setState(() { _loadingHealthUserKeys = _scanningHealthUserKeys = false; });
                    String resultMessage = success ? Localization().getStringEx(
                        'panel.settings.home.covid19.alert.qr_code.transfer.succeeded.msg', 'COVID-19 secret transferred successfully.') : Localization()
                        .getStringEx('panel.settings.home.covid19.alert.qr_code.transfer.failed.msg', 'Failed to transfer COVID-19 secret.');
                    AppAlert.showDialogResult(context, resultMessage).then((_) {
                      if (success) {
                        setState(() {
                          _healthUserKeysPaired = true;
                        });
                      }
                    });
                  }
                });
              }
              else {
                AppAlert.showDialogResult(context, Localization().getStringEx('panel.health.covid19.alert.qr_code.not_match.msg', 'COVID-19 secret key does not match existing public RSA key.'));
                setState(() { _loadingHealthUserKeys = _scanningHealthUserKeys = false; });
              }
            }
          });
        }
        else {
          AppAlert.showDialogResult(context, Localization().getStringEx('panel.health.covid19.alert.qr_code.invalid.msg', 'Invalid QR code.'));
          setState(() { _loadingHealthUserKeys = _scanningHealthUserKeys = false; });
        }
      }
    });
  }

  // Privacy

  Widget _buildPrivacy() {
    List<Widget> contentList = [];

    List<dynamic> codes = FlexUI()['settings.privacy'] ?? [];
    for (int index = 0; index < codes.length; index++) {
      String code = codes[index];
      if (code == 'statement') {
        contentList.add(RibbonButton(
          height: null,
          borderRadius: _borderRadiusFromIndex(index, codes.length),
          border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
          label: Localization().getStringEx("panel.settings.home.privacy.privacy_statement.title", "Privacy Statement"),
          onTap: _onPrivacyStatementClicked,
        ));
      }
    }

    return _OptionsSection(
      title: Localization().getStringEx("panel.settings.home.privacy.title", "Privacy"),
      widgets: contentList);
  }

  void _onPrivacyStatementClicked() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Privacy Statement");
      if (Config().privacyPolicyUrl != null) {
        Navigator.push(context, CupertinoPageRoute(
            builder: (context) => WebPanel(url: Config().privacyPolicyUrl, title: Localization().getStringEx("panel.settings.privacy_statement.label.title", "Privacy Statement"),)));
      }
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  // Account

  Widget _buildAccount() {
    List<Widget> contentList = [];

    List<dynamic> codes = FlexUI()['settings.account'] ?? [];
    for (int index = 0; index < codes.length; index++) {
      String code = codes[index];
      BorderRadius borderRadius = _borderRadiusFromIndex(index, codes.length);
      if (code == 'personal_info') {
        contentList.add(RibbonButton(
          height: null,
          border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
          borderRadius: borderRadius,
          label: Localization().getStringEx("panel.settings.home.account.personal_info.title", "Personal Info"),
          onTap: _onPersonalInfoClicked));
      }
      else if (code == 'family_members') {
        contentList.add(RibbonButton(
          height: null,
          border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
          borderRadius: borderRadius,
          label: Localization().getStringEx("panel.settings.home.account.family_members.title", "Family Members"),
          onTap: _onFamilyMembersClicked));
      }
    }

    return _OptionsSection(
      title: Localization().getStringEx("panel.settings.home.account.title", "Your Account"),
      widgets: contentList,
    );
  }

  void _onPersonalInfoClicked() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Personal Info");
      if (Auth().isLoggedIn) {
        Navigator.push(context, CupertinoPageRoute(builder: (context) => SettingsPersonalInfoPanel()));
      }
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onFamilyMembersClicked() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Family Members");
      if (Auth().isLoggedIn) {
        Navigator.push(context, CupertinoPageRoute(builder: (context) => SettingsFamilyMembersPanel()));
      }
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  // Feedback

  Widget _buildFeedback(){
    return Column(
      children: <Widget>[
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(
                Localization().getStringEx("panel.settings.home.feedback.title", "We need your ideas!"),
                style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20),
              ),
              Container(height: 5,),
              Text(
                Localization().getStringEx("panel.settings.home.feedback.description", "Enjoying the app? Missing something? Tap on the bottom to submit your idea."),
                style: TextStyle(fontFamily: Styles().fontFamilies.regular,color: Styles().colors.textBackground, fontSize: 16),
              ),
            ])
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: ScalableRoundedButton(
            label: Localization().getStringEx("panel.settings.home.button.feedback.title", "Submit Feedback"),
            hint: Localization().getStringEx("panel.settings.home.button.feedback.hint", ""),
            backgroundColor: Styles().colors.background,
            fontSize: 16.0,
            textColor: Styles().colors.fillColorPrimary,
            borderColor: Styles().colors.fillColorSecondary,
            showExternalLink: true,
            onTap: _onFeedbackClicked,
          ),
        ),
      ],
    );
  }

  void _onFeedbackClicked() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Provide Feedback");

      if (Connectivity().isNotOffline && (Config().feedbackUrl != null)) {
        String feedbackUrl = Config().feedbackUrl;

        String panelTitle = Localization().getStringEx('panel.settings.feedback.label.title', 'PROVIDE FEEDBACK');
        Navigator.push(
            context, CupertinoPageRoute(builder: (context) => WebPanel(url: feedbackUrl, title: panelTitle,)));
      }
      else {
        AppAlert.showOfflineMessage(context, Localization().getStringEx('panel.settings.label.offline.feedback', 'Providing a Feedback is not available while offline.'));
      }
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  // Debug

  Widget _buildDebug() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ScalableRoundedButton(
        label: Localization().getStringEx("panel.profile_info.button.debug.title", "Debug"),
        hint: Localization().getStringEx("panel.profile_info.button.debug.hint", ""),
        backgroundColor: Styles().colors.background,
        fontSize: 16.0,
        textColor: Styles().colors.fillColorPrimary,
        borderColor: Styles().colors.fillColorSecondary,
        onTap: () { _onDebugClicked(); },
      ),
    ); 
  }

  Widget _buildHeaderBarDebug() {
    return Semantics(
      label: Localization().getStringEx('panel.settings.home.button.debug.title', 'Debug'),
      hint: Localization().getStringEx('panel.settings.home.button.debug.hint', ''),
      button: true,
      excludeSemantics: true,
      child: IconButton(
        icon: Image.asset('images/debug-white.png'),
        onPressed: _onDebugClicked)
    );
  }

  void _onDebugClicked() {
    Analytics.instance.logSelect(target: "Debug");
    Navigator.push(context, CupertinoPageRoute(builder: (context) => DebugHomePanel()));
  }

  // Version Info

  Widget _buildVersionInfo(){
    return Container(
      alignment: Alignment.center,
      child:  Text(
        "Version: $_versionName",
        style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
    ));
  }

  void _loadVersionInfo() async {
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      setState(() {
        _versionName = packageInfo?.version;
      });
    });
  }

  // Utilities

  BorderRadius _borderRadiusFromIndex(int index, int length) {
    int first = 0;
    int last = length - 1;
    if ((index == first) && (index < last)) {
      return _topRounding;
    }
    else if ((first < index) && (index == last)) {
      return _bottomRounding;
    }
    else if ((index == first) && (index == last)) {
      return _allRounding;
    }
    else {
      return BorderRadius.zero;
    }
  }

  void _updateState() {
    Future.delayed(Duration(), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

}

class _OptionsSection extends StatelessWidget {
  final List<Widget> widgets;
  final String title;
  final String description;

  const _OptionsSection({Key key, this.widgets, this.title, this.description}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child:  Semantics( header: true,
              child: Text(title, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20),
            )),
          ),
          AppString.isStringEmpty(description)
              ? Container()
              : Padding(
                  padding: EdgeInsets.only(left: 8, right: 8, bottom: 12),
                  child: Text(
                    description,
                    style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
                  )),
          Stack(alignment: Alignment.topCenter, children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Styles().colors.surfaceAccent, width: 0.5),
                borderRadius: BorderRadius.circular(5.0),
              ),
              child: Padding(padding: EdgeInsets.all(0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets)),
            )
          ])
        ]));
  }
}

class _DebugContainer extends StatefulWidget {

  final Widget _child;

  _DebugContainer({@required Widget child}) : _child = child;

  _DebugContainerState createState() => _DebugContainerState();
}

class _DebugContainerState extends State<_DebugContainer> {

  int _clickedCount = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: widget._child,
      onTap: () {
        Log.d("On tap debug widget");
        _clickedCount++;
        if (_clickedCount == 7) {
          if (Auth().isDebugManager) {
            Navigator.push(context, CupertinoPageRoute(builder: (context) => DebugHomePanel()));
          }
          _clickedCount = 0;
        }
      },
    );
  }
}
