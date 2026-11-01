import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos'

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'
const EVENT_STARTUP_PROGRESS = 'EVENT_STARTUP_PROGRESS'

// 原生启动遮罩（与 JVMX java 版 Index.ets 对齐）。
// Flutter 打开 deferFirstFrame 后不会立即出帧，这段时间由这里显示
// 品牌图标 + 线性进度条；Dart 通过 qflistudio/platform.startupProgress
// 上报 0..1 的真实初始化进度，EntryAbility 转成 eventHub 事件广播过来。
@Component
struct StartupSplash {
  private context = getContext(this) as common.UIAbilityContext;
  @State progress: number = 0;

  private onProgress = (progress: number): void => {
    // 事件里已是 0..1，这里换成 Progress 需要的百分值。
    this.progress = progress * 100;
  };

  aboutToAppear(): void {
    this.context.eventHub.on(EVENT_STARTUP_PROGRESS, this.onProgress);
  }

  aboutToDisappear(): void {
    // 只在挂载期间订阅，首帧后 FlutterPage 会移除本组件。
    this.context.eventHub.off(EVENT_STARTUP_PROGRESS, this.onProgress);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image($r('app.media.icon'))
        .width(96)
        .height(96)
        .objectFit(ImageFit.Contain)
        .borderRadius(24)
        .clip(true)

      Column() {
        Blank()
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .constraintSize({ maxWidth: 420 })
          .style({ strokeWidth: 4, enableSmoothEffect: true, enableScanEffect: true })
          .id('qfli-native-startup-progress')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 32, right: 32, bottom: 48 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.IDENTITY,
      TransitionEffect.OPACITY.animation({ duration: 280, curve: Curve.EaseOut }),
    ))
    .id('qfli-native-startup-splash')
  }
}

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";

  @Builder
  startupSplash() {
    StartupSplash()
  }

  build() {
    Column() {
      FlutterPage({ viewId: this.viewId, splashScreenView: this.startupSplash })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }

  onBackPress(): boolean {
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
