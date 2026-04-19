using System.Threading;
using System.Windows.Forms;
using ChargeCat.WindowsApp.App;
using Microsoft.Win32;

namespace ChargeCat.WindowsApp.Battery;

internal sealed class BatteryMonitor : IDisposable
{
    private readonly AppModel _model;
    private readonly SynchronizationContext _syncContext;
    private Timer? _pollTimer;

    public BatteryMonitor(AppModel model)
    {
        _model = model;
        _syncContext = SynchronizationContext.Current ?? new WindowsFormsSynchronizationContext();
    }

    public void Start()
    {
        Stop();
        Poll("initial");

        SystemEvents.PowerModeChanged += HandlePowerModeChanged;
        _pollTimer = new Timer(_ => PostPoll("timer fallback"), null, TimeSpan.FromSeconds(15), TimeSpan.FromSeconds(15));
    }

    public void Stop()
    {
        SystemEvents.PowerModeChanged -= HandlePowerModeChanged;
        _pollTimer?.Dispose();
        _pollTimer = null;
    }

    public void Dispose()
    {
        Stop();
    }

    private void HandlePowerModeChanged(object? sender, PowerModeChangedEventArgs e)
    {
        PostPoll($"power event: {e.Mode}");
    }

    private void PostPoll(string reason)
    {
        _syncContext.Post(_ => Poll(reason), null);
    }

    private void Poll(string reason)
    {
        var snapshot = ReadSystemBattery();
        _model.UpdateBattery(snapshot);
    }

    private static BatterySnapshot? ReadSystemBattery()
    {
        var powerStatus = SystemInformation.PowerStatus;
        if ((powerStatus.BatteryChargeStatus & BatteryChargeStatus.NoSystemBattery) != 0)
        {
            return null;
        }

        var fraction = powerStatus.BatteryLifePercent;
        if (fraction < 0)
        {
            return null;
        }

        var level = (int)Math.Round(fraction * 100);
        var isPluggedIn = powerStatus.PowerLineStatus == PowerLineStatus.Online;
        var isCharging = (powerStatus.BatteryChargeStatus & BatteryChargeStatus.Charging) != 0;

        return new BatterySnapshot(level, isPluggedIn, isCharging);
    }
}
