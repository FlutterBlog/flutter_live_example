import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:handy_toast/handy_toast.dart';
import 'package:rongcloud_im_plugin/rongcloud_im_plugin.dart';
import 'package:rongcloud_rtc_wrapper_plugin/rongcloud_rtc_wrapper_plugin.dart';
import 'package:beeto_live/data/constants.dart';
import 'package:beeto_live/data/data.dart';
import 'package:beeto_live/frame/network/network.dart';
import 'package:beeto_live/global_config.dart';
import 'package:beeto_live/utils/utils.dart';
import 'package:beeto_live/frame/ui/loading.dart';
import 'package:beeto_live/frame/utils/extension.dart';
import 'package:beeto_live/router/router.dart';
import 'package:beeto_live/widgets/ui.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({Key? key}) : super(key: key);

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  /*
   * --------------------------
  */
  // CancelToken? _tag = CancelToken();

  bool _yuv = false;
  bool _srtp = false;
  bool _connected = false;

  RCRTCMediaType _type = RCRTCMediaType.audio_video;
  RCRTCRole _role = RCRTCRole.meeting_member;

  Config _config = Config.config();

  //账号 - 1000438579
  TextEditingController _tokenInputController = TextEditingController(
      text: "FORcy3ZR6BhXOJHUDko68u5hOKJrhxe4ZxCJwpSy0mQ=@ma72.sg.rongnav.com;ma72.sg.rongcfg.com");

  //账号 - 1000480268
  // TextEditingController _tokenInputController = TextEditingController(
  //     text: "FORcy3ZR6BiTS4rvzvMIfe5hOKJrhxe4o7cjqmIubCQ=@ma72.sg.rongnav.com;ma72.sg.rongcfg.com");

  TextEditingController _keyInputController = TextEditingController(text: "uwd1c0sxuk0j1");
  TextEditingController _navigateInputController = TextEditingController();
  TextEditingController _fileInputController = TextEditingController();
  TextEditingController _mediaInputController = TextEditingController();
  TextEditingController _inputController = TextEditingController();

  /*
   * --------------------------
  */
  @override
  void initState() {
    super.initState();

    _disconnect();
    widget.load();
  }

  @override
  void dispose() {
    if (_connected) _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'LiveTestDemo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.info_outlined,
            ),
            onPressed: () => _showInfo(context),
          ),
        ],
      ),
      body: Container(
        padding: EdgeInsets.all(20.dp),
        child: Column(
          children: [
            Row(
              children: [
                DropdownButton(
                  hint: Text('获取缓存用户'),
                  items: _buildUserItems(),
                  onChanged: (dynamic user) {
                    _keyInputController.text = user.key;
                    _navigateInputController.text = user.navigate;
                    _fileInputController.text = user.file;
                    _mediaInputController.text = user.media;
                    _tokenInputController.text = user.token;
                  },
                ),
                Spacer(),
                Button(
                  '清空缓存',
                  callback: () {
                    widget.clear();
                    setState(() {});
                  },
                ),
              ],
            ),
            Divider(
              height: 15.dp,
              color: Colors.transparent,
            ),
            InputBox(
              hint: 'App Key',
              controller: _keyInputController,
              formatter: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z]')),
              ],
            ),
            Divider(
              height: 15.dp,
              color: Colors.transparent,
            ),
            InputBox(
              hint: 'Navigate Url',
              controller: _navigateInputController,
              formatter: [
                FilteringTextInputFormatter.allow(RegExp(r'[\w\-\/\/\.:]')),
              ],
            ),
            Divider(
              height: 15.dp,
              color: Colors.transparent,
            ),
            InputBox(
              hint: 'File Url',
              controller: _fileInputController,
              formatter: [
                FilteringTextInputFormatter.allow(RegExp(r'[\w\-\/\/\.:]')),
              ],
            ),
            Divider(
              height: 15.dp,
              color: Colors.transparent,
            ),
            InputBox(
              hint: 'Media Url',
              controller: _mediaInputController,
              formatter: [
                FilteringTextInputFormatter.allow(RegExp(r'[\w\-\/\/\.:]')),
              ],
            ),
            Divider(
              height: 15.dp,
              color: Colors.transparent,
            ),
            Row(
              children: [
                Expanded(
                  child: InputBox(
                    hint: 'Token',
                    controller: _tokenInputController,
                  ),
                ),
              ],
            ),
            Divider(
              height: 15.dp,
              color: Colors.transparent,
            ),
            Row(
              children: [
                Spacer(),
                Button(
                  _connected ? '断开链接' : '链接',
                  callback: () => _connected ? _disconnect() : _connect(),
                ),
              ],
            ),
            _connected
                ? Container(
                    padding: EdgeInsets.only(top: 20.dp),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Radios(
                              '会议模式',
                              value: RCRTCRole.meeting_member,
                              groupValue: _role,
                              onChanged: (dynamic value) {
                                _inputController.text = '';
                                setState(() {
                                  _role = value;
                                });
                              },
                            ),
                            Spacer(),
                            Radios(
                              '主播模式',
                              value: RCRTCRole.live_broadcaster,
                              groupValue: _role,
                              onChanged: (dynamic value) {
                                _inputController.text = '';
                                setState(() {
                                  _role = value;
                                });
                              },
                            ),
                            Spacer(),
                            Radios(
                              '观众模式',
                              value: RCRTCRole.live_audience,
                              groupValue: _role,
                              onChanged: (dynamic value) {
                                _inputController.text = '';
                                setState(() {
                                  _role = value;
                                });
                              },
                            ),
                          ],
                        ),
                        Divider(
                          height: 15.dp,
                          color: Colors.transparent,
                        ),
                        _buildArea(context),
                        Divider(
                          height: 15.dp,
                          color: Colors.transparent,
                        ),
                        Row(
                          children: [
                            CheckBoxes(
                              'SRTP加密',
                              checked: _srtp,
                              onChanged: (checked) {
                                setState(() {
                                  _srtp = checked;
                                });
                              },
                            ),
                            Spacer(),
                            _role != RCRTCRole.live_audience
                                ? CheckBoxes(
                                    '大小流',
                                    checked: _config.enableTinyStream,
                                    onChanged: (checked) {
                                      setState(() {
                                        _config.enableTinyStream = checked;
                                      });
                                    },
                                  )
                                : Container(),
                            _role != RCRTCRole.live_audience ? Spacer() : Container(),
                            _role == RCRTCRole.live_broadcaster
                                ? CheckBoxes(
                                    '保存YUV数据',
                                    checked: _yuv,
                                    onChanged: (checked) {
                                      setState(() {
                                        _yuv = checked;
                                      });
                                    },
                                  )
                                : Container(),
                          ],
                        ),
                        Divider(
                          height: 15.dp,
                          color: Colors.transparent,
                        ),
                        Row(
                          children: [
                            Spacer(),
                            Button(
                              _getAction(),
                              callback: _action,
                            ),
                            Spacer(),
                          ],
                        ),
                      ],
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }

  /*
   * --------------------------
  */
  String _getHint() {
    switch (_role) {
      case RCRTCRole.meeting_member:
        return 'Meeting id';
      case RCRTCRole.live_broadcaster:
        return 'Room id';
      case RCRTCRole.live_audience:
        return 'Room id';
    }
  }

  String _getAction() {
    switch (_role) {
      case RCRTCRole.meeting_member:
        return '加入会议';
      case RCRTCRole.live_broadcaster:
        return '开始直播';
      case RCRTCRole.live_audience:
        return '观看直播';
    }
  }

  Widget _buildArea(BuildContext context) {
    switch (_role) {
      case RCRTCRole.meeting_member:
        return InputBox(
          hint: '${_getHint()}.',
          controller: _inputController,
        );
      case RCRTCRole.live_broadcaster:
        return Column(
          children: [
            InputBox(
              hint: '${_getHint()}.',
              controller: _inputController,
            ),
            Divider(
              height: 10.dp,
              color: Colors.transparent,
            ),
            Row(
              children: [
                Spacer(),
                Radios(
                  '音视频模式',
                  value: RCRTCMediaType.audio_video,
                  groupValue: _type,
                  onChanged: (dynamic value) {
                    setState(() {
                      _type = value;
                    });
                  },
                ),
                Spacer(),
                Radios(
                  '音频模式',
                  value: RCRTCMediaType.audio,
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
          ],
        );
      case RCRTCRole.live_audience:
        return Row(
          children: [
            Expanded(
              child: InputBox(
                hint: '${_getHint()}.',
                controller: _inputController,
              ),
            ),
          ],
        );
    }
  }

  void _showInfo(BuildContext context) {
    String info = '默认参数: \n'
        'App Key:${GlobalConfig.appKey}\n'
        'Nav Server:${GlobalConfig.navServer}\n'
        'File Server:${GlobalConfig.fileServer}\n'
        'Media Server:${GlobalConfig.mediaServer.isEmpty ? '自动获取' : GlobalConfig.mediaServer}\n';
    if (_connected)
      info += '当前使用: \n'
          'App Key:${DefaultData.user?.key}\n'
          'Nav Server:${DefaultData.user?.navigate}\n'
          'File Server:${DefaultData.user?.file}\n'
          'Media Server:${DefaultData.user?.media?.isEmpty ?? true ? '自动获取' : DefaultData.user?.media}\n';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('默认配置'),
          content: SelectableText(
            info,
          ),
          actions: [
            TextButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  List<DropdownMenuItem<User>> _buildUserItems() {
    List<DropdownMenuItem<User>> items = [];
    DefaultData.users.forEach((user) {
      items.add(DropdownMenuItem(
        value: user,
        child: Text(
          '${user.key}-${user.id}',
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.black,
            decoration: TextDecoration.none,
          ),
        ),
      ));
    });
    return items;
  }

  /*
   * --------------------------
  */

  // 融云 开始连接 IM-SDK
  void _connect() {
    FocusScope.of(context).requestFocus(FocusNode());

    String key = _keyInputController.text;
    String navigate = _navigateInputController.text;
    String file = _fileInputController.text;
    String token = _tokenInputController.text;
    String media = _mediaInputController.text;

    if (key.isEmpty) return 'Key Should not be null!'.toast();
    if (token.isEmpty) return 'Token Should not be null!'.toast();

    Loading.show(context);
    widget.connect(
      key,
      navigate,
      file,
      media,
      token,
      (code, info) {
        //
        if (code != 0)
          onConnectError(code, info);
        else
          onConnected(info);
      },
    );
  }

  // 融云 断开连接 IM-SDK
  void _disconnect() {
    widget.disconnect();
    setState(() {
      _connected = false;
    });
  }

  /*
   * --------------------------
  */

  // 融云 连接成功
  void onConnected(String id) {
    Loading.dismiss(context);
    'IM Connected.'.toast();
    setState(() {
      _connected = true;
    });
  }

  // 融云 连接失败
  void onConnectError(int code, String? id) {
    Loading.dismiss(context);
    'IM Connect Error, code = $code'.toast();
    setState(() {
      _connected = false;
    });
  }

  // 初始化引擎 成功
  void onDone(String id) {
    Loading.dismiss(context);
    switch (_role) {
      case RCRTCRole.meeting_member:
        _toMeeting(id);
        break;
      case RCRTCRole.live_broadcaster:
        _toHost(id);
        break;
      case RCRTCRole.live_audience:
        _toAudience(id);
        break;
    }
  }

  // 初始化引擎 失败
  void onError(int code, String? info) {
    Loading.dismiss(context);
    '${_getAction()}失败, Code = $code, Info = $info'.toast();
  }

  /*
   * --------------------------
   * Private Method
  */

  // 预初始化引擎，准备进入房间
  void _action() {
    // live_broadcaster - '开始直播'
    // live_audience - '观看直播'
    String info = _inputController.text;
    if (info.isEmpty) return '${_getHint()} should not be null!'.toast();
    Loading.show(context);
    RCRTCMediaType type = _role == RCRTCRole.live_broadcaster ? _type : RCRTCMediaType.audio_video;
    String media = _mediaInputController.text;

    widget.action(info, media, type, _role, _config.enableTinyStream, _yuv, _srtp, (code, info) {
      //
      if (code != 0) {
        onError(code, info);
      } else {
        onDone(info);
      }
    });
  }

  // 已进入房间 观看直播
  void _toAudience(String id) {
    Navigator.pushNamed(
      context,
      RouterManager.AUDIENCE,
      arguments: id,
    );
  }

  // 已进入房间 开始直播
  void _toHost(String id) {
    Map<String, dynamic> arguments = {
      'id': id,
      'config': _config.toJson(),
      'yuv': _yuv,
    };
    Navigator.pushNamed(
      context,
      RouterManager.HOST,
      arguments: arguments,
    );
  }

  // 已进入房间 加入会议
  void _toMeeting(String id) {
    // Map<String, dynamic> arguments = {
    //   'id': id,
    //   'config': _config.toJson(),
    // };

    // Navigator.pushNamed(
    //   context,
    //   RouterManager.MEETING,
    //   arguments: arguments,
    // );
  }
}

/*
 * --------------------------
 * Extension
*/
extension ConnectPageExtension on ConnectPage {
  // 缓存数据 加载
  void load() {
    DefaultData.loadUsers();
  }

  // 缓存数据 清空
  void clear() {
    DefaultData.clear();
  }

  // 融云 IM-SDK 开始连接
  void connect(
    String key,
    String navigate,
    String file,
    String media,
    String token,
    StateCallback callback,
  ) {
    if (key.isEmpty) key = GlobalConfig.appKey;
    if (navigate.isEmpty) navigate = GlobalConfig.navServer;
    if (file.isEmpty) file = GlobalConfig.fileServer;
    if (media.isEmpty) media = GlobalConfig.mediaServer;

    RongIMClient.setServerInfo(navigate, file);
    RongIMClient.init(key);

    RongIMClient.connect(token, (code, id) {
      if (code == RCErrorCode.Success) {
        User user = User.create(
          id!,
          key,
          navigate,
          file,
          media,
          token,
        );
        DefaultData.user = user;
      }
      callback(code, id);
    });
  }

  // 融云 IM-SDK 断开连接
  void disconnect() {
    RongIMClient.disconnect(false);
  }

  // 融云 RCRTCEngine 初始化 进入房间
  void action(
    String id,
    String media,
    RCRTCMediaType type,
    RCRTCRole role,
    bool tiny,
    bool yuv,
    bool srtp,
    StateCallback callback,
  ) async {
    RCRTCVideoSetup videoSetup = RCRTCVideoSetup.create(
      enableTinyStream: tiny,
      enableTexture: !yuv,
    );
    RCRTCEngineSetup engineSetup = RCRTCEngineSetup.create(
      enableSRTP: srtp,
      mediaUrl: media,
      videoSetup: videoSetup,
    );
    Utils.engine = await RCRTCEngine.create(engineSetup);

    RCRTCRoomSetup setup = RCRTCRoomSetup.create(type: type, role: role);
    Utils.engine?.onRoomJoined = (int code, String? message) {
      Utils.engine?.onRoomJoined = null;
      callback(code, code == 0 ? id : '$message');
    };
    int ret = await Utils.engine?.joinRoom(id, setup) ?? -1;
    if (ret != 0) {
      Utils.engine?.onRoomJoined = null;
      callback(ret, 'Join room error $ret');
    }
  }
}
