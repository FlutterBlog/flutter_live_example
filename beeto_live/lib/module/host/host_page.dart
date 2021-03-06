import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import 'dart:io';
import 'package:handy_toast/handy_toast.dart';
import 'package:path/path.dart' as Path;
import 'package:permission_handler/permission_handler.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:rongcloud_rtc_wrapper_plugin/rongcloud_rtc_wrapper_plugin.dart';
import 'package:beeto_live/data/data.dart';
import 'package:beeto_live/main.dart';
import 'package:beeto_live/frame/ui/loading.dart';
import 'package:beeto_live/frame/utils/extension.dart';
import 'package:beeto_live/utils/utils.dart';
import 'package:beeto_live/widgets/ui.dart';

class HostPage extends StatefulWidget {
  const HostPage({Key? key}) : super(key: key);

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> implements RCRTCStatsListener {
  /*
   * --------------------------
   * SomeThing
  */
  late String _roomId; //
  late Config _config; //
  late RCRTCVideoConfig _tinyConfig; //
  late RCRTCVideoConfig _customConfig; //

  RCRTCView? _local; //
  RCRTCView? _custom; //
  String? _customPath; //

  LiveMix _liveMix = LiveMix(); //
  Map<String, RCRTCView?> _remoteCustoms = {}; //

  bool _yuv = false; //
  bool _localYuv = false; //
  bool _published = false; //
  bool _customPublished = false; //

  List<CDNInfo> _cdnList = []; //
  Map<String, RCRTCView?> _remotes = {}; //

  StateSetter? _networkStatsStateSetter;
  RCRTCNetworkStats? _networkStats;

  StateSetter? _localAudioStatsStateSetter;
  StateSetter? _localVideoStatsStateSetter;
  RCRTCLocalAudioStats? _localAudioStats;
  Map<bool, RCRTCLocalVideoStats> _localVideoStats = {};

  Map<String, StateSetter> _remoteAudioStatsStateSetters = {};
  Map<String, StateSetter> _remoteVideoStatsStateSetters = {};
  Map<String, StateSetter> _remoteCustomAudioStatsStateSetters = {};
  Map<String, StateSetter> _remoteCustomVideoStatsStateSetters = {};

  Map<String, RCRTCRemoteAudioStats> _remoteAudioStats = {};
  Map<String, RCRTCRemoteVideoStats> _remoteVideoStats = {};
  Map<String, RCRTCRemoteAudioStats> _remoteCustomAudioStats = {};
  Map<String, RCRTCRemoteVideoStats> _remoteCustomVideoStats = {};

  /*
   * --------------------------
   * Widget Build
  */
  @override
  void initState() {
    super.initState();

    Map<String, dynamic> arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
    _config = Config.fromJson(arguments['config']);
    _roomId = arguments['id'];
    _yuv = arguments['yuv'] ?? false;
    _tinyConfig = RCRTCVideoConfig.create(
      minBitrate: 100,
      maxBitrate: 500,
      fps: RCRTCVideoFps.fps_15,
      resolution: RCRTCVideoResolution.resolution_180_320,
    );
    _customConfig = RCRTCVideoConfig.create();

    // ?????????????????????
    Utils.engine?.setStatsListener(this);
    // ?????????
    _initLiveRoom(context);
  }

  //????????????
  Future<void> _initLiveRoom(BuildContext context) async {
    await widget.changeVideoConfig(_config.videoConfig);
    await widget.changeMic(_config.mic);
    await widget.changeSpeaker(_config.speaker);

    await widget.changeTinyVideoConfig(RCRTCVideoConfig.create(
      minBitrate: 100,
      maxBitrate: 500,
      fps: RCRTCVideoFps.fps_15,
      resolution: RCRTCVideoResolution.resolution_180_320,
    ));

    // ?????????????????? ?????????????????? ???????????????????????????
    onUserListChanged();

    // ?????????????????? ????????????&??????
    Utils.users.forEach((user) {
      onUserAudioStateChanged(user.id, user.audioPublished);
      onUserVideoStateChanged(user.id, user.videoPublished);
    });

    // ????????? ??????????????????
    Utils.onUserListChanged = () {
      onUserListChanged();
    };

    // ????????? ???????????? ????????????
    Utils.onUserAudioStateChanged = (id, published) {
      onUserAudioStateChanged(id, published);
    };

    // ????????? ???????????? ????????????
    Utils.onUserVideoStateChanged = (id, published) {
      onUserVideoStateChanged(id, published);
    };

    // ????????? ??????????????? ????????????
    Utils.onUserCustomStateChanged = (id, tag, audio, video) {
      onUserCustomStateChanged(id, tag, audio, video);
    };

    // ????????? ??????????????? ????????????
    Utils.engine?.onCustomStreamPublishFinished = (tag) {
      onCustomVideoUnpublished();
    };

    // ????????? ???????????????????????????
    Utils.engine?.onJoinSubRoomRequestReceived = (roomId, userId, extra) {
      onReceiveJoinRequest(roomId, userId);
    };

    // ????????? ???????????????????????????
    Utils.engine?.onJoinSubRoomRequestResponseReceived = (roomId, userId, agree, extra) {
      onReceiveJoinResponse(roomId, userId, agree);
    };
  }

  @override
  void dispose() {
    _remotes.clear();
    _remoteCustoms.clear();

    _networkStats = null;
    _localAudioStats = null;
    _localVideoStats.clear();
    _remoteAudioStats.clear();
    _remoteVideoStats.clear();
    _remoteCustomAudioStats.clear();
    _remoteCustomVideoStats.clear();

    _networkStatsStateSetter = null;
    _localAudioStatsStateSetter = null;
    _localVideoStatsStateSetter = null;
    _remoteAudioStatsStateSetters.clear();
    _remoteVideoStatsStateSetters.clear();
    _remoteCustomAudioStatsStateSetters.clear();
    _remoteCustomVideoStatsStateSetters.clear();

    Utils.engine?.onCustomStreamPublishFinished = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '$_roomId',
            style: TextStyle(fontSize: 15.sp),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.link,
              ),
              onPressed: () => _showBandOption(context), // ????????????
            ),
            IconButton(
              icon: Icon(
                Icons.alt_route,
              ),
              onPressed: _published ? () => _showCDNInfo(context) : null, // CDN??????
            ),
            IconButton(
              icon: Icon(
                Icons.picture_in_picture,
              ),
              onPressed: _published ? () => _showMixInfo(context) : null, // ???????????????
            ),
            IconButton(
              icon: Icon(
                Icons.message,
              ),
              onPressed: () => _showMessagePanel(context), // ????????????
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: constraints.copyWith(
                  minHeight: constraints.maxHeight,
                  maxHeight: double.infinity,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    /// ????????? ??????&???????????? ??????
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 200.dp,
                          height: 160.dp,
                          color: Colors.blue,
                          child: Stack(
                            children: [
                              _local ?? Container(),
                              Align(
                                alignment: Alignment.topLeft,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: 5.dp,
                                    top: 5.dp,
                                  ),
                                  child: Text(
                                    '${DefaultData.user?.id}',
                                    softWrap: true,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.sp,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.topLeft,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: 5.dp,
                                    top: 15.dp,
                                  ),
                                  child: BoxFitChooser(
                                    fit: _local?.fit ?? BoxFit.contain,
                                    onSelected: (fit) {
                                      setState(() {
                                        _local?.fit = fit;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Spacer(),
                        Column(
                          children: [
                            Row(
                              children: [
                                CheckBoxes(
                                  '????????????',
                                  checked: _config.mic,
                                  onChanged: (checked) => _changeMic(checked),
                                ),
                                CheckBoxes(
                                  '????????????',
                                  checked: _config.camera,
                                  onChanged: (checked) => _changeCamera(checked),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                CheckBoxes(
                                  '????????????',
                                  checked: _config.audio,
                                  onChanged: (checked) => _changeAudio(checked),
                                ),
                                CheckBoxes(
                                  '????????????',
                                  checked: _config.video,
                                  onChanged: (checked) => _changeVideo(checked),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                CheckBoxes(
                                  '????????????',
                                  checked: _config.frontCamera,
                                  onChanged: (checked) => _changeFrontCamera(checked),
                                ),
                                CheckBoxes(
                                  '????????????',
                                  checked: _config.mirror,
                                  onChanged: (checked) => _changeMirror(checked),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Button(
                                  _config.speaker ? '?????????' : '??????',
                                  size: 15.sp,
                                  callback: () => _changeSpeaker(),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // ????????????
                                DropdownButtonHideUnderline(
                                  child: DropdownButton(
                                    isDense: true,
                                    value: _config.fps,
                                    items: videoFpsItems(),
                                    onChanged: (dynamic fps) => _changeFps(fps),
                                  ),
                                ),
                                // ???????????????
                                DropdownButtonHideUnderline(
                                  child: DropdownButton(
                                    isDense: true,
                                    value: _config.resolution,
                                    items: videoResolutionItems(),
                                    onChanged: (dynamic resolution) => _changeResolution(resolution),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  '????????????:',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 15.sp,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                // ??????????????????
                                DropdownButtonHideUnderline(
                                  child: DropdownButton(
                                    isDense: true,
                                    value: _config.minVideoKbps,
                                    items: minVideoKbpsItems(),
                                    onChanged: (dynamic kbps) => _changeMinVideoKbps(kbps),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  '????????????:',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 15.sp,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                // ??????????????????
                                DropdownButtonHideUnderline(
                                  child: DropdownButton(
                                    isDense: true,
                                    value: _config.maxVideoKbps,
                                    items: maxVideoKbpsItems(),
                                    onChanged: (dynamic kbps) => _changeMaxVideoKbps(kbps),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    /// ??????????????? ??????&????????????
                    Padding(
                      padding: EdgeInsets.all(5.dp),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 170.dp,
                              height: 150.dp,
                              color: Colors.yellow,
                              child: Stack(
                                children: [
                                  _custom ?? Container(),
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: 5.dp,
                                        top: 5.dp,
                                      ),
                                      child: Text(
                                        '${DefaultData.user!.id.replaceAll('_', '')}Custom',
                                        softWrap: true,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15.sp,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: 5.dp,
                                        top: 25.dp,
                                      ),
                                      child: BoxFitChooser(
                                        fit: _custom?.fit ?? BoxFit.contain,
                                        onSelected: (fit) {
                                          setState(() {
                                            _custom?.fit = fit;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            VerticalDivider(
                              width: 10.dp,
                              color: Colors.transparent,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 150.dp,
                                  child: '????????????:\n${_customPath != null ? Path.basename(_customPath!) : null} '.toText(),
                                ),
                                '????????????'.onClick(() => _selectMovie(context), color: Colors.blue),
                                Row(
                                  children: [
                                    CheckBoxes(
                                      'YUV??????',
                                      enable: _yuv && !_customPublished,
                                      checked: _localYuv,
                                      onChanged: (checked) => setState(() {
                                        _localYuv = checked;
                                      }),
                                    ),
                                    VerticalDivider(
                                      width: 10.dp,
                                      color: Colors.transparent,
                                    ),
                                    Button(
                                      '${_customPublished ? '????????????' : '??????'}',
                                      size: 15.dp,
                                      callback: () => _customAction(),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    // ????????????
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton(
                                        isDense: true,
                                        value: _customConfig.fps,
                                        items: videoFpsItems(),
                                        onChanged: (dynamic fps) => _changeCustomFps(fps),
                                      ),
                                    ),
                                    // ???????????????
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton(
                                        isDense: true,
                                        value: _customConfig.resolution,
                                        items: videoResolutionItems(),
                                        onChanged: (dynamic resolution) => _changeCustomResolution(resolution),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '????????????:',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 15.sp,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    // ??????????????????
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton(
                                        isDense: true,
                                        value: _customConfig.minBitrate,
                                        items: minVideoKbpsItems(),
                                        onChanged: (dynamic kbps) => _changeCustomMinBitrate(kbps),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '????????????:',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 15.sp,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),

                                    // ??????????????????
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton(
                                        isDense: true,
                                        value: _customConfig.maxBitrate,
                                        items: maxVideoKbpsItems(),
                                        onChanged: (dynamic kbps) => _changeCustomMaxBitrate(kbps),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    /// ????????? ???????????? ??????
                    Padding(
                      padding: EdgeInsets.all(5.dp),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Spacer(),
                            Text(
                              "????????????",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 15.sp,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            Spacer(),
                            Column(
                              children: [
                                // ?????? - ?????????
                                Row(
                                  children: [
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton(
                                        isDense: true,
                                        value: _tinyConfig.resolution,
                                        items: videoResolutionItems(),
                                        onChanged: (dynamic resolution) => _changeTinyResolution(resolution),
                                      ),
                                    ),
                                  ],
                                ),
                                // ?????? - ????????????
                                Row(
                                  children: [
                                    Text(
                                      '??????:',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 15.sp,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),

                                    // ??????
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton(
                                        isDense: true,
                                        value: _tinyConfig.minBitrate,
                                        items: tinyMinVideoKbpsItems(),
                                        onChanged: (dynamic kbps) => _changeTinyMinVideoKbps(kbps),
                                      ),
                                    ),

                                    Text(
                                      '??????:',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 15.sp,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),

                                    // ??????
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton(
                                        isDense: true,
                                        value: _tinyConfig.maxBitrate,
                                        items: tinyMaxVideoKbpsItems(),
                                        onChanged: (dynamic kbps) => _changeTinyMaxVideoKbps(kbps),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Spacer(),
                          ],
                        ),
                      ),
                    ),

                    /// ???????????????IP + ?????? + ?????? + ??????
                    StatefulBuilder(builder: (context, setter) {
                      _networkStatsStateSetter = setter;
                      return NetworkStatsTable(_networkStats);
                    }),

                    /// ????????????????????? + ?????????
                    StatefulBuilder(builder: (context, setter) {
                      _localAudioStatsStateSetter = setter;
                      return LocalAudioStatsTable(_localAudioStats);
                    }),

                    /// ????????????????????? + ????????? + ?????? + ?????????
                    StatefulBuilder(builder: (context, setter) {
                      _localVideoStatsStateSetter = setter;
                      return LocalVideoStatsTable(_localVideoStats);
                    }),

                    ///
                    Divider(
                      height: 10.dp,
                      color: Colors.black,
                    ),

                    /// ???????????? ???????????????
                    ListView.separated(
                      shrinkWrap: true,
                      physics: ClampingScrollPhysics(),
                      itemCount: Utils.users.length,
                      separatorBuilder: (context, index) {
                        return Divider(
                          height: 5.dp,
                          color: Colors.transparent,
                        );
                      },
                      itemBuilder: (context, index) {
                        UserState user = Utils.users[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// ???????????? ?????????
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ????????????
                                Container(
                                  width: 200.dp,
                                  height: 160.dp,
                                  color: Colors.blue,
                                  child: Stack(
                                    children: [
                                      // ???????????????????????????
                                      _remotes[user.id] ?? Container(),

                                      // ???????????? ??????ID
                                      Align(
                                        alignment: Alignment.topLeft,
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            left: 5.dp,
                                            top: 5.dp,
                                          ),
                                          child: Text(
                                            '${user.id}',
                                            softWrap: true,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15.sp,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // ???????????? ???????????????
                                      Align(
                                        alignment: Alignment.bottomLeft,
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            left: 5.dp,
                                            bottom: 5.dp,
                                          ),
                                          child: Offstage(
                                            offstage: !user.videoPublished,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                '?????????'.onClick(() {
                                                  _switchToNormalStream(user.id);
                                                }),
                                                VerticalDivider(
                                                  width: 10.dp,
                                                  color: Colors.transparent,
                                                ),
                                                '?????????'.onClick(() {
                                                  _switchToTinyStream(user.id);
                                                }),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // ???????????? ???????????????
                                      Align(
                                        alignment: Alignment.topLeft,
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            left: 5.dp,
                                            top: 15.dp,
                                          ),
                                          child: BoxFitChooser(
                                            fit: _remotes[user.id]?.fit ?? BoxFit.cover,
                                            onSelected: (fit) {
                                              setState(() {
                                                _remotes[user.id]?.fit = fit;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // ??????
                                VerticalDivider(
                                  width: 2.dp,
                                  color: Colors.transparent,
                                ),

                                // ???????????? ???????????? & ????????????
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // ????????????
                                      Row(
                                        children: [
                                          CheckBoxes(
                                            '????????????',
                                            enable: user.audioPublished,
                                            checked: user.audioSubscribed,
                                            onChanged: (subscribe) => _changeRemoteAudio(user, subscribe),
                                          ),
                                          CheckBoxes(
                                            '????????????',
                                            enable: user.videoPublished,
                                            checked: user.videoSubscribed,
                                            onChanged: (subscribe) => _changeRemoteVideo(user, subscribe),
                                          ),
                                        ],
                                      ),

                                      // ????????????????????? + ?????????
                                      StatefulBuilder(builder: (context, setter) {
                                        _remoteAudioStatsStateSetters[user.id] = setter;
                                        return RemoteAudioStatsTable(_remoteAudioStats[user.id]);
                                      }),

                                      // ????????????????????? + ?????? + ????????? + ?????????
                                      StatefulBuilder(builder: (context, setter) {
                                        _remoteVideoStatsStateSetters[user.id] = setter;
                                        return RemoteVideoStatsTable(_remoteVideoStats[user.id]);
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            /// ???????????? ?????????????????????
                            ListView.separated(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: user.customs.length,
                              separatorBuilder: (context, index) {
                                return Divider(
                                  height: 5.dp,
                                  color: Colors.transparent,
                                );
                              },
                              itemBuilder: (context, index) {
                                CustomState custom = user.customs[index];
                                String key = '${user.id}${custom.tag}';
                                return Row(
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 200.dp,
                                      height: 160.dp,
                                      color: Colors.yellow,
                                      child: Stack(
                                        children: [
                                          // ????????????????????????????????????
                                          _remoteCustoms[key] ?? Container(),

                                          // ????????????????????? ??????ID
                                          Align(
                                            alignment: Alignment.topLeft,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                left: 5.dp,
                                                top: 5.dp,
                                              ),
                                              child: Text(
                                                '${user.customs[index].tag}',
                                                softWrap: true,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15.sp,
                                                  decoration: TextDecoration.none,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // ????????????????????? ???????????????
                                          Align(
                                            alignment: Alignment.topLeft,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                left: 5.dp,
                                                top: 15.dp,
                                              ),
                                              child: BoxFitChooser(
                                                fit: _remoteCustoms[key]?.fit ?? BoxFit.cover,
                                                onSelected: (fit) {
                                                  setState(() {
                                                    _remoteCustoms[key]?.fit = fit;
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // ??????
                                    VerticalDivider(
                                      width: 2.dp,
                                      color: Colors.transparent,
                                    ),

                                    // ????????????????????? & ????????????
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // ????????????
                                          Row(
                                            children: [
                                              CheckBoxes(
                                                'YUV??????',
                                                enable: _yuv && !custom.videoSubscribed,
                                                checked: custom.yuv,
                                                onChanged: (checked) => setState(() {
                                                  custom.yuv = checked;
                                                }),
                                              ),
                                              Spacer(),
                                              CheckBoxes(
                                                '????????????',
                                                enable: custom.videoPublished,
                                                checked: custom.videoSubscribed,
                                                onChanged: (subscribe) =>
                                                    _changeRemoteCustomVideo(user, custom, subscribe),
                                              ),
                                            ],
                                          ),

                                          // ??????
                                          VerticalDivider(
                                            width: 2.dp,
                                            color: Colors.transparent,
                                          ),

                                          // ????????????
                                          Row(
                                            children: [
                                              CheckBoxes(
                                                '????????????',
                                                enable: custom.audioPublished,
                                                checked: custom.audioSubscribed,
                                                onChanged: (subscribe) =>
                                                    _changeRemoteCustomAudio(user, custom, subscribe),
                                              ),
                                              Spacer(),
                                            ],
                                          ),

                                          // ????????????????????? + ?????????
                                          StatefulBuilder(builder: (context, setter) {
                                            _remoteCustomAudioStatsStateSetters['${user.id}@${custom.tag}'] = setter;
                                            return RemoteAudioStatsTable(
                                                _remoteCustomAudioStats['${user.id}@${custom.tag}']);
                                          }),

                                          // ????????????????????? + ?????? + ????????? + ?????????
                                          StatefulBuilder(builder: (context, setter) {
                                            _remoteCustomVideoStatsStateSetters['${user.id}@${custom.tag}'] = setter;
                                            return RemoteVideoStatsTable(
                                                _remoteCustomVideoStats['${user.id}@${custom.tag}']);
                                          }),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      onWillPop: _exit,
    );
  }

  /*
   * --------------------------
   * Private Method
  */

  void _showBandOption(BuildContext context) async {
    // ???????????????
    showDialog(
      context: context,
      builder: (context) {
        return JoinSubRoomPanel(
          Utils.engine!,
          _roomId,
          Utils.joinedSubRooms,
          Utils.joinableSubRooms,
        );
      },
    );
  }

  void _showCDNInfo(BuildContext context) async {
    // ??????CDN???
    Loading.show(context);
    final String? id = await Utils.engine?.getSessionId();
    if (id?.isEmpty ?? true) return "Session Id is NULL!!".toast();
    Loading.dismiss(context);
    showDialog(
      context: context,
      builder: (context) {
        return CDNConfig(
          id: id!,
          engine: Utils.engine!,
          cdnList: _cdnList,
        );
      },
    );
  }

  void _showMixInfo(BuildContext context) {
    // ????????????????????????
    List<LiveMixItem> items = [];
    items.add(LiveMixItem(DefaultData.user!.id, null));
    if (_customPublished) {
      items.add(LiveMixItem(DefaultData.user!.id, '${DefaultData.user!.id.replaceAll('_', '')}Custom'));
    }
    Utils.users.forEach((user) {
      items.add(LiveMixItem(user.id, null));
      user.customs.forEach((custom) {
        items.add(LiveMixItem(user.id, custom.tag));
      });
    });
    showDialog(
      context: context,
      builder: (context) {
        return LiveMixPanel(Utils.engine!, _liveMix, items);
      },
    );
  }

  void _showMessagePanel(BuildContext context) {
    // ???????????????
    showDialog(
      context: context,
      builder: (context) {
        return MessagePanel(_roomId, true);
      },
    );
  }

  void _changeMic(bool open) async {
    // ???????????? ????????????
    Loading.show(context);
    bool result = await widget.changeMic(open);
    setState(() {
      _config.mic = result;
    });
    Loading.dismiss(context);
  }

  void _changeCamera(bool open) async {
    // ???????????? ????????????
    Loading.show(context);
    if (open) {
      _local = await RCRTCView.create(mirror: true);
      if (_local != null) {
        Utils.engine?.setLocalView(_local!);
      }
    } else {
      _local = null;
      Utils.engine?.removeLocalView();
    }
    bool result = await widget.changeCamera(open);
    setState(() {
      _config.camera = result;
    });
    Loading.dismiss(context);
  }

  void _changeAudio(bool publish) async {
    // ???????????? ????????????
    Loading.show(context);
    int result = await widget.changeAudio(publish);
    if (result != 0) {
      '${publish ? 'Publish' : 'Unpublish'} Audio Stream Error'.toast();
      publish = !publish;
    }
    setState(() {
      _config.audio = publish;
      _published = _config.audio || _config.video;
    });
    Loading.dismiss(context);
  }

  void _changeVideo(bool publish) async {
    // ???????????? ????????????
    Loading.show(context);
    int result = await widget.changeVideo(publish);
    if (result != 0) {
      '${publish ? 'Publish' : 'Unpublish'} Video Stream Error'.toast();
      publish = !publish;
    }
    setState(() {
      _config.video = publish;
      _published = _config.audio || _config.video;
    });
    Loading.dismiss(context);
  }

  void _changeFrontCamera(bool front) async {
    // ???????????? ???????????????
    bool result = await widget.changeFrontCamera(front);
    setState(() {
      _config.frontCamera = result;
    });
  }

  void _changeMirror(bool mirror) {
    // ???????????? ???????????????
    setState(() {
      _config.mirror = mirror;
      _local?.mirror = mirror;
    });
  }

  void _changeSpeaker() async {
    // ???????????? ????????????????????????
    bool result = await widget.changeSpeaker(!_config.speaker);
    setState(() {
      _config.speaker = result;
    });
  }

  void _changeFps(RCRTCVideoFps fps) {
    // ???????????? ???????????? - ?????????
    _config.fps = fps;
    widget.changeVideoConfig(_config.videoConfig);
    setState(() {});
  }

  void _changeResolution(RCRTCVideoResolution resolution) async {
    // ???????????? ??????????????? - ?????????
    _config.resolution = resolution;
    await widget.changeVideoConfig(_config.videoConfig);
    setState(() {});
  }

  void _changeMinVideoKbps(int kbps) {
    // ???????????? ?????????????????? - ?????????
    _config.minVideoKbps = kbps;
    widget.changeVideoConfig(_config.videoConfig);
    setState(() {});
  }

  void _changeMaxVideoKbps(int kbps) {
    // ???????????? ?????????????????? - ?????????
    _config.maxVideoKbps = kbps;
    widget.changeVideoConfig(_config.videoConfig);
    setState(() {});
  }

  void _selectMovie(BuildContext context) async {
    // ???????????? ??????????????? - ??????????????????
    final List<AssetEntity>? assets =
        await AssetPicker.pickAssets(context, maxAssets: 1, requestType: RequestType.video);
    File? file = await assets?.first.originFile;
    setState(() {
      _customPath = file?.absolute.path;
    });
  }

  void _customAction() async {
    // ???????????? ??????????????? - ??????
    if (!_customPublished) {
      if (_customPath?.isEmpty ?? true) {
        return '????????????????????????'.toast();
      }
      Loading.show(context);

      int code = await widget.publishCustomVideo(_roomId, _customPath!, _customConfig, _localYuv);
      if (code != 0) {
        onCustomVideoPublishedError(code);
      } else {
        onCustomVideoPublished();
      }
    } else {
      Loading.show(context);

      int code = await widget.unpublishCustomVideo();
      if (code != 0) {
        onCustomVideoUnpublishedError(code);
      } else {
        onCustomVideoUnpublished();
      }
    }
  }

  void _changeCustomFps(RCRTCVideoFps fps) async {
    // ???????????? ??????????????? - ????????????
    _customConfig.fps = fps;
    await widget.changeCustomConfig(_customConfig);
    setState(() {});
  }

  void _changeCustomResolution(RCRTCVideoResolution resolution) async {
    // ???????????? ??????????????? - ???????????????
    _customConfig.resolution = resolution;
    await widget.changeCustomConfig(_customConfig);
    setState(() {});
  }

  void _changeCustomMinBitrate(int kbps) async {
    // ???????????? ??????????????? - ??????????????????
    _customConfig.minBitrate = kbps;
    await widget.changeCustomConfig(_customConfig);
    setState(() {});
  }

  void _changeCustomMaxBitrate(int kbps) {
    // ???????????? ??????????????? - ??????????????????
    _customConfig.maxBitrate = kbps;
    widget.changeCustomConfig(_customConfig);
    setState(() {});
  }

  void _changeTinyResolution(RCRTCVideoResolution resolution) async {
    // ???????????? ?????? - ???????????????
    _tinyConfig.resolution = resolution;
    setState(() {});
    bool ret = await widget.changeTinyVideoConfig(_tinyConfig);
    (ret ? '????????????' : '????????????').toast();
  }

  void _changeTinyMinVideoKbps(int kbps) async {
    // ???????????? ?????? - ??????????????????
    _tinyConfig.minBitrate = kbps;
    setState(() {});
    bool ret = await widget.changeTinyVideoConfig(_tinyConfig);
    (ret ? '????????????' : '????????????').toast();
  }

  void _changeTinyMaxVideoKbps(int kbps) async {
    // ???????????? ?????? - ??????????????????
    _tinyConfig.maxBitrate = kbps;
    setState(() {});
    bool ret = await widget.changeTinyVideoConfig(_tinyConfig);
    (ret ? '????????????' : '????????????').toast();
  }

  void _switchToNormalStream(String id) {
    // ?????????????????? ????????????
    widget.switchToNormalStream(id);
  }

  void _switchToTinyStream(String id) {
    // ?????????????????? ????????????
    widget.switchToTinyStream(id);
  }

  void _changeRemoteAudio(UserState user, bool subscribe) async {
    // ?????????????????? ????????????
    Loading.show(context);
    user.audioSubscribed = await widget.changeRemoteAudioStatus(user.id, subscribe);
    setState(() {});
    Loading.dismiss(context);
  }

  void _changeRemoteVideo(UserState user, bool subscribe) async {
    // ?????????????????? ????????????
    Loading.show(context);
    user.videoSubscribed = await widget.changeRemoteVideoStatus(user.id, subscribe);
    if (user.videoSubscribed) {
      if (_remotes.containsKey(user.id)) _remotes.remove(user.id);
      RCRTCView view = await RCRTCView.create(mirror: false);
      _remotes[user.id] = view;
      await Utils.engine?.setRemoteView(user.id, view);
    } else {
      if (_remotes.containsKey(user.id)) {
        _remotes.remove(user.id);
        await Utils.engine?.removeRemoteView(user.id);
      }
    }
    setState(() {});
    Loading.dismiss(context);
  }

  void _changeRemoteCustomVideo(UserState user, CustomState custom, bool subscribe) async {
    // ???????????? - ??????????????? - ????????????
    Loading.show(context);
    custom.videoSubscribed =
        await widget.changeRemoteCustomVideoStatus(_roomId, user.id, custom.tag, custom.yuv, subscribe);
    String key = '${user.id}${custom.tag}';
    if (custom.videoSubscribed) {
      if (_remoteCustoms.containsKey(key)) _remoteCustoms.remove(key);
      RCRTCView view = await RCRTCView.create(mirror: false);
      _remoteCustoms[key] = view;
      await Utils.engine?.setRemoteCustomStreamView(user.id, custom.tag, view);
    } else {
      if (_remoteCustoms.containsKey(key)) {
        _remoteCustoms.remove(key);
        await Utils.engine?.removeRemoteCustomStreamView(user.id, custom.tag);
      }
    }
    setState(() {});
    Loading.dismiss(context);
  }

  void _changeRemoteCustomAudio(UserState user, CustomState custom, bool subscribe) async {
    // ???????????? - ??????????????? - ????????????
    Loading.show(context);
    custom.audioSubscribed = await widget.changeRemoteCustomAudioStatus(_roomId, user.id, custom.tag, subscribe);
    setState(() {});
    Loading.dismiss(context);
  }

  Future<bool> _exit() async {
    // ???????????????
    Loading.show(context);
    await Main.getInstance().disableLocalCustomYuv();
    await Main.getInstance().disableAllRemoteCustomYuv();
    await Utils.engine?.setStatsListener(null);

    // ???????????????
    int code = await widget.exit();
    if (code != 0) {
      onExitWithError(code);
    } else {
      onExit();
    }

    return Future.value(false);
  }

  void _bandAction(BuildContext context, String roomId, String userId, bool agree) async {
    // ???????????? ??????????????????
    Navigator.pop(context);
    Loading.show(context);
    int ret = await widget.responseJoinSubRoom(roomId, userId, agree);
    Loading.dismiss(context);
    if (ret == 0 && agree) {
      Utils.joinSubRoom(context, roomId);
    }
    if (ret != 0) {
      '?????????????????????????????????, code:$ret'.toast();
    }
  }

  Future<void> _updateRemoteView() {
    // ???????????????????????????
    Completer<void> completer = Completer();
    _remotes.clear();
    _remoteCustoms.clear();
    int count = Utils.users.length;
    if (count > 0) {
      Utils.users.forEach((user) async {
        if (user.videoSubscribed) {
          RCRTCView view = await RCRTCView.create(mirror: false);
          Utils.engine?.setRemoteView(user.id, view);
          _remotes[user.id] = view;
        }
        user.customs.forEach((custom) async {
          if (custom.videoSubscribed) {
            RCRTCView view = await RCRTCView.create(mirror: false);
            Utils.engine?.setRemoteCustomStreamView(user.id, custom.tag, view);
            _remoteCustoms['${user.id}${custom.tag}'] = view;
          }
        });
        count--;
        if (count <= 0) {
          completer.complete();
        }
      });
    } else {
      completer.complete();
    }
    return completer.future;
  }

  /*
   * --------------------------
   * Method
  */

  void onUserListChanged() async {
    // ?????????????????? ???????????????????????????
    await _updateRemoteView();
    setState(() {});
  }

  void onUserAudioStateChanged(String id, bool published) {
    // ???????????? ????????????
    setState(() {});
  }

  void onUserVideoStateChanged(String id, bool published) async {
    // ???????????? ????????????
    if (!published) {
      if (_remotes.containsKey(id)) {
        _remotes.remove(id);
        Utils.engine?.removeRemoteView(id);
      }
    }
    setState(() {});
  }

  void onUserCustomStateChanged(String id, String tag, bool audio, bool video) async {
    // ??????????????? ????????????
    if (!video) {
      await Main.getInstance().disableRemoteCustomYuv(id, tag);
      String key = '$id$tag';
      if (_remoteCustoms.containsKey(key)) {
        _remoteCustoms.remove(key);
        await Utils.engine?.removeRemoteCustomStreamView(id, tag);
      }
    }
    setState(() {});
  }

  /*
   * --------------------------
   * CustomVideo
  */
  void onCustomVideoPublished() async {
    // ???????????? ??????????????? - ????????????
    Loading.dismiss(context);
    _custom = await RCRTCView.create(mirror: false);
    int code =
        await Utils.engine?.setLocalCustomStreamView('${DefaultData.user!.id.replaceAll('_', '')}Custom', _custom!) ??
            -1;
    if (code != 0) '?????????????????????????????????, $code'.toast();
    setState(() {
      _customPublished = true;
    });
  }

  void onCustomVideoPublishedError(int code) {
    // ???????????? ??????????????? - ????????????
    Loading.dismiss(context);
    '???????????????????????????, $code'.toast();
  }

  void onCustomVideoUnpublished() async {
    // ???????????? ??????????????? - ???????????? ??????
    await Main.getInstance().disableLocalCustomYuv();
    Loading.dismiss(context);
    setState(() {
      _custom = null;
      _customPublished = false;
    });
  }

  void onCustomVideoUnpublishedError(int code) {
    // ???????????? ??????????????? - ???????????? ??????
    Loading.dismiss(context);
    '?????????????????????????????????, $code'.toast();
  }

  /*
   * --------------------------
   * Link
  */
  void onReceiveJoinRequest(String roomId, String userId) {
    // ??????????????????????????? ????????????
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('??????????????????'),
          content: Text('??????$roomId???$userId???????????????????????????????????????'),
          actions: [
            TextButton(
              child: Text('??????'),
              onPressed: () => _bandAction(context, roomId, userId, true),
            ),
            TextButton(
              child: Text('??????'),
              onPressed: () => _bandAction(context, roomId, userId, false),
            ),
          ],
        );
      },
    );
  }

  void onReceiveJoinResponse(String roomId, String userId, bool agree) {
    // ??????????????????????????? ????????????
    if (agree) {
      '$roomId???$userId??????????????????????????????????????????..'.toast();
      Utils.joinSubRoom(context, roomId);
    } else {
      '$roomId???$userId???????????????????????????'.toast();
    }
  }

  /*
   * --------------------------
   * Exit
  */
  void onExit() {
    // ???????????????
    Loading.dismiss(context);
    Navigator.pop(context);
  }

  void onExitWithError(int code) {
    // ??????????????? ??????
    Loading.dismiss(context);
    'Exit with error, code = $code'.toast();
    Navigator.pop(context);
  }

  /*
   * --------------------------
   * RCRTCStatsListener
  */
  @override
  void onLiveMixAudioStats(RCRTCRemoteAudioStats stats) {}

  @override
  void onLiveMixVideoStats(RCRTCRemoteVideoStats stats) {}

  @override
  void onLiveMixMemberAudioStats(String userId, int volume) {}

  @override
  void onLiveMixMemberCustomAudioStats(String userId, String tag, int volume) {}

  @override
  void onLocalCustomAudioStats(String tag, RCRTCLocalAudioStats stats) {}

  @override
  void onLocalCustomVideoStats(String tag, RCRTCLocalVideoStats stats) {}

  @override
  void onNetworkStats(RCRTCNetworkStats stats) {
    _networkStatsStateSetter?.call(() {
      _networkStats = stats;
    });
  }

  @override
  void onLocalAudioStats(RCRTCLocalAudioStats stats) {
    _localAudioStatsStateSetter?.call(() {
      _localAudioStats = stats;
    });
  }

  @override
  void onLocalVideoStats(RCRTCLocalVideoStats stats) {
    _localVideoStatsStateSetter?.call(() {
      _localVideoStats[stats.tiny] = stats;
    });
  }

  @override
  void onRemoteAudioStats(String roomId, String userId, RCRTCRemoteAudioStats stats) {
    _remoteAudioStatsStateSetters[userId]?.call(() {
      _remoteAudioStats[userId] = stats;
    });
  }

  @override
  void onRemoteVideoStats(String roomId, String userId, RCRTCRemoteVideoStats stats) {
    _remoteVideoStatsStateSetters[userId]?.call(() {
      _remoteVideoStats[userId] = stats;
    });
  }

  @override
  void onRemoteCustomAudioStats(String roomId, String userId, String tag, RCRTCRemoteAudioStats stats) {
    _remoteCustomAudioStatsStateSetters['$userId@$tag']?.call(() {
      _remoteCustomAudioStats['$userId@$tag'] = stats;
    });
  }

  @override
  void onRemoteCustomVideoStats(String roomId, String userId, String tag, RCRTCRemoteVideoStats stats) {
    _remoteCustomVideoStatsStateSetters['$userId@$tag']?.call(() {
      _remoteCustomVideoStats['$userId@$tag'] = stats;
    });
    Main.getInstance().writeReceiveVideoFps(userId, tag, '${stats.fps}');
    Main.getInstance().writeReceiveVideoBitrate(userId, tag, '${stats.bitrate}');
  }
}

extension HostPageExtension on HostPage {
  /*
   * --------------------------
   * RongCloud Control Method
  */
  Future<bool> changeMic(bool open) async {
    if (open) {
      PermissionStatus status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          openAppSettings();
        }
        return false;
      }
    }
    int code = await Utils.engine?.enableMicrophone(open) ?? -1;
    return code != 0 ? !open : open;
  }

  Future<bool> changeCamera(bool open) async {
    if (open) {
      PermissionStatus status = await Permission.camera.request();
      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          openAppSettings();
        }
        return false;
      }
    }
    Completer<bool> completer = Completer();
    Utils.engine?.onCameraEnabled = (bool enable, int code, String? message) {
      Utils.engine?.onCameraEnabled = null;
      completer.complete(enable);
    };
    int code = await Utils.engine?.enableCamera(open) ?? -1;
    if (code != 0) {
      Utils.engine?.onCameraEnabled = null;
      return !open;
    }
    return completer.future;
  }

  Future<int> changeAudio(bool publish) async {
    int code = -1;
    Completer<int> completer = Completer();
    if (publish) {
      Utils.engine?.onPublished = (RCRTCMediaType type, int code, String? message) {
        Utils.engine?.onPublished = null;
        completer.complete(code);
      };
      code = await Utils.engine?.publish(RCRTCMediaType.audio) ?? -1;
    } else {
      Utils.engine?.onUnpublished = (RCRTCMediaType type, int code, String? message) {
        Utils.engine?.onUnpublished = null;
        completer.complete(code);
      };
      code = await Utils.engine?.unpublish(RCRTCMediaType.audio) ?? -1;
    }
    if (code != 0) {
      Utils.engine?.onPublished = null;
      Utils.engine?.onUnpublished = null;
      return code;
    }
    return completer.future;
  }

  Future<int> changeVideo(bool publish) async {
    int code = -1;
    Completer<int> completer = Completer();
    if (publish) {
      Utils.engine?.onPublished = (RCRTCMediaType type, int code, String? message) {
        Utils.engine?.onPublished = null;
        completer.complete(code);
      };
      code = await Utils.engine?.publish(RCRTCMediaType.video) ?? -1;
    } else {
      Utils.engine?.onUnpublished = (RCRTCMediaType type, int code, String? message) {
        Utils.engine?.onUnpublished = null;
        completer.complete(code);
      };
      code = await Utils.engine?.unpublish(RCRTCMediaType.video) ?? -1;
    }
    if (code != 0) {
      Utils.engine?.onPublished = null;
      Utils.engine?.onUnpublished = null;
      return code;
    }
    return completer.future;
  }

  Future<bool> changeFrontCamera(bool front) async {
    Completer<bool> completer = Completer();
    Utils.engine?.onCameraSwitched = (RCRTCCamera camera, int code, String? message) {
      Utils.engine?.onCameraSwitched = null;
      completer.complete(camera == RCRTCCamera.front);
    };
    int code = await Utils.engine?.switchCamera() ?? -1;
    if (code != 0) {
      Utils.engine?.onCameraSwitched = null;
      return !front;
    }
    return completer.future;
  }

  Future<bool> changeSpeaker(bool open) async {
    int code = await Utils.engine?.enableSpeaker(open) ?? -1;
    return code != 0 ? !open : open;
  }

  Future<bool> changeVideoConfig(RCRTCVideoConfig config) async {
    int code = await Utils.engine?.setVideoConfig(config) ?? -1;
    return code == 0;
  }

  Future<bool> changeTinyVideoConfig(RCRTCVideoConfig config) async {
    int code = await Utils.engine?.setVideoConfig(config, true) ?? -1;
    return code == 0;
  }

  Future<bool> switchToNormalStream(String id) async {
    Completer<bool> completer = Completer();
    Utils.engine?.onSubscribed = (String id, RCRTCMediaType type, int code, String? message) {
      Utils.engine?.onSubscribed = null;
      completer.complete(code == 0);
    };
    int code = await Utils.engine?.subscribe(id, RCRTCMediaType.video, false) ?? -1;
    if (code != 0) {
      Utils.engine?.onSubscribed = null;
      return false;
    }
    return completer.future;
  }

  Future<bool> switchToTinyStream(String id) async {
    Completer<bool> completer = Completer();
    Utils.engine?.onSubscribed = (String id, RCRTCMediaType type, int code, String? message) {
      Utils.engine?.onSubscribed = null;
      completer.complete(code == 0);
    };
    int code = await Utils.engine?.subscribe(id, RCRTCMediaType.video, true) ?? -1;
    if (code != 0) {
      Utils.engine?.onSubscribed = null;
      return false;
    }
    return completer.future;
  }

  /*
   * --------------------------
   * RongCloud Live Method
  */
  Future<bool> changeRemoteAudioStatus(String id, bool subscribe) async {
    // ???????????? ????????????
    Completer<bool> completer = Completer();
    int code = -1;
    if (subscribe) {
      Utils.engine?.onSubscribed = (String id, RCRTCMediaType type, int code, String? message) {
        Utils.engine?.onSubscribed = null;
        completer.complete(code != 0 ? !subscribe : subscribe);
      };
      code = await Utils.engine?.subscribe(id, RCRTCMediaType.audio) ?? -1;
    } else {
      Utils.engine?.onUnsubscribed = (String id, RCRTCMediaType type, int code, String? message) {
        Utils.engine?.onUnsubscribed = null;
        completer.complete(code != 0 ? !subscribe : subscribe);
      };
      code = await Utils.engine?.unsubscribe(id, RCRTCMediaType.audio) ?? -1;
    }
    if (code != 0) {
      Utils.engine?.onSubscribed = null;
      Utils.engine?.onUnsubscribed = null;
      return !subscribe;
    }
    return completer.future;
  }

  Future<bool> changeRemoteVideoStatus(String id, bool subscribe) async {
    // ???????????? ????????????
    Completer<bool> completer = Completer();
    int code = -1;
    if (subscribe) {
      Utils.engine?.onSubscribed = (String id, RCRTCMediaType type, int code, String? message) {
        Utils.engine?.onSubscribed = null;
        completer.complete(code != 0 ? !subscribe : subscribe);
      };
      code = await Utils.engine?.subscribe(id, RCRTCMediaType.video) ?? -1;
    } else {
      Utils.engine?.onUnsubscribed = (String id, RCRTCMediaType type, int code, String? message) {
        Utils.engine?.onUnsubscribed = null;
        completer.complete(code != 0 ? !subscribe : subscribe);
      };
      code = await Utils.engine?.unsubscribe(id, RCRTCMediaType.video) ?? -1;
    }
    if (code != 0) {
      Utils.engine?.onSubscribed = null;
      Utils.engine?.onUnsubscribed = null;
      return !subscribe;
    }
    return completer.future;
  }

  Future<int> publishCustomVideo(String id, String path, RCRTCVideoConfig config, bool yuv) async {
    // ???????????? ??????????????? - ??????
    Completer<int> completer = Completer();
    String tag = '${DefaultData.user!.id.replaceAll('_', '')}Custom';
    int code = await Utils.engine?.createCustomStreamFromFile(path: path, tag: tag) ?? -1;
    if (code != 0) {
      completer.complete(code);
      return completer.future;
    }
    code = await Utils.engine?.setCustomStreamVideoConfig(tag, config) ?? -1;
    if (code != 0) {
      completer.complete(code);
      return completer.future;
    }
    if (yuv) Main.getInstance().enableLocalCustomYuv(id);
    Utils.engine?.onCustomStreamPublished = (String tag, int code, String? message) {
      Utils.engine?.onCustomStreamPublished = null;
      completer.complete(code);
    };
    code = await Utils.engine?.publishCustomStream(tag) ?? -1;
    if (code != 0) {
      Utils.engine?.onCustomStreamPublished = null;
      completer.complete(code);
      return completer.future;
    }
    return completer.future;
  }

  Future<int> unpublishCustomVideo() async {
    // ???????????? ??????????????? - ????????????
    Completer<int> completer = Completer();
    String tag = '${DefaultData.user!.id.replaceAll('_', '')}Custom';
    Utils.engine?.onCustomStreamUnpublished = (String tag, int code, String? message) {
      Utils.engine?.onCustomStreamUnpublished = null;
      completer.complete(code);
    };
    int code = await Utils.engine?.unpublishCustomStream(tag) ?? -1;
    if (code != 0) {
      Utils.engine?.onCustomStreamUnpublished = null;
      completer.complete(code);
    }
    return completer.future;
  }

  Future<bool> changeCustomConfig(RCRTCVideoConfig config) async {
    // ???????????? ??????????????? - ?????????????????? - ???????????????????????????
    String tag = '${DefaultData.user!.id.replaceAll('_', '')}Custom';
    int code = await Utils.engine?.setCustomStreamVideoConfig(tag, config) ?? -1;
    return code == 0;
  }

  Future<bool> changeRemoteCustomVideoStatus(String rid, String uid, String tag, bool yuv, bool subscribe) async {
    // ???????????? - ??????????????? - ????????????
    Completer<bool> completer = Completer();
    int code = -1;
    if (subscribe) {
      Utils.engine?.onCustomStreamSubscribed = (String id, String tag, RCRTCMediaType type, int code, String? message) {
        Utils.engine?.onCustomStreamSubscribed = null;
        completer.complete(code != 0 ? !subscribe : subscribe);
      };
      if (yuv) Main.getInstance().enableRemoteCustomYuv(rid, uid, tag);
      code = await Utils.engine?.subscribeCustomStream(uid, tag, RCRTCMediaType.video, false) ?? -1;
    } else {
      Utils.engine?.onCustomStreamUnsubscribed =
          (String id, String tag, RCRTCMediaType type, int code, String? message) {
        Utils.engine?.onCustomStreamUnsubscribed = null;
        completer.complete(code != 0 ? !subscribe : subscribe);
      };
      Main.getInstance().disableRemoteCustomYuv(uid, tag);
      code = await Utils.engine?.unsubscribeCustomStream(uid, tag, RCRTCMediaType.video) ?? -1;
    }
    if (code != 0) {
      Utils.engine?.onCustomStreamSubscribed = null;
      Utils.engine?.onCustomStreamUnsubscribed = null;
      return !subscribe;
    }
    return completer.future;
  }

  Future<bool> changeRemoteCustomAudioStatus(String rid, String uid, String tag, bool subscribe) async {
    // ???????????? - ??????????????? - ????????????
    Completer<bool> completer = Completer();
    int code = -1;
    if (subscribe) {
      Utils.engine?.onCustomStreamSubscribed = (String id, String tag, RCRTCMediaType type, int code, String? message) {
        Utils.engine?.onCustomStreamSubscribed = null;
        completer.complete(code != 0 ? !subscribe : subscribe);
      };
      code = await Utils.engine?.subscribeCustomStream(uid, tag, RCRTCMediaType.audio, false) ?? -1;
    } else {
      Utils.engine?.onCustomStreamUnsubscribed =
          (String id, String tag, RCRTCMediaType type, int code, String? message) {
        Utils.engine?.onCustomStreamUnsubscribed = null;
        completer.complete(code != 0 ? !subscribe : subscribe);
      };
      Main.getInstance().disableRemoteCustomYuv(uid, tag);
      code = await Utils.engine?.unsubscribeCustomStream(uid, tag, RCRTCMediaType.audio) ?? -1;
    }
    if (code != 0) {
      Utils.engine?.onCustomStreamSubscribed = null;
      Utils.engine?.onCustomStreamUnsubscribed = null;
      return !subscribe;
    }
    return completer.future;
  }

  Future<int> responseJoinSubRoom(String rid, String uid, bool agree) async {
    // ????????????
    Completer<int> completer = Completer();
    Utils.engine?.onJoinSubRoomRequestResponded = (roomId, userId, agree, code, message) {
      Utils.engine?.onJoinSubRoomRequestResponded = null;
      completer.complete(code);
    };
    int code = await Utils.engine?.responseJoinSubRoomRequest(rid, uid, agree) ?? -1;
    if (code != 0) {
      Utils.engine?.onJoinSubRoomRequestResponded = null;
      return code;
    }
    return completer.future;
  }

  /*
   * --------------------------
   * Page Control Method
  */
  Future<int> exit() async {
    // ???????????????
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
