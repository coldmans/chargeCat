using System.Drawing;
using System.Windows.Forms;

namespace ChargeCat.WindowsApp.Overlay;

internal sealed class OverlayForm : Form
{
    private readonly GifFrameSequence _sequence;
    private readonly PictureBox _pictureBox;
    private CancellationTokenSource? _playbackCts;

    public OverlayForm(string assetPath)
    {
        _sequence = GifFrameSequence.Load(assetPath);

        AutoScaleMode = AutoScaleMode.None;
        BackColor = Color.Magenta;
        TransparencyKey = Color.Magenta;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        TopMost = true;
        ClientSize = _sequence.CanvasSize;

        _pictureBox = new PictureBox
        {
            Dock = DockStyle.Fill,
            BackColor = Color.Magenta,
            SizeMode = PictureBoxSizeMode.Normal
        };

        Controls.Add(_pictureBox);
    }

    protected override bool ShowWithoutActivation => true;

    protected override CreateParams CreateParams
    {
        get
        {
            const int WsExToolWindow = 0x00000080;
            const int WsExNoActivate = 0x08000000;
            var cp = base.CreateParams;
            cp.ExStyle |= WsExToolWindow | WsExNoActivate;
            return cp;
        }
    }

    public void ShowOverlay(OverlayPayload payload)
    {
        _playbackCts?.Cancel();
        _playbackCts?.Dispose();
        _playbackCts = new CancellationTokenSource();

        PositionWindow(payload.Side);
        Opacity = 1;
        Show();
        _ = PlayOnceAsync(_playbackCts.Token);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _playbackCts?.Cancel();
            _playbackCts?.Dispose();
            _pictureBox.Dispose();
            _sequence.Dispose();
        }

        base.Dispose(disposing);
    }

    private async Task PlayOnceAsync(CancellationToken cancellationToken)
    {
        try
        {
            for (var frameIndex = 0; frameIndex < _sequence.FrameCount; frameIndex++)
            {
                _pictureBox.Image = _sequence.GetFrame(frameIndex);
                await Task.Delay(_sequence.DelaysMs[frameIndex], cancellationToken);
            }

            await FadeOutAsync(cancellationToken);
        }
        catch (OperationCanceledException)
        {
            // Ignore.
        }
        finally
        {
            if (cancellationToken.IsCancellationRequested == false)
            {
                Hide();
            }
        }
    }

    private async Task FadeOutAsync(CancellationToken cancellationToken)
    {
        const int steps = 12;
        for (var step = 0; step < steps; step++)
        {
            Opacity = 1 - ((step + 1) / (double)steps);
            await Task.Delay(65, cancellationToken);
        }
    }

    private void PositionWindow(OverlaySide side)
    {
        var workingArea = Screen.PrimaryScreen?.WorkingArea ?? new Rectangle(0, 0, 1920, 1080);
        const int inset = 18;

        var x = side == OverlaySide.Left
            ? workingArea.Left + inset
            : workingArea.Right - Width - inset;

        var y = workingArea.Bottom - Height - inset;
        Location = new Point(x, y);
    }
}
