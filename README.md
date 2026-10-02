# Escape School Native

原生 Android C++ / NDK / OpenGL ES 3.0 的 3D「逃离学校」小游戏。

## 自动构建 APK

GitHub Actions 会在 main 分支 push 后自动：

1. 合并 `payload/chunk00.b64` 到 `chunk07.b64`
2. 校验源码 ZIP SHA-256
3. 解压完整 C++ + GLB 工程
4. 使用 Android NDK 编译
5. 上传 `escape-school-debug-apk` artifact

源码归档 SHA-256:

`7fd9187029f38ccd790f73e5bc2a055cd0023c5cc7fb0220b3bd3530c7db70bf`

游戏包含第一人称触控、学校场景、钥匙、出口门、碰撞和巡逻老师。
