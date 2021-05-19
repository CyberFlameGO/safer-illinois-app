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
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as Http;

import 'package:collection/collection.dart';
import 'package:illinois/model/UserProfile.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/UserProfile.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:path/path.dart';

class FlexUI with Service implements NotificationsListener {

  static const String notifyChanged  = "edu.illinois.rokwire.health.flexui.changed";

  static const String _flexUIName   = "flexUI.json";

  Map<String, dynamic> _content;
  Map<String, dynamic> _contentSource;
  Set<dynamic>         _features;
  File                 _cacheFile;
  DateTime             _pausedDateTime;

  // Singleton Factory

  FlexUI._internal();
  static final FlexUI _instance = FlexUI._internal();

  factory FlexUI() {
    return _instance;
  }

  FlexUI get instance {
    return _instance;
  }

  // Service

  @override
  void createService() {
    NotificationService().subscribe(this,[
      UserProfile.notifyProfileUpdated,
      UserProfile.notifyProfileDeleted,
      UserProfile.notifyRolesUpdated,
      Auth.notifyAuthTokenChanged,
      Auth.notifyCardChanged,
      Auth.notifyUserPiiDataChanged,
      Health.notifyUserUpdated,
      AppLivecycle.notifyStateChanged,
    ]);
  }

  @override
  void destroyService() {
    NotificationService().unsubscribe(this);
  }

  @override
  Future<void> initService() async {
    _cacheFile = await _getCacheFile();
    _contentSource = await _loadContentSource();
    _content = _buildContent(_contentSource);
    _features = _buildFeatures(_content);
    _updateContentSourceFromNet();
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([Config(), UserProfile(), Auth(), Health()]);
  }

  @override
  Future<void> clearService() async {
    await AppFile.delete(_cacheFile);
    _cacheFile = null;
    _content = null;
    _contentSource = null;
    _features = null;
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if ((name == UserProfile.notifyRolesUpdated) ||
        (name == UserProfile.notifyProfileUpdated) ||
        (name == UserProfile.notifyProfileDeleted))
    {
      _updateContent();
    }
    else if ((name == Auth.notifyAuthTokenChanged) ||
        (name == Auth.notifyCardChanged) || 
        (name == Auth.notifyUserPiiDataChanged))
    {
      _updateContent();
    }
    else if ((name == Health.notifyUserUpdated)) {
      _updateContent();
    }
    else if (name == AppLivecycle.notifyStateChanged) {
     _onAppLivecycleStateChanged(param); 
    }
  }

