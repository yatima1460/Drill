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
            this.versionNumber = new System.Windows.Forms.Label();
            this.websiteLink = new System.Windows.Forms.LinkLabel();
            this.versionText = new System.Windows.Forms.Label();
            this.emailLink = new System.Windows.Forms.LinkLabel();
            this.tableLayoutPanel1 = new System.Windows.Forms.TableLayoutPanel();
            this.logo = new System.Windows.Forms.PictureBox();
            this.tableLayoutPanel1.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.logo)).BeginInit();
            this.SuspendLayout();
            // 
            // versionNumber
            // 
            this.versionNumber.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
            | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.versionNumber.AutoSize = true;
            this.versionNumber.Location = new System.Drawing.Point(3, 287);
            this.versionNumber.Name = "versionNumber";
            this.versionNumber.Size = new System.Drawing.Size(587, 25);
            this.versionNumber.TabIndex = 2;
            this.versionNumber.Text = "ERROR: CAN\'T GET VERSION NUMBER";
            this.versionNumber.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // websiteLink
            // 
            this.websiteLink.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
            | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.websiteLink.AutoSize = true;
            this.websiteLink.Location = new System.Drawing.Point(3, 312);
            this.websiteLink.Name = "websiteLink";
            this.websiteLink.Size = new System.Drawing.Size(587, 25);
            this.websiteLink.TabIndex = 4;
            this.websiteLink.TabStop = true;
            this.websiteLink.Text = "https://drill.software";
            this.websiteLink.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            this.websiteLink.LinkClicked += new System.Windows.Forms.LinkLabelLinkClickedEventHandler(this.websiteLink_LinkClicked);
            // 
            // versionText
            // 
            this.versionText.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
            | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.versionText.AutoSize = true;
            this.versionText.Location = new System.Drawing.Point(3, 262);
            this.versionText.Name = "versionText";
            this.versionText.Size = new System.Drawing.Size(587, 25);
            this.versionText.TabIndex = 1;
            this.versionText.Text = "Version: ";
            this.versionText.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // emailLink
            // 
            this.emailLink.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
            | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.emailLink.AutoSize = true;
            this.emailLink.Location = new System.Drawing.Point(3, 337);
            this.emailLink.Name = "emailLink";
            this.emailLink.Size = new System.Drawing.Size(587, 48);
            this.emailLink.TabIndex = 5;
            this.emailLink.TabStop = true;
            this.emailLink.Text = "contact@drill.software";
            this.emailLink.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            this.emailLink.LinkClicked += new System.Windows.Forms.LinkLabelLinkClickedEventHandler(this.emailLink_LinkClicked);
            // 
            // tableLayoutPanel1
            // 
            this.tableLayoutPanel1.ColumnCount = 1;
            this.tableLayoutPanel1.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle());
            this.tableLayoutPanel1.Controls.Add(this.logo, 0, 0);
            this.tableLayoutPanel1.Controls.Add(this.emailLink, 0, 4);
            this.tableLayoutPanel1.Controls.Add(this.versionText, 0, 1);
            this.tableLayoutPanel1.Controls.Add(this.websiteLink, 0, 3);
            this.tableLayoutPanel1.Controls.Add(this.versionNumber, 0, 2);
            this.tableLayoutPanel1.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tableLayoutPanel1.Location = new System.Drawing.Point(0, 0);
            this.tableLayoutPanel1.Name = "tableLayoutPanel1";
            this.tableLayoutPanel1.RowCount = 5;
            this.tableLayoutPanel1.RowStyles.Add(new System.Windows.Forms.RowStyle());
            this.tableLayoutPanel1.RowStyles.Add(new System.Windows.Forms.RowStyle());
            this.tableLayoutPanel1.RowStyles.Add(new System.Windows.Forms.RowStyle());
            this.tableLayoutPanel1.RowStyles.Add(new System.Windows.Forms.RowStyle());
            this.tableLayoutPanel1.RowStyles.Add(new System.Windows.Forms.RowStyle());
            this.tableLayoutPanel1.Size = new System.Drawing.Size(593, 385);
            this.tableLayoutPanel1.TabIndex = 6;
            // 
            // logo
            // 
            this.logo.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
            | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.logo.Image = global::WinForms.Properties.Resources.drill;
            this.logo.Location = new System.Drawing.Point(3, 3);
            this.logo.Name = "logo";
            this.logo.Size = new System.Drawing.Size(587, 256);
            this.logo.SizeMode = System.Windows.Forms.PictureBoxSizeMode.CenterImage;
            this.logo.TabIndex = 0;
            this.logo.TabStop = false;
            // 
            // AboutForm
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(10F, 25F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.BackColor = System.Drawing.Color.WhiteSmoke;
            this.ClientSize = new System.Drawing.Size(593, 385);
            this.Controls.Add(this.tableLayoutPanel1);
            this.DoubleBuffered = true;
            this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedSingle;
            this.MaximizeBox = false;
            this.Name = "AboutForm";
            this.ShowIcon = false;
            this.StartPosition = System.Windows.Forms.FormStartPosition.CenterParent;
            this.Text = "❓ About";
            this.Load += new System.EventHandler(this.AboutForm_Load);
            this.tableLayoutPanel1.ResumeLayout(false);
            this.tableLayoutPanel1.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.logo)).EndInit();
            this.ResumeLayout(false);

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