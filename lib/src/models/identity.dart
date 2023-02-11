import 'dart:typed_data';
import 'package:json_annotation/json_annotation.dart';

import 'package:eosdart/eosdart.dart';

part 'identity.g.dart';

@JsonSerializable(explicitToJson: true)
abstract class Identity {
  @JsonKey(name: 'permission')
  late IdentityPermission identityPermission;

  Map<String, dynamic> toJson();

  Uint8List toBinary(Type type) {
    var buffer = SerialBuffer(Uint8List(0));
    type.serialize!(type, buffer, this.toJson());
    return buffer.asUint8List();
  }
}

@JsonSerializable(explicitToJson: true)
class IdentityV2 extends Identity {
  IdentityV2();

  factory IdentityV2.fromJson(Map<String, dynamic> json) =>
      _$IdentityV2FromJson(json) as IdentityV2;

  @override
  Map<String, dynamic> toJson() => _$IdentityV2ToJson(this);

  @override
  String toString() => this.toJson().toString();
}

@JsonSerializable(explicitToJson: true)
class IdentityV3 extends Identity {
  @JsonKey(name: 'scope')
  late String scope;

  IdentityV3();

  factory IdentityV3.fromJson(Map<String, dynamic> json) =>
      _$IdentityV3FromJson(json) as IdentityV3;

  @override
  Map<String, dynamic> toJson() => _$IdentityV3ToJson(this);

  @override
  String toString() => this.toJson().toString();
}

@JsonSerializable(explicitToJson: true)
class IdentityPermission {
  @JsonKey(name: 'actor')
  late String actor;

  @JsonKey(name: 'permission')
  late String permission;

  IdentityPermission();

  factory IdentityPermission.fromJson(Map<String, dynamic> json) =>
      _$IdentityPermissionFromJson(json);

  Map<String, dynamic> toJson() => _$IdentityPermissionToJson(this);

  @override
  String toString() => this.toJson().toString();
}