  void _onAppLivecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedDateTime = DateTime.now();
    }
    else if (state == AppLifecycleState.resumed) {
      if (_pausedDateTime != null) {
        Duration pausedDuration = DateTime.now().difference(_pausedDateTime);
        if (Config().refreshTimeout < pausedDuration.inSeconds) {
          _updateContentSourceFromNet();
        }
      }
    }
  }

  // Flex UI

  Future<File> _getCacheFile() async {
    Directory assetsDir = Config().assetsCacheDir;
    if ((assetsDir != null) && !await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
    }
    String cacheFilePath = join(assetsDir.path, _flexUIName);
    return File(cacheFilePath);
  }

  Future<String> _loadContentSourceStringFromCache() async {
    return ((_cacheFile != null) && await _cacheFile.exists()) ? await _cacheFile.readAsString() : null;
  }

  Future<void> _saveContentSourceStringToCache(String contentString) async {
    if (contentString != null) {
      await _cacheFile?.writeAsString(contentString, flush: true);
    }
    else if ((_cacheFile != null) && (await _cacheFile.exists())) {
      try { _cacheFile.delete(); } catch(e) { print(e?.toString()); }
    }
  }

  Future<Map<String, dynamic>> _loadContentSourceFromCache() async {
    return AppJson.decodeMap(await _loadContentSourceStringFromCache());
  }

  Future<Map<String, dynamic>> _loadContentSourceFromAssets() async {
    return AppJson.decodeMap(await rootBundle.loadString('assets/$_flexUIName'));
  }

  Future<Map<String, dynamic>> _loadContentSource() async {
    Map<String, dynamic> conentSource;
    if (_isValidContentSource(conentSource = await _loadContentSourceFromCache())) {
      return conentSource;
    }
    else if (_isValidContentSource(conentSource = await _loadContentSourceFromAssets())) {
      return conentSource;
    }
    else {
      return null;
    }
  }

  Future<String> _loadContentSourceStringFromNet() async {
    Http.Response response = (Config().assetsUrl != null) ? await Network().get("${Config().assetsUrl}/$_flexUIName") : null;
    return ((response != null) && (response.statusCode == 200)) ? response.body : null;
  }

  Future<void> _updateContentSourceFromNet() async {
    String contentSourceString = await _loadContentSourceStringFromNet();
    if (contentSourceString != null) { // request succeeded
      
      Map<String, dynamic> contentSource = AppJson.decodeMap(contentSourceString);
      if (!_isValidContentSource(contentSource) && (_cacheFile != null) && await _cacheFile.exists()) { // empty JSON content
        await AppFile.delete(_cacheFile);                     // clear cached content source
        contentSource = await _loadContentSourceFromAssets(); // load content source from assets
        contentSourceString = null;                           // do not store this content source
      }

      if (_isValidContentSource(contentSource) && ((_contentSource == null) || !DeepCollectionEquality().equals(_contentSource, contentSource))) {
        _contentSource = contentSource;
        _saveContentSourceStringToCache(contentSourceString);
        _updateContent();
      }
    }
  }

  void _updateContent() {
    Map<String, dynamic> content = _buildContent(_contentSource);
    if ((content != null) && ((_content == null) || !DeepCollectionEquality().equals(_content, content))) {
      _content = content;
      _features = _buildFeatures(_content);
      NotificationService().notify(notifyChanged, null);
    }
  }

  static Set<dynamic> _buildFeatures(Map<String, dynamic> content) {
    dynamic featuresList = (content != null) ? content['features'] : null;
    return (featuresList is Iterable) ? Set.from(featuresList) : null;
  }

  static bool _isValidContentSource(Map<String, dynamic> contentSource) {
    return (contentSource != null) && (contentSource['content'] is Map) && (contentSource['rules'] is Map);
  }

  // Content

  Map<String, dynamic> get content {
    return _content;
  }

  dynamic operator [](dynamic key) {
    return (_content != null) ? _content[key] : null;
  }

  Set<dynamic> get features {
    return _features;
  }

  bool hasFeature(String feature) {
    return (_features == null) || _features.contains(feature);
  }

  void update() {
    return _updateContent();
  }

  // Local Build

  static Map<String, dynamic> _buildContent(Map<String, dynamic> contentSource) {
    Map<String, dynamic> result;
    if (contentSource != null) {
      Map<String, dynamic> contents = contentSource['content'];
      Map<String, dynamic> rules = contentSource['rules'];

      result = Map();
      contents.forEach((String key, dynamic list) {
        if (list is List) {
          List<String> resultList = <String>[];
          for (String entry in list) {
            if (_localeIsEntryAvailable(entry, group: key, rules: rules)) {
              resultList.add(entry);
            }
          }
          result[key] = resultList;
        }
        else {
          result[key] = list;
        }
      });
    }
    return result;
  }

  static bool _localeIsEntryAvailable(String entry, { String group, Map<String, dynamic> rules }) {

    String pathEntry = (group != null) ? '$group.$entry' : null;

    Map<String, dynamic> roleRules = (rules != null) ? rules['roles'] : null;
    dynamic roleRule = (roleRules != null) ? (((pathEntry != null) ? roleRules[pathEntry] : null) ?? roleRules[entry]) : null;
    if ((roleRule != null) && !_localeEvalRoleRule(roleRule)) {
      return false;
    }

    Map<String, dynamic> authRules = (rules != null) ? rules['auth'] : null;
    dynamic authRule = (authRules != null) ? (((pathEntry != null) ? authRules[pathEntry] : null) ?? authRules[entry])  : null;
    if ((authRule != null) && !_localeEvalAuthRule(authRule)) {
      return false;
    }
    
    Map<String, dynamic> platformRules = (rules != null) ? rules['platform'] : null;
    dynamic platformRule = (platformRules != null) ? (((pathEntry != null) ? platformRules[pathEntry] : null) ?? platformRules[entry])  : null;
    if ((platformRule != null) && !_localeEvalPlatformRule(platformRule)) {
      return false;
    }

    Map<String, dynamic> enableRules = (rules != null) ? rules['enable'] : null;
    dynamic enableRule = (enableRules != null) ? (((pathEntry != null) ? enableRules[pathEntry] : null) ?? enableRules[entry])  : null;
    if ((enableRule != null) && !_localeEvalEnableRule(enableRule)) {
      return false;
    }
    
    return true;
  }

  static bool _localeEvalRoleRule(dynamic roleRule) {
    
    if (roleRule is String) {

      if (roleRule == 'TRUE') {
        return true;
      }
      if (roleRule == 'FALSE') {
        return false;
      }
      
      UserRole userRole = UserRole.fromString(roleRule);
      if (userRole != null) {
        Set<UserRole> userRoles = UserProfile().roles;
        return (userRoles != null) && (userRoles.contains(userRole));
      }
    }
    
    if (roleRule is List) {
      
      if (roleRule.length == 1) {
        return _localeEvalRoleRule(roleRule[0]);
      }
      
      if (roleRule.length == 2) {
        dynamic operation = roleRule[0];
        dynamic argument = roleRule[1];
        if (operation is String) {
          if (operation == 'NOT') {
            return !_localeEvalRoleRule(argument);
          }
        }
      }

      if (roleRule.length > 2) {
        bool result = _localeEvalRoleRule(roleRule[0]);
        for (int index = 1; (index + 1) < roleRule.length; index += 2) {
          dynamic operation = roleRule[index];
          dynamic argument = roleRule[index + 1];
          if (operation is String) {
            if (operation == 'AND') {
              result = result && _localeEvalRoleRule(argument);
            }
            else if (operation == 'OR') {
              result = result || _localeEvalRoleRule(argument);
            }
          }
        }
        return result;
      }
    }
    
    return true; // allow everything that is not defined or we do not understand
  }

  static bool _localeEvalAuthRule(dynamic authRule) {
    bool result = true;  // allow everything that is not defined or we do not understand
    if (authRule is Map) {
      authRule.forEach((dynamic key, dynamic value) {
        if (key is String) {
          if ((key == 'loggedIn') && (value is bool)) {
            result = result && (Auth().isLoggedIn == value);
          }
          else if ((key == 'shibbolethLoggedIn') && (value is bool)) {
            result = result && (Auth().isShibbolethLoggedIn == value);
          }
          else if ((key == 'phoneLoggedIn') && (value is bool)) {
            result = result && (Auth().isPhoneLoggedIn == value);
          }
          
          else if ((key == 'healthLoggedIn') && (value is bool)) {
            result = result && (Health().isUserLoggedIn == value);
          }
          else if ((key == 'healthMultipleAccounts') && (value is bool)) {
            result = result && (Health().userMultipleAccounts == value);
          }
          
          else if ((key == 'shibbolethMemberOf') && (value is String)) {
            result = result && Auth().isMemberOf(value);
          }
          else if ((key == 'eventEditor') && (value is bool)) {
            result = result && (Auth().isEventEditor == value);
          }
          else if ((key == 'stadiumPollManager') && (value is bool)) {
            result = result && (Auth().isStadiumPollManager == value);
          }
          
          else if ((key == 'iCard') && (value is bool)) {
            result = result && ((Auth().authCard != null) == value);
          }
          else if ((key == 'iCardNum') && (value is bool)) {
            result = result && ((0 < (Auth().authCard?.cardNumber?.length ?? 0)) == value);
          }
          else if ((key == 'iCardLibraryNum') && (value is bool)) {
            result = result && ((0 < (Auth().authCard?.libraryNumber?.length ?? 0)) == value);
          }
        }
      });
    }
    return result;
  }

  static bool _localeEvalPlatformRule(dynamic platformRule) {
    bool result = true;  // allow everything that is not defined or we do not understand
    if (platformRule is Map) {
      platformRule.forEach((dynamic key, dynamic value) {
        if (key is String) {
          if (key == 'os') {
            if (value is List) {
              result = result && value.contains(Platform.operatingSystem);
            }
            else if (value is String) {
              result = result && (value == Platform.operatingSystem);
            }
          }
        }
      });
    }
    return result;
  }

  static bool _localeEvalEnableRule(dynamic enableRule) {
    return (enableRule is bool) ? enableRule : true; // allow everything that is not defined or we do not understand
  }
}