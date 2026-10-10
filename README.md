> 当前主要开发版本为 **Faceless 2**，代码在 [`faceless2/`](faceless2/README.md)。
> 安卓构建使用 **Build Faceless 2 v10 Layered Forest and Natural Motion APK** 工作流；当前游戏与测试说明见 [faceless2/README.md](faceless2/README.md)，下面是保留的旧版原型说明。

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

## Current Android build: Backrooms / Night Relay v0.11.0

The current development branch replaces monster/combat gameplay with three Backrooms layers and FNAF-inspired live surveillance, power, isolation shutters, anomaly reporting and cooperative exploration. Native ENet direct P2P supports up to four players. See [gameplay, connection instructions, testing and APK build](faceless2/README.md). The workflow exports `backrooms-v11-zorix.apk` with the supplied Zorix branding.
