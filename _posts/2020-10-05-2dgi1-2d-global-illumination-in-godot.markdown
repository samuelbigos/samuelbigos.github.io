---
layout: post
title:  "2DGI #1 - Global Illumination in Godot"
date:   2020-10-05 00:00:00 +0000
categories: none
---

Hello.

This is the first of a series of blog posts I plan to write, breaking apart the algorithms and implementation of a custom 2D global illumination (or raytracing, or radiosity, or whatever you want to call it) lighting engine in [Godot](https://godotengine.org/).

I want to do more than just give you the code and tell you where to put it (after all, [i've made the source available](https://github.com/samuelbigos/godot_2d_global_illumination)), Amit Patel's [Red Blob Games](https://www.redblobgames.com/) has proven an invaluable resource in many of my game dev ventures, and my hope is that this series, in some small way, emulates the way he carves up complex theories into bite-sized and beatiful morsels of knowledge. That is to say I'll be talking less about the Godot implementation and more about the algorithms and process such that you can go away and implement it in whichever framework you'd like.

Having said _that_, I will come clean and tell you I knew next to nothing about any of these subjects before around three months ago, so I am hardly the authority on the matter. However, around that time I did a _lot_ of Googling and found only smatterings of info/examples. The most useful resource was [/u/toocanzs](https://www.reddit.com/r/gamedev/comments/91mwrh/infinity_2d_lights_with_shadows_gi/e2zts0a/) who wrote a [shadertoy](https://www.shadertoy.com/view/lltcRN) example of the technique (which was itself inspired by another reddit user's example). It's safe to say without this as a jumping-board my implementation wouldn't exist. Apart from this, I only found a few other people who have done something similar - two of the more inspiring being [Thomas Diewald's animations](https://vimeo.com/diwi) and [Andy Duboc's images](http://andbc.co/2d_radiosity/) - but nothing with implementation details.

_Come on get to the point._ Ok fine.

<img class="full" src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/1.png" />

## What's The Point?

The point is that I'm lazy, and I want a lighting system that _just works_ without me, the curator, having to worry about placing lights, probes, occlusion volumes, dealing with light blending, shadowing artifacts, yada yada, and what better way to achieve that than do it the way it _just works_ in real life with actual rays of photons (unless you believe a certain outcome of the [Simulation Argument](https://www.simulation-argument.com/simulation.html)). Of course, I also want it to look amazing and unlike any other game out there. And I've looked, no other game I've found is doing this (probably because it's _really fucking hard_ - more on this later). It also needs to run well.

**Tl;dr**
* It needs to run well on medium spec hardware. No point in looking pretty if it makes the game unplayable.
* It needs to look good (bounced light, shadows, colour blending).
* It should make curation (i.e. levels, environments, _content_) easier, not harder, compared to more standard lighting techniques.

Let's get started...

## Looking At The Data

_"The purpose of all programs, and all parts of those programs, is to transform data from one form to another."_ - Jackie Chan, probably (actually I lied it was [Mike Acton](https://www.youtube.com/watch?v=rX0ItVEVjHc))

Let's start by looking at the data we're putting in, and the data we expect to get out the other end, so we can properly reason about the transform we need to do in the middle.

**In** - There are two entities we care about: _Emitters_ and _Occluders_. We care about their position, rotation, shape, emissive (brightness) and colour for emitters, albedo (reflectivity) and colour for occluders.

**Out** - A brightness and colour value for each pixel in the scene, representing the amount of light gathered by that pixel from surrounding emissive surfaces.

We also need to consider the **hardware** (or platform) we're running on. My goal when developing this technique was to eventually make a game that used it as a lighting engine, and the target platform would be PCs with medium-to-high spec graphics cards. This means we have access to the GPU and the potentially powerful parallel pixel processing proficiency (or [PPPPPP](https://soundcloud.com/james-l-jackson/sets/pppppp-the-vvvvvv-soundtrack), soundtrack to the amazing [VVVVVV](https://store.steampowered.com/app/70300/VVVVVV/) by Terry Cavanagh) it has, which we will utilise fully to transform our data from A to B.

<div class="info">
<p>If you're new to shaders or want a refresher, check out <a href="https://thebookofshaders.com/">The Book of Shaders</a>. All the algorithms we'll be exploring are done on the GPU in shader language so some knowledge is expected.</p>
</div>

Since the common data format of the GPU is the humble texture, we'll be storing our input data in texture format. Thankfully it just so happens that most game engines come equipped with a simple method of storing spatial and colour information about 2D entities in texture data, it's done by drawing a sprite to the screen! Well, that was easy, let's move on to the fun stuff.

## Setting The Scene

Ok, there's an important thing we need to do first. By default, when you draw a sprite in most engines it will get drawn to the frame buffer, which is a texture (or a group of textures) onto which the whole scene is drawn, and then 'presented' to the screen. Instead we want to draw our sprite onto a texture we can then use as an input to our lighting shader. How to do this will differ depending on the engine or framework, I will show how it's done in Godot. 

### Render Textures In Godot

Godot has an object called a [Viewport](https://docs.godotengine.org/en/stable/tutorials/viewports/viewports.html). Nodes (Sprites, Canvases, Particles, etc) are drawn to the closest parent Viewport, and each Scene has a root viewport even if you don't add one manually, that root viewport is what presents it's contents to the screen.

This means we can create a new viewport, add our emitters and occluders as child sprites to it, then access the resulting texture to feed into our lighting shader. Our sprites can be anything, but for now the emitter should be white and the occluder black. 

<div class="info">
<p>If you're following along with your own Godot project, there are some setup steps you need to take:
<ul>
	<li>Make sure you're using GLES3 as the rendering driver.</li>
	<li>Set your root viewport size (Display>Window>Size>Width/Height) to something small, e.g. 360x240, then set test size (Test Width/Test Height) to a larger multiple of the base resolution, e.g. 1280x720.</li>
	<li>Set stretch mode (at the bottom) to viewport. This causes the base resolution to be blown up to the test resolution which will make it easier to see what's happening (which is important since we care about what's happening on an individual pixel level).</li>
</ul></p>
</div>

I'm also going to create a TextureRect called Screen as a child of the root node. This will be how we display the contents of a viewport to screen, so for now we will set it's texture to a ViewportTexture, and point it at the EmittersAndOccluders viewport we created.

So let's see how all that looks in a Godot scene.

<div class="row">
	<div class="column">
		<img src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/viewport_screen_layout.png" />
	</div>
	<div class="column">
		<img src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/screen_settings.png" />
	</div>
</div>
  
This is actually a little bit annoying because having our sprites as children of the non-root viewport means they don't appear in the editor. There are a couple of ways I've found to work around this, but the easiest for now is to parent the sprites to the root viewport in editor and move them to the EmittersAndOccluders viewport at runtime. 

So lets move those sprites to the root node.

Now there's some setup in code that we have to do. Attach a script to the root node, and add the following code:

{% highlight gdscript %}
extends Node2D

func _ready():
  # parent our emissive and occluding sprites to the EmittersAndOccluders viewport at runtime.
  var emitter = $Emitter
  var occluder = $Occluder
  remove_child(emitter)
  remove_child(occluder)
  $EmittersAndOccluders.add_child(emitter)
  $EmittersAndOccluders.add_child(occluder)

  # setup our viewports and screen texture.
  # you can do this in the editor, but i prefer to do it in code since it's more visible and easier to update.
  $EmittersAndOccluders.transparent_bg = true
  $EmittersAndOccluders.render_target_update_mode = Viewport.UPDATE_ALWAYS
  $EmittersAndOccluders.size = get_viewport().size
  $Screen.rect_size = get_viewport().size
{% endhighlight %}

Now, running this we see two sprites drawn, but the entire window appears upside down. This is normal, and is because Godot and OpenGL's Y-coordinate expects different directionality (in Godot Y increases towards the bottom, and in OpenGL it increases towards the top). We fix this by enabling _V Flip_ in our EmittersAndOccluders viewport settings. Thus:

<img class="small" src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/first_output.png" />

## The Fun Stuff - Fields And Algorithms

So, we have a texture that contains our emissive and occlusion data (note: there's not really a discrepancy here, all pixels will occlude, and any with a colour value > 0.0 will emit light). Looking back at our expected output, we want to use our input data to determine the brightness and colour value of each pixel in our scene.

<div class="info">
<p><a href="https://en.wikipedia.org/wiki/Global_illumination">Global illumination</a> is obviously a huge and well researched topic, and I'm not sure where the method I'm using falls on the wide spectrum of algorithms that attempt to achieve some form of GI lighting. If you want some background on the history of lighting in video games, I highly recommend <a href="https://www.youtube.com/watch?v=P6UKhR0T6cs">this talk by John Carmack</a>.</p>
</div>

In our implementation we're going to send a number of rays out from each pixel. These rays will travel until they hit a surface, and the emissive value of that surface will contribute to the total brightness value of that pixel. At a fundamental level it's really that simple. What is complicated is how we determine what a surface is and when our ray has hit it, and how we get the emissive value from that pixel once we do.

A naive approach could be to sample each point on our ray in step size of one pixel. We'd need to sample every pixel to make sure we don't jump past a surface. However, to do this would be exorbitantly expensive as a ray travelling from one side of our viewport to the other would potentially sample up to _√(width<sup>2</sup>+height<sup>2</sup>)_ times. If only there was some way to encode the distance to the nearest surface in texture form that we could reference in our shader...

### Distance Fields

A distance field is just that, a map where the value of each pixel is the distance from that pixel to the nearest surface. The reason this is useful for us is that instead of crawling along our ray one pixel at a time, we can sample the distance field at our current location and whatever value is returned, we know it is safe to advance exactly that far along the ray. This dramatically cuts down the amount of steps along our rays we need to do, in the best case we could jump straight from our ray origin to a surface, though in most cases it will still take a few steps (the worst case is that a ray is parallel and close to a surface, which means it will never reach the surface but can only step forward a small amount at a time).

<div class="info">
<p>You might have heard the term Signed Distance Field (SDF) used more than Distance Field in computer graphics. They are the same concept except that when inside an object, an SDF returns a negative distance value to the object's closest surface, while a DF doesn't know whether it's inside or outside an object and just returns positive values.</p>
<p>In our case, we're actually going to implify things even further and set the distance value to 0.0 at every point inside an object.</p>
</div>

There are two main ways to generate a distance field in a shader:
1. Naively sample in a radius around each pixel, and record the closest surface if one is found (or the max value if not). Very expensive.
2. Use the [Jump Flooding algorithm](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.101.8568&rep=rep1&type=pdf) (also [see here](https://blog.demofox.org/2016/02/29/fast-voronoi-diagrams-and-distance-dield-textures-on-the-gpu-with-the-jump-flooding-algorithm/)) to generate a Voronoi Diagram, then convert that into a distance field.

Since #1 is completely impractical if we want the end result to run acceptably fast, we're going to have to implement the Jump Flooding algorithm, then convert that Voronoi Diagram to a distance field. If you want more information on these then I recommend reading the links above, though don't try to understand how the Jump Flooding algorithm works, it's impossible and you might as well attribute it to magic.

### Jump Flooding Part I - The Seed
_(no that's not a move in Super Mario Sunshine)_

We need to seed the Jump Flooding algorithm with a copy of our emitter/occluder map, but each non-transparent pixel should store its own UV (a 2D vector between [0,0] and [1,1] that stores a position on a texture) in the RG component of the texture. To do this we'll make a new Viewport with child TextureRect. This combo will be frequently used, the idea is the full-screen TextureRect draws the output of another viewport with our given shader, then it's parent viewport stores that in its own texture ready to be drawn on another TextureRect. The whole render pipeline is primarily a daisy-chain of these Viewport + RenderTexture pairings.

On the RenderTexture, we set _texture_ to a 1x1 image so there's something to draw to, and set _expand_ to true so it fills the whole viewport. Then we need to setup the material and shader that will actually convert the incoming emitter/occluder map to the seed for the Jump Flooding algorithm. Set _material_ to be a new ShaderMaterial, and then set _shader_ on that Material to a new Shader. You can then save that Shader for easy access later (I called mine VoronoiSeed.shader).

<div class="row">
	<div class="column">
		<img src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/voronoi-seed-1.png" />
	</div>
	<div class="column">
		<img src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/voronoi-seed-2.png" />
	</div>
</div>

Now, we need to add some setup code below the previous setup code, in _\_ready()_:

{% highlight gdscript %}
func _ready():
  ...

  # setup our voronoi seed render texture.
  $VoronoiSeed.render_target_update_mode = Viewport.UPDATE_ALWAYS
  $VoronoiSeed.render_target_v_flip = true
  $VoronoiSeed.size = get_viewport().size
  $VoronoiSeed/Tex.rect_size = get_viewport().size
  $VoronoiSeed/Tex.material.set_shader_param("u_input_tex", $EmittersAndOccluders.get_texture())

  # set the screen texture to use the voronoi seed output.
  $Screen.texture = $VoronoiSeed.get_texture()
{% endhighlight %}

Finally, we need to add the GLSL (OpenGL Shader Language) code to the shader we just created.

{% highlight glsl %}
shader_type canvas_item;

uniform sampler2D u_input_tex;

void fragment() 
{
  // for the voronoi seed texture we just store the UV of the pixel if the pixel is
  // part of an object (emissive or occluding), or black otherwise.
  vec4 scene_col = texture(u_input_tex, UV);
  COLOR = vec4(UV.x * scene_col.a, UV.y * scene_col.a, 0.0, 1.0);
}
{% endhighlight %}

_Et voila_, if everything went correctly (aka I didn't forget any steps when writing this up) you should have something that looks like this:

<img class="small" src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/voronoi-seed-3.png" />

_Note that I moved the sprites to make the UV storage more visible. UV.x is represented on the red channel, so the sprite to the right appears red, and vice-versa._

### Jump Flooding Part II - Multipass

Lets implement the actual Jump Flooding algorithm. Like I said before, I don't know how this works, and you don't need to either, suffice it to say that it does work and it's actually very cheap (at least compared to our actual GI calculations that come later).

In short, we do a number of render passes, starting with the voronoi seed we created earlier, and ending with a full voronoi diagram. The number of iterations depends on the size of the buffer we're working with. So, again we'll set up a number of Viewport and TextureRect pairs (which I'll call a render pass from now on) which we'll daisy chain together, however since the amount of render passes is dynamic, we'll create them programatically by duplicating a single render pass we set up in editor.

We create our initial jump flood render pass in the exact same way as our voronoi seed render pass, the only difference is that we point it to a brand new shader (empty for now). _Be mindful if you duplicate the VoronoiSeed viewport, you'll need to make the material unique or changes to the material on one viewport will be duplicated to the other. This has caught me out many times._

<div class="row">
	<div class="column">
		<img src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/jump-flood-1.png" />
	</div>
  <div class="column">
		<img src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/jump-flood-2.png" />
	</div>
</div>

Again we add setup code to the _\_ready()_ function in the script attached to our root node, and we add _\_voronoi_passes[]_ which will keep track of our jump flooding render passes. There's quite a lot going on here, but we're basically just creating a bunch of render passes and setting up the correct shader uniforms (inputs).

{% highlight gdscript %}
var _voronoi_passes = []

func _ready():
  ...

  # setup our voronoi pass render texture.
  $JumpFloodPass.render_target_update_mode = Viewport.UPDATE_ALWAYS
  $JumpFloodPass.render_target_v_flip = true
  $JumpFloodPass.size = get_viewport().size
  $JumpFloodPass/Tex.rect_size = get_viewport().size

  # number of passes required is the log2 of the largest viewport dimension rounded up to the nearest power of 2.
  # i.e. 768x512 is log2(1024) == 10
  var passes = ceil(log(max(get_viewport().size.x, get_viewport().size.y)) / log(2.0))

  # iterate through each pass and set up the required render pass objects.
  for i in range(0, passes):

    # offset for each pass is half the previous one, starting at half the square resolution rounded up to nearest power 2.
    # i.e. for 768x512 we round up to 1024x1024 and the offset for the first pass is 512x512, then 256x256, etc. 
    var offset = pow(2, passes - i - 1)

    # on the first pass, use our existing render pass, on subsequent passes we duplicate the existing render pass.
    var render_pass
    if i == 0:
      render_pass = $JumpFloodPass
    else:
      render_pass = $JumpFloodPass.duplicate(0)

    render_pass.get_child(0).material = render_pass.get_child(0).material.duplicate(0)
    add_child(render_pass)
    _voronoi_passes.append(render_pass)

    # here we set the input texture for each pass, which is the previous pass, unless it's the first pass in which case it's
    # the seed texture.
    var input_texture = $VoronoiSeed.get_texture()
    if i > 0:
      input_texture = _voronoi_passes[i - 1].get_texture()

    # set size and shader uniforms for this pass.
    render_pass.set_size(get_viewport().size)
    render_pass.get_child(0).material.set_shader_param("u_level", i)
    render_pass.get_child(0).material.set_shader_param("u_max_steps", passes)
    render_pass.get_child(0).material.set_shader_param("u_offset", offset)
    render_pass.get_child(0).material.set_shader_param("u_input_tex", input_texture)

  # set the screen texture to use the final jump flooding pass output.
  $Screen.texture = _voronoi_passes[_voronoi_passes.size() - 1].get_texture()

{% endhighlight %}

Finally, we need to add the GLSL code which does most of the work.

{% highlight glsl %}
shader_type canvas_item;

uniform sampler2D u_input_tex;
uniform float u_offset = 0.0; 
uniform float u_level = 0.0;
uniform float u_max_steps = 0.0;

void fragment() 
{
  float closest_dist = 9999999.9;
  vec2 closest_pos = vec2(0.0);

  // insert jump flooding algorithm here.
  for(float x = -1.0; x <= 1.0; x += 1.0)
  {
    for(float y = -1.0; y <= 1.0; y += 1.0)
    {
      vec2 voffset = UV;
      voffset += vec2(x, y) * SCREEN_PIXEL_SIZE * u_offset;

      vec2 pos = texture(u_input_tex, voffset).xy;
      float dist = distance(pos.xy, UV.xy);

      if(pos.x != 0.0 && pos.y != 0.0 && dist < closest_dist)
      {
        closest_dist = dist;
        closest_pos = pos;
      }
    }
  }
  COLOR = vec4(closest_pos, 0.0, 1.0);
}
{% endhighlight %}

Whew, that was a mouthful. It should look something like this when run:

<img class="small" src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/jump-flood-3.png" />

This is a Voronoi Diagram, which is a map where each pixel stores the UV of the closest surface to it according to the seed input texture. It doesn't look very exciting because our seed only contains two objects, so the Voronoi Diagram just carves the image into two regions with a line down the middle of our emitter and occluder. _Play around with adding more sprites to the scene and see what Voronoi Diagrams you can create._

What's more interesting to look at is the way a Voronoi Diagram is created over multiple passes:

<img class="full" src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/jump-flood-4.png" />

### Creating The Distance Field

We're finally ready to create a distance field! Thankfully, this is comparatively straight-forward compared to the Voronoi Diagram. 

All we need to do, is for each pixel of the distance field, we sample the pixel at the same UV on the Voronoi Diagram and store the distance between it's own UV (labeled UV in the image below), and the UV stored in it's RG channels (labeled as RG below). We can then adjust this distance by some factor depending on what sort of precision/range trade-off we want, and that's our distance field!

<img class="full" src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/distance-field-1.png" />

Create another render pass for the distance field, here's what our full scene looks like right now:

<img src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/distance-field-2.png" />

Set it up as we've done before, the input texture is the final output from the jump flood render passes.

{% highlight gdscript %}
func _ready():
  ...
  
  # setup our distance field render texture.
  $DistanceField.transparent_bg = true
  $DistanceField.render_target_update_mode = Viewport.UPDATE_ALWAYS
  $DistanceField.render_target_v_flip = true
  $DistanceField.size = get_viewport().size
  $DistanceField/Tex.rect_size = get_viewport().size
  $DistanceField/Tex.material.set_shader_param("u_input_tex", _voronoi_passes[_voronoi_passes.size() - 1].get_texture())

  # set the screen texture to use the distance field output.
  $Screen.texture = $DistanceField.get_texture()
{% endhighlight %}

Finally, add the shader code. _u\_dist\_mod_ can be left at 1.0 for now, basically it allows us to control the distance scaling, or how far from a surface before we report the max distance. Also worth noting is that the distance field is in UV space, that means a distance of 1.0 in the Y axis is the full height of the texture, and in X is the full width of the texture.

{% highlight glsl %}
shader_type canvas_item;

uniform sampler2D u_input_tex;
uniform float u_dist_mod = 1.0;

void fragment() 
{
  // input is the voronoi output which stores in each pixel the UVs of the closest surface.
  // here we simply take that value, calculate the distance between the closest surface and this
  // pixel, and return that distance. 
  vec4 tex = texture(u_input_tex, UV);
  float dist = distance(tex.xy, UV);
  float mapped = clamp(dist * u_dist_mod, 0.0, 1.0);
  COLOR = vec4(vec3(mapped), 1.0);
}
{% endhighlight %}

And we have something that looks like this:

<img class="small" src="/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/distance-field-3.png" />

## It's Time To Cast Some Rays