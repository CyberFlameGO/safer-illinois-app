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

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Covid19.dart';
import 'package:illinois/utils/Crypt.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:pointycastle/export.dart' as PointyCastle;

class Covid19TransferEncryptionKeyPanel extends StatefulWidget {

  const Covid19TransferEncryptionKeyPanel({Key key}) : super(key: key);
  @override
  _Covid19TransferEncryptionKeyPanelState createState() => _Covid19TransferEncryptionKeyPanelState();
}

class _Covid19TransferEncryptionKeyPanelState extends State<Covid19TransferEncryptionKeyPanel> {

  PointyCastle.PublicKey _userHealthPublicKey;
  PointyCastle.PrivateKey _userHealthPrivateKey;
  bool _userHealthKeysLoading, _userHealthKeysPaired, _userHealthPublicKeyLoaded, _userHealthPrivateKeyLoaded;
  Uint8List _qrCodeBytes;
  bool _saving = false;

  @override
  void initState() {
    _userHealthKeysLoading = true;
    _loadHealthRSAPublicKey();
    _loadHealthRSAPrivateKey();
    super.initState();
  }

  void _loadHealthRSAPublicKey() {
    Health().loadRSAPublicKey().then((publicKey) {
      if (mounted) {
        _userHealthPublicKey = publicKey;
        _userHealthPublicKeyLoaded = true;
        _verifyHealthRSAKeys();
      }
    });
  }

  void _loadHealthRSAPrivateKey() {
    Health().loadRSAPrivateKey().then((privateKey) {
      if (mounted) {
        _userHealthPrivateKey = privateKey;
        _userHealthPrivateKeyLoaded = true;
        _verifyHealthRSAKeys();
      }
    });
  }

  void _verifyHealthRSAKeys() {

    if ((_userHealthPrivateKey != null) && (_userHealthPublicKey != null)) {
      RsaKeyHelper.verifyRsaKeyPair(PointyCastle.AsymmetricKeyPair<PointyCastle.PublicKey, PointyCastle.PrivateKey>(_userHealthPublicKey, _userHealthPrivateKey)).then((bool result) {
        if (mounted) {
          _userHealthKeysPaired = result;
          _buildHealthRSAQRCode();
        }
      });
    }
    else if ((_userHealthPrivateKeyLoaded == true) && (_userHealthPublicKeyLoaded == true)) {
      _finishHealthRSAKeysLoading();
    }
  }

  void _buildHealthRSAQRCode() {
    Uint8List privateKeyData = (_userHealthKeysPaired && (_userHealthPrivateKey != null)) ? RsaKeyHelper.encodePrivateKeyToPEMDataPKCS1(_userHealthPrivateKey) : null;
    List<int> privateKeyCompressedData = (privateKeyData != null) ? GZipEncoder().encode(privateKeyData) : null;
    String privateKeyString = (privateKeyData != null) ? base64.encode(privateKeyCompressedData) : null;
    if (privateKeyString != null) {
      NativeCommunicator().getBarcodeImageData({
        'content': privateKeyString,
        'format': 'qrCode',
        'width': 1024,
        'height': 1024,
      }).then((Uint8List qrCodeBytes) {
        if (mounted) {
          _qrCodeBytes = qrCodeBytes;
          _finishHealthRSAKeysLoading();
        }
      });
    }
    else {
      _finishHealthRSAKeysLoading();
    }
  }

