import re
from html import escape
from typing import Callable

from PyQt6.QtGui import QTextDocument
from PyQt6.QtWidgets import QApplication, QStyle, QStyledItemDelegate, QStyleOptionViewItem


class FilenameMatchBoldDelegate(QStyledItemDelegate):
    def __init__(self, query_getter: Callable[[], str], parent=None):
        super().__init__(parent)
        self._query_getter = query_getter

    def _to_highlighted_html(self, text: str, query: str) -> str:
        if not query:
            return escape(text)
        pattern = re.compile(re.escape(query), flags=re.IGNORECASE)
        parts = []
        start = 0
        for match in pattern.finditer(text):
            parts.append(escape(text[start:match.start()]))
            parts.append(f"<b>{escape(match.group(0))}</b>")
            start = match.end()
        parts.append(escape(text[start:]))
        return "".join(parts)

    def paint(self, painter, option, index):
        if painter is None:
            return
        if index.column() != 0:
            super().paint(painter, option, index)
            return

        query = self._query_getter().strip()
        if not query:
            super().paint(painter, option, index)
            return

        item_option = QStyleOptionViewItem(option)
        self.initStyleOption(item_option, index)
        plain_text = item_option.text or ""
        item_option.text = ""

        widget = item_option.widget
        style = widget.style() if widget is not None else QApplication.style()
        if style is None:
            super().paint(painter, option, index)
            return
        style.drawControl(QStyle.ControlElement.CE_ItemViewItem, item_option, painter, widget)

        text_rect = style.subElementRect(QStyle.SubElement.SE_ItemViewItemText, item_option, widget)
        if not text_rect.isValid():
            return

        color_role = (
            item_option.palette.ColorRole.HighlightedText
            if item_option.state & QStyle.StateFlag.State_Selected
            else item_option.palette.ColorRole.Text
        )
        text_color = item_option.palette.color(color_role).name()
        html_text = self._to_highlighted_html(plain_text, query)

        doc = QTextDocument()
        doc.setDefaultFont(item_option.font)
        doc.setDocumentMargin(0)
        doc.setHtml(f'<span style="color:{text_color};">{html_text}</span>')
        doc.setTextWidth(text_rect.width())

        painter.save()
        painter.translate(text_rect.topLeft())
        y_offset = max(0.0, (text_rect.height() - doc.size().height()) / 2.0)
        painter.translate(0, y_offset)
        doc.drawContents(painter)
        painter.restore()
