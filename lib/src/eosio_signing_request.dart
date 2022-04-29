import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:dart_esr/src/serializeUtils.dart';
import 'package:dart_esr/src/signing_request_json.dart';

import 'package:dart_esr/src/utils/base64u.dart';
import 'package:dart_esr/src/utils/esr_constant.dart';

import 'package:dart_esr/src/models/identity.dart';
import 'package:dart_esr/src/models/signing_request.dart';

import 'package:eosdart/eosdart.dart' as eosDart;

/**
 * The callback payload sent to background callbacks.
 */
class CallbackPayload {
  // /** The first signature. */
  String sig;
  /** Transaction ID as HEX-encoded string. */
  String tx;
  /** Block number hint (only present if transaction was broadcast). */
  String bn;
  /** Signer authority, aka account name. */
  String sa;
  /** Signer permission, e.g. "active". */
  String sp;
  /** Reference block num used when resolving request. */
  String rbn;
  /** Reference block id used when resolving request. */
  String rid;
  /** The originating signing request packed as a uri string. */
  String req;
  /** Expiration time used when resolving request. */
  String ex;
  /** The resolved chain id.  */
  String cid;
  /** All signatures 0-indexed as `sig0`, `sig1`, etc. */
  List<String> sigX = [];
}

/**
 * Context used to resolve a callback.
 * Compatible with the JSON response from a `push_transaction` call.
 */
class ResolvedCallback {
  /** The URL to hit. */
  String url;
  /**
     * Whether to run the request in the background. For a https url this
     * means POST in the background instead of a GET redirect.
     */
  bool background;
  /**
     * The callback payload as a object that should be encoded to JSON
     * and POSTed to background callbacks.
     */
  CallbackPayload payload;
}

class EOSIOSigningrequest {
  EOSSerializeUtils _client;
  Map<int, Map<String, eosDart.Type>> _signingRequestTypes;
  SigningRequest _signingRequest;
  Uint8List _request;
  int _version;
  String _esrURI;
  eosDart.Transaction _resolveTransaction;

  EOSIOSigningrequest(String nodeUrl, String nodeVersion,
      {String chainId, ChainName chainName, int flags = 1, String callback = '', List info, int version = 2}) {
    this._signingRequest = SigningRequest();
    this._client = EOSSerializeUtils(nodeUrl, nodeVersion);

    this._signingRequestTypes = {
      2: eosDart.getTypesFromAbi(eosDart.createInitialTypes(), eosDart.Abi.fromJson(json.decode(signingRequestJsonV2))),
      3: eosDart.getTypesFromAbi(eosDart.createInitialTypes(), eosDart.Abi.fromJson(json.decode(signingRequestJsonV3)))
    };

    this.setChainId(chainName: chainName, chainId: chainId);
    this.setOtherFields(flags: flags, callback: callback, info: info != null ? info : []);
    this._version = version;
  }

  void setNode(String nodeUrl, String nodeVersion) {
    _client = EOSSerializeUtils(nodeUrl, nodeVersion);
  }

  void setChainId({ChainName chainName, String chainId}) {
    if (chainName != null) {
      _signingRequest.chainId = ['chain_alias', ESRConstants.getChainAlias(chainName)];
      return;
    } else if (chainId != null) {
      _signingRequest.chainId = ['chain_id', chainId];
      return;
    } else {
      throw 'Either "ChainName" or "ChainId" must be set';
    }
  }

  void setOtherFields({int flags, String callback, List info}) {
    if (flags != null) this._signingRequest.flags = flags;
    if (callback != null) this._signingRequest.callback = callback;
    if (info != null) this._signingRequest.info = info;
  }

  Future<String> encodeTransaction(eosDart.Transaction transaction) async {
    await _client.fullFillTransaction(transaction);
    _signingRequest.req = ['transaction', transaction.toJson()];
    return this._encode();
  }

  Future<String> encodeAction(eosDart.Action action) async {
    await this._client.serializeActions([action]);
    _signingRequest.req = ['action', action.toJson()];
    return this._encode();
  }

  Future<String> encodeActions(List<eosDart.Action> actions) async {
    await this._client.serializeActions(actions);
    var jsonAction = [];
    for (var action in actions) {
      jsonAction.add(action.toJson());
    }
    _signingRequest.req = ['action[]', jsonAction];
    return this._encode();
  }

  Future<String> encodeIdentity(Identity identity, String callback) async {
    if (callback == null) {
      throw 'Callback is needed';
    }

    if (identity is IdentityV3) {
      this._version = 3;
    }

    _signingRequest.req = ['identity', identity.toJson()];
    _signingRequest.callback = callback;
    _signingRequest.flags = 0;

    return this._encode();
  }

  Future<String> _encode() async {
    this._request = _signingRequest.toBinary(_signingRequestTypes[this._version]['signing_request']);

    this._compressRequest();
    this._addVersionHeaderToRequest();

    return this._requestToBase64();
  }

