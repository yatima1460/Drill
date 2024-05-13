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
            this.components = new System.ComponentModel.Container();
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(SearchWindow));
            this.refreshVirtualListTicker = new System.Windows.Forms.Timer(this.components);
            this.contextMenuRightClickFile = new System.Windows.Forms.ContextMenuStrip(this.components);
            this.open = new System.Windows.Forms.ToolStripMenuItem();
            this.openWithToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.openContainingFolder = new System.Windows.Forms.ToolStripMenuItem();
            this.copyToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.nameToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.nameWithExtensionToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.fullPathToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.modifiedDateToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.sizeToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.containingFolderFullPathToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.copyFileToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.menuStrip = new System.Windows.Forms.MenuStrip();
            this.fileToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.exportResultsTocsvToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.exitToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.resultsCountToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.stopToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.autoSortingToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.drivesToolStripMenuItem1 = new System.Windows.Forms.ToolStripMenuItem();
            this.filtersToolStripMenuItem1 = new System.Windows.Forms.ToolStripMenuItem();
            this.heuristicsToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.debugToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.aboutToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.toolStripMenuItem1 = new System.Windows.Forms.ToolStripMenuItem();
            this.fileSearchInput = new System.Windows.Forms.TextBox();
            this.fileSearchResults = new System.Windows.Forms.ListView();
            this.columnHeader3 = new System.Windows.Forms.ColumnHeader();
            this.columnHeader4 = new System.Windows.Forms.ColumnHeader();
            this.columnHeader5 = new System.Windows.Forms.ColumnHeader();
            this.columnHeader6 = new System.Windows.Forms.ColumnHeader();
            this.columnHeader7 = new System.Windows.Forms.ColumnHeader();
            this.searchStringChangedTimer = new System.Windows.Forms.Timer(this.components);
            this.contextMenuRightClickFile.SuspendLayout();
            this.menuStrip.SuspendLayout();
            this.SuspendLayout();
            // 
            // refreshVirtualListTicker
            // 
            this.refreshVirtualListTicker.Tick += new System.EventHandler(this.RefreshVirtualListCountTick);
            // 
            // contextMenuRightClickFile
            // 
            this.contextMenuRightClickFile.ImageScalingSize = new System.Drawing.Size(20, 20);
            this.contextMenuRightClickFile.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.open,
            this.openWithToolStripMenuItem,
            this.openContainingFolder,
            this.copyToolStripMenuItem,
            this.copyFileToolStripMenuItem});
            this.contextMenuRightClickFile.Name = "contextMenuStrip2";
            this.contextMenuRightClickFile.Size = new System.Drawing.Size(269, 197);
            // 
            // open
            // 
            this.open.Name = "open";
            this.open.Size = new System.Drawing.Size(268, 32);
            this.open.Text = "Open";
            this.open.Click += new System.EventHandler(this.open_Click);
            // 
            // openWithToolStripMenuItem
            // 
            this.openWithToolStripMenuItem.Name = "openWithToolStripMenuItem";
            this.openWithToolStripMenuItem.Size = new System.Drawing.Size(268, 32);
            this.openWithToolStripMenuItem.Text = "Open with...";
            this.openWithToolStripMenuItem.Click += new System.EventHandler(this.openWithToolStripMenuItem_Click);
            // 
            // openContainingFolder
            // 
            this.openContainingFolder.Name = "openContainingFolder";
            this.openContainingFolder.Size = new System.Drawing.Size(268, 32);
            this.openContainingFolder.Text = "Open containing folder";
            this.openContainingFolder.Click += new System.EventHandler(this.openContainingFolder_Click);
            // 
            // copyToolStripMenuItem
            // 
            this.copyToolStripMenuItem.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.nameToolStripMenuItem,
            this.nameWithExtensionToolStripMenuItem,
            this.fullPathToolStripMenuItem,
            this.modifiedDateToolStripMenuItem,
            this.sizeToolStripMenuItem,
            this.containingFolderFullPathToolStripMenuItem});
            this.copyToolStripMenuItem.Name = "copyToolStripMenuItem";
            this.copyToolStripMenuItem.Size = new System.Drawing.Size(268, 32);
            this.copyToolStripMenuItem.Text = "Copy metadata";
            // 
            // nameToolStripMenuItem
            // 
            this.nameToolStripMenuItem.Name = "nameToolStripMenuItem";
            this.nameToolStripMenuItem.Size = new System.Drawing.Size(322, 34);
            this.nameToolStripMenuItem.Text = "Name";
            this.nameToolStripMenuItem.Click += new System.EventHandler(this.copyName);
            // 
            // nameWithExtensionToolStripMenuItem
            // 
            this.nameWithExtensionToolStripMenuItem.Name = "nameWithExtensionToolStripMenuItem";
            this.nameWithExtensionToolStripMenuItem.Size = new System.Drawing.Size(322, 34);
            this.nameWithExtensionToolStripMenuItem.Text = "Name with extension";
            this.nameWithExtensionToolStripMenuItem.Click += new System.EventHandler(this.copyNameWithExtension);
            // 
            // fullPathToolStripMenuItem
            // 
            this.fullPathToolStripMenuItem.Name = "fullPathToolStripMenuItem";
            this.fullPathToolStripMenuItem.Size = new System.Drawing.Size(322, 34);
            this.fullPathToolStripMenuItem.Text = "Full path";
            this.fullPathToolStripMenuItem.Click += new System.EventHandler(this.copyFullPath);
            // 
            // modifiedDateToolStripMenuItem
            // 
            this.modifiedDateToolStripMenuItem.Name = "modifiedDateToolStripMenuItem";
            this.modifiedDateToolStripMenuItem.Size = new System.Drawing.Size(322, 34);
            this.modifiedDateToolStripMenuItem.Text = "Modified date";
            this.modifiedDateToolStripMenuItem.Click += new System.EventHandler(this.copyModifiedDate);
            // 
            // sizeToolStripMenuItem
            // 
            this.sizeToolStripMenuItem.Name = "sizeToolStripMenuItem";
            this.sizeToolStripMenuItem.Size = new System.Drawing.Size(322, 34);
            this.sizeToolStripMenuItem.Text = "Size";
            this.sizeToolStripMenuItem.Click += new System.EventHandler(this.copySize);
            // 
            // containingFolderFullPathToolStripMenuItem
            // 
            this.containingFolderFullPathToolStripMenuItem.Name = "containingFolderFullPathToolStripMenuItem";
            this.containingFolderFullPathToolStripMenuItem.Size = new System.Drawing.Size(322, 34);
            this.containingFolderFullPathToolStripMenuItem.Text = "Containing folder full path";
            this.containingFolderFullPathToolStripMenuItem.Click += new System.EventHandler(this.copyContainingFolderFullPath);
            // 
            // copyFileToolStripMenuItem
            // 
            this.copyFileToolStripMenuItem.Name = "copyFileToolStripMenuItem";
            this.copyFileToolStripMenuItem.Size = new System.Drawing.Size(268, 32);
            this.copyFileToolStripMenuItem.Text = "Copy file";
            this.copyFileToolStripMenuItem.Click += new System.EventHandler(this.copyFile);
            // 
            // menuStrip
            // 
            this.menuStrip.BackColor = System.Drawing.Color.Transparent;
            this.menuStrip.ImageScalingSize = new System.Drawing.Size(24, 24);
            this.menuStrip.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.fileToolStripMenuItem,
            this.resultsCountToolStripMenuItem,
            this.drivesToolStripMenuItem1,
            this.filtersToolStripMenuItem1,
            this.heuristicsToolStripMenuItem,
            this.debugToolStripMenuItem,
            this.aboutToolStripMenuItem,
            this.toolStripMenuItem1});
            this.menuStrip.Location = new System.Drawing.Point(0, 0);
            this.menuStrip.Name = "menuStrip";
            this.menuStrip.Size = new System.Drawing.Size(1608, 33);
            this.menuStrip.TabIndex = 3;
            this.menuStrip.Text = "menuStrip";
            this.menuStrip.ItemClicked += new System.Windows.Forms.ToolStripItemClickedEventHandler(this.menuStrip_ItemClicked);
            // 
            // fileToolStripMenuItem
            // 
            this.fileToolStripMenuItem.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.exportResultsTocsvToolStripMenuItem,
            this.exitToolStripMenuItem});
            this.fileToolStripMenuItem.Name = "fileToolStripMenuItem";
            this.fileToolStripMenuItem.Size = new System.Drawing.Size(84, 29);
            this.fileToolStripMenuItem.Text = "📄 File";
            // 
            // exportResultsTocsvToolStripMenuItem
            // 
            this.exportResultsTocsvToolStripMenuItem.Name = "exportResultsTocsvToolStripMenuItem";
            this.exportResultsTocsvToolStripMenuItem.Size = new System.Drawing.Size(289, 34);
            this.exportResultsTocsvToolStripMenuItem.Text = "Export results to .csv...";
            // 
            // exitToolStripMenuItem
            // 
            this.exitToolStripMenuItem.Name = "exitToolStripMenuItem";
            this.exitToolStripMenuItem.Size = new System.Drawing.Size(289, 34);
            this.exitToolStripMenuItem.Text = "Exit";
            this.exitToolStripMenuItem.Click += new System.EventHandler(this.exitToolStripMenuItem_Click);
            // 
            // resultsCountToolStripMenuItem
            // 
            this.resultsCountToolStripMenuItem.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.stopToolStripMenuItem,
            this.autoSortingToolStripMenuItem});
            this.resultsCountToolStripMenuItem.Name = "resultsCountToolStripMenuItem";
            this.resultsCountToolStripMenuItem.Size = new System.Drawing.Size(111, 29);
            this.resultsCountToolStripMenuItem.Text = "⚙️ Engine";
            this.resultsCountToolStripMenuItem.Click += new System.EventHandler(this.searchToolStripMenuItem_Click);
            // 
            // stopToolStripMenuItem
            // 
            this.stopToolStripMenuItem.Name = "stopToolStripMenuItem";
            this.stopToolStripMenuItem.Size = new System.Drawing.Size(216, 34);
            this.stopToolStripMenuItem.Text = "⏹️ Stop";
            this.stopToolStripMenuItem.Click += new System.EventHandler(this.stopToolStripMenuItem_Click);
            // 
            // autoSortingToolStripMenuItem
            // 
            this.autoSortingToolStripMenuItem.CheckOnClick = true;
            this.autoSortingToolStripMenuItem.Name = "autoSortingToolStripMenuItem";
            this.autoSortingToolStripMenuItem.Size = new System.Drawing.Size(216, 34);
            this.autoSortingToolStripMenuItem.Text = "Auto Sorting";
            this.autoSortingToolStripMenuItem.CheckedChanged += new System.EventHandler(this.autoSortingToolStripMenuItem_CheckedChanged);
            // 
            // drivesToolStripMenuItem1
            // 
            this.drivesToolStripMenuItem1.Name = "drivesToolStripMenuItem1";
            this.drivesToolStripMenuItem1.Size = new System.Drawing.Size(104, 29);
            this.drivesToolStripMenuItem1.Text = "💿 Roots";
            this.drivesToolStripMenuItem1.Click += new System.EventHandler(this.drivesToolStripMenuItem1_Click);
            // 
            // filtersToolStripMenuItem1
            // 
            this.filtersToolStripMenuItem1.Name = "filtersToolStripMenuItem1";
            this.filtersToolStripMenuItem1.Size = new System.Drawing.Size(104, 29);
            this.filtersToolStripMenuItem1.Text = "🔍 Filters";
            this.filtersToolStripMenuItem1.Click += new System.EventHandler(this.filtersToolStripMenuItem1_Click);
            // 
            // heuristicsToolStripMenuItem
            // 
            this.heuristicsToolStripMenuItem.Name = "heuristicsToolStripMenuItem";
            this.heuristicsToolStripMenuItem.Size = new System.Drawing.Size(134, 29);
            this.heuristicsToolStripMenuItem.Text = "💡 Heuristics";
            this.heuristicsToolStripMenuItem.Click += new System.EventHandler(this.heuristicsToolStripMenuItem_Click);
            // 
            // debugToolStripMenuItem
            // 
            this.debugToolStripMenuItem.Name = "debugToolStripMenuItem";
            this.debugToolStripMenuItem.Size = new System.Drawing.Size(112, 29);
            this.debugToolStripMenuItem.Text = "🪲 Debug";
            // 
            // aboutToolStripMenuItem
            // 
            this.aboutToolStripMenuItem.Name = "aboutToolStripMenuItem";
            this.aboutToolStripMenuItem.Size = new System.Drawing.Size(108, 29);
            this.aboutToolStripMenuItem.Text = "❓ About";
            this.aboutToolStripMenuItem.Click += new System.EventHandler(this.aboutToolStripMenuItem_Click);
            // 
            // toolStripMenuItem1
            // 
            this.toolStripMenuItem1.Name = "toolStripMenuItem1";
            this.toolStripMenuItem1.Size = new System.Drawing.Size(16, 29);
            // 
            // fileSearchInput
            // 
            this.fileSearchInput.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
            | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.fileSearchInput.BackColor = System.Drawing.Color.White;
            this.fileSearchInput.Font = new System.Drawing.Font("Segoe UI", 24F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point);
            this.fileSearchInput.Location = new System.Drawing.Point(13, 37);
            this.fileSearchInput.Margin = new System.Windows.Forms.Padding(4);
            this.fileSearchInput.MaxLength = 260;
            this.fileSearchInput.Name = "fileSearchInput";
            this.fileSearchInput.PlaceholderText = "Drill for...";
            this.fileSearchInput.Size = new System.Drawing.Size(1582, 71);
            this.fileSearchInput.TabIndex = 5;
            this.fileSearchInput.TextChanged += new System.EventHandler(this.searchBox_TextChanged);
            // 
            // fileSearchResults
            // 
            this.fileSearchResults.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
            | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.fileSearchResults.BorderStyle = System.Windows.Forms.BorderStyle.None;
            this.fileSearchResults.Columns.AddRange(new System.Windows.Forms.ColumnHeader[] {
            this.columnHeader3,
            this.columnHeader4,
            this.columnHeader5,
            this.columnHeader6,
            this.columnHeader7});
            this.fileSearchResults.FullRowSelect = true;
            this.fileSearchResults.GridLines = true;
            this.fileSearchResults.HeaderStyle = System.Windows.Forms.ColumnHeaderStyle.Nonclickable;
            this.fileSearchResults.Location = new System.Drawing.Point(13, 116);
            this.fileSearchResults.Margin = new System.Windows.Forms.Padding(4);
            this.fileSearchResults.Name = "fileSearchResults";
            this.fileSearchResults.Size = new System.Drawing.Size(1582, 601);
            this.fileSearchResults.TabIndex = 4;
            this.fileSearchResults.UseCompatibleStateImageBehavior = false;
            this.fileSearchResults.RetrieveVirtualItem += new System.Windows.Forms.RetrieveVirtualItemEventHandler(this.SearchResults_RetrieveVirtualItem);
            this.fileSearchResults.SelectedIndexChanged += new System.EventHandler(this.fileSearchResults_SelectedIndexChanged_1);
            this.fileSearchResults.KeyDown += new System.Windows.Forms.KeyEventHandler(this.searchBox_KeyDown);
            this.fileSearchResults.MouseClick += new System.Windows.Forms.MouseEventHandler(this.searchResults_MouseClick);
            this.fileSearchResults.MouseDoubleClick += new System.Windows.Forms.MouseEventHandler(this.searchResults_MouseDoubleClick);
            // 
            // columnHeader3
            // 
            this.columnHeader3.Text = "Name";
            this.columnHeader3.Width = 355;
            // 
            // columnHeader4
            // 
            this.columnHeader4.Text = "Folder";
            this.columnHeader4.Width = 255;
            // 
            // columnHeader5
            // 
            this.columnHeader5.Text = "Size";
            this.columnHeader5.Width = 150;
            // 
            // columnHeader6
            // 
            this.columnHeader6.Text = "Date";
            this.columnHeader6.Width = 150;
            // 
            // columnHeader7
            // 
            this.columnHeader7.Text = "Filter";
            this.columnHeader7.Width = 150;
            // 
            // searchStringChangedTimer
            // 
            this.searchStringChangedTimer.Interval = 250;
            this.searchStringChangedTimer.Tick += new System.EventHandler(this.searchStringChangedTimer_Tick);
            // 
            // SearchWindow
            // 
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.None;
            this.BackColor = System.Drawing.Color.White;
            this.ClientSize = new System.Drawing.Size(1608, 730);
            this.Controls.Add(this.fileSearchInput);
            this.Controls.Add(this.fileSearchResults);
            this.Controls.Add(this.menuStrip);
            this.Icon = ((System.Drawing.Icon)(resources.GetObject("$this.Icon")));
            this.MainMenuStrip = this.menuStrip;
            this.Margin = new System.Windows.Forms.Padding(4);
            this.Name = "SearchWindow";
            this.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen;
            this.Text = "Drill";
            this.FormClosing += new System.Windows.Forms.FormClosingEventHandler(this.Window_Closing);
            this.Load += new System.EventHandler(this.SearchWindow_Load);
            this.contextMenuRightClickFile.ResumeLayout(false);
            this.menuStrip.ResumeLayout(false);
            this.menuStrip.PerformLayout();
            this.ResumeLayout(false);
            this.PerformLayout();

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
        private ToolStripMenuItem filtersToolStripMenuItem1;
        private ToolStripMenuItem drivesToolStripMenuItem1;
        private ToolStripMenuItem heuristicsToolStripMenuItem;
        private TextBox fileSearchInput;
        private ListView fileSearchResults;
        private ColumnHeader columnHeader3;
        private ColumnHeader columnHeader4;
        private ColumnHeader columnHeader5;
        private ColumnHeader columnHeader6;
        private ColumnHeader columnHeader7;
        private ToolStripMenuItem autoSortingToolStripMenuItem;
        private ToolStripMenuItem aboutToolStripMenuItem;
        private ToolStripMenuItem exportResultsTocsvToolStripMenuItem;
        private ToolStripMenuItem toolStripMenuItem1;
        private ToolStripMenuItem debugToolStripMenuItem;
        private System.Windows.Forms.Timer searchStringChangedTimer;
    }
}