using System.Drawing;
using System.Windows.Forms;
using ChargeCat.WindowsApp.App;
using ChargeCat.WindowsApp.Overlay;

namespace ChargeCat.WindowsApp.Panel;

internal sealed class SettingsForm : Form
{
    private readonly AppModel _model;
    private readonly Panel _previewPanel;
    private readonly PictureBox _previewPictureBox;
    private readonly ComboBox _sideComboBox;
    private readonly TrackBar _batteryTrackBar;
    private readonly Label _batteryValueLabel;
    private readonly CheckBox _autoMonitorCheckBox;
    private readonly CheckBox _launchAtLoginCheckBox;
    private readonly Label _batteryStatusLabel;
    private readonly Label _powerModeLabel;
    private readonly Label _lastEventLabel;
    private readonly Label _launchAtLoginErrorLabel;

    public SettingsForm(AppModel model, string assetPath)
    {
        _model = model;

        Text = "Charge Cat for Windows";
        ClientSize = new Size(460, 640);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(252, 247, 240);

        var root = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            AutoScroll = true,
            Padding = new Padding(24)
        };
        Controls.Add(root);

        var header = new Label
        {
            Text = "Charge Cat",
            Font = new Font("Segoe UI", 24, FontStyle.Bold),
            ForeColor = Color.FromArgb(46, 38, 33),
            AutoSize = true,
            Margin = new Padding(0, 0, 0, 4)
        };
        root.Controls.Add(header);

        var subtitle = new Label
        {
            Text = "A tiny charging ritual for your Windows laptop.",
            Font = new Font("Segoe UI", 10, FontStyle.Regular),
            ForeColor = Color.FromArgb(102, 88, 80),
            AutoSize = true,
            Margin = new Padding(0, 0, 0, 18)
        };
        root.Controls.Add(subtitle);

        _previewPanel = new Panel
        {
            Width = 396,
            Height = 250,
            BackColor = Color.FromArgb(36, 40, 48),
            Margin = new Padding(0, 0, 0, 18)
        };
        _previewPanel.Paint += PaintPreviewPanel;
        _previewPanel.Resize += (_, _) => LayoutPreview();
        root.Controls.Add(_previewPanel);

        _previewPictureBox = new PictureBox
        {
            SizeMode = PictureBoxSizeMode.Zoom,
            BackColor = Color.Transparent,
            Image = Image.FromFile(assetPath)
        };
        _previewPanel.Controls.Add(_previewPictureBox);

        var controlsGroup = new GroupBox
        {
            Text = "Controls",
            Width = 396,
            Height = 210,
            Font = new Font("Segoe UI", 9, FontStyle.Bold),
            Margin = new Padding(0, 0, 0, 18)
        };
        root.Controls.Add(controlsGroup);

