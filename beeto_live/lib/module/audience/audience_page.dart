import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:handy_toast/handy_toast.dart';
import 'package:rongcloud_rtc_wrapper_plugin/rongcloud_rtc_wrapper_plugin.dart';
import 'package:beeto_live/frame/ui/loading.dart';
import 'package:beeto_live/frame/utils/extension.dart';
import 'package:beeto_live/utils/utils.dart';
import 'package:beeto_live/widgets/ui.dart';
import 'package:beeto_live/data/constants.dart';

class AudiencePage extends StatefulWidget {
  const AudiencePage({Key? key}) : super(key: key);

  @override
  State<AudiencePage> createState() => _AudiencePageState();
}

class _AudiencePageState extends State<AudiencePage> implements RCRTCStatsListener {
  /*
   * --------------------------
   * SomeThing
  */
  late String _roomId; //直播间ID
  RCRTCView? _host; //RTC流容器
  RCRTCMediaType _type = RCRTCMediaType.audio_video; //RTC流类型 音频、视频、音视频
  bool _tiny = false; // 是否小流
  bool _speaker = false; //是否扬声器

  StateSetter? _remoteAudioStatsStateSetter; //
  StateSetter? _remoteVideoStatsStateSetter; //
  StateSetter? _remoteUserAudioStateSetter; //

  RCRTCRemoteAudioStats? _remoteAudioStats; // 远端用户的音频数据 音频类型、码率、音量、丢包率
  RCRTCRemoteVideoStats? _remoteVideoStats; // 远端用户的视频数据 视频类型、码率、帧率、丢包率、视频分辨率

  Map<String, int> _remoteUserAudioState = {}; //远端用户的流媒体数据

  bool _muteAudio = false; //静音音频
  bool _muteVideo = false; //静音视频

  /*
   * --------------------------
   * Widget Build
  */
  @override
  void initState() {
    super.initState();
    //
    widget.changeSpeaker(false);
  }

