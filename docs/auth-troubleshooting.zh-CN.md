# Claude 认证故障排查

[English](auth-troubleshooting.md) | [日本語版](auth-troubleshooting.ja.md)

CC Pocket 会使用保存在你的 Bridge 机器上的 Claude Code 登录状态。
如果认证失败，请在那台机器上重新登录 Claude Code。

## 当你不在 Bridge 机器旁边时

在 CC Pocket 的使用场景里，你的 Bridge 机器可能是家里的 Mac mini，或者另一台一直开着的 Mac。
即使如此，你也可以直接用手机远程重新登录 Claude Code。

1. 用终端应用连接到 Bridge 机器
   - 可以使用 Moshi、Termius、Blink 或任意 SSH 客户端
2. 运行 `claude`
3. 在 Claude Code 中执行 `/login`
4. 在手机或电脑浏览器中打开显示出来的 URL
5. 完成登录
6. 如果终端提示需要粘贴结果，就把结果贴回去

从下一次请求开始，CC Pocket 就会使用更新后的登录状态。

## 当你就在 Bridge 机器旁边时

1. 在 Bridge 机器上运行 `claude`
2. 执行 `/login`
3. 在浏览器中完成登录流程

## Shell 方式

如果你愿意，也可以直接运行下面的命令：

```bash
claude auth login
```

## 常见原因

- 你的 Claude 登录已过期
- Claude Code 更新后，旧的登录状态失效了
- Anthropic 撤销了已保存的令牌
