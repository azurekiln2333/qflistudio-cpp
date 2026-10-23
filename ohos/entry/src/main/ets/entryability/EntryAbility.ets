
import {
  FlutterAbility,
  FlutterEngine,
  MethodChannel,
  MethodCall,
  MethodResult,
} from '@ohos/flutter_ohos';
import { authentication } from '@kit.AccountKit';
import { systemShare } from '@kit.ShareKit';
import { common, Want, ConfigurationConstant } from '@kit.AbilityKit';
import { window, router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { handlePickerCall, isPickerMethod } from './PickerBridge';
// 应用内 LLVM/WASI C/C++ 编译运行后端。
import { registerQfliNativeChannel } from '../plugins/QfliCNative';

const CHANNEL_PLATFORM = 'qflistudio/platform';
const CHANNEL_HUAWEI = 'qflistudio/huawei_account';
// Standalone C/C++ keeps platform integration local.
const OFFLINE_ONLY = true;

export default class EntryAbility extends FlutterAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 启动遮罩消失后、Flutter 首帧渲染前，引擎初始化期间窗口会露出
    // 默认白底。窗口底色与 Flutter 的 MD3 surface 保持一致。
    try {
      const isDark = this.context.config?.colorMode ===
        ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      windowStage.getMainWindowSync().setWindowBackgroundColor(
        isDark ? '#FF111418' : '#FFF8F9FF',
      );
    } catch (e) {
      // 设置失败不影响启动（仅深色模式可能出现短暂白闪）。
    }
    super.onWindowStageCreate(windowStage);
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)

    const abilityContext = this.context as common.UIAbilityContext;

    // 原生编译运行后端：注册 qfli_forge/native 与 qfli_forge/native/events。
    //
    // 教学页面通过包内 LLVM 22 编译，再用 WasmEdge 解释执行 WASI 字节码。
    // C++20、标准库、异常和混编的可用性以 App 实际验证为准。
    //
    // 这里刻意用 try/catch 包住：如果工具链资源缺失或解压失败，
    // Dart 侧会收到 available:false 并报告不可用，而不是整个 App 起不来。
    try {
      registerQfliNativeChannel(flutterEngine, abilityContext);
    } catch (e) {
      const err = e as BusinessError;
      console.error(`QFLI native channel unavailable: ${err.code}: ${err.message}`);
    }

    // 本地平台能力；独立版先拒绝远程协议和浏览器入口。
    const platformChannel = new MethodChannel(
      flutterEngine.dartExecutor.getBinaryMessenger(),
      CHANNEL_PLATFORM,
    );
    platformChannel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult): void {
        if (OFFLINE_ONLY && (call.method === 'openAgreement' || call.method === 'openUrl')) {
          result.error('OFFLINE_ONLY', '独立离线版不提供远程协议或浏览器入口', null);
          return;
        }
        if (call.method === 'openAgreement') {
          const url = call.argument('url') as string;
          const title = call.argument('title') as string;
          if (typeof url !== 'string' || !url.startsWith('https://')) {
            result.error('INVALID_URL', '协议地址无效', null);
            return;
          }
          router.pushUrl({ url: 'pages/AgreementReader', params: { url, title } })
            .then(() => result.success(null))
            .catch((err: BusinessError) => result.error('AGREEMENT_OPEN_FAILED', `${err.code}: ${err.message}`, null));
        } else if (call.method === 'openUrl') {
          const url = call.argument('url') as string;
          const want: Want = {
            action: 'ohos.want.action.viewData',
            uri: url,
          };
          abilityContext.startAbility(want)
            .then(() => {
              result.success(null);
            })
            .catch((err: BusinessError) => {
              result.error(`${err.code}`, `${err.message}`, null);
            });
        } else if (call.method === 'shareText') {
          // 系统分享面板（Share Kit）：纯文本分享。
          const title = call.argument('title') as string;
          const text = call.argument('text') as string;
          const record: systemShare.SharedRecord = {
            utd: 'general.plain-text',
            content: text,
            title: title,
          };
          const data = new systemShare.SharedData(record);
          const controller = new systemShare.ShareController(data);
          const options: systemShare.ShareControllerOptions = {};
          controller.show(abilityContext, options)
            .then(() => {
              result.success(null);
            })
            .catch((err: BusinessError) => {
              result.error('SHARE_FAILED', `${err.code}: ${err.message}`, null);
            });
        } else if (isPickerMethod(call.method)) {
          handlePickerCall(abilityContext, call, result);
        } else {
          result.notImplemented();
        }
      },
    });

    // 华为账号（Account Kit v4 / API 11）：
    // AuthorizationWithHuaweiIDRequest -> executeRequest -> authorizationCode，
    // authorizationCode 交给服务端换取 token / userinfo。
    const huaweiChannel = new MethodChannel(
      flutterEngine.dartExecutor.getBinaryMessenger(),
      CHANNEL_HUAWEI,
    );
    huaweiChannel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult): void {
        if (OFFLINE_ONLY && call.method === 'login') {
          result.error('OFFLINE_ONLY', '独立离线版不提供账号登录', null);
          return;
        }
        if (call.method === 'login') {
          try {
            const provider = new authentication.HuaweiIDProvider();
            const request: authentication.AuthorizationWithHuaweiIDRequest =
              provider.createAuthorizationWithHuaweiIDRequest();
            request.scopes = ['openid'];
            request.permissions = [];

            const controller =
              new authentication.AuthenticationController(abilityContext);
            controller.executeRequest(request)
              .then((response: authentication.AuthenticationResponse) => {
                const authResponse =
                  response as authentication.AuthorizationWithHuaweiIDResponse;
                const code: string =
                  authResponse.data?.authorizationCode ?? '';
                if (code.length > 0) {
                  result.success(code);
                } else {
                  result.error('HUAWEI_LOGIN_EMPTY', '未获取到授权码', null);
                }
              })
              .catch((err: BusinessError) => {
                result.error('HUAWEI_LOGIN_FAILED', `${err.code}: ${err.message}`, null);
              });
          } catch (e) {
            const err = e as BusinessError;
            result.error('HUAWEI_LOGIN_ERROR', `${err.code}: ${err.message}`, null);
          }
        } else {
          result.notImplemented();
        }
      },
    });
  }
}