  @override
  void dispose() {
    super.dispose();
    //
    _remoteAudioStatsStateSetter = null;
    _remoteVideoStatsStateSetter = null;
    _remoteUserAudioStateSetter = null;
    _remoteAudioStats = null;
    _remoteVideoStats = null;
    _remoteUserAudioState.clear();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text('观众端'), //
          actions: [
            IconButton(
              icon: Icon(Icons.mail), //
              onPressed: () => _showMessagePanel(context),
            ),
          ],
        ),
        body: Column(
          children: [
            Row(
              children: [
                Spacer(),
                Radios(
                  '音频',
                  value: RCRTCMediaType.audio,
                  groupValue: _type,
                  onChanged: (dynamic value) {
                    setState(() {
                      _type = value;
                    });
                  },
                ),
                Spacer(),
                Radios(
                  '视频',
                  value: RCRTCMediaType.video,
                  groupValue: _type,
                  onChanged: (dynamic value) {
                    setState(() {
                      _type = value;
                    });
                  },
                ),
                Spacer(),
                Radios(
                  '音视频',
                  value: RCRTCMediaType.audio_video,
                  groupValue: _type,
                  onChanged: (dynamic value) {
                    setState(() {
                      _type = value;
                    });
                  },
                ),
                Spacer(),
              ],
            ),
            Divider(
              height: 5.dp,
              color: Colors.transparent,
            ),
            _type != RCRTCMediaType.audio
                ? Row(
                    children: [
                      Spacer(),
                      CheckBoxes(
                        '订阅小流',
                        checked: _tiny,
                        onChanged: (checked) {
                          setState(() {
                            _tiny = checked;
                          });
                        },
                      ),
                      Spacer(),
                    ],
                  )
                : Container(),
            _type != RCRTCMediaType.audio
                ? Divider(
                    height: 15.dp,
                    color: Colors.transparent,
                  )
                : Container(),
            Row(
              children: [
                Spacer(),
                Button(
                  '订阅',
                  callback: () => _refresh(),
                ),
                Spacer(),
              ],
            ),
            Divider(
              height: 5.dp,
              color: Colors.transparent,
            ),
            AspectRatio(
              aspectRatio: 3 / 2,
              child: Container(
                color: Colors.blue,
                child: Stack(
                  children: [
                    _host ?? Container(),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: 5.dp,
                          top: 5.dp,
                        ),
                        child: BoxFitChooser(
                          fit: _host?.fit ?? BoxFit.cover,
                          onSelected: (fit) {
                            setState(() {
                              _host?.fit = fit;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              height: 5.dp,
              color: Colors.transparent,
            ),
            Row(
              children: [
                Spacer(),
                CheckBoxes(
                  '静音视频',
                  checked: _muteVideo,
                  onChanged: (checked) {
                    _muteVideoStream();
                  },
                ),
                Spacer(),
                CheckBoxes(
                  '静音音频',
                  checked: _muteAudio,
                  onChanged: (checked) {
                    _muteAudioStream();
                  },
                ),
                Spacer(),
              ],
            ),
            Divider(
              height: 5.dp,
              color: Colors.transparent,
            ),
            Row(
              children: [
                Spacer(),
                Button(
                  _speaker ? '扬声器' : '听筒',
                  size: 15.sp,
                  callback: () => _changeSpeaker(),
                ),
                Spacer(),
              ],
            ),
            Divider(
              height: 5.dp,
              color: Colors.transparent,
            ),
            Row(
              children: [
                Spacer(),
                Button(
                  'Reset View',
                  size: 15.sp,
                  callback: () => _resetView(),
                ),
                Spacer(),
              ],
            ),
            Divider(
              height: 5.dp,
              color: Colors.transparent,
            ),
            StatefulBuilder(builder: (context, setter) {
              _remoteAudioStatsStateSetter = setter;
              return RemoteAudioStatsTable(_remoteAudioStats);
            }),
            StatefulBuilder(builder: (context, setter) {
              _remoteVideoStatsStateSetter = setter;
              return RemoteVideoStatsTable(_remoteVideoStats);
            }),
            StatefulBuilder(builder: (context, setter) {
              _remoteUserAudioStateSetter = setter;
              return Expanded(
                child: ListView.separated(
                  itemCount: _remoteUserAudioState.keys.length,
                  separatorBuilder: (context, index) {
                    return Divider(
                      height: 5.dp,
                      color: Colors.transparent,
                    );
                  },
                  itemBuilder: (context, index) {
                    String userId = _remoteUserAudioState.keys.elementAt(index);
                    int volume = _remoteUserAudioState[userId] ?? 0;
                    return Row(
                      children: [
                        Spacer(),
                        userId.toText(),
                        VerticalDivider(
                          width: 10.dp,
                          color: Colors.transparent,
                        ),
                        '$volume'.toText(),
                        Spacer(),
                      ],
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
      onWillPop: _exit,
    );
  }

  /*
   * --------------------------
   * Private Method
  */

  void _showMessagePanel(BuildContext context) {
    // 打开消息面板
    showDialog(
      context: context,
      builder: (context) {
        return MessagePanel(_roomId, false);
      },
    );
  }

  void _refresh() async {
    // 流容器 初始化
    Loading.show(context);
    if (_type == RCRTCMediaType.audio) {
      // 音频类
      _host = null;
      await Utils.engine?.removeLiveMixView();
    } else {
      // 视频类
      _host = await RCRTCView.create(
        mirror: false,
        onFirstFrameRendered: () {
          print('AudiencePage onFirstFrameRendered');
        },
      );

      // 开始拉流
      if (_host != null) {
        await Utils.engine?.setLiveMixView(_host!);
      }
    }

    //
    widget.subscribe(_type, _tiny, (info) {
      onConnected();
    }, (code, info) {
      onConnectError(code, info);
    });
    setState(() {});
  }

  void _muteAudioStream() async {
    // 将音频静音
    bool result = await widget.mute(RCRTCMediaType.audio, !_muteAudio);
    setState(() {
      _muteAudio = result;
    });
  }

  void _muteVideoStream() async {
    // 将视频静音
    bool result = await widget.mute(RCRTCMediaType.video, !_muteVideo);
    setState(() {
      _muteVideo = result;
    });
  }

  void _changeSpeaker() async {
    // 切换音频输出设备 听筒、麦克风
    bool result = await widget.changeSpeaker(!_speaker);
    setState(() {
      _speaker = result;
    });
  }

  void _resetView() async {
    // 流容器 重新初始化
    BoxFit? fit = _host?.fit;
    bool? mirror = _host?.mirror;
    _host = null;
    await Utils.engine?.removeLiveMixView();
    _host = await RCRTCView.create(
      fit: fit ?? BoxFit.contain,
      mirror: mirror ?? false,
    );

    // 开始拉流
    if (_host != null) {
      await Utils.engine?.setLiveMixView(_host!);
    }
    setState(() {});
  }

  Future<bool> _exit() async {
    // 退出直播间
    Loading.show(context);
    await Utils.engine?.setStatsListener(null);
    // await presenter.exit();
    Loading.dismiss(context);
    Navigator.pop(context);
    return Future.value(false);
  }

  /*
   * --------------------------
   * RongCloud Connect
  */
  void onConnected() {
    Loading.dismiss(context);
    'Subscribe success!'.toast();
  }

  void onConnectError(int? code, String? message) {
    Loading.dismiss(context);
    'Subscribe error, code = $code, message = $message'.toast();
  }

  /*
   * --------------------------
   * RongCloud Listener
  */
  @override
  void onNetworkStats(RCRTCNetworkStats stats) {}

  @override
  void onLocalAudioStats(RCRTCLocalAudioStats stats) {}

  @override
  void onLocalVideoStats(RCRTCLocalVideoStats stats) {}

  @override
  void onRemoteAudioStats(String roomId, String userId, RCRTCRemoteAudioStats stats) {}

  @override
  void onRemoteVideoStats(String roomId, String userId, RCRTCRemoteVideoStats stats) {}

  @override
  void onLiveMixAudioStats(RCRTCRemoteAudioStats stats) {
    _remoteAudioStatsStateSetter?.call(() {
      _remoteAudioStats = stats;
    });
  }

  @override
  void onLiveMixVideoStats(RCRTCRemoteVideoStats stats) {
    _remoteVideoStatsStateSetter?.call(() {
      _remoteVideoStats = stats;
    });
  }

  @override
  void onLiveMixMemberAudioStats(String userId, int volume) {
    _remoteUserAudioStateSetter?.call(() {
      _remoteUserAudioState[userId] = volume;
    });
  }

  @override
  void onLiveMixMemberCustomAudioStats(String userId, String tag, int volume) {
    _remoteUserAudioStateSetter?.call(() {
      _remoteUserAudioState['$userId@$tag'] = volume;
    });
  }

  @override
  void onLocalCustomAudioStats(String tag, RCRTCLocalAudioStats stats) {}

  @override
  void onLocalCustomVideoStats(String tag, RCRTCLocalVideoStats stats) {}

  @override
  void onRemoteCustomAudioStats(String roomId, String userId, String tag, RCRTCRemoteAudioStats stats) {}

  @override
  void onRemoteCustomVideoStats(String roomId, String userId, String tag, RCRTCRemoteVideoStats stats) {}
}

extension AudiencePageExtension on AudiencePage {
  /*
   * --------------------------
   * RongCloud Init
  */
  void subscribe(
    RCRTCMediaType type,
    bool tiny,
    Callback success,
    StateCallback error,
  ) async {
    _unsubscribe(() async {
      Utils.engine?.onLiveMixSubscribed = (type2, code2, message2) {
        Utils.engine?.onLiveMixSubscribed = null;
        if (code2 != 0)
          error(code2, 'Subscribe error $code2.');
        else
          success('Subscribe success.');
      };
      int code = await Utils.engine?.subscribeLiveMix(type, tiny) ?? -1;
      if (code != 0) {
        Utils.engine?.onLiveMixSubscribed = null;
        error(code, 'Subscribe error $code.');
      }
    });
  }

  Future<void> _unsubscribe(Function() next) async {
    Utils.engine?.onLiveMixUnsubscribed = (type, code, message) async {
      Utils.engine?.onLiveMixUnsubscribed = null;
      next.call();
    };
    int code = await Utils.engine?.unsubscribeLiveMix(RCRTCMediaType.audio_video) ?? -1;
    if (code != 0) {
      Utils.engine?.onLiveMixUnsubscribed = null;
      next.call();
    }
  }

  /*
   * --------------------------
   * RongCloud Control Method
  */
  Future<bool> mute(RCRTCMediaType type, bool mute) async {
    int code = await Utils.engine?.muteLiveMixStream(type, mute) ?? -1;
    if (code != 0) return !mute;
    return mute;
  }

  Future<bool> changeSpeaker(bool enable) async {
    int code = await Utils.engine?.enableSpeaker(enable) ?? -1;
    if (code != 0) return !enable;
    return enable;
  }

  /*
   * --------------------------
   * Page Control Method
  */
  Future<int> exit() async {
    Completer<int> completer = Completer();
    Utils.engine?.onRoomLeft = (int code, String? message) async {
      Utils.engine?.onRoomLeft = null;
      await Utils.engine?.destroy();
      Utils.engine = null;
      completer.complete(code);
    };
    int code = await Utils.engine?.leaveRoom() ?? -1;
    if (code != 0) {
      Utils.engine?.onRoomLeft = null;
      await Utils.engine?.destroy();
      Utils.engine = null;
      return code;
    }
    return completer.future;
  }
}
