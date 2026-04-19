namespace ChargeCat.WindowsApp.Overlay;

internal enum OverlayEventKind
{
    ChargeStarted,
    FullyCharged
}

internal static class OverlayEventKindExtensions
{
    public static string Title(this OverlayEventKind kind) =>
        kind switch
        {
            OverlayEventKind.ChargeStarted => "Charge Start",
            OverlayEventKind.FullyCharged => "Fully Charged",
            _ => "Unknown"
        };
}
