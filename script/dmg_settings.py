"""Finder layout generated without Finder automation or accessibility access."""
from pathlib import Path

app = Path(defines["app"])
files = [str(app), (defines["documentation"], ".Documentation")]
symlinks = {"Applications": "/Applications"}
icon = str(app / "Contents/Resources/AppIcon.icns")
background = defines["background"]
format = "UDZO"
filesystem = "HFS+"
volume_name = defines["volume_name"]
window_rect = ((180, 180), (720, 492))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False
arrange_by = None
icon_size = 104
text_size = 14
label_pos = "bottom"
icon_locations = {app.name: (180, 238), "Applications": (540, 238)}
