# 验证状态

本包已通过：

- 对固定上游提交执行 `git apply --check`，8 个文件的补丁均匹配。
- 两个构建 Shell 脚本通过 `bash -n`。
- 4 个 Python 文件通过语法解析。
- GitHub Actions YAML 可解析，手动触发与只读 token 配置检查通过。
- 5 项打包器测试通过：拒绝 arm64 模拟器、拒绝过高系统要求、拒绝桌面 x86、拒绝截断 Mach-O，以及验证 IPA 内部路径与主程序执行权限。这些使用合成的测试数据，不是 FreeKill 编译产物。
- 源码依赖下载并记录 SHA256；Qt 6.8.3 的 iOS 下载元数据中确认了本工作流使用的附加模块名称。

云端及实际产物验证（2026-10-29）：

- [第六轮 GitHub Actions](https://github.com/KHGEDx/freekill-ios-build/actions/runs/40798606145)成功，使用 Xcode 16.4、Qt 6.8.3，构建提交为 `372f11cef0c7a3e6d13107c1dce47998ac4d41a7`。
- 已下载真实产物，外层 ZIP 的 SHA256 与 GitHub 摘要一致：`850f8d2bab9dc642c7af3065781a5a05317afc397f2074efd2acbf5294cedc99`。
- IPA 为 71,666,398 字节；SHA256：`877ce9a5ce820a9b5377e831fd93fc37cd3b7d481179325bbccd9110e7d8e1dd`。
- 已独立检查 IPA 的 ZIP 完整性、Payload 路径、主程序执行权限、Info.plist 的 iPhoneOS/iPad 配置及游戏资源。
- 主程序和 5 个 FFmpeg 框架均为 arm64 iOS 真机 Mach-O，最低系统均为 16.0；没有遗漏的 `@rpath` 框架依赖。

尚未完成：外部签名、安装与 iPadOS 16.1.1 上的启动、联网及完整对局验证。编译和静态检查通过不能证明实际游玩正常。