  void _finishHealthRSAKeysLoading() {
    setState(() {
      _userHealthKeysLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(
          Localization().getStringEx('panel.covid19.transfer.title', 'Transfer Encryption Key'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      body: Column(children: <Widget>[
        Expanded(child:
          Padding(padding: EdgeInsets.all(24), child:
            _userHealthKeysLoading ? _buildWaitingContent() : _buildPrivateKeyContent()
          ),
        ),
      ],),
      backgroundColor: Styles().colors.background,
    );
  }

  Widget _buildWaitingContent() {
    return Center(child:
      CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
    );
  }

  Widget _buildPrivateKeyContent(){
    return SingleChildScrollView(
      child: (_qrCodeBytes != null) ? _buildQrCodeContent() : _buildNoQrCodeContent(),
    );
  }

  Widget _buildQrCodeContent(){
    return Column( children: <Widget>[
        Container(height: 15,),
        Semantics( header: true, hint: Localization().getStringEx("app.common.heading.one.hint","Header 1"),
          child:Text(Localization().getStringEx("panel.covid19.transfer.primary.heading.title", "Your COVID-19 Encryption Key"),
            textAlign: TextAlign.left,
            style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 28, color:Styles().colors.fillColorPrimary),
          )),
        Container(height: 30,),
        _buildQrCode(),
        Container(height: 20,),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: RoundedButton(
            label: Localization().getStringEx("panel.covid19.transfer.primary.button.save.title", "Save Your Encryption Key"),
            hint: Localization().getStringEx("panel.covid19.transfer.primary.button.save.hint", ""),
            borderColor: Styles().colors.fillColorSecondaryVariant,
            backgroundColor: Styles().colors.surface,
            fontSize: 16,
            height: 40,
            padding: EdgeInsets.symmetric(vertical: 5),
            textColor: Styles().colors.fillColorPrimary,
            onTap: _onSaveImage,
          ),
        ),
        Container(height: 30,)
      ],
    );
  }

  Widget _buildNoQrCodeContent(){
    return Column( children: <Widget>[
      Container(height: 15,),
      Semantics( header: true, hint: Localization().getStringEx("app.common.heading.one.hint","Header 1"),
        child:Text(Localization().getStringEx("panel.covid19.transfer.secondary.heading.title", "Missing COVID-19 Encryption Key"),
          textAlign: TextAlign.left,
          style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 28, color:Styles().colors.fillColorPrimary),
        )),
      Container(height: 30,),
      _buildAction(
          heading: Localization().getStringEx("panel.covid19.transfer.secondary.button.scan.heading", "If you are adding a second device:"),
          description: Localization().getStringEx("panel.covid19.transfer.secondary.button.scan.description", "If you still have access to your primary device, you can directly scan the COVID-19 Encryption Key QR code from that device."),
          title: Localization().getStringEx("panel.covid19.transfer.secondary.button.scan.title", "Scan Your QR Code"),
          iconRes: "images/fill-1.png",
          onTap: _onScan
      ),
      Container(height: 12,),
      _buildAction(
          heading: Localization().getStringEx("panel.covid19.transfer.secondary.button.retrieve.heading", "If you are using a replacement device:"),
          description: Localization().getStringEx("panel.covid19.transfer.secondary.button.retrieve.description", "If you no longer have access to your primary device, but saved your QR code to a cloud photo service, you can transfer your COVID-19 Encryption Key by retrieving it from your photos."),
          title: Localization().getStringEx("panel.covid19.transfer.secondary.button.retrieve.title", "Retrieve Your QR Code"),
          iconRes: "images/group-10.png",
          onTap: _onRetrieve
      ),
      Container(height: 12,),
      Container(height: 40,)
    ],
);
  }

  Widget _buildQrCode(){
    return Container(
      decoration: BoxDecoration(
          color: Styles().colors.white,
          borderRadius: BorderRadius.all( Radius.circular(5))),
      padding: EdgeInsets.all(1),
      child: Semantics(child:
        Image.memory(_qrCodeBytes, fit: BoxFit.fitWidth, semanticLabel: Localization().getStringEx("panel.covid19.transfer.primary.heading.title", "Your COVID-19 Encryption Key"),
      )),
    );
  }

