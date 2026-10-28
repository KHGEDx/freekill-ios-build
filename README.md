# FreeKill iPad 云端构建包

目标：iPadOS **16.1.1**；真机 **arm64**；最低部署系统 **16.0**。

**这是尚未经过 macOS 编译和 iPad 真机验证的第一版移植工程，不是已经可安装的 IPA。** 云端首次构建可能失败，需要根据日志继续修正；即使编译成功，也需要在 iPad 上验证能否正常游玩。

不需要 Mac。本工程使用 GitHub Actions 的 macOS 环境编译，再把未签名 IPA 交给你的签名软件处理。不需要把签名证书或密码上传到仓库。

## 上传和运行

1. 登录 GitHub，建立一个新仓库，例如 `freekill-ios-build`。建议选择 Public；Private 的 Actions 用量取决于账号额度。不要为本工程购买付费 runner。
2. 解压构建包。在新仓库的文件页面点击 **Add file → Upload files**，把解压后目录里的全部内容（包括 **`.github`、`ios`、`tests`、`.gitattributes`、`.gitignore`、`LICENSE` 和 `README.md`**）一起上传。`.github/workflows/build-ios.yml` 必须位于仓库根目录下的这个路径，不能多套一层 `freekill-ios-cloud` 文件夹。不要直接上传 ZIP。
3. 提交上传。进入仓库的 **Actions** 页，若出现启用按钮，启用本仓库工作流。
4. 选择 **Build FreeKill for iPad → Run workflow → Run workflow**。只提供手动触发，不会在每次上传时自动编译。
5. 构建成功后，在本次运行页面下方 **Artifacts** 下载 `FreeKill-iPad-unsigned`。解压后得到 `FreeKill-iPad-unsigned.ipa` 与 `build-report.json`。用你自己的签名软件签署 IPA，再安装到 iPad。
6. 如果变红，下载 `FreeKill-iPad-build-logs`，把失败日志或运行链接提供给协作者继续修正。首次编译的目标是获取真实诊断，不能承诺一次成功。

如果看不到 **Run workflow**，先确认 `.github/workflows/build-ios.yml` 已提交到默认分支。GitHub 的操作参考：[手动运行工作流](https://docs.github.com/en/actions/using-workflows/manually-running-a-workflow)。

## 代码和构建范围

- 固定 FreeKill 提交：`671b0ad698c36b703808d8b29f3483ce54b36631`，项目版本 0.5.25。不会悄悄跟随 master 更新。
- Qt 主机工具和 iOS 库均固定 6.8.3。runner 使用 `macos-15-intel`；若存在 Xcode 16.4，优先使用它，否则记录镜像默认 Xcode 版本。
- Lua 5.4.8、OpenSSL 3.5.4、libgit2 1.9.0 从固定源码构建；下载前后核对 `ios/sources.json` 的 SHA256。
- 增加 iOS 依赖分支、SoLoud 静态链接、QML 静态插件导入、iPad 横屏与文件共享配置。
- 在打开日志前，将随包数据复制到 `Documents/FreeKill`；更新不会覆盖已有扩展包文件。应用中的“修复资源”会使内置资源在下次启动重新复制。需要删除应用时，先导出数据。
- 应用标识符：`org.freekill.ipad`。签名软件可能更改它；具体签名/安装能力由所用工具和证书决定。
- 打包脚本检查真机平台、arm64、系统要求和资源文件；成功生成 IPA 仍不能证明联网、音效、动画和完整对局正常。
- 工作流只上传构建产物和日志，不自动发布 Release。

扩展包能否正常使用也需要实测，尤其是涉及额外本机二进制库的扩展。Lua 游戏脚本可以复用，但不能保证所有 Android 原生扩展可用。

## 真机验收

安装并启动，检查中文界面与横屏触摸；连接服务器并完成一局；检查音效与动画、录像、扩展包安装、后台返回后的重连，以及关闭重开后的设置保留。任一步失败都需继续修正，不能仅凭安装成功宣告移植完成。

## 许可证与来源

FreeKill：https://github.com/Qsgs-Fans/FreeKill ，GPL-3.0。保留随包 LICENSE。
本工程新增代码和补丁同样按 GPL-3.0-or-later 提供。
构建所用第三方源码地址和完整性摘要见 `ios/sources.json`；Qt、Lua、OpenSSL、libgit2 等组件分别遵循其许可证。

Qt 6.8 的 iOS 系统范围及构建要求：[Qt 官方文档](https://doc.qt.io/qt-6.8/ios.html)。
runner 标签依据：[GitHub runner-images](https://github.com/actions/runner-images)。