  void decode(String encodedRequest) {
    var request = '';
    if (encodedRequest.startsWith('esr://')) {
      request = encodedRequest.substring(6);
    } else if (encodedRequest.startsWith('esr:')) {
      request = encodedRequest.substring(4);
    } else {
      throw 'Invalid encoded EOSIO signing request';
    }

    var decoded = Base64u().decode(request);
    var header = decoded[0];
    this._version = header & ~(1 << 7);
    var list = Uint8List(decoded.length - 1);

    list = decoded.sublist(1);
    var decompressed = ZLibCodec(raw: true).decode(list);

    this._signingRequest =
        SigningRequest.fromBinary(_signingRequestTypes[this._version]['signing_request'], decompressed);
  }

  SigningRequest deserialize(String encodedRequest) {
    _esrURI = encodedRequest;
    this.decode(encodedRequest);
    return _signingRequest;
  }

  List<eosDart.Action> getRawActions(eosDart.Authorization authorization) {
    var req = _signingRequest.req;
    List<eosDart.Action> actions;
    switch (req[0]) {
      case 'action':
        {}
        break;
      case 'action[]':
        {}
        break;
      case 'identity':
        {
          Map permission = req[1]['permission'];
          if (permission == null ||
              permission['actor'] == ESRConstants.PlaceholderName ||
              permission['permission'] == ESRConstants.PlaceholderPermission) {
            // permission = ESRConstants.PlaceholderAuth;
            permission = authorization.toJson();
          }

          var identityPermission = IdentityPermission.fromJson(new Map<String, dynamic>.from(permission));

          // var identityPermission = IdentityPermission.fromJson(authorization.toJson());

          var identity;
          if (_version == 2) {
            identity = IdentityV2()..identityPermission = identityPermission;
          } else if (_version == 3) {
            identity = IdentityV3()
              ..scope = req[1]['scope']
              ..identityPermission = identityPermission;
          }
          var data = identity.toBinary(_signingRequestTypes[_version]['identity']);
          actions = [
            eosDart.Action()
              ..account = ''
              ..name = 'identity'
              ..authorization = [eosDart.Authorization.fromJson(new Map<String, dynamic>.from(permission))]
              // ..authorization = [authorization]
              ..data = data
          ];
        }
        break;
      default:
        throw 'Invalid signing request data';
    }
    return actions;
  }

  eosDart.Transaction getRawTransaction(eosDart.Authorization authorization) {
    var req = _signingRequest.req;
    switch (req[0]) {
      case 'transaction':
        return eosDart.Transaction.fromJson(req[1]);
      case 'action':
      case 'action[]':
      case 'identity':
        return eosDart.Transaction()..actions = getRawActions(authorization);
      default:
        throw 'Invalid signing request data';
    }
  }

  List<eosDart.Action> resolveAction(Type type, eosDart.Authorization authorization, List<eosDart.Action> actions) {
    List<eosDart.Action> resolveActions;
    for (var action in actions) {}
  }

  eosDart.Transaction resolveTransaction(eosDart.Authorization authorization) {
    var transaction = getRawTransaction(authorization);
    // var actions = resolveAction(type, authorization, transaction.actions);
    // return transaction..actions = actions;
    return transaction;
  }

  eosDart.Transaction resolve(eosDart.Authorization authorization) {
    if (this._signingRequest == null) throw 'Must decode signing request before resolve it!';
    return resolveTransaction(authorization);
    // var resolveTransaction = getRawTransaction(_signingRequest, authorization);
  }

  ResolvedCallback getCallback(eosDart.Transaction signedTx, eosDart.Authorization authorization) {
    var callbackPayload = CallbackPayload()
      ..sig = signedTx.signatures.toString()
      ..bn = signedTx.refBlockNum.toString()
      ..ex = signedTx.expiration.toIso8601String()
      ..rbn = signedTx.refBlockNum.toString()
      ..req = _esrURI
      ..rid = signedTx.refBlockPrefix.toString() // TODO: block id
      ..sa = authorization.actor
      ..sp = authorization.permission
      ..cid = _signingRequest.chainId.toString();

    // TODO: multisig

    return ResolvedCallback()
      ..url = this._signingRequest.callback
      ..background = this._signingRequest.background
      ..payload = callbackPayload;
  }

  void _compressRequest() {
    var encoded = ZLibCodec(raw: true).encode(this._request);
    this._request = Uint8List.fromList(encoded);
  }

  void _addVersionHeaderToRequest() {
    var list = Uint8List(this._request.length + 1);
    list[0] = this._version | 1 << 7;
    for (int i = 1; i < list.length; i++) {
      list[i] = this._request[i - 1];
    }
    this._request = list;
  }

  String _requestToBase64() {
    var encoded = Base64u().encode(Uint8List.fromList(this._request));
    return ESRConstants.Scheme + '//' + encoded;
  }
}
