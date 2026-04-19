using System.Drawing;
using System.Runtime.InteropServices;
using ChargeCat.WindowsApp.Battery;

namespace ChargeCat.WindowsApp.App;

internal static class TrayIconFactory
{
    public static Icon Create(BatterySnapshot? snapshot)
    {
        using var bitmap = new Bitmap(32, 32);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.Clear(Color.Transparent);
        graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;

        using var pen = new Pen(Color.Black, 2.2f);
        using var brush = new SolidBrush(Color.Black);
        var mood = TrayIconMood.Resolve(snapshot);

        graphics.DrawRoundedRectangle(pen, 6, 10, 20, 14, 8);
        graphics.DrawPolygon(pen, [
            new PointF(10, 11),
            new PointF(13, 4 + mood.EarLift),
            new PointF(15, 11)
        ]);
        graphics.DrawPolygon(pen, [
            new PointF(17, 11),
            new PointF(19, 4 + mood.EarLift),
            new PointF(22, 11)
        ]);

        graphics.FillEllipse(brush, 10, mood.EyeY, mood.EyeWidth, mood.EyeHeight);
        graphics.FillEllipse(brush, 19, mood.EyeY, mood.EyeWidth, mood.EyeHeight);
        graphics.DrawArc(pen, 13, mood.MouthY, 6, 4, 10, mood.MouthSweep);

        var iconHandle = bitmap.GetHicon();
        try
        {
            using var icon = Icon.FromHandle(iconHandle);
            return (Icon)icon.Clone();
        }
        finally
        {
            DestroyIcon(iconHandle);
        }
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyIcon(IntPtr hIcon);

    private sealed record TrayIconMood(int EarLift, int EyeY, int EyeWidth, int EyeHeight, int MouthY, int MouthSweep)
    {
        public static TrayIconMood Resolve(BatterySnapshot? snapshot)
        {
            if (snapshot is null)
            {
                return Regular;
            }

            if (snapshot.IsCharging)
            {
                return Charging;
            }

            if (snapshot.Level <= 20)
            {
                return Low;
            }

            if (snapshot.Level >= 80)
            {
                return Full;
            }

            return Regular;
        }

        private static readonly TrayIconMood Low = new(-2, 15, 4, 1, 20, -120);
        private static readonly TrayIconMood Regular = new(0, 15, 3, 3, 20, -180);
        private static readonly TrayIconMood Full = new(1, 14, 3, 3, 19, -220);
        private static readonly TrayIconMood Charging = new(2, 14, 3, 4, 19, -240);
    }
}
