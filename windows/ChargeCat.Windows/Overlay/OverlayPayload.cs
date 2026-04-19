namespace ChargeCat.WindowsApp.Overlay;

internal sealed record OverlayPayload(
    OverlayEventKind Kind,
    int BatteryLevel,
    OverlaySide Side
);
