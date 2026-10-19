// If you use a file(...) object, instead of caching the asset it will be loaded from disk every time it's requested.
// This is useful for development, but not recommended for production.
// All builds use content-based asset names: non-TGS servers also need to
// invalidate browser caches when interfaces are added or changed.

#ifdef TGS
/datum/asset/simple/tgui
	keep_local_name = FALSE
	assets = list(
		"tgui.bundle.js" = "tgui/public/tgui.bundle.js",
		"tgui.bundle.css" = "tgui/public/tgui.bundle.css",
	)

/datum/asset/simple/tgui_panel
	keep_local_name = FALSE
	assets = list(
		"tgui-panel.bundle.js" = "tgui/public/tgui-panel.bundle.js",
		"tgui-panel.bundle.css" = "tgui/public/tgui-panel.bundle.css",
	)

#else
/datum/asset/simple/tgui
	keep_local_name = FALSE
	assets = list(
		"tgui.bundle.js" = file("tgui/public/tgui.bundle.js"),
		"tgui.bundle.css" = file("tgui/public/tgui.bundle.css"),
	)

/datum/asset/simple/tgui_panel
	keep_local_name = FALSE
	assets = list(
		"tgui-panel.bundle.js" = file("tgui/public/tgui-panel.bundle.js"),
		"tgui-panel.bundle.css" = file("tgui/public/tgui-panel.bundle.css"),
	)

#endif
