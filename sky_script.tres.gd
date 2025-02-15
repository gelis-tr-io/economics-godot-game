tool
extends Spatial
onready var env: Environment = $WorldEnvironment.environment
onready var sun: DirectionalLight = $Sun_Moon
onready var sky_view: Viewport = $sky_viewport
onready var clouds_view: Viewport = $clouds_viewport
onready var sky_tex: Sprite = $sky_viewport/sky_texture
onready var clouds_tex: Sprite = $clouds_viewport/clouds_texture

export (int) var clouds_resolution: int=1024 setget set_clouds_resolution
export (int) var sky_resolution: int=2048 setget set_sky_resolution

export (GradientTexture) var sky_gradient_texture: GradientTexture setget set_sky_gradient;
export (bool) var SCATERRING :bool = false setget set_SCATERRING
export (Color, RGBA) var color_sky :Color = Color(0.25,0.5,1.0,1.0)setget set_color_sky
export (float, 0.0,10.0,0.0001) var sky_tone: float = 3.0 setget set_sky_tone #from 0 to 10
export (float, 0.0,2.0,0.0001) var sky_density: float = 0.75 setget set_sky_density #from 0 to 2
export (float, 0.0,10.0,0.0001) var sky_rayleig_coeff: float = 0.75 setget set_sky_rayleig_coeff #from 0 to 10
export (float, 0.0,10.0,0.0001) var sky_mie_coeff: float = 2.0 setget set_sky_mie_coeff #from 0 to 10
export (float, 0.0,2.0,0.0001) var multiScatterPhase: float = 0.0 setget set_multiScatterPhase #from 0 to 2
export (float, -2.0,2.0,0.0001) var anisotropicIntensity: float = 0.0 setget set_anisotropicIntensity #from 0 to 2

export (int, 0, 23) var hours: int=0 setget set_hours
export (int, 0, 59) var minutes: int=0 setget set_minutes
export (int, 0, 59) var seconds: int=0 setget set_seconds
export (float, 0.0,1.0,0.000001) var time_of_day_setup: float=0.0 setget set_time_of_day#from 0 to 1 for setup time_of_day, Because of the offset, it is difficult to manage this variable in the editor directly
var time_of_day: float=0.0
var one_second: float = 1.0/(24.0*60.0*60.0)#What part of a second takes in a day in the range from 0 to 1

export (float, 0.0,1.0,0.0001) var clouds_coverage: float = 0.5 setget set_clouds_coverage#from 0 to 1
export (float, 0.0,10.0,0.0001) var clouds_size: float = 2.0 setget set_clouds_size#from 0 to 10
export (float, 0.0,10.0,0.0001) var clouds_softness: float = 1.0 setget set_clouds_softness#from 0 to 1
export (float, 0.0,1.0,0.0001) var clouds_dens: float = 0.07 setget set_clouds_dens#from 0 to 1
export (float, 0.0,1.0,0.0001) var clouds_height: float = 0.35 setget set_clouds_height#from 0 to 1
export (int, 1,100) var clouds_quality: int = 25 setget set_clouds_quality#from 5 to 100
var sun_pos: Vector3
var moon_pos: Vector3
var god_rays
var iTime: float=0.0


export (Color, RGBA) var moon_light :Color = Color(0.6,0.6,0.8,1.0)
export (Color, RGBA) var sunset_light :Color = Color(1.0,0.7,0.55,1.0)
export (float, -0.3,0.3,0.000001) var sunset_offset: float=-0.1
export (float, 0.0,0.3,0.000001) var sunset_range: float=0.2
export (Color, RGBA) var day_light :Color = Color(1.0,1.0,1.0,1.0)
export (Color, RGBA) var moon_tint :Color = Color(1.0,0.7,0.35,1.0) setget set_moon_tint
export (Color, RGBA) var clouds_tint :Color = Color(1.0,1.0,1.0,1.0) setget set_clouds_tint
export (float, 0.0,1.0,0.0001) var sun_radius: float = 0.04 setget set_sun_radius#from 0 to 1
export (float, 0.0,0.5,0.0001) var moon_radius: float = 0.1 setget set_moon_radius#from 0 to 0.5
export (float, -1.0,1.0,0.0001) var moon_phase: float =0.0 setget set_moon_phase#from 0 to 1
export var night_level_light: float=0.05 setget set_night_level_light
export var wind_dir: Vector2=Vector2(1.0,0.0) setget set_wind_dir
export (float, 0.0,1.0,0.0001) var wind_strength: float = 0.1 setget set_wind_strength#from 0 to 1
export var lighting_pos: Vector3=Vector3(0.0,1.0,1.0) setget set_lighting_pos

func set_call_deff_shader_params(node: Material, params:String, value):
	node.set(params,value)

func set_clouds_resolution(value: int):
	clouds_resolution = value
	if is_inside_tree():
		clouds_view.size = Vector2(clouds_resolution,clouds_resolution)
		clouds_tex.texture.set_size_override(Vector2(clouds_resolution,clouds_resolution))

