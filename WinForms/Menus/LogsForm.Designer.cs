namespace WinForms
{
    partial class LogsForm
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
            this.logsList = new System.Windows.Forms.ListView();
            this.columnHeader13 = new System.Windows.Forms.ColumnHeader();
            this.columnHeader14 = new System.Windows.Forms.ColumnHeader();
            this.columnHeader15 = new System.Windows.Forms.ColumnHeader();
            this.SuspendLayout();
            // 
            // logsList
            // 
            this.logsList.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle;
            this.logsList.CheckBoxes = true;
            this.logsList.Columns.AddRange(new System.Windows.Forms.ColumnHeader[] {
            this.columnHeader13,
            this.columnHeader14,
            this.columnHeader15});
            this.logsList.Dock = System.Windows.Forms.DockStyle.Fill;
            this.logsList.GridLines = true;
            this.logsList.Location = new System.Drawing.Point(0, 0);
            this.logsList.Name = "logsList";
            this.logsList.Size = new System.Drawing.Size(800, 450);
            this.logsList.TabIndex = 3;
            this.logsList.UseCompatibleStateImageBehavior = false;
            this.logsList.View = System.Windows.Forms.View.Details;
            // 
            // columnHeader13
            // 
            this.columnHeader13.Text = "Date";
            // 
            // columnHeader14
            // 
            this.columnHeader14.Text = "Level";
            // 
            // columnHeader15
            // 
            this.columnHeader15.Text = "Description";
            // 
            // LogsForm
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(10F, 25F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(800, 450);
            this.Controls.Add(this.logsList);
            this.DoubleBuffered = true;
            this.Name = "LogsForm";
            this.Text = "LogsForm";
            this.ResumeLayout(false);

        }

        #endregion

        private ListView logsList;
        private ColumnHeader columnHeader13;
        private ColumnHeader columnHeader14;
        private ColumnHeader columnHeader15;
    }
}