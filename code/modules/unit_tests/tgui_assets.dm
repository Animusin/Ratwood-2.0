/// Production builds without TGS also need cache-busting bundle URLs.
/datum/unit_test/tgui_asset_urls/Run()
	var/datum/asset_transport/transport = new
	allocated += transport
	for(var/asset_type in list(/datum/asset/simple/tgui, /datum/asset/simple/tgui_panel))
		var/datum/asset/simple/bundle = get_asset_datum(asset_type)
		for(var/asset_name in bundle.assets)
			var/datum/asset_cache_item/asset = bundle.assets[asset_name]
			TEST_ASSERT_EQUAL(transport.get_asset_url(asset_name, asset), "asset.[asset.hash][asset.ext]", "[asset_name] must use a content-based URL so updates cannot reuse an old bundle URL.")
