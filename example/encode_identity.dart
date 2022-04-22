import 'package:dart_esr/dart_esr.dart';

void main(List<String> arguments) => identityV3Example();

Future<void> identityV2Example() async {
  print('Identity');
  var esr = EOSIOSigningrequest('https://jungle2.cryptolions.io', 'v1',
      chainName: ChainName.EOS_JUNGLE2);

  var permission = IdentityPermission()
    ..actor = 'testname1111'
    ..permission = 'active';

  var identity = IdentityV2()..identityPermission = permission;
  String callback = "https://cNallback.com";

  var encoded = await esr.encodeIdentity(identity, callback);
  var decoded = esr.deserialize(encoded);

  print('encoded v2 : ' + encoded);
  print('decoded v2 : ' + decoded.toString());
}

Future<void> identityV3Example() async {
  print('Identity');
  var esr = EOSIOSigningrequest('https://jungle2.cryptolions.io', 'v1',
      chainName: ChainName.EOS_JUNGLE2);

  var permission = IdentityPermission()
    ..actor = 'testname1111'
    ..permission = 'active';

  var identity = IdentityV3()
    ..scope = 'example'
    ..identityPermission = permission;
  String callback = "https://cNallback.com";

  var encoded = await esr.encodeIdentity(identity, callback);
  var decoded = esr.deserialize(encoded);

  print('encoded v3 : ' + encoded);
  print('decoded v3 : ' + decoded.toString());
}
