namespace ChargeCat.WindowsApp.Overlay;

internal enum OverlaySide
{
    Left,
    Right
}

internal static class OverlaySideExtensions
{
    public static string Title(this OverlaySide side) =>
        side == OverlaySide.Left ? "Left" : "Right";
}
