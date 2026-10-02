# Escape Black Pine / 逃离黑松疗养院

这是一个 Godot 4.7.2 制作的 3D 第一人称恐怖逃脱游戏原型，目标平台为 Android。

## 已实现

- 废弃疗养院 / 旧校舍风格室内 3D 场景
- 两枚保险丝 → 恢复配电 → 档案室钥匙 → 正门逃生的完整目标链
- “值夜人”巡逻、视线侦测、追逐、搜索、抓捕与重生
- 手电筒电量、低电量闪烁、冲刺体力、头部晃动
- 动态阴影、雾、Film tonemapping、PBR 材质、应急灯与随机视觉惊吓
- Android 双区触控：左侧拖动移动，右侧拖动观察，右侧轻点交互
- PC：WASD / Shift / 鼠标 / E或左键 / F

## Godot 无头构建 APK

GitHub Actions 使用官方 Godot 4.7.2 与 Android export templates，并执行：

```bash
godot --headless --path . --import
godot --headless --path . --export-debug Android build/escape-black-pine.apk
```

构建成功后，在 Actions 对应运行的 Artifacts 下载 `escape-black-pine-apk`。

> `payload/` 是旧版原生 C++ 构建留下的历史文件，新 Godot 工作流不再读取它。
