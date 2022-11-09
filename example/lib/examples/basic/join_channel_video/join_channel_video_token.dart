import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class JoinChannelVideoToken extends StatefulWidget {
  const JoinChannelVideoToken({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<JoinChannelVideoToken> {
  late final RtcEngine _engine;
  bool _isReadyPreview = false;

  bool isJoined = false, switchCamera = true, switchRender = true;
  Set<int> remoteUid = {};
  static const String appId = '<Your App Id>';
  static const String channelId = 'test_channel_id';
  static const String hostUrl = '<Your Host Url>';

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  @override
  void dispose() {
    super.dispose();
    _dispose();
  }

  Future<void> _dispose() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  Future<void> _initEngine() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: appId,
    ));

    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        setState(() {
          isJoined = true;
        });
      },
      onUserJoined: (RtcConnection connection, int rUid, int elapsed) {
        setState(() {
          remoteUid.add(rUid);
        });
      },
      onUserOffline:
          (RtcConnection connection, int rUid, UserOfflineReasonType reason) {
        setState(() {
          remoteUid.removeWhere((element) => element == rUid);
        });
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        setState(() {
          isJoined = false;
          remoteUid.clear();
        });
      },
      onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
        _fetchToken(1234, channelId, 1, false);
      },
      onRequestToken: (RtcConnection connection) {
        _fetchToken(1234, channelId, 1, true);
      },
    ));

    await _engine.enableVideo();

    await _engine.startPreview();
    await _fetchToken(1234, channelId, 1, true);

    setState(() {
      _isReadyPreview = true;
    });
  }

  Future<void> _fetchToken(
    int uid,
    String channelName,
    int toeknRole,
    bool needJoinChannel,
  ) async {
    var client = http.Client();
    try {
      Map<String, String> headers = {
        'Content-type': 'application/json',
        'Accept': 'application/json',
      };

      var response = await client.post(Uri.parse(hostUrl),
          headers: headers,
          body: jsonEncode(
              {'uid': uid, 'ChannelName': channelName, 'role': toeknRole}));
      var decodedResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map;

      final token = decodedResponse['token'];
      if (needJoinChannel) {
        await _engine.joinChannel(
          token: token,
          channelId: channelName,
          uid: uid,
          options: const ChannelMediaOptions(
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );
      } else {
        await _engine.renewToken(token);
      }
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReadyPreview) return Container();
    return Stack(
      children: [
        AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine,
            canvas: const VideoCanvas(uid: 0),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.of(remoteUid.map(
                (e) => SizedBox(
                  width: 120,
                  height: 120,
                  child: AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine,
                      canvas: VideoCanvas(uid: e),
                      connection: const RtcConnection(channelId: channelId),
                    ),
                  ),
                ),
              )),
            ),
          ),
        )
      ],
    );
  }
}
