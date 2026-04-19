using ChargeCat.WindowsApp.Battery;
using ChargeCat.WindowsApp.Overlay;
using ChargeCat.WindowsApp.Settings;

namespace ChargeCat.WindowsApp.App;

internal sealed class AppModel
{
    private DateTime? _lastTriggerAt;
    private OverlayEventKind? _lastTriggerKind;

    public AppModel(UserSettings settings)
    {
        Settings = settings;
        PreferredSide = settings.PreferredSide;
        AutoMonitorEnabled = settings.AutoMonitorEnabled;
        LaunchAtLoginEnabled = LaunchAtLogin.IsEnabled() || settings.LaunchAtLoginEnabled;
        PreviewBatteryLevel = settings.PreviewBatteryLevel;
        CurrentPowerMode = PowerModeReader.ReadCurrentMode();
        LastEventDescription = "Ready for the next charging ritual.";
    }

    public UserSettings Settings { get; }
    public OverlaySide PreferredSide { get; private set; }
    public bool AutoMonitorEnabled { get; private set; }
    public bool LaunchAtLoginEnabled { get; private set; }
    public int PreviewBatteryLevel { get; private set; }
    public BatterySnapshot? LatestBattery { get; private set; }
    public bool BatteryMonitoringAvailable { get; private set; }
    public PowerMode CurrentPowerMode { get; private set; }
    public string LastEventDescription { get; private set; }
    public string? LaunchAtLoginErrorMessage { get; private set; }

    public event Action? StateChanged;
    public event Action<OverlayPayload>? OverlayRequested;

    public void UpdatePreferredSide(OverlaySide side)
    {
        PreferredSide = side;
        Settings.PreferredSide = side;
        Settings.Save();
        NotifyStateChanged();
    }

    public void UpdatePreviewBatteryLevel(int level)
    {
        PreviewBatteryLevel = Math.Clamp(level, 1, 100);
        Settings.PreviewBatteryLevel = PreviewBatteryLevel;
        Settings.Save();
        NotifyStateChanged();
    }

    public void UpdateAutoMonitorEnabled(bool enabled)
    {
        AutoMonitorEnabled = enabled;
        Settings.AutoMonitorEnabled = enabled;
        Settings.Save();
        NotifyStateChanged();
    }

    public void UpdateLaunchAtLogin(bool enabled)
    {
        try
        {
            LaunchAtLogin.SetEnabled(enabled);
            LaunchAtLoginEnabled = enabled;
            Settings.LaunchAtLoginEnabled = enabled;
            Settings.Save();
            LaunchAtLoginErrorMessage = null;
        }
        catch (Exception ex)
        {
            LaunchAtLoginEnabled = LaunchAtLogin.IsEnabled();
            LaunchAtLoginErrorMessage = ex.Message;
        }

        NotifyStateChanged();
    }

    public void UpdateBattery(BatterySnapshot? snapshot)
    {
        var previousSnapshot = LatestBattery;
        LatestBattery = snapshot;
        BatteryMonitoringAvailable = snapshot is not null;
        CurrentPowerMode = PowerModeReader.ReadCurrentMode();

        if (snapshot is null)
        {
            LastEventDescription = "No battery detected. Preview buttons still work on this PC.";
            NotifyStateChanged();
            return;
        }

        if (string.Equals(LastEventDescription, "No battery detected. Preview buttons still work on this PC.", StringComparison.Ordinal))
        {
            LastEventDescription = "Ready for the next charging ritual.";
        }

        NotifyStateChanged();

        if (AutoMonitorEnabled == false || previousSnapshot is null)
        {
            return;
        }

        if (IsChargeStarted(previousSnapshot, snapshot))
        {
            Trigger(OverlayEventKind.ChargeStarted, snapshot.Level, "system");
        }

        if (IsFullyCharged(previousSnapshot, snapshot))
        {
            Trigger(OverlayEventKind.FullyCharged, snapshot.Level, "system");
        }
    }

    public void RefreshPowerMode()
    {
        CurrentPowerMode = PowerModeReader.ReadCurrentMode();
        NotifyStateChanged();
    }

    public void Trigger(OverlayEventKind kind, int? level = null, string source = "preview")
    {
        var resolvedLevel = Math.Clamp(level ?? PreviewBatteryLevel, 1, 100);

        if (ShouldThrottle(kind, source))
        {
            LastEventDescription = $"{kind.Title} ignored to avoid a duplicate trigger.";
            NotifyStateChanged();
            return;
        }

        _lastTriggerAt = DateTime.UtcNow;
        _lastTriggerKind = kind;

        LastEventDescription = $"{kind.Title} from {source} at {resolvedLevel}% on the {PreferredSide.Title.ToLowerInvariant()} side.";
        NotifyStateChanged();

        OverlayRequested?.Invoke(new OverlayPayload(kind, resolvedLevel, PreferredSide));
    }

    private bool ShouldThrottle(OverlayEventKind kind, string source)
    {
        if (source != "system" || _lastTriggerAt is null || _lastTriggerKind is null)
        {
            return false;
        }

        return _lastTriggerKind == kind && (DateTime.UtcNow - _lastTriggerAt.Value).TotalSeconds < 10;
    }

    private static bool IsChargeStarted(BatterySnapshot previous, BatterySnapshot current)
    {
        var powerWasConnected = previous.IsPluggedIn == false && current.IsPluggedIn;
        var chargingJustStarted = previous.IsCharging == false && current.IsCharging;
        return powerWasConnected || chargingJustStarted;
    }

    private static bool IsFullyCharged(BatterySnapshot previous, BatterySnapshot current)
    {
        var reachedHundred = previous.Level < 100 && current.Level == 100 && current.IsPluggedIn;
        var chargingStoppedAtFull = previous.IsCharging && current.IsPluggedIn && current.IsCharging == false && current.Level >= 99;
        return reachedHundred || chargingStoppedAtFull;
    }

    private void NotifyStateChanged()
    {
        StateChanged?.Invoke();
    }
}
