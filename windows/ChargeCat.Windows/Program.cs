using System.Windows.Forms;
using ChargeCat.WindowsApp.App;

namespace ChargeCat.WindowsApp;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        using var app = new ChargeCatApplicationContext();
        Application.Run(app);
    }
}