func set_sky_resolution(value: int):
	sky_resolution = value
	if is_inside_tree():
		sky_view.size = Vector2(sky_resolution,sky_resolution)
		sky_tex.texture.set_size_override(Vector2(sky_resolution,sky_resolution))
	
func _ready():
	god_rays = get_node_or_null("GodRays")
	_set_god_rays(true)
	set_lighting_strike(false)
	call_deferred("_set_attenuation",3.0)
	call_deferred("_set_exposure",1.0)
	call_deferred("_set_light_size",0.2)
	call_deferred("set_color_sky",color_sky)
	call_deferred("set_moon_tint",moon_tint)
	call_deferred("set_clouds_tint",clouds_tint)
	call_deferred("set_moon_phase",moon_phase)
	call_deferred("set_moon_radius",moon_radius)
	call_deferred("set_wind_strength",wind_strength)
	call_deferred("set_wind_strength",wind_strength)
	call_deferred("set_clouds_quality",clouds_quality)
	call_deferred("set_clouds_height",clouds_height)
	call_deferred("set_clouds_coverage",clouds_coverage)
	call_deferred("set_time")
	call_deferred("reflections_update")

func reflections_update():
	#env.background_sky.set_panorama(null)
	env.background_sky.set_panorama(sky_view.get_texture())

func set_SCATERRING(value :bool):
	SCATERRING = value
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/SCATERRING",SCATERRING)

func set_sky_gradient(value: GradientTexture):
	sky_gradient_texture = value
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/sky_gradient_texture",sky_gradient_texture)
		


func set_night_level_light(value: float):
	night_level_light = clamp(value,0.0,1.0)
	set_time()

func set_hours(value: int):
	hours = clamp(value,0,23)
	set_time_of_day((hours*3600+minutes*60+seconds)*one_second)
		
func set_minutes(value: int):
	minutes = clamp(value,0,59)
	set_time_of_day((hours*3600+minutes*60+seconds)*one_second)
	
func set_seconds(value: int):
	seconds = clamp(value,0,59)
	set_time_of_day((hours*3600+minutes*60+seconds)*one_second)
		
func set_time_of_day(value: float):
	time_of_day_setup = value
	var time: float = value/one_second
	value -= 2.0/24.0
	if value < 0.0:
		value = 1.0 + value
	time_of_day = value
	hours = int(clamp(time/3600.0,0.0,23.0))
	time -= hours*3600
	minutes = int(clamp(time/60,0.0,59.0))
	time -= minutes*60
	seconds = int(clamp(time,0.0,59.0))
	#print (hours,":",minutes,":",seconds)
	set_time()

func set_time():
	if !is_inside_tree():
		return
	var light_color :Color = Color(1.0,1.0,1.0,1.0)
	var phi: float = time_of_day*2.0*PI
	sun_pos = Vector3(0.0,-1.0,0.0).normalized().rotated(Vector3(1.0,0.0,0.0).normalized(),phi) #here you can change the start position of the Sun and axis of rotation
	moon_pos = Vector3(0.0,1.0,0.0).normalized().rotated(Vector3(1.0,0.0,0.0).normalized(),phi) #Same for Moon
	var moon_tex_pos: Vector3 = Vector3(0.0,1.0,0.0).normalized().rotated(Vector3(1.0,0.0,0.0).normalized(),(phi+PI)*0.5) #This magical formula for shader
	call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/MOON_TEX_POS",moon_tex_pos)
	var light_energy: float = smoothstep(sunset_offset,0.4,sun_pos.y);# light intensity depending on the height of the sun
	call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/SUN_POS",sun_pos)
	call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/MOON_POS",moon_pos)
	call_deferred("set_call_deff_shader_params", clouds_tex.material, "shader_param/SUN_POS",-sun_pos)
	call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/attenuation",clamp(light_energy,night_level_light*0.25,1.00))#clouds to bright with night_level_light
	light_energy = clamp(light_energy,night_level_light,1.00);
	var sun_height: float = sun_pos.y-sunset_offset
	if sun_height < sunset_range:
		light_color=lerp(moon_light, sunset_light, clamp(sun_height/sunset_range,0.0,1.0))
	else:
		light_color=lerp(sunset_light, day_light, clamp((sun_height-sunset_range)/sunset_range,0.0,1.0))
	if sun_pos.y < 0.0:
		if moon_pos.normalized() != Vector3.UP:# error  Up vector and direction between node origin and target are aligned, look_at() failed.
			sun.look_at_from_position(moon_pos,Vector3.ZERO,Vector3.UP); # move sun to position and look at center scene from position
	else:
		if sun_pos.normalized() != Vector3.UP:
			sun.look_at_from_position(sun_pos,Vector3.ZERO,Vector3.UP); # move sun to position and look at center scene from position
	set_clouds_tint(light_color) # comment this, if you need custom clouds tint
	light_energy = light_energy *(1-clouds_coverage*0.5)
	sun.light_energy = light_energy
	sun.light_color = light_color
	env.ambient_light_energy = light_energy
	env.ambient_light_color = light_color
	env.adjustment_saturation = 1-clouds_coverage*0.5
	env.set_fog_color(light_color)
	#call_deferred("reflections_update")


