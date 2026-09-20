/datum/buildmode_mode/catalog
	key = "catalog"

/datum/buildmode_mode/catalog/get_button_iconstate()
	return "buildmode_advanced"

/datum/buildmode_mode/catalog/enter_mode(datum/buildmode/BM)
	BM.refresh_spawn_preview()

/datum/buildmode_mode/catalog/exit_mode(datum/buildmode/BM)
	BM.clear_spawn_preview()

/datum/buildmode_mode/catalog/change_settings(client/c)
	BM.ui_interact(c.mob)

/datum/buildmode_mode/catalog/show_help(client/c)
	to_chat(c, span_notice("F7: каталог спавна. Выберите объект по спрайту или найдите по имени/пути. ЛКМ на карте — разместить, ПКМ — снять выбор, без выбора — удалить объект, Alt + ЛКМ — взять тип объекта с карты. Кнопка каталога в верхней панели снова открывает окно. F7 — выйти из строительства."))

/datum/buildmode_mode/catalog/handle_click(client/c, params, atom/object)
	if(!BM.can_build(c) || QDELETED(object) || istype(object, /atom/movable/screen))
		return
	var/list/pa = params2list(params)
	if(pa["right"])
		if(BM.selected_path)
			BM.clear_catalog_selection()
			return
		BM.delete_catalog_object(c, object)
	else if(pa["left"] && pa["alt"])
		if(BM.select_catalog_path(object.type))
			BM.catalog_status = "Выбран тип: [initial(object.name)]"
		else
			BM.catalog_status = "Этот тип недоступен в каталоге."
		SStgui.update_uis(BM)
	else if(pa["left"])
		if(BM.selected_path)
			BM.catalog_status = null
			BM.place_catalog(c, get_turf(object))
