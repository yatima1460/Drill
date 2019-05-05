project('GIR-to-D', 'd', version: '0.16.0')

source = [
	'source/girtod.d',
	'source/gtd/DefReader.d',
	'source/gtd/GlibTypes.d',
	'source/gtd/GirAlias.d',
	'source/gtd/GirConstant.d',
	'source/gtd/GirEnum.d',
	'source/gtd/GirField.d',
	'source/gtd/GirFunction.d',
	'source/gtd/GirPackage.d',
	'source/gtd/GirStruct.d',
	'source/gtd/GirType.d',
	'source/gtd/GirVersion.d',
	'source/gtd/GirWrapper.d',
	'source/gtd/IndentedStringBuilder.d',
	'source/gtd/Log.d',
	'source/gtd/LinkedHasMap.d',
	'source/gtd/WrapException.d',
	'source/gtd/XMLReader.d'
]

sources_dir = include_directories('source/')

version = vcs_tag(command: ['git', 'describe', '--dirty=+', '--tags'], input: 'VERSION.in', output: 'VERSION')
# d_import_dirs was added in meson 0.43 for now add -J manually.
add_project_arguments('-J'+meson.current_build_dir(), language: 'd')

executable(
	'girtod',
	[source, version],
	include_directories : [sources_dir],
#	d_import_dirs : meson.build_root(),
	install : true
)
