@tool
extends EditorPlugin

var definitions = "definitions"

var filesystem = get_editor_interface().get_resource_filesystem()

var popupFilesystem : PopupMenu
var popupWindows
var popupAssign : Window
var popupCreate : Window
var popupMessage : Window

var overrideAssigned : CheckBox
var texturingType : OptionButton
var materialTypes : OptionButton
var materialFolder : LineEdit

var textureDefinitionsConfig : ConfigFile
var textureDefinitions : Dictionary
var suffixStartSymbol = "_"
var allShaders : Array[Shader]

var assignMaterialsId = 91
var createMaterialsId = 92

var message

func _enter_tree():
	popupWindows = preload("res://addons/AutoMat/Resources/AutoMat popups.tscn").instantiate()
	
	get_editor_interface().get_window().call_deferred("add_child", popupWindows)
	
	popupAssign = popupWindows.get_node("Assign")
	popupCreate = popupWindows.get_node("Create")
	popupMessage = popupWindows.get_node("Message")
	
	popupAssign.hide()
	popupCreate.hide()
	popupMessage.hide()
	
	popupAssign.connect("close_requested", popupAssign.hide.bind())
	popupCreate.connect("close_requested", popupCreate.hide.bind())
	popupMessage.connect("close_requested", popupMessage.hide.bind())
	
	overrideAssigned = popupAssign.get_node("Content/Override")
	
	var autoAssignButton : Button = popupAssign.get_node("Content/Auto Assign")
	
	autoAssignButton.connect("pressed", AutoMat_Assign.bind())
	
	var createMaterialsButton : Button = popupCreate.get_node("Content/Create materials")
	createMaterialsButton.connect("pressed", CreateMaterialsFromSelection.bind())
	
	var editDefinitionsButton : Button = popupCreate.get_node("Content/Edit definitions")
	editDefinitionsButton.connect("pressed", EditDefinitions.bind())
	
	LoadTextureDefinitions()
	
	materialTypes = popupCreate.get_node("Content/Material types")
	texturingType = popupCreate.get_node("Content/Texturing type")
	materialFolder = popupCreate.get_node("Content/Material folder")
	
	FindAllShaders()
	for shader in allShaders:
		materialTypes.add_item(shader.resource_path)
	
	FindFilesystemPopup()

func _exit_tree():
	popupWindows.queue_free()

func LoadTextureDefinitions():
	textureDefinitionsConfig = ConfigFile.new()
	textureDefinitionsConfig.load("res://addons/AutoMat/texture definitions.cfg")
	textureDefinitions = textureDefinitionsConfig.get_value(definitions, "suffix-param")
	suffixStartSymbol = textureDefinitionsConfig.get_value(definitions, "suffix_start_symbol")

##
##
##Auto assign materials
##
##

func GetSelectedMeshes() -> String:
	var meshes = ""
	var selected = get_selected_paths(get_filesystem_tree(self))
	
	for path in selected:
		var file = load(path)
		if file is PackedScene:
			meshes += path + "\n"
	
	return meshes

func AutoMat_Assign():
	var selected = get_selected_paths(get_filesystem_tree(self))
	
	for path in selected:
		var file = load(path)
		if file is PackedScene:
			AutoAssingMaterials(load(path))

func FindMaterialInProject(matName : String) -> String:
	var possibleNames : Array[String]
	
	#Possible name variants
	possibleNames.append(matName)
	possibleNames.append(matName.replace(" ", "_"))
	possibleNames.append(matName.replace("_", " "))
	possibleNames.append(matName.replace(" ", ""))
	possibleNames.append(matName.replace("_", ""))
	
	var folders = GetAllFolders()
	
	for folder in folders:
		for name in possibleNames:
			#Find with extra steps to keep cases matching
			var correctName = name
			var files = DirAccess.get_files_at(folder)
			for file in files:
				if file.to_lower() == (name + ".tres").to_lower():
					correctName = file
			
			var path = folder + correctName
			
			if FileAccess.file_exists(path):
				var m = load(path)
				if m != null:
					if m.is_class("Material"):
						print("[AutoMat] Material found: " + matName + ", " + m.resource_path)
						return m.resource_path
	
	print("[AutoMat] Material not found: " + matName)
	return ""

