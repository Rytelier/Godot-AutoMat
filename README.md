# AutoMat for Godot 4 - asset import automation and batch process

Plugin for automating tedious parts of asset importing.

- Automatically find materials in the project and assign them to imported meshes

Automates the tedious steps of editing the imported mesh to assign materials, now you can just press one button and it will automatically find materials with matching name.

![image](https://user-images.githubusercontent.com/45795134/221383675-57385bb2-6f81-4f11-a7da-12603b3458d0.png)

- Create materials from selected textures

Will create materials out of selected texture and automatically find textures starting with same name for additional shader params

![image](https://user-images.githubusercontent.com/45795134/221383610-b85392b1-5dde-4529-bfb7-31aa544b923c.png)

- Export mesh's animation clips with custom tracks enabled

Automatically enables animation clip editing on every clip of imported mesh's animation player and puts them in a subfolder

# Usage

Enable the AutoMat plugin in project settings.
The plugin panel will appear in upper-left dock, under AutoMat tab.
Select desired items in the FileSystem and use AutoMat commands on them.
