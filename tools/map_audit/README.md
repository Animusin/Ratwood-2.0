# TGM map audit

`render_tgm.py` creates a compact PNG overview for every z-level of a
TGM-formatted `.dmm` map and a CSV list of items placed on closed turfs,
doors, windows, bars, stairs, or railings.

```powershell
python tools/map_audit/render_tgm.py `
  _maps/map_files/roguetown/otherz/roguehamlet.dmm `
  tmp/roguehamlet-audit
```

The overview uses dark gray for closed turfs, blue for water, green for
grass, brown for dirt and wood, cyan for doors/windows, magenta outlines for
tables, yellow dots for items, green squares for job starts, and solid red for
placement issues. `spawn_points.csv` lists every role landmark and any solid
object sharing its tile.

`render_rooms.py` creates a separate enlarged image for every indoor room.
It marks furniture with letter glyphs and draws job starts as green rings;
suspicious starts that share a tile with a solid structure are red.

```powershell
python tools/map_audit/render_rooms.py `
  _maps/map_files/roguetown/otherz/roguehamlet.dmm `
  tmp/roguehamlet-rooms
```
