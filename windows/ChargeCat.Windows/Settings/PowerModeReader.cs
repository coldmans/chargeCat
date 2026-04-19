using System.Diagnostics;

namespace ChargeCat.WindowsApp.Settings;

internal enum PowerMode
{
    PowerSaver,
    Balanced,
    HighPerformance,
    Unknown
}

internal static class PowerModeExtensions
{
    public static string Title(this PowerMode mode) =>
        mode switch
        {
            PowerMode.PowerSaver => "Power Saver",
            PowerMode.Balanced => "Balanced",
            PowerMode.HighPerformance => "High Performance",
            _ => "Unknown"
        };
}

internal static class PowerModeReader
{
    public static PowerMode ReadCurrentMode()
    {
        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = "powercfg",
                Arguments = "/getactivescheme",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
                UseShellExecute = false
            };

            using var process = Process.Start(startInfo);
            if (process is null)
            {
                return PowerMode.Unknown;
            }

            var output = process.StandardOutput.ReadToEnd().ToLowerInvariant();
            process.WaitForExit();

            if (output.Contains("ultimate performance") || output.Contains("high performance"))
            {
                return PowerMode.HighPerformance;
            }

            if (output.Contains("power saver"))
            {
                return PowerMode.PowerSaver;
            }

            if (output.Contains("balanced"))
            {
                return PowerMode.Balanced;
            }

            return PowerMode.Unknown;
        }
        catch
        {
            return PowerMode.Unknown;
        }
    }
}
