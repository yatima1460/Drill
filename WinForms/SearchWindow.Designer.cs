namespace WinForms
{
    partial class SearchWindow
    {
        /// <summary>
        ///  Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        ///  Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        ///  Required method for Designer support - do not modify
        ///  the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            components = new System.ComponentModel.Container();
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(SearchWindow));
            refreshVirtualListTicker = new System.Windows.Forms.Timer(components);
            contextMenuRightClickFile = new ContextMenuStrip(components);
            open = new ToolStripMenuItem();
            openWithToolStripMenuItem = new ToolStripMenuItem();
            openContainingFolder = new ToolStripMenuItem();
            copyToolStripMenuItem = new ToolStripMenuItem();
            nameToolStripMenuItem = new ToolStripMenuItem();
            nameWithExtensionToolStripMenuItem = new ToolStripMenuItem();
            fullPathToolStripMenuItem = new ToolStripMenuItem();
            modifiedDateToolStripMenuItem = new ToolStripMenuItem();
            sizeToolStripMenuItem = new ToolStripMenuItem();
            containingFolderFullPathToolStripMenuItem = new ToolStripMenuItem();
            copyFileToolStripMenuItem = new ToolStripMenuItem();
            menuStrip = new MenuStrip();
            fileToolStripMenuItem = new ToolStripMenuItem();
            exportResultsTocsvToolStripMenuItem = new ToolStripMenuItem();
            exitToolStripMenuItem = new ToolStripMenuItem();
            resultsCountToolStripMenuItem = new ToolStripMenuItem();
            stopToolStripMenuItem = new ToolStripMenuItem();
            autoSortingToolStripMenuItem = new ToolStripMenuItem();
            debugToolStripMenuItem = new ToolStripMenuItem();
            aboutToolStripMenuItem = new ToolStripMenuItem();
            toolStripMenuItem1 = new ToolStripMenuItem();
            fileSearchInput = new TextBox();
            fileSearchResults = new ListView();
            columnHeader3 = new ColumnHeader();
            columnHeader4 = new ColumnHeader();
            columnHeader5 = new ColumnHeader();
            columnHeader6 = new ColumnHeader();
            tableLayoutPanel1 = new TableLayoutPanel();
            searchStringChangedTimer = new System.Windows.Forms.Timer(components);
            contextMenuRightClickFile.SuspendLayout();
            menuStrip.SuspendLayout();
            tableLayoutPanel1.SuspendLayout();
            SuspendLayout();
            // 
            // refreshVirtualListTicker
            // 
            refreshVirtualListTicker.Tick += RefreshVirtualListCountTick;
            // 
            // contextMenuRightClickFile
            // 
            contextMenuRightClickFile.ImageScalingSize = new Size(20, 20);
            contextMenuRightClickFile.Items.AddRange(new ToolStripItem[] { open, openWithToolStripMenuItem, openContainingFolder, copyToolStripMenuItem, copyFileToolStripMenuItem });
            contextMenuRightClickFile.Name = "contextMenuStrip2";
            contextMenuRightClickFile.Size = new Size(198, 114);
            // 
            // open
            // 
            open.Name = "open";
            open.Size = new Size(197, 22);
            open.Text = "Open";
            open.Click += open_Click;
            // 
            // openWithToolStripMenuItem
            // 
            openWithToolStripMenuItem.Name = "openWithToolStripMenuItem";
            openWithToolStripMenuItem.Size = new Size(197, 22);
            openWithToolStripMenuItem.Text = "Open with...";
            openWithToolStripMenuItem.Click += openWithToolStripMenuItem_Click;
            // 
            // openContainingFolder
            // 
            openContainingFolder.Name = "openContainingFolder";
            openContainingFolder.Size = new Size(197, 22);
            openContainingFolder.Text = "Open containing folder";
            openContainingFolder.Click += openContainingFolder_Click;
            // 
            // copyToolStripMenuItem
            // 
            copyToolStripMenuItem.DropDownItems.AddRange(new ToolStripItem[] { nameToolStripMenuItem, nameWithExtensionToolStripMenuItem, fullPathToolStripMenuItem, modifiedDateToolStripMenuItem, sizeToolStripMenuItem, containingFolderFullPathToolStripMenuItem });
            copyToolStripMenuItem.Name = "copyToolStripMenuItem";
            copyToolStripMenuItem.Size = new Size(197, 22);
            copyToolStripMenuItem.Text = "Copy metadata";
            // 
            // nameToolStripMenuItem
            // 
            nameToolStripMenuItem.Name = "nameToolStripMenuItem";
            nameToolStripMenuItem.Size = new Size(214, 22);
            nameToolStripMenuItem.Text = "Name";
            nameToolStripMenuItem.Click += copyName;
            // 
            // nameWithExtensionToolStripMenuItem
            // 
            nameWithExtensionToolStripMenuItem.Name = "nameWithExtensionToolStripMenuItem";
            nameWithExtensionToolStripMenuItem.Size = new Size(214, 22);
            nameWithExtensionToolStripMenuItem.Text = "Name with extension";
            nameWithExtensionToolStripMenuItem.Click += copyNameWithExtension;
            // 
            // fullPathToolStripMenuItem
            // 
            fullPathToolStripMenuItem.Name = "fullPathToolStripMenuItem";
            fullPathToolStripMenuItem.Size = new Size(214, 22);
            fullPathToolStripMenuItem.Text = "Full path";
            fullPathToolStripMenuItem.Click += copyFullPath;
            // 
            // modifiedDateToolStripMenuItem
            // 
            modifiedDateToolStripMenuItem.Name = "modifiedDateToolStripMenuItem";
            modifiedDateToolStripMenuItem.Size = new Size(214, 22);
            modifiedDateToolStripMenuItem.Text = "Modified date";
            modifiedDateToolStripMenuItem.Click += copyModifiedDate;
            // 
            // sizeToolStripMenuItem
            // 
            sizeToolStripMenuItem.Name = "sizeToolStripMenuItem";
            sizeToolStripMenuItem.Size = new Size(214, 22);
            sizeToolStripMenuItem.Text = "Size";
            sizeToolStripMenuItem.Click += copySize;
            // 
            // containingFolderFullPathToolStripMenuItem
            // 
            containingFolderFullPathToolStripMenuItem.Name = "containingFolderFullPathToolStripMenuItem";
            containingFolderFullPathToolStripMenuItem.Size = new Size(214, 22);
            containingFolderFullPathToolStripMenuItem.Text = "Containing folder full path";
            containingFolderFullPathToolStripMenuItem.Click += copyContainingFolderFullPath;
            // 
            // copyFileToolStripMenuItem
            // 
            copyFileToolStripMenuItem.Name = "copyFileToolStripMenuItem";
            copyFileToolStripMenuItem.Size = new Size(197, 22);
            copyFileToolStripMenuItem.Text = "Copy file";
            copyFileToolStripMenuItem.Click += copyFile;
            // 
            // menuStrip
            // 
            menuStrip.BackColor = Color.White;
            menuStrip.Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point, 0);
            menuStrip.ImageScalingSize = new Size(24, 24);
            menuStrip.Items.AddRange(new ToolStripItem[] { fileToolStripMenuItem, resultsCountToolStripMenuItem, debugToolStripMenuItem, aboutToolStripMenuItem, toolStripMenuItem1 });
            menuStrip.Location = new Point(0, 0);
            menuStrip.Name = "menuStrip";
            menuStrip.Size = new Size(1608, 24);
            menuStrip.TabIndex = 3;
            menuStrip.Text = "menuStrip";
            menuStrip.ItemClicked += menuStrip_ItemClicked;
            // 
            // fileToolStripMenuItem
            // 
            fileToolStripMenuItem.DropDownItems.AddRange(new ToolStripItem[] { exportResultsTocsvToolStripMenuItem, exitToolStripMenuItem });
            fileToolStripMenuItem.Name = "fileToolStripMenuItem";
            fileToolStripMenuItem.Size = new Size(50, 20);
            fileToolStripMenuItem.Text = "📄 File";
            // 
            // exportResultsTocsvToolStripMenuItem
            // 
            exportResultsTocsvToolStripMenuItem.Name = "exportResultsTocsvToolStripMenuItem";
            exportResultsTocsvToolStripMenuItem.Size = new Size(189, 22);
            exportResultsTocsvToolStripMenuItem.Text = "Export results to .tsv...";
            exportResultsTocsvToolStripMenuItem.Click += exportResultsTocsvToolStripMenuItem_Click_2;
            // 
            // exitToolStripMenuItem
            // 
            exitToolStripMenuItem.Name = "exitToolStripMenuItem";
            exitToolStripMenuItem.Size = new Size(189, 22);
            exitToolStripMenuItem.Text = "Exit";
            exitToolStripMenuItem.Click += exitToolStripMenuItem_Click;
            // 
            // resultsCountToolStripMenuItem
            // 
            resultsCountToolStripMenuItem.DropDownItems.AddRange(new ToolStripItem[] { stopToolStripMenuItem, autoSortingToolStripMenuItem });
            resultsCountToolStripMenuItem.Name = "resultsCountToolStripMenuItem";
            resultsCountToolStripMenuItem.Size = new Size(70, 20);
            resultsCountToolStripMenuItem.Text = "⚙️ Engine";
            resultsCountToolStripMenuItem.Click += searchToolStripMenuItem_Click;
            // 
            // stopToolStripMenuItem
            // 
            stopToolStripMenuItem.Name = "stopToolStripMenuItem";
            stopToolStripMenuItem.Size = new Size(141, 22);
            stopToolStripMenuItem.Text = "⏹️ Stop";
            stopToolStripMenuItem.Click += stopToolStripMenuItem_Click;
            // 
            // autoSortingToolStripMenuItem
            // 
            autoSortingToolStripMenuItem.CheckOnClick = true;
            autoSortingToolStripMenuItem.Name = "autoSortingToolStripMenuItem";
            autoSortingToolStripMenuItem.Size = new Size(141, 22);
            autoSortingToolStripMenuItem.Text = "Auto Sorting";
            autoSortingToolStripMenuItem.CheckedChanged += autoSortingToolStripMenuItem_CheckedChanged;
            // 
            // debugToolStripMenuItem
            // 
            debugToolStripMenuItem.Name = "debugToolStripMenuItem";
            debugToolStripMenuItem.Size = new Size(65, 20);
            debugToolStripMenuItem.Text = "\U0001fab2 Debug";
            // 
            // aboutToolStripMenuItem
            // 
            aboutToolStripMenuItem.Name = "aboutToolStripMenuItem";
            aboutToolStripMenuItem.Size = new Size(64, 20);
            aboutToolStripMenuItem.Text = "❓ About";
            aboutToolStripMenuItem.Click += aboutToolStripMenuItem_Click;
            // 
            // toolStripMenuItem1
            // 
            toolStripMenuItem1.Name = "toolStripMenuItem1";
            toolStripMenuItem1.Size = new Size(12, 20);
            // 
            // fileSearchInput
            // 
            fileSearchInput.BackColor = Color.White;
            fileSearchInput.Dock = DockStyle.Fill;
            fileSearchInput.Font = new Font("Segoe UI", 24F);
            fileSearchInput.Location = new Point(4, 4);
            fileSearchInput.Margin = new Padding(4);
            fileSearchInput.MaxLength = 260;
            fileSearchInput.Name = "fileSearchInput";
            fileSearchInput.PlaceholderText = "Search everywhere...";
            fileSearchInput.Size = new Size(1600, 50);
            fileSearchInput.TabIndex = 5;
            fileSearchInput.TextChanged += searchBox_TextChanged;
            fileSearchInput.KeyDown += searchBox_KeyDown;
            // 
            // fileSearchResults
            // 
            fileSearchResults.BorderStyle = BorderStyle.None;
            fileSearchResults.Columns.AddRange(new ColumnHeader[] { columnHeader3, columnHeader4, columnHeader5, columnHeader6 });
            fileSearchResults.Dock = DockStyle.Fill;
            fileSearchResults.Font = new Font("Consolas", 9F);
            fileSearchResults.FullRowSelect = true;
            fileSearchResults.GridLines = true;
            fileSearchResults.HeaderStyle = ColumnHeaderStyle.Nonclickable;
            fileSearchResults.Location = new Point(4, 62);
            fileSearchResults.Margin = new Padding(4);
            fileSearchResults.Name = "fileSearchResults";
            fileSearchResults.Size = new Size(1600, 640);
            fileSearchResults.TabIndex = 4;
            fileSearchResults.UseCompatibleStateImageBehavior = false;
            fileSearchResults.RetrieveVirtualItem += SearchResults_RetrieveVirtualItem;
            fileSearchResults.SelectedIndexChanged += fileSearchResults_SelectedIndexChanged_1;
            fileSearchResults.KeyDown += searchBox_KeyDown;
            fileSearchResults.MouseClick += searchResults_MouseClick;
            fileSearchResults.MouseDoubleClick += searchResults_MouseDoubleClick;
            fileSearchResults.Resize += fileSearchResults_Resize;
            // 
            // columnHeader3
            // 
            columnHeader3.Text = "Name";
            columnHeader3.Width = 355;
            // 
            // columnHeader4
            // 
            columnHeader4.Text = "Folder";
            columnHeader4.Width = 255;
            // 
            // columnHeader5
            // 
            columnHeader5.Text = "Size";
            columnHeader5.Width = 150;
            // 
            // columnHeader6
            // 
            columnHeader6.Text = "Date";
            columnHeader6.Width = 150;
            // 
            // tableLayoutPanel1
            // 
            tableLayoutPanel1.ColumnCount = 1;
            tableLayoutPanel1.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            tableLayoutPanel1.Controls.Add(fileSearchResults, 0, 1);
            tableLayoutPanel1.Controls.Add(fileSearchInput, 0, 0);
            tableLayoutPanel1.Dock = DockStyle.Fill;
            tableLayoutPanel1.Location = new Point(0, 24);
            tableLayoutPanel1.Name = "tableLayoutPanel1";
            tableLayoutPanel1.RowCount = 2;
            tableLayoutPanel1.RowStyles.Add(new RowStyle());
            tableLayoutPanel1.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            tableLayoutPanel1.Size = new Size(1608, 706);
            tableLayoutPanel1.TabIndex = 7;
            // 
            // searchStringChangedTimer
            // 
            searchStringChangedTimer.Interval = 250;
            searchStringChangedTimer.Tick += searchStringChangedTimer_Tick;
            // 
            // SearchWindow
            // 
            AutoScaleMode = AutoScaleMode.None;
            BackColor = Color.White;
            ClientSize = new Size(1608, 730);
            Controls.Add(tableLayoutPanel1);
            Controls.Add(menuStrip);
            Font = new Font("Consolas", 9F);
            Icon = (Icon)resources.GetObject("$this.Icon");
            MainMenuStrip = menuStrip;
            Margin = new Padding(4);
            Name = "SearchWindow";
            StartPosition = FormStartPosition.CenterScreen;
            Text = "Drill";
            FormClosing += Window_Closing;
            Load += SearchWindow_Load;
            contextMenuRightClickFile.ResumeLayout(false);
            menuStrip.ResumeLayout(false);
            menuStrip.PerformLayout();
            tableLayoutPanel1.ResumeLayout(false);
            tableLayoutPanel1.PerformLayout();
            ResumeLayout(false);
            PerformLayout();
        }

        #endregion

        private System.Windows.Forms.Timer refreshVirtualListTicker;
        private ContextMenuStrip contextMenuRightClickFile;
        private ToolStripMenuItem open;
        private ToolStripMenuItem openContainingFolder;
        private ToolStripMenuItem copyToolStripMenuItem;
        private ToolStripMenuItem nameToolStripMenuItem;
        private ToolStripMenuItem nameWithExtensionToolStripMenuItem;
        private ToolStripMenuItem fullPathToolStripMenuItem;
        private ToolStripMenuItem modifiedDateToolStripMenuItem;
        private ToolStripMenuItem sizeToolStripMenuItem;
        private ToolStripMenuItem openWithToolStripMenuItem;
        private ToolStripMenuItem copyFileToolStripMenuItem;
        private ToolStripMenuItem containingFolderFullPathToolStripMenuItem;
        private MenuStrip menuStrip;
        private ToolStripMenuItem resultsCountToolStripMenuItem;
        private ToolStripMenuItem stopToolStripMenuItem;
        private ToolStripMenuItem fileToolStripMenuItem;
        private ToolStripMenuItem exitToolStripMenuItem;
        private TextBox fileSearchInput;
        private ListView fileSearchResults;
        private ColumnHeader columnHeader3;
        private ColumnHeader columnHeader4;
        private ColumnHeader columnHeader5;
        private ColumnHeader columnHeader6;
        private ToolStripMenuItem autoSortingToolStripMenuItem;
        private ToolStripMenuItem aboutToolStripMenuItem;
        private ToolStripMenuItem exportResultsTocsvToolStripMenuItem;
        private ToolStripMenuItem toolStripMenuItem1;
        private ToolStripMenuItem debugToolStripMenuItem;
        private TableLayoutPanel tableLayoutPanel1;
        private System.Windows.Forms.Timer searchStringChangedTimer;
    }
}