func set_clouds_height(value: float):
	clouds_height = clamp(value,0.0,1.0)
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", clouds_tex.material, "shader_param/HEIGHT",clouds_height)

func set_clouds_coverage(value: float):
	clouds_coverage = clamp(value,0.0,1.0)
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", clouds_tex.material, "shader_param/ABSORPTION",clouds_coverage+0.75)
		call_deferred("set_call_deff_shader_params", clouds_tex.material, "shader_param/COVERAGE",1.0-(clouds_coverage*0.7+0.1))
		call_deferred("set_call_deff_shader_params", clouds_tex.material, "shader_param/THICKNESS",clouds_coverage*10.0+10.0)
		call_deferred("set_time")

func set_clouds_size(value: float):
	clouds_size = clamp(value,0.0,10.0)
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", clouds_tex.material, "shader_param/SIZE",clouds_size)

func set_clouds_softness(value: float):
	clouds_softness = clamp(value,0.0,10.0)
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", clouds_tex.material, "shader_param/SOFTNESS",clouds_softness)
		
func set_clouds_dens(value: float):
	clouds_dens = clamp(value,0.0,1.0)
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", clouds_tex.material, "shader_param/DENS",clouds_dens)

func set_clouds_quality(value: int):
	clouds_quality = value
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", clouds_tex.material, "shader_param/STEPS",clamp (clouds_quality,5,100))

func set_wind_dir(value: Vector2):
	wind_dir = value.normalized() #normalize wind vector
	set_wind_strength(wind_strength)

func set_wind_strength(value: float):
	wind_strength = value
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", clouds_tex.material, "shader_param/WIND",Vector3(wind_dir.x,0.0,wind_dir.y)*wind_strength)
	
func set_sun_radius(value: float):
	sun_radius = clamp(value,0.0,1.0)
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/sun_radius",value)

func set_moon_radius(value: float):
	moon_radius = clamp(value,0.0,1.0)
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/moon_radius",value)
	
func set_moon_phase(value: float):
	moon_phase = clamp(value,-1.0,1.0)
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/MOON_PHASE",moon_phase)#*0.4-0.2) # convert to diapazon -0.2...+0.2

func set_sky_tone(value: float):
	sky_tone = value
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/sky_tone",sky_tone)

func set_sky_density(value: float):
	sky_density = value
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/sky_density",sky_density)

func set_sky_rayleig_coeff(value: float):
	sky_rayleig_coeff = value
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/sky_rayleig_coeff",sky_rayleig_coeff)
		
func set_sky_mie_coeff(value: float):
	sky_mie_coeff = value
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/sky_mie_coeff",sky_mie_coeff)

func set_multiScatterPhase(value: float):
	multiScatterPhase = value
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/multiScatterPhase",multiScatterPhase)

func set_anisotropicIntensity(value: float):
	anisotropicIntensity = value
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/anisotropicIntensity",anisotropicIntensity)

func set_color_sky(value: Color):
	color_sky = value
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/color_sky",color_sky)

func set_moon_tint(value: Color):
	moon_tint = value
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/moon_tint",moon_tint)

func set_clouds_tint(value: Color):
	clouds_tint = value
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/clouds_tint",clouds_tint)

func _process(delta:float):
	iTime += delta
	var lighting_strength = clamp(sin(iTime*20.0),0.0,1.0)
	lighting_pos = lighting_pos.normalized()
	sun.light_color = day_light
	sun.light_energy = lighting_strength*2
	call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/LIGHTTING_POS",lighting_pos)
	call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/LIGHTING_STRENGTH",Vector3(lighting_strength,lighting_strength,lighting_strength))
	sun.look_at_from_position(lighting_pos,Vector3.ZERO,Vector3.UP);
			

func set_lighting_strike(on: bool):
	if on:
		_set_god_rays(false)
		set_process(true)
	else:
		_set_god_rays(true)
		set_process(false)
		iTime = 0.0
		if sky_tex:
			call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/LIGHTING_STRENGTH",Vector3(0.0,0.0,0.0))
		set_time()

func set_lighting_pos(value):
	lighting_pos = value;
	if is_inside_tree():
		call_deferred("set_call_deff_shader_params", sky_tex.material, "shader_param/LIGHTTING_POS",lighting_pos.normalized())

		
func thunder():
	var thunder_sound:AudioStreamPlayer = $thunder;
	if thunder_sound.is_playing():
		#thunder_sound.stop()
		return
	thunder_sound.play()
	yield(get_tree().create_timer(0.3),"timeout");
	set_lighting_strike(true)
	yield(get_tree().create_timer(0.8),"timeout");
	set_lighting_strike(false)

func _set_exposure(value: float):
	if god_rays:
		god_rays.set_exposure(value)

func _set_attenuation(value: float):
	if god_rays:
		god_rays.set_attenuation(value)
	
func _set_light_size(value: float):
	if god_rays:
		god_rays.set_light_size(value)

func _set_god_rays(on: bool):
	if not god_rays:
		return
	if on:
		if !god_rays.is_inside_tree():
			add_child(god_rays)
		god_rays.light = sun
		god_rays.set_clouds(clouds_view.get_texture())
	else:
		remove_child(god_rays)