        var controlsLayout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            RowCount = 6,
            Padding = new Padding(12),
        };
        controlsLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 55));
        controlsLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 45));
        controlsGroup.Controls.Add(controlsLayout);

        controlsLayout.Controls.Add(new Label { Text = "Side", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft }, 0, 0);
        _sideComboBox = new ComboBox { Dock = DockStyle.Fill, DropDownStyle = ComboBoxStyle.DropDownList };
        _sideComboBox.Items.AddRange(["Left", "Right"]);
        _sideComboBox.SelectedIndexChanged += (_, _) =>
        {
            _model.UpdatePreferredSide(_sideComboBox.SelectedIndex == 0 ? OverlaySide.Left : OverlaySide.Right);
            LayoutPreview();
        };
        controlsLayout.Controls.Add(_sideComboBox, 1, 0);

        controlsLayout.Controls.Add(new Label { Text = "Preview Battery", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft }, 0, 1);
        var batteryRow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.LeftToRight, WrapContents = false };
        _batteryTrackBar = new TrackBar { Minimum = 1, Maximum = 100, TickFrequency = 10, Width = 120 };
        _batteryTrackBar.ValueChanged += (_, _) =>
        {
            _model.UpdatePreviewBatteryLevel(_batteryTrackBar.Value);
            _batteryValueLabel.Text = $"{_batteryTrackBar.Value}%";
        };
        _batteryValueLabel = new Label { AutoSize = true, TextAlign = ContentAlignment.MiddleLeft, Padding = new Padding(0, 8, 0, 0) };
        batteryRow.Controls.Add(_batteryTrackBar);
        batteryRow.Controls.Add(_batteryValueLabel);
        controlsLayout.Controls.Add(batteryRow, 1, 1);

        var previewChargeButton = new Button { Text = "Play Charge Start", Dock = DockStyle.Fill };
        previewChargeButton.Click += (_, _) => _model.Trigger(OverlayEventKind.ChargeStarted);
        controlsLayout.Controls.Add(previewChargeButton, 0, 2);

        var previewFullButton = new Button { Text = "Play Full Charge", Dock = DockStyle.Fill };
        previewFullButton.Click += (_, _) => _model.Trigger(OverlayEventKind.FullyCharged, 100);
        controlsLayout.Controls.Add(previewFullButton, 1, 2);

        _autoMonitorCheckBox = new CheckBox { Text = "Auto react to real charging events", AutoSize = true };
        _autoMonitorCheckBox.CheckedChanged += (_, _) => _model.UpdateAutoMonitorEnabled(_autoMonitorCheckBox.Checked);
        controlsLayout.Controls.Add(_autoMonitorCheckBox, 0, 3);
        controlsLayout.SetColumnSpan(_autoMonitorCheckBox, 2);

        _launchAtLoginCheckBox = new CheckBox { Text = "Launch at Login", AutoSize = true };
        _launchAtLoginCheckBox.CheckedChanged += (_, _) => _model.UpdateLaunchAtLogin(_launchAtLoginCheckBox.Checked);
        controlsLayout.Controls.Add(_launchAtLoginCheckBox, 0, 4);
        controlsLayout.SetColumnSpan(_launchAtLoginCheckBox, 2);

        _launchAtLoginErrorLabel = new Label
        {
            ForeColor = Color.FromArgb(227, 117, 95),
            AutoSize = true,
            MaximumSize = new Size(340, 0)
        };
        controlsLayout.Controls.Add(_launchAtLoginErrorLabel, 0, 5);
        controlsLayout.SetColumnSpan(_launchAtLoginErrorLabel, 2);

        var statusGroup = new GroupBox
        {
            Text = "Live Status",
            Width = 396,
            Height = 150,
            Font = new Font("Segoe UI", 9, FontStyle.Bold)
        };
        root.Controls.Add(statusGroup);

        var statusLayout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 3,
            Padding = new Padding(12)
        };
        statusGroup.Controls.Add(statusLayout);

        _batteryStatusLabel = new Label { AutoSize = true, MaximumSize = new Size(340, 0) };
        _powerModeLabel = new Label { AutoSize = true, MaximumSize = new Size(340, 0) };
        _lastEventLabel = new Label { AutoSize = true, MaximumSize = new Size(340, 0) };
        statusLayout.Controls.Add(_batteryStatusLabel, 0, 0);
        statusLayout.Controls.Add(_powerModeLabel, 0, 1);
        statusLayout.Controls.Add(_lastEventLabel, 0, 2);

        RefreshFromModel();
    }

    public void ShowSettings()
    {
        RefreshFromModel();
        if (Visible == false)
        {
            Show();
        }

        BringToFront();
        Activate();
    }

    public void RefreshFromModel()
    {
        _sideComboBox.SelectedIndex = _model.PreferredSide == OverlaySide.Left ? 0 : 1;
        _batteryTrackBar.Value = Math.Clamp(_model.PreviewBatteryLevel, _batteryTrackBar.Minimum, _batteryTrackBar.Maximum);
        _batteryValueLabel.Text = $"{_batteryTrackBar.Value}%";
        _autoMonitorCheckBox.Checked = _model.AutoMonitorEnabled;
        _launchAtLoginCheckBox.Checked = _model.LaunchAtLoginEnabled;
        _launchAtLoginErrorLabel.Text = _model.LaunchAtLoginErrorMessage ?? string.Empty;
        _batteryStatusLabel.Text = _model.LatestBattery is null
            ? "Battery unavailable"
            : $"Battery • {_model.LatestBattery.Level}% • {_model.LatestBattery.PowerText}";
        _powerModeLabel.Text = $"Power Mode • {_model.CurrentPowerMode.Title}";
        _lastEventLabel.Text = _model.LastEventDescription;
        LayoutPreview();
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        if (e.CloseReason == CloseReason.UserClosing)
        {
            e.Cancel = true;
            Hide();
            return;
        }

        base.OnFormClosing(e);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _previewPictureBox.Image?.Dispose();
        }

        base.Dispose(disposing);
    }

    private void PaintPreviewPanel(object? sender, PaintEventArgs e)
    {
        using var stroke = new Pen(Color.FromArgb(60, 255, 255, 255), 1);
        e.Graphics.DrawRectangle(stroke, 0, 0, _previewPanel.Width - 1, _previewPanel.Height - 1);

        using var dockBrush = new SolidBrush(Color.FromArgb(28, 255, 255, 255));
        e.Graphics.FillRoundedRectangle(dockBrush, 118, _previewPanel.Height - 28, 160, 14, 7);

        using var dot1 = new SolidBrush(Color.FromArgb(64, 255, 255, 255));
        using var dot2 = new SolidBrush(Color.FromArgb(42, 255, 255, 255));
        using var dot3 = new SolidBrush(Color.FromArgb(32, 255, 255, 255));
        e.Graphics.FillEllipse(dot1, 16, 16, 10, 10);
        e.Graphics.FillEllipse(dot2, 32, 16, 10, 10);
        e.Graphics.FillEllipse(dot3, 48, 16, 10, 10);
    }

    private void LayoutPreview()
    {
        var imageWidth = 110;
        var imageHeight = 134;
        var x = _model.PreferredSide == OverlaySide.Left
            ? 22
            : _previewPanel.Width - imageWidth - 22;

        var y = _previewPanel.Height - imageHeight - 18;
        _previewPictureBox.Bounds = new Rectangle(x, y, imageWidth, imageHeight);
    }
}