func GetAllFolders(path : String = "res://") -> Array[String]:
	var folders : Array[String]
	for dir in DirAccess.get_directories_at(path):
		if dir.begins_with("."):
			continue
		
		var p = path + dir + "/"
		folders.append(p)
		folders.append_array(GetAllFolders(p))
	
	return folders

func GetAllChilds(node,array : Array[Node] =[]) -> Array[Node]:
	array.push_back(node)
	for child in node.get_children():
		array = GetAllChilds(child, array)
	return array

func GetAllSurfaces(node : Node) -> Array[String]:
	var childs = GetAllChilds(node)
	var list : Array[String]
	for child in childs:
		if child.get_class() == "MeshInstance3D":
			var mi : MeshInstance3D = child
			for s in mi.mesh.get_surface_count():
				var matName = mi.mesh.get("surface_" + str(s) + "/name") #Surface name?
				if !list.has(matName):
					list.append(matName)
	
	return list

func AutoAssingMaterials(meshFile : PackedScene):
	message = ""
	
	var subresourcesLine = "_subresources="
	
	var scene = meshFile.instantiate()
	var matNames = GetAllSurfaces(scene)
	message += "Surface materials: " + str(matNames) + "\n"
	
	var matPaths : Array[String]
	
	for matn in matNames:
		var mat = FindMaterialInProject(matn)
		matPaths.append(mat)
	
	var config = ConfigFile.new()
	config.load(meshFile.resource_path + ".import")
	
	var subresources : Dictionary = config.get_value("params", "_subresources")
	var subresourcesmats : Dictionary
	if subresources.has("materials"):
		subresourcesmats = subresources["materials"].duplicate()
	
	for m in range(matNames.size()):
		if matPaths[m] != "":
			if overrideAssigned.button_pressed:
				subresourcesmats[matNames[m]] = { "use_external/enabled": true, "use_external/path": matPaths[m] }
			else:
				if !subresourcesmats.has(matNames[m]):
					subresourcesmats[matNames[m]] = { "use_external/enabled": true, "use_external/path": matPaths[m] }
				else:
					if !subresourcesmats[matNames[m]]["use_external/enabled"]:
						subresourcesmats[matNames[m]] = { "use_external/enabled": true, "use_external/path": matPaths[m] }
					else:
						message += matPaths[m] + " already assigned, skipping" + "\n"
	
	if !subresources.has("materials"):
		subresources["materials"] = {}
	
	subresources["materials"].clear()
	subresources["materials"] = subresourcesmats
	
	config.set_value("params", "_subresources", subresources)
	config.save(meshFile.resource_path + ".import")
	
	filesystem.reimport_files([meshFile.resource_path])
	ShowMessage(message)
	
	#print(config.get_value("params", "_subresources"))

##
##
## Automatic materials
##
##

#Just lazily copied script below... whatever
func GetSelectedTextures():
	var selected = get_selected_paths(get_filesystem_tree(self))
	var materials = ""
	
	var completed : Array[String]
	for file in selected:
		if not load(file) is Texture2D: continue
		var f = RemoveIgnoredFromName(file)
		var simple = texturingType.selected == 1
		var namePath = TexturePathSeparate(f, simple)
		
		if !completed.has(namePath[0]):
			materials += namePath[0] + "\n"
			completed.append(namePath[0])
	
	return materials

func CreateMaterialsFromSelection():
	var selected = get_selected_paths(get_filesystem_tree(self))
	message = ""
	
	var completed : Array[String]
	for file in selected:
		if not load(file) is Texture2D: continue
		var f = RemoveIgnoredFromName(file)
		var simple = texturingType.selected == 1
		var namePath = TexturePathSeparate(f, simple)
		
		if !completed.has(namePath[0]):
			var material = CreateMaterial(namePath, f, simple)
			completed.append(namePath[0])
	
	popupCreate.emit_signal("close_requested")
	ShowMessage(message)

