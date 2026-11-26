extends SceneTree
const SHADER := """
shader_type canvas_item;
render_mode unshaded;
varying vec4 v_custom;
varying vec4 v_col;
void vertex(){
	v_custom = INSTANCE_CUSTOM;
	v_col = COLOR;
}
void fragment(){
	COLOR = vec4(v_custom.rgb, 1.0);
}
"""
func _initialize():
	_run.call_deferred()
func _run():
	var sv := SubViewport.new()
	sv.size = Vector2i(64,64)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	root.add_child(sv)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	var q := QuadMesh.new(); q.size = Vector2(64,64)
	mm.mesh = q
	mm.instance_count = 1
	var buf := PackedFloat32Array()
	buf.resize(16)
	buf[0]=1.0; buf[5]=1.0; buf[3]=0.0; buf[7]=0.0
	buf[8]=1.0; buf[9]=0.0; buf[10]=0.0; buf[11]=1.0
	buf[12]=0.25; buf[13]=0.5; buf[14]=0.75; buf[15]=1.0
	mm.buffer = buf
	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = mm
	mmi.position = Vector2(32,32)
	var sh := Shader.new(); sh.code = SHADER
	var mat := ShaderMaterial.new(); mat.shader = sh
	mmi.material = mat
	sv.add_child(mmi)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img = sv.get_texture().get_image()
	print("CENTER=", img.get_pixel(32,32), " CORNER=", img.get_pixel(2,2))
	quit(0)
