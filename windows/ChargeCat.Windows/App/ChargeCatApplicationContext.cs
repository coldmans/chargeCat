using System.Drawing;
using System.Windows.Forms;
using ChargeCat.WindowsApp.Battery;
using ChargeCat.WindowsApp.Overlay;
using ChargeCat.WindowsApp.Panel;
using ChargeCat.WindowsApp.Settings;

namespace ChargeCat.WindowsApp.App;

internal sealed class ChargeCatApplicationContext : ApplicationContext
{
    private readonly AppModel _model;
    private readonly BatteryMonitor _batteryMonitor;
    private readonly OverlayForm _overlayForm;
    private readonly SettingsForm _settingsForm;
    private readonly NotifyIcon _notifyIcon;
    private readonly ToolStripMenuItem _batteryStatusItem;
    private readonly ToolStripMenuItem _powerModeStatusItem;

    public ChargeCatApplicationContext()
    {
        var settings = UserSettings.Load();
        var assetPath = Path.Combine(AppContext.BaseDirectory, "Assets", "cat-door.gif");

        _model = new AppModel(settings);
        _overlayForm = new OverlayForm(assetPath);
        _settingsForm = new SettingsForm(_model, assetPath);
        _batteryMonitor = new BatteryMonitor(_model);

        _model.StateChanged += HandleStateChanged;
        _model.OverlayRequested += payload => _overlayForm.ShowOverlay(payload);

        _batteryStatusItem = new ToolStripMenuItem { Enabled = false };
        _powerModeStatusItem = new ToolStripMenuItem { Enabled = false };

        _notifyIcon = new NotifyIcon
        {
            Visible = true,
            Text = "Charge Cat",
            ContextMenuStrip = BuildMenu(),
            Icon = TrayIconFactory.Create(null)
        };
        _notifyIcon.DoubleClick += (_, _) => OpenSettings();

        _batteryMonitor.Start();
        UpdateNotifyIcon();

        if (_model.Settings.HasCompletedOnboarding == false)
        {
            _model.Settings.HasCompletedOnboarding = true;
            _model.Settings.Save();
            _settingsForm.ShowSettings();
        }
    }

    private ContextMenuStrip BuildMenu()
    {
        var menu = new ContextMenuStrip();
        menu.Items.Add(_batteryStatusItem);
        menu.Items.Add(_powerModeStatusItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Open Settings", null, (_, _) => OpenSettings());
        menu.Items.Add("Preview Charge Start", null, (_, _) => _model.Trigger(OverlayEventKind.ChargeStarted, source: "tray preview"));
        menu.Items.Add("Preview Full Charge", null, (_, _) => _model.Trigger(OverlayEventKind.FullyCharged, level: 100, source: "tray preview"));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit", null, (_, _) => ExitThread());
        return menu;
    }

    private void HandleStateChanged()
    {
        UpdateNotifyIcon();
        _settingsForm.RefreshFromModel();
    }

    private void UpdateNotifyIcon()
    {
        var snapshot = _model.LatestBattery;
        var batteryText = snapshot is null ? "Battery unavailable" : $"{snapshot.Level}% • {snapshot.PowerText}";
        var tooltip = $"Charge Cat - {batteryText}";

        _notifyIcon.Icon?.Dispose();
        _notifyIcon.Icon = TrayIconFactory.Create(snapshot);
        _notifyIcon.Text = tooltip.Length > 63 ? tooltip[..63] : tooltip;

        _batteryStatusItem.Text = batteryText;
        _powerModeStatusItem.Text = $"Power Mode • {_model.CurrentPowerMode.Title}";
    }

    private void OpenSettings()
    {
        _settingsForm.ShowSettings();
    }

    protected override void ExitThreadCore()
    {
        _batteryMonitor.Dispose();
        _overlayForm.Dispose();
        _settingsForm.Dispose();
        _notifyIcon.Visible = false;
        _notifyIcon.Icon?.Dispose();
        _notifyIcon.Dispose();
        base.ExitThreadCore();
    }
}
