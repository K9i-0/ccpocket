using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using System.Text.Json.Serialization;

namespace CCPocketTray;

internal sealed class BridgeProcessManager : IDisposable
{
    private static readonly string LogDirectory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "CCPocket");
    private static readonly string LogFilePath = Path.Combine(LogDirectory, "tray.log");

    private readonly object logsLock = new();
    private readonly StringBuilder logs = new();
    private Process? process;

    public event Action? LogsChanged;
    public event Action? StateChanged;

    public bool IsRunning => process is { HasExited: false };
    public string RepositoryRoot { get; }
    public bool HasRepository => IsRepositoryRoot(RepositoryRoot);
    public string BridgeDirectory => Path.Combine(RepositoryRoot, "packages", "bridge");
    public string Logs
    {
        get
        {
            lock (logsLock)
            {
                return logs.ToString();
            }
        }
    }

    public BridgeProcessManager()
    {
        RepositoryRoot = FindRepositoryRoot();
    }

    public async Task<BridgeHealth?> GetHealthAsync(int port, CancellationToken cancellationToken)
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
        try
        {
            return await client.GetFromJsonAsync<BridgeHealth>(
                $"http://127.0.0.1:{port}/health",
                cancellationToken);
        }
        catch
        {
            return null;
        }
    }

    public void Start(TraySettings settings)
    {
        if (IsRunning) return;
        ValidateBridgeDirectory();

        var distEntry = Path.Combine(BridgeDirectory, "dist", "index.js");
        var hasBuiltBridge = File.Exists(distEntry);
        var startInfo = new ProcessStartInfo
        {
            WorkingDirectory = hasBuiltBridge ? BridgeDirectory : RepositoryRoot,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };

        if (hasBuiltBridge)
        {
            startInfo.FileName = "node";
            startInfo.ArgumentList.Add(distEntry);
        }
        else
        {
            startInfo.FileName = ResolveNpmCommand();
            startInfo.ArgumentList.Add("run");
            startInfo.ArgumentList.Add("bridge");
        }

        startInfo.Environment["BRIDGE_PORT"] = settings.Port.ToString();
        startInfo.Environment["BRIDGE_HOST"] = settings.Host;
        startInfo.Environment["BRIDGE_ALLOWED_DIRS"] = settings.AllowedDirs;
        startInfo.Environment.Remove("CLAUDECODE");

        if (!string.IsNullOrWhiteSpace(settings.ApiKey))
        {
            startInfo.Environment["BRIDGE_API_KEY"] = settings.ApiKey.Trim();
        }

        AppendLog($"[tray] Starting bridge from {BridgeDirectory}");
        process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
        process.OutputDataReceived += (_, e) => AppendLog(e.Data);
        process.ErrorDataReceived += (_, e) => AppendLog(e.Data);
        process.Exited += (_, _) =>
        {
            AppendLog($"[tray] Bridge exited with code {process?.ExitCode}");
            StateChanged?.Invoke();
        };

        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        StateChanged?.Invoke();
    }

    public void Stop()
    {
        if (!IsRunning) return;

        try
        {
            process!.Kill(entireProcessTree: true);
            process.WaitForExit(3000);
        }
        catch (Exception ex)
        {
            AppendLog($"[tray] Stop failed: {ex.Message}");
        }
        finally
        {
            StateChanged?.Invoke();
        }
    }

    public static IReadOnlyList<string> GetWebSocketUrls(int port)
    {
        var urls = new List<string> { $"ws://127.0.0.1:{port}" };
        foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (nic.OperationalStatus != OperationalStatus.Up) continue;

            foreach (var address in nic.GetIPProperties().UnicastAddresses)
            {
                if (address.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                if (IPAddress.IsLoopback(address.Address)) continue;
                urls.Add($"ws://{address.Address}:{port}");
            }
        }

        return urls.Distinct().ToList();
    }

    public static string BuildDeepLink(string wsUrl, string apiKey)
    {
        var query = $"url={Uri.EscapeDataString(wsUrl)}";
        if (!string.IsNullOrWhiteSpace(apiKey))
        {
            query += $"&token={Uri.EscapeDataString(apiKey.Trim())}";
        }

        return $"ccpocket://connect?{query}";
    }

    public void Dispose()
    {
        Stop();
        process?.Dispose();
    }

    private void AppendLog(string? line)
    {
        if (string.IsNullOrEmpty(line)) return;
        lock (logsLock)
        {
            logs.AppendLine(line);
        }
        WriteLogFile(line);
        LogsChanged?.Invoke();
    }

    private static void WriteLogFile(string line)
    {
        try
        {
            Directory.CreateDirectory(LogDirectory);
            File.AppendAllText(
                LogFilePath,
                $"[{DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss}] {line}{Environment.NewLine}",
                Encoding.UTF8);
        }
        catch
        {
            // Logging must never crash the tray app.
        }
    }

    private void ValidateBridgeDirectory()
    {
        if (!HasRepository)
        {
            throw new InvalidOperationException(
                "未找到 CC Pocket Bridge 源码目录。\n\n" +
                "请把 CCPocketTray.exe 放在 ccpocket 仓库目录内运行，" +
                "或者设置环境变量 CCPOCKET_REPO_ROOT 指向 ccpocket 仓库路径。\n\n" +
                $"当前查找路径：{RepositoryRoot}");
        }
    }

    private static string ResolveNpmCommand()
    {
        return OperatingSystem.IsWindows() ? "npm.cmd" : "npm";
    }

    private static string FindRepositoryRoot()
    {
        var overrideRoot = Environment.GetEnvironmentVariable("CCPOCKET_REPO_ROOT");
        if (!string.IsNullOrWhiteSpace(overrideRoot) && IsRepositoryRoot(overrideRoot))
        {
            return Path.GetFullPath(overrideRoot);
        }

        foreach (var start in new[] { AppContext.BaseDirectory, Environment.CurrentDirectory })
        {
            var dir = new DirectoryInfo(start);
            while (dir != null)
            {
                if (IsRepositoryRoot(dir.FullName)) return dir.FullName;
                dir = dir.Parent;
            }
        }

        return Path.GetFullPath(AppContext.BaseDirectory);
    }

    private static bool IsRepositoryRoot(string path)
    {
        return File.Exists(Path.Combine(path, "packages", "bridge", "package.json"));
    }
}

internal sealed class BridgeHealth
{
    [JsonPropertyName("status")]
    public string Status { get; set; } = "";

    [JsonPropertyName("uptime")]
    public int Uptime { get; set; }

    [JsonPropertyName("sessions")]
    public int Sessions { get; set; }

    [JsonPropertyName("clients")]
    public int Clients { get; set; }
}