func EditDefinitions():
	get_editor_interface().edit_resource(load("res://addons/AutoMat/texture definitions.cfg"))
	popupCreate.emit_signal("close_requested")

func CreateMaterial(namePath : Array[String], file : String, simple : bool) -> Material:
	var material : Material
	var paramPath = ""
	var matPath = "res://" + materialFolder.text + "/" + namePath[0] + ".tres"
	
	if FileAccess.file_exists(matPath):
		message += "Material already exists: " + namePath[0] + "\n"
		return
	
	match materialTypes.selected:
		0:
			material = ORMMaterial3D.new()
		1:
			material = StandardMaterial3D.new()
		_: #Finds all object shader in project
			material = ShaderMaterial.new()
			material.shader = load(materialTypes.get_item_text(materialTypes.selected))
			paramPath = "shader_parameter/"
	
	var textures : Array[Texture2D]
	message += "Create material " + namePath[0] + "\n"
	
	if !simple:
		textures = GetAllTextures(namePath)
		for texture in textures:
			var texNamePath = TexturePathSeparate(texture.resource_path, true)
			texNamePath[0] = RemoveIgnoredFromName(texNamePath[0])
			var suf = GetSuffix(texNamePath[0])
			
			if textureDefinitions.has(suf):
				var definition = textureDefinitions[suf]
				material.set(paramPath + definition, texture)
				message += definition + " - param assign: " + suf + " " + texture.resource_path + "\n"
				
				#Enable parameters in base material
				if materialTypes.selected == 0: #ORM
					match definition:
						"normal_texture": material.normal_enabled = true
						"heightmap_texture": material.heightmap_enabled = true
						"emission": material.emission_enabled = true
						"ao_texture": material.ao_enabled = true
						"metallic_texture": material.ao_enabled = true
				if materialTypes.selected == 1: #Standard
					match definition:
						"normal_texture": material.normal_enabled = true
						"heightmap_texture": material.heightmap_enabled = true
						"emission": material.emission_enabled = true
						"orm_texture": material.ao_enabled = true
	else:
		textures = [load(file) as Texture2D]
		material.set(paramPath + textureDefinitionsConfig.get_value(definitions, "basic"), textures[0])
	
	ResourceSaver.save(material, matPath)
	return material

func TexturePathSeparate(path : String, simple : bool) -> Array[String]:
	var fileStart = path.rfind("/")
	
	var file = path.substr(fileStart+1)
	var fileName = file.split(".")[0]
	if !simple:
		var lastSymbol = fileName.rfind(suffixStartSymbol)
		fileName = fileName.replace(fileName.substr(lastSymbol), "")
	
	var folderPath = path.replace(file, "")
	
	return [fileName, folderPath]

func GetSuffix(file : String) -> String:
	var s = file.rfind(suffixStartSymbol)
	
	return file.substr(s+1).to_lower()

#Get all textures from material group
func GetAllTextures(namePath : Array[String]) -> Array[Texture2D]:
	var textures : Array[Texture2D] = []
	
	var dir = DirAccess.open(namePath[1])
	var files = dir.get_files()
	for file in files:
		var fname = RemoveIgnoredFromName(file)
		fname = fname.split(".")[0]
		fname = fname.to_lower()
		var s = fname.substr(fname.rfind(suffixStartSymbol + GetSuffix(fname)))
		fname = fname.replace(s, "")

		if fname == namePath[0].to_lower() and !file.ends_with(".import"):
			var texture = load(namePath[1] + file)
			if texture is Texture2D:
				textures.append(texture)
	
	return textures

func FindAllShaders():
	var shaders : Array[Shader]
	var folders = GetAllFolders()
	
	for folder in folders:
		var dir = DirAccess.open(folder)
		
		for file in dir.get_files():
			if file.ends_with(".gdshader") or file.ends_with(".tres"):
				var shader = load(folder + file)
				if shader is Shader:
					if shader.get_mode() == Shader.MODE_SPATIAL:
						allShaders.append(shader)

