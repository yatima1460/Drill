namespace WinForms.Menus
{
    partial class AboutForm
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
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
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            versionNumber = new Label();
            websiteLink = new LinkLabel();
            versionText = new Label();
            emailLink = new LinkLabel();
            tableLayoutPanel1 = new TableLayoutPanel();
            logo = new PictureBox();
            tableLayoutPanel1.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)logo).BeginInit();
            SuspendLayout();
            // 
            // versionNumber
            // 
            versionNumber.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            versionNumber.AutoSize = true;
            versionNumber.Location = new Point(2, 173);
            versionNumber.Margin = new Padding(2, 0, 2, 0);
            versionNumber.Name = "versionNumber";
            versionNumber.Size = new Size(411, 15);
            versionNumber.TabIndex = 2;
            versionNumber.Text = "ERROR: CAN'T GET VERSION NUMBER";
            versionNumber.TextAlign = ContentAlignment.MiddleCenter;
            // 
            // websiteLink
            // 
            websiteLink.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            websiteLink.AutoSize = true;
            websiteLink.Location = new Point(2, 188);
            websiteLink.Margin = new Padding(2, 0, 2, 0);
            websiteLink.Name = "websiteLink";
            websiteLink.Size = new Size(411, 15);
            websiteLink.TabIndex = 4;
            websiteLink.TabStop = true;
            websiteLink.Text = "https://drill.software";
            websiteLink.TextAlign = ContentAlignment.MiddleCenter;
            websiteLink.LinkClicked += websiteLink_LinkClicked;
            // 
            // versionText
            // 
            versionText.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            versionText.AutoSize = true;
            versionText.Location = new Point(2, 158);
            versionText.Margin = new Padding(2, 0, 2, 0);
            versionText.Name = "versionText";
            versionText.Size = new Size(411, 15);
            versionText.TabIndex = 1;
            versionText.Text = "Version: ";
            versionText.TextAlign = ContentAlignment.MiddleCenter;
            // 
            // emailLink
            // 
            emailLink.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            emailLink.AutoSize = true;
            emailLink.Location = new Point(2, 203);
            emailLink.Margin = new Padding(2, 0, 2, 0);
            emailLink.Name = "emailLink";
            emailLink.Size = new Size(411, 15);
            emailLink.TabIndex = 5;
            emailLink.TabStop = true;
            emailLink.Text = "contact@drill.software";
            emailLink.TextAlign = ContentAlignment.MiddleCenter;
            emailLink.LinkClicked += emailLink_LinkClicked;
            // 
            // tableLayoutPanel1
            // 
            tableLayoutPanel1.ColumnCount = 1;
            tableLayoutPanel1.ColumnStyles.Add(new ColumnStyle());
            tableLayoutPanel1.Controls.Add(logo, 0, 0);
            tableLayoutPanel1.Controls.Add(emailLink, 0, 4);
            tableLayoutPanel1.Controls.Add(versionText, 0, 1);
            tableLayoutPanel1.Controls.Add(websiteLink, 0, 3);
            tableLayoutPanel1.Controls.Add(versionNumber, 0, 2);
            tableLayoutPanel1.Dock = DockStyle.Fill;
            tableLayoutPanel1.Location = new Point(0, 0);
            tableLayoutPanel1.Margin = new Padding(2);
            tableLayoutPanel1.Name = "tableLayoutPanel1";
            tableLayoutPanel1.RowCount = 6;
            tableLayoutPanel1.RowStyles.Add(new RowStyle());
            tableLayoutPanel1.RowStyles.Add(new RowStyle());
            tableLayoutPanel1.RowStyles.Add(new RowStyle());
            tableLayoutPanel1.RowStyles.Add(new RowStyle());
            tableLayoutPanel1.RowStyles.Add(new RowStyle());
            tableLayoutPanel1.RowStyles.Add(new RowStyle(SizeType.Absolute, 20F));
            tableLayoutPanel1.Size = new Size(415, 231);
            tableLayoutPanel1.TabIndex = 6;
            // 
            // logo
            // 
            logo.Dock = DockStyle.Fill;
            logo.Image = Properties.Resources.drill;
            logo.Location = new Point(2, 2);
            logo.Margin = new Padding(2);
            logo.Name = "logo";
            logo.Size = new Size(411, 154);
            logo.SizeMode = PictureBoxSizeMode.CenterImage;
            logo.TabIndex = 0;
            logo.TabStop = false;
            // 
            // AboutForm
            // 
            AutoScaleDimensions = new SizeF(7F, 15F);
            AutoScaleMode = AutoScaleMode.Font;
            BackColor = Color.WhiteSmoke;
            ClientSize = new Size(415, 231);
            Controls.Add(tableLayoutPanel1);
            DoubleBuffered = true;
            FormBorderStyle = FormBorderStyle.FixedSingle;
            Margin = new Padding(2);
            MaximizeBox = false;
            Name = "AboutForm";
            ShowIcon = false;
            StartPosition = FormStartPosition.CenterParent;
            Text = "❓ About";
            Load += AboutForm_Load;
            tableLayoutPanel1.ResumeLayout(false);
            tableLayoutPanel1.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)logo).EndInit();
            ResumeLayout(false);
        }

        #endregion

        private Label versionNumber;
        private LinkLabel websiteLink;
        private Label versionText;
        private LinkLabel emailLink;
        private TableLayoutPanel tableLayoutPanel1;
        private PictureBox logo;
    }
}