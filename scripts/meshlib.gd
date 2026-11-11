extends RefCounted
## 절차적 로우폴리 모델을 조립하는 헬퍼. 메시와 머티리얼을 캐시해서 같은 모양·색은 공유한다.

static var _mats := {}
static var _meshes := {}


static func col(c) -> Color:
	return c if c is Color else Color(str(c))


## 기본 머티리얼. emis>0 이면 발광, alpha<1 이면 반투명, unshaded 면 조명 무시
static func mat(c, emis := 0.0, alpha := 1.0, unshaded := false, rough := 0.9) -> StandardMaterial3D:
	var cc := col(c)
	var key := "%s|%.2f|%.2f|%s|%.2f" % [cc.to_html(), emis, alpha, unshaded, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(cc.r, cc.g, cc.b, alpha)
	m.roughness = rough
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = cc
		m.emission_energy_multiplier = emis
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


## 가산 합성 발광 (폭발 불덩이·빛기둥·예광탄). 인스턴스마다 색을 바꿔야 하므로 캐시하지 않는다
static func add_mat(c, a := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var cc := col(c)
	m.albedo_color = Color(cc.r, cc.g, cc.b, a)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## 정점 색을 쓰는 반투명 무조명 머티리얼 (바닥 표시·파티클)
static func vcol_mat(additive := false, no_depth := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if no_depth:
		m.no_depth_test = true
	return m


static func _mesh(key: String, make: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = make.call()
	return _meshes[key]


static func box_mesh(s: Vector3) -> Mesh:
	return _mesh("b%.3f,%.3f,%.3f" % [s.x, s.y, s.z], func():
		var m := BoxMesh.new()
		m.size = s
		return m)


static func cyl_mesh(rt: float, rb: float, h: float, seg := 10) -> Mesh:
	return _mesh("c%.3f,%.3f,%.3f,%d" % [rt, rb, h, seg], func():
		var m := CylinderMesh.new()
		m.top_radius = rt
		m.bottom_radius = rb
		m.height = h
		m.radial_segments = seg
		m.rings = 1
		return m)


static func sph_mesh(r: float, seg := 12, rings := 6) -> Mesh:
	return _mesh("s%.3f,%d,%d" % [r, seg, rings], func():
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = seg
		m.rings = rings
		return m)


static func cap_mesh(r: float, h: float) -> Mesh:
	return _mesh("p%.3f,%.3f" % [r, h], func():
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0)
		m.radial_segments = 8
		m.rings = 2
		return m)


static func _inst(parent: Node3D, mesh: Mesh, c, pos: Vector3, rot: Vector3, scl := Vector3.ONE, m: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m if m else mat(c)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, s: Vector3, c, pos := Vector3.ZERO, rot := Vector3.ZERO, m: Material = null) -> MeshInstance3D:
	return _inst(parent, box_mesh(s), c, pos, rot, Vector3.ONE, m)


static func cyl(parent: Node3D, rt: float, rb: float, h: float, c, pos := Vector3.ZERO, rot := Vector3.ZERO, seg := 10, m: Material = null) -> MeshInstance3D:
	return _inst(parent, cyl_mesh(rt, rb, h, seg), c, pos, rot, Vector3.ONE, m)


static func sph(parent: Node3D, r: float, c, pos := Vector3.ZERO, scl := Vector3.ONE, m: Material = null, seg := 12) -> MeshInstance3D:
	return _inst(parent, sph_mesh(r, seg, maxi(4, seg / 2)), c, pos, Vector3.ZERO, scl, m)


static func cap(parent: Node3D, r: float, h: float, c, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	return _inst(parent, cap_mesh(r, h), c, pos, rot)


## a에서 b까지 이어지는 막대 (철탑 다리·팔·안테나)
static func beam(parent: Node3D, a: Vector3, b: Vector3, t: float, c, m: Material = null) -> MeshInstance3D:
	var len := a.distance_to(b)
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(Vector3(t, t, 1.0))
	mi.material_override = m if m else mat(c)
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	if len > 0.0001:
		var up := Vector3.UP if absf((b - a).normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		mi.basis = Basis.looking_at(b - a, up)
	mi.scale = Vector3(1, 1, len)
	return mi


static var _outline_mat: StandardMaterial3D
static var _outlined := {}


## 뒤집은 껍질 방식 외곽선. 캐릭터가 바닥·건물과 섞이지 않고 또렷하게 떠 보인다
static func outline(root: Node, width := 0.011) -> void:
	if _outline_mat == null:
		_outline_mat = StandardMaterial3D.new()
		_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_mat.albedo_color = Color(0.035, 0.04, 0.06)
		_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline_mat.grow = true
		_outline_mat.grow_amount = width
	for c in root.get_children():
		if c is MeshInstance3D and c.material_override is StandardMaterial3D:
			var m: StandardMaterial3D = c.material_override
			if m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and m.next_pass == null:
				var id := m.get_instance_id()
				if not _outlined.has(id):
					var d: StandardMaterial3D = m.duplicate()
					d.next_pass = _outline_mat
					_outlined[id] = d
				c.material_override = _outlined[id]
		outline(c, width)


## 그림자를 드리우지 않게 (바닥 장식·투명 효과)
static func no_shadow(mi: GeometryInstance3D) -> GeometryInstance3D:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
