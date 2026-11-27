/* Native owner-data list. Only the displayed cells cross the model boundary. */
static int selected_index(const DrillWindow *ui) {
    return ListView_GetNextItem(ui->table, -1, LVNI_SELECTED);
}

static uint64_t id_at(const DrillWindow *ui, int index) {
    return index >= 0 ? drill_row_id(ui->model, (size_t)index) : 0;
}

static void show_selection(DrillWindow *ui, int index) {
    ListView_SetItemState(ui->table, -1, 0, LVIS_SELECTED | LVIS_FOCUSED);
    if (index >= 0) {
        ListView_SetItemState(ui->table, index, LVIS_SELECTED | LVIS_FOCUSED,
                             LVIS_SELECTED | LVIS_FOCUSED);
        ListView_EnsureVisible(ui->table, index, FALSE);
    }
}

static void choose_index(DrillWindow *ui, int index) {
    drill_select(ui->model, id_at(ui, index));
    ui->syncing = true;
    show_selection(ui, index);
    ui->syncing = false;
}

static void display_item(DrillWindow *ui, LVITEMW *item) {
    uint64_t id = id_at(ui, item->iItem);
    if ((item->mask & LVIF_TEXT) && item->pszText && item->cchTextMax > 0) {
        item->pszText[0] = L'\0';
        DrillRow row;
        if ((unsigned)item->iSubItem < 4 && drill_row(ui->model, id, &row)) {
            const char *cell = row.cells[item->iSubItem];
            if (!MultiByteToWideChar(CP_UTF8, 0, cell, -1, item->pszText, item->cchTextMax)) {
                WCHAR *full = win_copy_cell(cell);
                if (full) {
                    lstrcpynW(item->pszText, full, item->cchTextMax);
                    size_t length = wcslen(item->pszText);
                    if (length && IS_HIGH_SURROGATE(item->pszText[length - 1])) {
                        item->pszText[length - 1] = 0;
                    }
                    free(full);
                }
            }
        }
    }
    if (item->mask & LVIF_IMAGE) {
        item->iImage = (id && ui->actions) ? drill_win_icon(ui->actions, id) : I_IMAGENONE;
    }
}

static void sort_table(DrillWindow *ui, int column) {
    if ((unsigned)column >= 4) return;
    drill_sort(ui->model, (unsigned)column);
    ui->ascending = column != ui->sort_column || !ui->ascending;
    ui->sort_column = column;
    HWND header = ListView_GetHeader(ui->table);
    for (int i = 0; i < 4; ++i) {
        HDITEMW item = {0};
        item.mask = HDI_FORMAT;
        if (Header_GetItem(header, i, &item)) {
            item.fmt &= ~(HDF_SORTUP | HDF_SORTDOWN);
            if (i == column) item.fmt |= ui->ascending ? HDF_SORTUP : HDF_SORTDOWN;
            Header_SetItem(header, i, &item);
        }
    }
    update_window(ui);
}

static LRESULT table_notify(DrillWindow *ui, NMHDR *note) {
    switch (note->code) {
    case LVN_GETDISPINFOW:
        display_item(ui, &((NMLVDISPINFOW *)note)->item);
        break;
    case LVN_ITEMCHANGED:
    case LVN_ODSTATECHANGED:
        if (!ui->syncing) drill_select(ui->model, id_at(ui, selected_index(ui)));
        break;
    case LVN_COLUMNCLICK:
        sort_table(ui, ((NMLISTVIEW *)note)->iSubItem);
        break;
    case NM_DBLCLK: {
        uint64_t id = id_at(ui, ((NMITEMACTIVATE *)note)->iItem);
        if (id && id == ui->press_id) drill_win_open(ui->actions, id);
        break;
    }
    case NM_CUSTOMDRAW: {
        NMLVCUSTOMDRAW *draw = (NMLVCUSTOMDRAW *)note;
        switch (draw->nmcd.dwDrawStage) {
        case CDDS_PREPAINT: return CDRF_NOTIFYITEMDRAW;
        case CDDS_ITEMPREPAINT:
            // Leave selected/focused rendering to the native control and its theme.
            draw->clrText = ui->text_color;
            draw->clrTextBk = (draw->nmcd.dwItemSpec & 1) ? ui->stripe_color : ui->list_color;
            return CDRF_DODEFAULT;
        }
        break;
    }
    }
    return 0;
}

static void context_at(DrillWindow *ui, LPARAM coords) {
    POINT pos = {GET_X_LPARAM(coords), GET_Y_LPARAM(coords)};
    int index;
    if (pos.x == -1 && pos.y == -1) {
        index = selected_index(ui);
        RECT label;
        if (index < 0 || !ListView_GetItemRect(ui->table, index, &label, LVIR_LABEL)) return;
        pos.x = label.left;
        pos.y = label.bottom;
        ClientToScreen(ui->table, &pos);
    } else {
        LVHITTESTINFO hit = {0};
        hit.pt = pos;
        ScreenToClient(ui->table, &hit.pt);
        index = ListView_SubItemHitTest(ui->table, &hit);
        if (index < 0) return;
    }
    uint64_t id = id_at(ui, index);
    if (id) {
        choose_index(ui, index);
        drill_win_context(ui->actions, id, pos, ui->apps);
    }
}

static bool make_columns(DrillWindow *ui) {
    static WCHAR *const titles[] = {L"Name", L"Path", L"Size", L"Date"};
    static const int widths[] = {208, 223, 65, 166};
    ListView_SetUnicodeFormat(ui->table, TRUE);
    ListView_SetExtendedListViewStyle(ui->table, LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER |
                                                LVS_EX_LABELTIP);
    for (int i = 0; i < 4; ++i) {
        LVCOLUMNW col = {0};
        col.mask = LVCF_FMT | LVCF_TEXT | LVCF_WIDTH | LVCF_SUBITEM;
        col.pszText = titles[i];
        col.cx = px(ui, widths[i]);
        col.fmt = i == 2 ? LVCFMT_RIGHT : LVCFMT_LEFT;
        col.iSubItem = i;
        if (ListView_InsertColumn(ui->table, i, &col) < 0) return false;
    }
    return true;
}
