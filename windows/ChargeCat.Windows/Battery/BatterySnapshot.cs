namespace ChargeCat.WindowsApp.Battery;

internal sealed record BatterySnapshot(int Level, bool IsPluggedIn, bool IsCharging)
{
    public string PowerText =>
        IsPluggedIn && Level >= 99 && IsCharging == false ? "Fully Charged" :
        IsCharging ? "Charging" :
        IsPluggedIn ? "Power Connected" :
        "On Battery";
}
