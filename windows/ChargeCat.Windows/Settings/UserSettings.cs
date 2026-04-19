using System.Text.Json;
using ChargeCat.WindowsApp.Overlay;

namespace ChargeCat.WindowsApp.Settings;

internal sealed class UserSettings
{
    private static readonly JsonSerializerOptions SerializerOptions = new() { WriteIndented = true };

    public OverlaySide PreferredSide { get; set; } = OverlaySide.Left;
    public bool AutoMonitorEnabled { get; set; } = true;
    public bool LaunchAtLoginEnabled { get; set; }
    public int PreviewBatteryLevel { get; set; } = 38;
    public bool HasCompletedOnboarding { get; set; }

    public static UserSettings Load()
    {
        var path = GetSettingsPath();
        if (File.Exists(path) == false)
        {
            return new UserSettings();
        }

        try
        {
            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<UserSettings>(json, SerializerOptions) ?? new UserSettings();
        }
        catch
        {
            return new UserSettings();
        }
    }

    public void Save()
    {
        var path = GetSettingsPath();
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var json = JsonSerializer.Serialize(this, SerializerOptions);
        File.WriteAllText(path, json);
    }

    private static string GetSettingsPath()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        return Path.Combine(appData, "ChargeCat.Windows", "settings.json");
    }
}
