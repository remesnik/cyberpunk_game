class_name NodeCapabilityIconRenderer
extends RefCounted

## Immediate-mode vector glyphs. Coordinates are normalized around `center`, so
## the same silhouettes remain crisp at node-map and inspection-panel sizes.
static func draw_icon(canvas: CanvasItem, capability: int, center: Vector2, extent: float, color: Color, width: float) -> void:
	var s := extent
	match capability:
		NodeCapabilityType.Value.IO: _io(canvas, center, s, color, width)
		NodeCapabilityType.Value.FEED: _feed(canvas, center, s, color, width)
		NodeCapabilityType.Value.DATASTORE: _datastore(canvas, center, s, color, width)
		NodeCapabilityType.Value.DATABASE: _database(canvas, center, s, color, width)
		NodeCapabilityType.Value.MEATSPACE: _meatspace(canvas, center, s, color, width)
		NodeCapabilityType.Value.COMMUNICATIONS: _communications(canvas, center, s, color, width)
		NodeCapabilityType.Value.CONTROL_SYSTEM: _control(canvas, center, s, color, width)
		NodeCapabilityType.Value.SECURITY: _security(canvas, center, s, color, width)
		NodeCapabilityType.Value.ICE: _ice(canvas, center, s, color, width)
		NodeCapabilityType.Value.SOFTWARE: _software(canvas, center, s, color, width)
		NodeCapabilityType.Value.CREDENTIALS: _credentials(canvas, center, s, color, width)
		NodeCapabilityType.Value.ACTIVE_PROCESS: _process(canvas, center, s, color, width)
		NodeCapabilityType.Value.SYSTEM_ACCESS_NODE: _san(canvas, center, s, color, width)
		NodeCapabilityType.Value.OBJECTIVE: _objective(canvas, center, s, color, width)

static func _line(canvas: CanvasItem, center: Vector2, points: Array[Vector2], s: float, color: Color, width: float, closed := false) -> void:
	var transformed := PackedVector2Array()
	for point in points: transformed.append(center + point * s)
	if closed and not transformed.is_empty(): transformed.append(transformed[0])
	canvas.draw_polyline(transformed, color, width, true)

static func _io(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	_line(c, o, [Vector2(-.75,-.28),Vector2(.45,-.28),Vector2(.18,-.55),Vector2(.45,-.28),Vector2(.18,0)], s,col,w)
	_line(c, o, [Vector2(.75,.32),Vector2(-.45,.32),Vector2(-.18,.05),Vector2(-.45,.32),Vector2(-.18,.59)], s,col,w)

static func _feed(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	c.draw_rect(Rect2(o-Vector2(.72,.5)*s,Vector2(1.44,1.0)*s),col,false,w)
	c.draw_circle(o,.20*s,col,false,w,true)
	_line(c,o,[Vector2(-.3,.7),Vector2(.3,.7)],s,col,w)

static func _datastore(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	for y in [-.48, -.08, .32]: c.draw_rect(Rect2(o+Vector2(-.64,y)*s,Vector2(1.28,.27)*s),col,false,w)

static func _database(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	c.draw_arc(o+Vector2(0,-.45)*s,Vector2(.62,.22).x*s,0,TAU,20,col,w,true)
	_line(c,o,[Vector2(-.62,-.45),Vector2(-.62,.48),Vector2(.62,.48),Vector2(.62,-.45)],s,col,w)
	c.draw_arc(o+Vector2(0,.02)*s,.62*s,0,PI,12,col,w,true)
	c.draw_arc(o+Vector2(0,.48)*s,.62*s,0,PI,12,col,w,true)

static func _meatspace(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	c.draw_circle(o+Vector2(0,-.42)*s,.23*s,col,false,w,true)
	_line(c,o,[Vector2(0,-.18),Vector2(0,.25),Vector2(-.48,.55),Vector2(0,.25),Vector2(.48,.55)],s,col,w)
	_line(c,o,[Vector2(-.5,.02),Vector2(0,.12),Vector2(.5,.02)],s,col,w)

static func _communications(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	_line(c,o,[Vector2(-.75,.12),Vector2(-.48,.12),Vector2(-.32,-.48),Vector2(-.08,.55),Vector2(.12,-.25),Vector2(.3,.32),Vector2(.48,.12),Vector2(.75,.12)],s,col,w)

static func _control(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	c.draw_circle(o,.34*s,col,false,w,true)
	for i in 8:
		var a:=TAU*float(i)/8.0; c.draw_line(o+Vector2(cos(a),sin(a))*.43*s,o+Vector2(cos(a),sin(a))*.73*s,col,w,true)
	c.draw_circle(o,.1*s,col)

static func _security(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	_line(c,o,[Vector2(-.58,-.55),Vector2(.58,-.55),Vector2(.48,.2),Vector2(0,.7),Vector2(-.48,.2)],s,col,w,true)
	_line(c,o,[Vector2(-.18,-.05),Vector2(-.18,-.25),Vector2(.18,-.25),Vector2(.18,-.05)],s,col,w)
	c.draw_rect(Rect2(o+Vector2(-.27,-.05)*s,Vector2(.54,.38)*s),col,false,w)

static func _ice(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	_line(c,o,[Vector2(0,-.75),Vector2(.66,-.35),Vector2(.48,.48),Vector2(0,.72),Vector2(-.48,.48),Vector2(-.66,-.35)],s,col,w,true)
	_line(c,o,[Vector2(-.42,-.28),Vector2(.42,.32),Vector2(.42,-.28),Vector2(-.42,.32)],s,col,w)

static func _software(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	_line(c,o,[Vector2(-.62,-.5),Vector2(.35,-.5),Vector2(.62,-.23),Vector2(.62,.55),Vector2(-.62,.55)],s,col,w,true)
	_line(c,o,[Vector2(-.35,-.08),Vector2(-.55,.12),Vector2(-.35,.32),Vector2(.12,.32),Vector2(.35,.12),Vector2(.12,-.08)],s,col,w)

static func _credentials(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	c.draw_circle(o+Vector2(-.37,-.12)*s,.3*s,col,false,w,true)
	_line(c,o,[Vector2(-.08,.05),Vector2(.68,.05),Vector2(.68,.35),Vector2(.42,.35),Vector2(.42,.57),Vector2(.18,.57),Vector2(.18,.05)],s,col,w)

static func _process(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	_line(c,o,[Vector2(-.72,.28),Vector2(-.43,.28),Vector2(-.26,-.45),Vector2(.02,.62),Vector2(.28,-.2),Vector2(.43,.28),Vector2(.72,.28)],s,col,w)
	c.draw_circle(o+Vector2(-.72,.28)*s,.07*s,col); c.draw_circle(o+Vector2(.72,.28)*s,.07*s,col)

static func _san(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	c.draw_circle(o+Vector2(0,-.28)*s,.34*s,col,false,w,true)
	c.draw_circle(o+Vector2(0,-.28)*s,.09*s,col)
	_line(c,o,[Vector2(0,.06),Vector2(0,.38),Vector2(-.32,.62),Vector2(0,.38),Vector2(.32,.62)],s,col,w)

static func _objective(c: CanvasItem, o: Vector2, s: float, col: Color, w: float) -> void:
	for radius in [.68,.38]: c.draw_circle(o,radius*s,col,false,w,true)
	_line(c,o,[Vector2(-.82,0),Vector2(-.52,0),Vector2(.52,0),Vector2(.82,0)],s,col,w)
	_line(c,o,[Vector2(0,-.82),Vector2(0,-.52),Vector2(0,.52),Vector2(0,.82)],s,col,w)
