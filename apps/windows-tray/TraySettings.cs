using System.Text.Json;

namespace CCPocketTray;

internal sealed class TraySettings
{
    private static readonly string SettingsDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "CCPocket");

    private static readonly string SettingsPath = Path.Combine(SettingsDir, "tray-settings.json");

    public int Port { get; set; } = 8765;
    public string Host { get; set; } = "0.0.0.0";
    public string AllowedDirs { get; set; } = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    public string ApiKey { get; set; } = "";
    public bool StartBridgeOnLaunch { get; set; } = true;
    public bool HideWindowOnLaunch { get; set; } = false;
    public string Language { get; set; } = "zh-CN";

    public static TraySettings Load()
    {
        try
        {
            if (!File.Exists(SettingsPath)) return new TraySettings();
            var json = File.ReadAllText(SettingsPath);
            return JsonSerializer.Deserialize<TraySettings>(json) ?? new TraySettings();
        }
        catch
        {
            return new TraySettings();
        }
    }

    public void Save()
    {
        Directory.CreateDirectory(SettingsDir);
        var json = JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(SettingsPath, json);
    }
}
