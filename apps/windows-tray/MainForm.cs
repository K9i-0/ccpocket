namespace CCPocketTray;

internal sealed class MainForm : Form
{
    private static readonly Color Ink = Color.FromArgb(31, 39, 36);
    private static readonly Color Muted = Color.FromArgb(101, 115, 108);
    private static readonly Color Canvas = Color.FromArgb(237, 241, 238);
    private static readonly Color Surface = Color.FromArgb(250, 252, 250);
    private static readonly Color SurfaceRaised = Color.FromArgb(226, 234, 229);
    private static readonly Color Field = Color.FromArgb(244, 248, 245);
    private static readonly Color Accent = Color.FromArgb(57, 132, 91);
    private static readonly Color Warning = Color.FromArgb(181, 123, 46);
    private static readonly Color Danger = Color.FromArgb(185, 72, 64);

    private readonly TraySettings settings;
    private readonly BridgeProcessManager bridge;
    private readonly System.Windows.Forms.Timer pollTimer;

    private readonly Label statusPill = new();
    private readonly Label metricLabel = new();
    private readonly Label repoLabel = new();
    private readonly NumericUpDown portInput = new() { Minimum = 1, Maximum = 65535, Width = 120 };
    private readonly TextBox hostInput = new();
    private readonly TextBox allowedDirsInput = new();
    private readonly TextBox apiKeyInput = new() { UseSystemPasswordChar = true };
    private readonly CheckBox startOnLaunchInput = new() { Text = "Open Bridge with tray app", AutoSize = true };
    private readonly ComboBox languageInput = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 116 };
    private readonly ListBox urlList = new();
    private readonly TextBox deepLinkBox = new() { ReadOnly = true };
    private readonly TextBox logBox = new()
    {
        Multiline = true,
        ReadOnly = true,
        ScrollBars = ScrollBars.Vertical,
        WordWrap = false,
        BorderStyle = BorderStyle.None,
        Font = new Font("Cascadia Mono", 9F),
    };

    public event Action? LanguageChanged;

    public MainForm(TraySettings settings, BridgeProcessManager bridge)
    {
        this.settings = settings;
        this.bridge = bridge;

        Text = "CC Pocket Bridge";
        Width = 1040;
        Height = 780;
        MinimumSize = new Size(960, 700);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Canvas;
        ForeColor = Ink;
        Font = new Font("Segoe UI Variable Text", 9.5F);

        BuildLayout();
        LoadSettingsIntoInputs();
        RefreshUrls();
        RefreshStatus();
        RefreshLogs();

        urlList.SelectedIndexChanged += (_, _) => RefreshDeepLink();
        portInput.ValueChanged += (_, _) => RefreshUrls();
        apiKeyInput.TextChanged += (_, _) => RefreshDeepLink();
        languageInput.SelectionChangeCommitted += (_, _) => ChangeLanguage();

        bridge.LogsChanged += OnBridgeLogsChanged;
        bridge.StateChanged += OnBridgeStateChanged;

        pollTimer = new System.Windows.Forms.Timer { Interval = 2000 };
        pollTimer.Tick += async (_, _) => await PollHealthAsync();
        pollTimer.Start();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            pollTimer.Dispose();
            bridge.LogsChanged -= OnBridgeLogsChanged;
            bridge.StateChanged -= OnBridgeStateChanged;
        }

        base.Dispose(disposing);
    }

    public void SaveSettings()
    {
        settings.Port = (int)portInput.Value;
        settings.Host = hostInput.Text.Trim();
        settings.AllowedDirs = allowedDirsInput.Text.Trim();
        settings.ApiKey = apiKeyInput.Text.Trim();
        settings.StartBridgeOnLaunch = startOnLaunchInput.Checked;
        settings.HideWindowOnLaunch = false;
        settings.Language = languageInput.SelectedIndex == 0 ? I18n.Chinese : I18n.English;
        settings.Save();
        RefreshUrls();
    }

    private void BuildLayout()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 3,
            Padding = new Padding(22),
            BackColor = Canvas,
        };
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 190));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 300));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        Controls.Add(root);
        root.BringToFront();

        root.Controls.Add(BuildHero(), 0, 0);

        var topGrid = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            RowCount = 1,
            Padding = new Padding(0, 16, 0, 16),
            BackColor = Canvas,
        };
        topGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 48));
        topGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 52));
        topGrid.Controls.Add(BuildSettingsPanel(), 0, 0);
        topGrid.Controls.Add(BuildConnectionPanel(), 1, 0);
        root.Controls.Add(topGrid, 0, 1);

        root.Controls.Add(BuildLogPanel(), 0, 2);

    }

    private Control BuildHero()
    {
        var hero = Card();
        hero.Height = 176;

        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
            BackColor = Surface,
            Padding = new Padding(24, 18, 24, 18),
        };
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 48));
        hero.Controls.Add(layout);

        var topRow = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 3,
            RowCount = 1,
            BackColor = Surface,
        };
        topRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        topRow.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        topRow.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        layout.Controls.Add(topRow, 0, 0);

        var titleStack = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            BackColor = Surface,
        };
        titleStack.Controls.Add(new Label
        {
            Text = "CC Pocket Bridge",
            AutoSize = true,
            Font = new Font("Segoe UI Variable Display", 22F, FontStyle.Bold),
            ForeColor = Ink,
        });
        titleStack.Controls.Add(new Label
        {
            Text = T("heroSubtitle"),
            AutoSize = true,
            ForeColor = Muted,
            Padding = new Padding(2, 6, 0, 0),
        });
        repoLabel.ForeColor = Muted;
        repoLabel.AutoEllipsis = true;
        repoLabel.MaximumSize = new Size(620, 24);
        repoLabel.Padding = new Padding(2, 8, 0, 0);
        titleStack.Controls.Add(repoLabel);
        topRow.Controls.Add(titleStack, 0, 0);

        var statusStack = new FlowLayoutPanel
        {
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            AutoSize = true,
            BackColor = Surface,
            Anchor = AnchorStyles.Right | AnchorStyles.Top,
        };
        statusPill.AutoSize = true;
        statusPill.Padding = new Padding(14, 7, 14, 7);
        statusPill.Font = new Font(Font, FontStyle.Bold);
        statusStack.Controls.Add(statusPill);
        metricLabel.AutoSize = true;
        metricLabel.ForeColor = Muted;
        metricLabel.TextAlign = ContentAlignment.MiddleRight;
        metricLabel.Padding = new Padding(0, 12, 0, 0);
        statusStack.Controls.Add(metricLabel);
        topRow.Controls.Add(statusStack, 1, 0);

        var languageRow = new FlowLayoutPanel
        {
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = false,
            AutoSize = true,
            BackColor = Surface,
            Padding = new Padding(18, 2, 0, 0),
            Anchor = AnchorStyles.Right | AnchorStyles.Top,
        };
        languageRow.Controls.Add(new Label
        {
            Text = T("language"),
            AutoSize = true,
            ForeColor = Muted,
            Padding = new Padding(0, 5, 8, 0),
        });
        StyleComboBox(languageInput);
        languageRow.Controls.Add(languageInput);
        topRow.Controls.Add(languageRow, 2, 0);

        var actionBar = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = false,
            BackColor = Surface,
            Padding = new Padding(0, 10, 0, 0),
        };
        actionBar.Controls.Add(ActionButton(T("start"), StartBridge, primary: true, wide: true));
        actionBar.Controls.Add(ActionButton(T("stop"), () => bridge.Stop(), wide: true));
        actionBar.Controls.Add(ActionButton(T("restart"), RestartBridge, wide: true));
        actionBar.Controls.Add(ActionButton(T("copyUrl"), CopySelectedUrl, wide: true));
        actionBar.Controls.Add(ActionButton(T("healthPage"), OpenHealth, wide: true));
        layout.Controls.Add(actionBar, 0, 1);

        return hero;
    }

    private Control BuildSettingsPanel()
    {
        var card = Card();
        card.AutoScroll = true;
        var panel = InnerStack(T("settings"));
        card.Controls.Add(panel);

        var grid = new TableLayoutPanel { Dock = DockStyle.Top, AutoSize = true, ColumnCount = 2, BackColor = Surface };
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 112));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        panel.Controls.Add(grid, 0, 1);

        StyleField(hostInput);
        StyleField(allowedDirsInput);
        StyleField(apiKeyInput);
        StyleNumericField(portInput);
        StyleCheckBox(startOnLaunchInput);
        startOnLaunchInput.Text = T("startOnLaunch");

        AddRow(grid, T("port"), portInput);
        AddRow(grid, T("host"), hostInput);
        AddRow(grid, T("allowedDirs"), allowedDirsInput);
        AddRow(grid, T("apiKey"), apiKeyInput);
        AddRow(grid, "", startOnLaunchInput);

        var buttonPanel = new FlowLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            FlowDirection = FlowDirection.LeftToRight,
            BackColor = Surface,
            Padding = new Padding(0, 14, 0, 0),
        };
        buttonPanel.Controls.Add(ActionButton(T("save"), SaveSettings));
        buttonPanel.Controls.Add(ActionButton(T("start"), StartBridge, primary: true));
        buttonPanel.Controls.Add(ActionButton(T("stop"), () => bridge.Stop()));
        buttonPanel.Controls.Add(ActionButton(T("restart"), RestartBridge));
        panel.Controls.Add(buttonPanel, 0, 2);

        return card;
    }

    private Control BuildConnectionPanel()
    {
        var card = Card();
        var panel = InnerStack(T("connectPhone"));
        card.Controls.Add(panel);

        var note = new Label
        {
            Text = T("connectNote"),
            Dock = DockStyle.Top,
            ForeColor = Muted,
            Height = 44,
        };
        panel.Controls.Add(note, 0, 1);

        urlList.Dock = DockStyle.Top;
        urlList.Height = 120;
        urlList.BorderStyle = BorderStyle.None;
        urlList.BackColor = Field;
        urlList.ForeColor = Ink;
        urlList.Font = new Font("Cascadia Mono", 9.5F);
        panel.Controls.Add(urlList, 0, 2);

        var linkLabel = SmallLabel(T("deepLink"));
        linkLabel.Padding = new Padding(0, 14, 0, 4);
        panel.Controls.Add(linkLabel, 0, 3);

        StyleField(deepLinkBox);
        deepLinkBox.Dock = DockStyle.Top;
        panel.Controls.Add(deepLinkBox, 0, 4);

        var buttonPanel = new FlowLayoutPanel
        {
            Dock = DockStyle.Bottom,
            AutoSize = true,
            FlowDirection = FlowDirection.LeftToRight,
            BackColor = Surface,
            Padding = new Padding(0, 14, 0, 0),
        };
        buttonPanel.Controls.Add(ActionButton(T("copyUrl"), CopySelectedUrl, primary: true));
        buttonPanel.Controls.Add(ActionButton(T("copyDeepLink"), CopyDeepLink));
        buttonPanel.Controls.Add(ActionButton(T("healthPage"), OpenHealth));
        panel.Controls.Add(buttonPanel, 0, 5);

        return card;
    }

    private Control BuildLogPanel()
    {
        var card = Card();
        var panel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 3,
            BackColor = Surface,
            Padding = new Padding(18),
        };
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        card.Controls.Add(panel);

        panel.Controls.Add(new Label
        {
            Text = T("logs"),
            Dock = DockStyle.Top,
            AutoSize = true,
            Font = new Font("Segoe UI Variable Display", 13F, FontStyle.Bold),
            ForeColor = Ink,
            Padding = new Padding(0, 0, 0, 8),
        }, 0, 0);

        panel.Controls.Add(new Label
        {
            Text = T("logsNote"),
            Dock = DockStyle.Top,
            AutoSize = true,
            ForeColor = Muted,
            Padding = new Padding(0, 0, 0, 12),
        }, 0, 1);

        logBox.Dock = DockStyle.Fill;
        logBox.BackColor = Color.FromArgb(22, 27, 25);
        logBox.ForeColor = Color.FromArgb(209, 226, 216);
        logBox.Padding = new Padding(12);
        panel.Controls.Add(logBox, 0, 2);

        return card;
    }

    private void LoadSettingsIntoInputs()
    {
        repoLabel.Text = bridge.RepositoryRoot;
        portInput.Value = settings.Port;
        hostInput.Text = settings.Host;
        allowedDirsInput.Text = settings.AllowedDirs;
        apiKeyInput.Text = settings.ApiKey;
        startOnLaunchInput.Checked = settings.StartBridgeOnLaunch;
        languageInput.Items.Clear();
        languageInput.Items.Add(I18n.DisplayName(I18n.Chinese));
        languageInput.Items.Add(I18n.DisplayName(I18n.English));
        languageInput.SelectedIndex = I18n.IsChinese(settings.Language) ? 0 : 1;
    }

    private void RefreshUrls()
    {
        var selected = urlList.SelectedItem as string;
        urlList.Items.Clear();

        foreach (var url in BridgeProcessManager.GetWebSocketUrls((int)portInput.Value))
        {
            urlList.Items.Add(url);
        }

        if (selected != null && urlList.Items.Contains(selected))
        {
            urlList.SelectedItem = selected;
        }
        else if (urlList.Items.Count > 0)
        {
            urlList.SelectedIndex = 0;
        }

        RefreshDeepLink();
    }

    private void RefreshDeepLink()
    {
        var url = SelectedUrl();
        deepLinkBox.Text = url == null ? "" : BridgeProcessManager.BuildDeepLink(url, apiKeyInput.Text);
    }

    private void RefreshStatus(BridgeHealth? health = null)
    {
        if (health != null)
        {
            statusPill.Text = T("running");
            statusPill.BackColor = Accent;
            statusPill.ForeColor = Color.White;
            metricLabel.Text = $"{T("uptime")} {health.Uptime}s   {T("clients")} {health.Clients}   {T("sessions")} {health.Sessions}";
            return;
        }

        statusPill.Text = bridge.IsRunning ? T("starting") : T("stopped");
        statusPill.BackColor = bridge.IsRunning ? Warning : Danger;
        statusPill.ForeColor = Color.White;
        metricLabel.Text = bridge.IsRunning ? T("waitingHealth") : T("notReachable");
    }

    private async Task PollHealthAsync()
    {
        var health = await bridge.GetHealthAsync((int)portInput.Value, CancellationToken.None);
        if (!IsDisposed) RefreshStatus(health);
    }

    private void RefreshLogs()
    {
        var logs = bridge.Logs;
        logBox.Text = string.IsNullOrWhiteSpace(logs)
            ? T("emptyLogs")
            : logs;
        logBox.SelectionStart = logBox.TextLength;
        logBox.ScrollToCaret();
    }

    private void OnBridgeLogsChanged()
    {
        if (IsDisposed) return;
        BeginInvoke(RefreshLogs);
    }

    private void OnBridgeStateChanged()
    {
        if (IsDisposed) return;
        BeginInvoke(() => RefreshStatus());
    }

    private void StartBridge()
    {
        try
        {
            SaveSettings();
            bridge.Start(settings);
            RefreshStatus();
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "CC Pocket", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void RestartBridge()
    {
        bridge.Stop();
        StartBridge();
    }

    private void ChangeLanguage()
    {
        SaveSettings();
        Controls.Clear();
        BuildLayout();
        LoadSettingsIntoInputs();
        RefreshUrls();
        RefreshStatus();
        RefreshLogs();
        LanguageChanged?.Invoke();
    }

    private void CopySelectedUrl()
    {
        var url = SelectedUrl();
        if (url == null) return;
        Clipboard.SetText(url);
    }

    private void CopyDeepLink()
    {
        if (string.IsNullOrWhiteSpace(deepLinkBox.Text)) return;
        Clipboard.SetText(deepLinkBox.Text);
    }

    private void OpenHealth()
    {
        var url = $"http://127.0.0.1:{(int)portInput.Value}/health";
        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
        {
            FileName = url,
            UseShellExecute = true,
        });
    }

    private string? SelectedUrl()
    {
        return urlList.SelectedItem as string ?? (urlList.Items.Count > 0 ? urlList.Items[0]?.ToString() : null);
    }

    private static Panel Card()
    {
        return new Panel
        {
            Dock = DockStyle.Fill,
            BackColor = Surface,
            Padding = new Padding(1),
            Margin = new Padding(0, 0, 14, 0),
        };
    }

    private static TableLayoutPanel InnerStack(string title)
    {
        var panel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 7,
            BackColor = Surface,
            Padding = new Padding(18),
        };
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        panel.Controls.Add(new Label
        {
            Text = title,
            Dock = DockStyle.Top,
            AutoSize = true,
            Font = new Font("Segoe UI Variable Display", 13F, FontStyle.Bold),
            ForeColor = Ink,
            Padding = new Padding(0, 0, 0, 12),
        }, 0, 0);
        return panel;
    }

    private static Button ActionButton(
        string text,
        Action action,
        bool primary = false,
        bool wide = false)
    {
        var button = new Button
        {
            Text = text,
            AutoSize = true,
            MinimumSize = wide ? new Size(116, 34) : new Size(92, 34),
            FlatStyle = FlatStyle.Flat,
            BackColor = primary ? Accent : SurfaceRaised,
            ForeColor = primary ? Color.White : Ink,
            Margin = wide ? new Padding(0, 0, 0, 8) : new Padding(0, 0, 8, 0),
            Cursor = Cursors.Hand,
            Font = new Font("Segoe UI Variable Text", 9F, FontStyle.Bold),
        };
        button.FlatAppearance.BorderSize = 0;
        button.FlatAppearance.MouseOverBackColor = primary
            ? Color.FromArgb(42, 112, 74)
            : Color.FromArgb(216, 226, 220);
        button.FlatAppearance.MouseDownBackColor = primary
            ? Color.FromArgb(31, 92, 59)
            : Color.FromArgb(204, 216, 209);
        button.Click += (_, _) => action();
        return button;
    }

    private static void AddRow(TableLayoutPanel panel, string label, Control control)
    {
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.Controls.Add(SmallLabel(label), 0, panel.RowCount);
        panel.Controls.Add(control, 1, panel.RowCount);
        panel.RowCount++;
    }

    private static Label SmallLabel(string text)
    {
        return new Label
        {
            Text = text,
            AutoSize = true,
            ForeColor = Muted,
            Padding = new Padding(0, 8, 12, 8),
        };
    }

    private static void StyleField(TextBox textBox)
    {
        textBox.Dock = DockStyle.Top;
        textBox.BorderStyle = BorderStyle.FixedSingle;
        textBox.BackColor = Field;
        textBox.ForeColor = Ink;
        textBox.Margin = new Padding(0, 4, 0, 8);
        textBox.Font = new Font("Segoe UI Variable Text", 9.5F);
    }

    private static void StyleNumericField(NumericUpDown numeric)
    {
        numeric.BackColor = Field;
        numeric.ForeColor = Ink;
        numeric.BorderStyle = BorderStyle.FixedSingle;
        numeric.Margin = new Padding(0, 4, 0, 8);
        numeric.Font = new Font("Segoe UI Variable Text", 9.5F);
    }

    private static void StyleCheckBox(CheckBox checkBox)
    {
        checkBox.ForeColor = Ink;
        checkBox.BackColor = Surface;
        checkBox.Padding = new Padding(0, 8, 0, 4);
        checkBox.FlatStyle = FlatStyle.Flat;
    }

    private static void StyleComboBox(ComboBox comboBox)
    {
        comboBox.BackColor = Field;
        comboBox.ForeColor = Ink;
        comboBox.FlatStyle = FlatStyle.Flat;
        comboBox.Font = new Font("Segoe UI Variable Text", 9F);
    }

    private string T(string key) => I18n.T(settings.Language, key);
}
