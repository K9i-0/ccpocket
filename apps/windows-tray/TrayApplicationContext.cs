namespace CCPocketTray;

internal sealed class TrayApplicationContext : ApplicationContext
{
    private readonly TraySettings settings = TraySettings.Load();
    private readonly BridgeProcessManager bridge = new();
    private readonly NotifyIcon trayIcon;
    private MainForm? form;
    private bool isExiting;

    public TrayApplicationContext()
    {
        trayIcon = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Text = "CC Pocket Bridge",
            Visible = true,
            ContextMenuStrip = BuildMenu(),
        };
        trayIcon.DoubleClick += (_, _) => ShowWindow();

        bridge.StateChanged += UpdateTrayText;

        ShowWindow();

        if (settings.StartBridgeOnLaunch)
        {
            _ = StartBridgeOnLaunchAsync();
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            trayIcon.Visible = false;
            trayIcon.Dispose();
            bridge.Dispose();
            form?.Dispose();
        }

        base.Dispose(disposing);
    }

    private ContextMenuStrip BuildMenu()
    {
        var menu = new ContextMenuStrip();
        menu.Items.Add(T("open"), null, (_, _) => ShowWindow());
        menu.Items.Add(T("start"), null, (_, _) => StartBridge());
        menu.Items.Add(T("stop"), null, (_, _) => bridge.Stop());
        menu.Items.Add(T("copyWsUrl"), null, (_, _) => CopyPrimaryUrl());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(T("exit"), null, (_, _) => ExitApp());
        return menu;
    }

    private void ShowWindow()
    {
        if (form == null || form.IsDisposed)
        {
            form = new MainForm(settings, bridge);
            form.LanguageChanged += OnLanguageChanged;
            form.FormClosing += (_, e) =>
            {
                if (isExiting) return;
                e.Cancel = true;
                form.Hide();
            };
        }

        form.Show();
        form.WindowState = FormWindowState.Normal;
        form.Activate();
    }

    private void StartBridge()
    {
        try
        {
            form?.SaveSettings();
            bridge.Start(settings);
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "CC Pocket", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private async Task StartBridgeOnLaunchAsync()
    {
        var health = await bridge.GetHealthAsync(settings.Port, CancellationToken.None);
        if (health != null)
        {
            trayIcon.ShowBalloonTip(
                2000,
                "CC Pocket",
                T("attached"),
                ToolTipIcon.Info);
            return;
        }

        try
        {
            bridge.Start(settings);
            trayIcon.ShowBalloonTip(2000, "CC Pocket", T("startingBalloon"), ToolTipIcon.Info);
        }
        catch (Exception ex)
        {
            trayIcon.ShowBalloonTip(5000, "CC Pocket", ex.Message, ToolTipIcon.Error);
            ShowWindow();
        }
    }

    private void CopyPrimaryUrl()
    {
        var urls = BridgeProcessManager.GetWebSocketUrls(settings.Port);
        Clipboard.SetText(urls.First());
        trayIcon.ShowBalloonTip(1200, "CC Pocket", $"{T("copied")} {urls.First()}", ToolTipIcon.Info);
    }

    private void UpdateTrayText()
    {
        var status = bridge.IsRunning ? T("running") : T("stopped");
        trayIcon.Text = $"CC Pocket Bridge ({status})";
    }

    private void OnLanguageChanged()
    {
        trayIcon.ContextMenuStrip?.Dispose();
        trayIcon.ContextMenuStrip = BuildMenu();
        UpdateTrayText();
    }

    private void ExitApp()
    {
        isExiting = true;
        ExitThread();
    }

    private string T(string key) => I18n.T(settings.Language, key);
}