  Widget _buildAction({String heading, String description, String title, String iconRes, Function onTap}){
    return Semantics(container: true, child:Container(
        decoration: BoxDecoration(
        color: Styles().colors.white,
        borderRadius: BorderRadius.all( Radius.circular(5))),
        child: Column(
          children: <Widget>[
            Container(height: 18,),
            Container( padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(heading, style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color:Styles().colors.fillColorPrimary))),
            Container(height: 9,),
            Container( padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(description, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 14, color:Styles().colors.fillColorPrimary))),
            Container(height: 14,),
            Semantics(
               explicitChildNodes: true,
              child: Container(child:
                GestureDetector(
                  onTap: onTap,
                  child:Container(
                    decoration: BoxDecoration(
                        color: Styles().colors.background,
                        borderRadius: BorderRadius.only( bottomLeft: Radius.circular(5), bottomRight: Radius.circular(5)),
                        border: Border.all(color: Styles().colors.surfaceAccent,)
                    ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    children: <Widget>[
                      Image.asset(iconRes, excludeFromSemantics: true,),
                      Container(width: 7,),
                      Semantics(button: true, excludeSemantics:false, child:
                        Text(title, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 14, color:Styles().colors.fillColorPrimary))),
                      Expanded(child: Container(),),
                      Image.asset('images/chevron-right.png',excludeFromSemantics: true,),
                    ],
                  ))))),
          ],
        )
    ));
  }

  void _onSaveImage(){
    Analytics.instance.logSelect(target: "Save Your Encryption Key");
    if(!_saving) {
      setState(() {
        _saving = true;
      });
      Covid19Utils.saveQRCodeImageToPictures(qrCodeBytes: _qrCodeBytes, title: Localization().getStringEx("panel.covid19.transfer.label.qr_image_label", "Safer Illinois COVID-19 Code")).then((bool result) {
        setState(() {
          _saving = false;
        });
        String platformTargetText = (defaultTargetPlatform == TargetPlatform.android) ? Localization().getStringEx("panel.covid19.transfer.alert.save.success.pictures", "Pictures") : Localization().getStringEx("panel.covid19.transfer.alert.save.success.gallery", "Gallery");
        String message = result
            ? (Localization().getStringEx("panel.covid19.transfer.alert.save.success.msg", "Successfully saved qr code in ") + platformTargetText)
            : Localization().getStringEx("panel.covid19.transfer.alert.save.fail.msg", "Failed to save qr code in ") + platformTargetText;
        AppAlert.showDialogResult(context, message);
      });
    }
  }

  void _onScan(){
    Analytics.instance.logSelect(target: "Scan Your QR Code");
    BarcodeScanner.scan().then((ScanResult scanResult) {
      // barcode_scan plugin returns 8 digits when it cannot read the qr code. Prevent it from storing such values
      if ((scanResult.type == ResultType.Barcode) && AppString.isStringNotEmpty(scanResult.rawContent) && (8 < scanResult.rawContent.length)) {
        _onCovid19QrCodeScanSucceeded(scanResult.rawContent);
      }
      else if (scanResult.type != ResultType.Cancelled) {
        AppAlert.showDialogResult(context, Localization().getStringEx('panel.covid19.transfer.alert.qr_code.scan.failed.msg', 'Failed to read QR code.'));
      }
    });
  }

  void _onRetrieve() {
    Analytics.instance.logSelect(target: "Retrieve Your QR Code");
    Covid19Utils.loadQRCodeImageFromPictures().then((String qrCodeString) {
      _onCovid19QrCodeScanSucceeded(qrCodeString);
    });
  }

  void _onCovid19QrCodeScanSucceeded(String result) {

    PointyCastle.PrivateKey privateKey;
    try {
      Uint8List pemCompressedData = (result != null) ? base64.decode(result) : null;
      List<int> pemData = (pemCompressedData != null) ? GZipDecoder().decodeBytes(pemCompressedData) : null;
      privateKey = (pemData != null) ? RsaKeyHelper.parsePrivateKeyFromPemData(pemData) : null;
    }
    catch (e) { print(e?.toString()); }
    
    if (privateKey != null) {
      RsaKeyHelper.verifyRsaKeyPair(PointyCastle.AsymmetricKeyPair<PointyCastle.PublicKey, PointyCastle.PrivateKey>(_userHealthPublicKey, privateKey)).then((bool result) {
        if (mounted) {
          if (result == true) {
            Health().setUserRSAPrivateKey(privateKey).then((success) {
              if (mounted) {
                String resultMessage = success ?
                    Localization().getStringEx("panel.covid19.transfer.alert.qr_code.transfer.succeeded.msg", "COVID-19 secret transferred successfully.") :
                    Localization().getStringEx("panel.covid19.transfer.alert.qr_code.transfer.failed.msg", "Failed to transfer COVID-19 secret.");
                AppAlert.showDialogResult(context, resultMessage);
              }
            });
          }
          else {
            AppAlert.showDialogResult(context, Localization().getStringEx('panel.covid19.transfer.alert.qr_code.not_match.msg', 'COVID-19 secret key does not match existing public RSA key.'));
          }
        }
      });
    }
    else {
      AppAlert.showDialogResult(context, Localization().getStringEx('panel.covid19.transfer.alert.qr_code.invalid.msg', 'Invalid QR code.'));
    }
  }

}
