namespace WinForms
{
    partial class HeuristicsForm
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
            this.heuristicsList = new System.Windows.Forms.ListView();
            this.columnHeader16 = new System.Windows.Forms.ColumnHeader();
            this.columnHeader1 = new System.Windows.Forms.ColumnHeader();
            this.columnHeader2 = new System.Windows.Forms.ColumnHeader();
            this.SuspendLayout();
            // 
            // heuristicsList
            // 
            this.heuristicsList.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle;
            this.heuristicsList.CheckBoxes = true;
            this.heuristicsList.Columns.AddRange(new System.Windows.Forms.ColumnHeader[] {
            this.columnHeader16,
            this.columnHeader1,
            this.columnHeader2});
            this.heuristicsList.Dock = System.Windows.Forms.DockStyle.Fill;
            this.heuristicsList.FullRowSelect = true;
            this.heuristicsList.GridLines = true;
            this.heuristicsList.Location = new System.Drawing.Point(0, 0);
            this.heuristicsList.Name = "heuristicsList";
            this.heuristicsList.Size = new System.Drawing.Size(800, 450);
            this.heuristicsList.TabIndex = 1;
            this.heuristicsList.UseCompatibleStateImageBehavior = false;
            this.heuristicsList.View = System.Windows.Forms.View.Details;
            this.heuristicsList.ItemChecked += new System.Windows.Forms.ItemCheckedEventHandler(this.heuristicsList_ItemChecked);
            // 
            // columnHeader16
            // 
            this.columnHeader16.Text = "";
            // 
            // columnHeader1
            // 
            this.columnHeader1.Text = "Name";
            // 
            // columnHeader2
            // 
            this.columnHeader2.Text = "Description";
            // 
            // HeuristicsForm
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(10F, 25F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(800, 450);
            this.Controls.Add(this.heuristicsList);
            this.DoubleBuffered = true;
            this.Name = "HeuristicsForm";
            this.ShowIcon = false;
            this.StartPosition = System.Windows.Forms.FormStartPosition.CenterParent;
            this.Text = "HeuristicsForm";
            this.Load += new System.EventHandler(this.HeuristicsForm_Load);
            this.ResumeLayout(false);

        }

        #endregion

        private ListView heuristicsList;
        private ColumnHeader columnHeader16;
        private ColumnHeader columnHeader1;
        private ColumnHeader columnHeader2;
    }
}