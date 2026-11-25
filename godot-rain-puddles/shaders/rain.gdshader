shader_type canvas_item;
render_mode unshaded, blend_mix;

// 雨丝：动态 ArrayMesh 的顶点色由 CPU 写入（尾透明→头亮），
// 一层 MeshInstance2D 一次绘制；没有粒子节点。

void fragment() {
	COLOR = COLOR;
}
