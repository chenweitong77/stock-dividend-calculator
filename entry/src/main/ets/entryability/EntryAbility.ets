/**
 * EntryAbility - 应用入口
 */
import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage) {
    // 加载主页面
    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        console.error('加载页面失败:', JSON.stringify(err));
      }
    });
  }
}
