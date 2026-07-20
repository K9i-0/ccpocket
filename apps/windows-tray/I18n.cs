namespace CCPocketTray;

internal static class I18n
{
    public const string Chinese = "zh-CN";
    public const string English = "en-US";

    public static bool IsChinese(string language) => language == Chinese;

    public static string DisplayName(string language)
    {
        return IsChinese(language) ? "中文" : "English";
    }

    public static string T(string language, string key)
    {
        var zh = IsChinese(language);
        return key switch
        {
            "appTitle" => "CC Pocket Bridge",
            "heroSubtitle" => zh
                ? "本机代理网关，后台运行并让手机连接到本机编码会话。"
                : "Local agent gateway for phone control, running quietly from the tray.",
            "language" => zh ? "语言" : "Language",
            "running" => zh ? "运行中" : "Running",
            "starting" => zh ? "启动中" : "Starting",
            "stopped" => zh ? "已停止" : "Stopped",
            "waitingHealth" => zh ? "等待健康检查" : "waiting for health check",
            "notReachable" => zh ? "Bridge 暂不可连接" : "bridge is not reachable",
            "uptime" => zh ? "运行" : "uptime",
            "clients" => zh ? "客户端" : "clients",
            "sessions" => zh ? "会话" : "sessions",
            "start" => zh ? "开始" : "Start",
            "stop" => zh ? "停止" : "Stop",
            "restart" => zh ? "重启" : "Restart",
            "save" => zh ? "保存" : "Save",
            "open" => zh ? "打开主界面" : "Open",
            "exit" => zh ? "退出" : "Exit",
            "copyWsUrl" => zh ? "复制 WebSocket 地址" : "Copy WebSocket URL",
            "settings" => zh ? "Bridge 设置" : "Bridge settings",
            "port" => zh ? "端口" : "Port",
            "host" => zh ? "监听地址" : "Host",
            "allowedDirs" => zh ? "允许目录" : "Allowed dirs",
            "apiKey" => zh ? "API 密钥" : "API key",
            "startOnLaunch" => zh ? "打开托盘程序时自动启动 Bridge" : "Open Bridge with tray app",
            "connectPhone" => zh ? "连接手机" : "Connect phone",
            "connectNote" => zh
                ? "选择 iOS 客户端能访问的地址。手机和电脑在同一网络时，优先使用局域网地址。"
                : "Pick a reachable address for the iOS client. LAN addresses work when both devices are on the same network.",
            "deepLink" => zh ? "深度链接" : "Deep link",
            "copyUrl" => zh ? "复制 URL" : "Copy URL",
            "copyDeepLink" => zh ? "复制链接" : "Copy deep link",
            "healthPage" => zh ? "健康页" : "Open health",
            "logs" => zh ? "Bridge 日志" : "Bridge logs",
            "logsNote" => zh ? "后台 Bridge 进程的实时输出。" : "Live output from the background bridge process.",
            "emptyLogs" => zh ? "暂无 Bridge 日志。点击“开始”后会在这里显示输出。" : "No bridge logs yet. Start Bridge to stream output here.",
            "attached" => zh ? "Bridge 已可连接，托盘已接管显示。" : "Bridge is already reachable. Tray app is attached.",
            "startingBalloon" => zh ? "Bridge 正在后台启动。" : "Bridge is starting in the background.",
            "copied" => zh ? "已复制" : "Copied",
            _ => key,
        };
    }
}