#Remove all parts in definitions' "ignore" array
func RemoveIgnoredFromName(name : String) -> String:
	var nameIgnored = name
	
	var ignored = textureDefinitionsConfig.get_value(definitions, "ignore")
	
	for part in ignored:
		if nameIgnored.contains(suffixStartSymbol + part + suffixStartSymbol) or nameIgnored.contains(suffixStartSymbol + part + ".") or nameIgnored.ends_with(suffixStartSymbol + part):
			nameIgnored = nameIgnored.replace(suffixStartSymbol + part, "")
	
	return nameIgnored

##
##
#Get selected files
##
##

#https://github.com/me2beats/asset-dropper/blob/main/addons/asset-dropper/utils.gd
static func get_selected_paths(fs_tree:Tree)->Array:
	var sel_items: = tree_get_selected_items(fs_tree)
	var result: = []
	for i in sel_items:
		i = i as TreeItem
		result.push_back(i.get_metadata(0))
	return result

static func get_filesystem_tree(plugin:EditorPlugin)->Tree:
	var dock = plugin.get_editor_interface().get_file_system_dock()
	return find_node_by_class_path(dock, ['VSplitContainer','Tree']) as Tree


#get all selected items
static func tree_get_selected_items(tree:Tree)->Array:
	var res = []
	var item = tree.get_next_selected(tree.get_root())
	while true:
		if item == null: break
		res.push_back(item)
		item = tree.get_next_selected(item)
	return res

static func find_node_by_class_path(node:Node, class_path:Array)->Node:
	var res:Node

	var stack = []
	var depths = []

	var first = class_path[0]
	for c in node.get_children():
		if c.get_class() == first:
			stack.push_back(c)
			depths.push_back(0)

	if stack == null: return res
	
	var max_ = class_path.size()-1

	while stack:
		var d = depths.pop_back()
		var n = stack.pop_back()

		if d>max_:
			continue
		if n.get_class() == class_path[d]:
			if d == max_:
				res = n
				return res

			for c in n.get_children():
				stack.push_back(c)
				depths.push_back(d+1)

	return res

##
##
## Interface
##
##

func ShowMessage(message):
	popupMessage.show()
	popupMessage.popup_centered()
	popupMessage.get_node("Content/Text").text = message

func FindFilesystemPopup():
	var file_system:FileSystemDock = get_editor_interface().get_file_system_dock()
	
	for child in file_system.get_children():
		# this is what we want
		var pop:PopupMenu = child as PopupMenu

		# let's check that is what we want
		if not pop: continue

		# and finally, connect the about_to_show signal. We're going to pass the Popupmenu reference too. We do this because file system clears the popup menu everytime is going to show the popup.
		popupFilesystem = pop
		popupFilesystem.connect("about_to_popup", AddItemToPopup.bind(pop))
		popupFilesystem.connect("id_pressed", AssignMaterialsMenu.bind())
		popupFilesystem.connect("id_pressed", CreateMaterialsMenu.bind())

func AddItemToPopup(popup : Popup):
	popup.add_separator("AutoMat")
	popup.add_icon_item(get_editor_interface().get_base_control().get_theme_icon('PackedScene', 'EditorIcons'), "Assign materials", assignMaterialsId)
	popup.add_icon_item(get_editor_interface().get_base_control().get_theme_icon('StandardMaterial3D', 'EditorIcons'), "Create materials", createMaterialsId)

func AssignMaterialsMenu(id : int):
	if id == assignMaterialsId:
		var selected = GetSelectedMeshes()
		if selected == "": return
		popupAssign.get_node("Content/Info").text = GetSelectedMeshes()
		popupAssign.show()
		popupAssign.popup_centered()
	
func CreateMaterialsMenu(id : int):
	if id == createMaterialsId:
		var selected = GetSelectedTextures()
		if selected == "": return
		popupCreate.get_node("Content/Info").text = selected
		popupCreate.show()
		popupCreate.popup_centered()
