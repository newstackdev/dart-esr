part of 'identity.dart';

Identity _$IdentityV2FromJson(Map<String, dynamic> json) {
  return IdentityV2()..identityPermission = json['permission'];
}

Map<String, dynamic> _$IdentityV2ToJson(IdentityV2 instance) => <String, dynamic>{
      'permission': instance.identityPermission.toJson(),
    };

IdentityPermission _$IdentityPermissionFromJson(Map<String, dynamic> json) {
  return IdentityPermission()
    ..actor = json['actor'] as String
    ..permission = json['permission'] as String;
}

Map<String, dynamic> _$IdentityPermissionToJson(IdentityPermission instance) =>
    <String, dynamic>{
      'actor': instance.actor,
      'permission': instance.permission
    };

Identity _$IdentityV3FromJson(Map<String, dynamic> json) {
  return IdentityV3()
    ..scope = json['scope']
    ..identityPermission = json['permission'];
}

Map<String, dynamic> _$IdentityV3ToJson(IdentityV3 instance) => <String, dynamic>{
  'scope': instance.scope,
  'permission': instance.identityPermission.toJson(),
};
