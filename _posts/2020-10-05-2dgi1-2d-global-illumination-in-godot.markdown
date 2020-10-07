---
layout: post
title:  "2DGI #1 - Global Illumination in Godot"
date:   2020-10-05 00:00:00 +0000
categories: none
---

Hello.

This is the first of a series of blog posts I plan to write, breaking apart the algorithms and implementation of a custom 2D global illumination (or raytracing, or radiosity, or whatever you want to call it) lighting engine in [Godot](https://godotengine.org/).

I want to do more than just give you the code and tell you where to put it (after all, [i've made the source available](https://github.com/samuelbigos/godot_2d_global_illumination)), Amit Patel's [Red Blob Games](https://www.redblobgames.com/) has proven an invaluable resource in many of my game dev ventures, and my hope is that this series, in some small way, emulates the way he carves up complex theories into bite-sized and beatiful morsels of knowledge. That is to say I'll be talking less about the Godot implementation and more about the algorithms and process such that you can go away and implement it in whichever framwork you'd like.

Having said _that_, I will come clean and tell you I knew next to nothing about any of these subjects before around three months ago, so I am hardly the authority on the matter. However, around that time I did a _lot_ of Googling and found only smatterings of info/examples. The most useful resource was [/u/toocanzs](https://www.reddit.com/r/gamedev/comments/91mwrh/infinity_2d_lights_with_shadows_gi/e2zts0a/) who wrote a [shadertoy](https://www.shadertoy.com/view/lltcRN) example of the technique (which was itself inspired by another reddit user's example). It's safe to say without this as a jumping-board my implementation wouldn't exist. Apart from this, I only found a few other people who have done something similar - two of the more inspiring being [Thomas Diewald's animations](https://vimeo.com/diwi) and [Andy Duboc's images](http://andbc.co/2d_radiosity/) - but nothing with implementation details.

_Come on get to the point._ Ok fine.

![Forza Street](/assets/2020-10-05-2dgi1-2d-global-illumination-in-godot/1.png "Forza Street")

## The Point

The point is that I'm lazy, and I want a lighting system that _just works_ without me, the curator, having to worry about placing lights, probes, occlusion volumes, dealing with light blending, shadowing artifacts, yada yada, and what better way to achieve that than do it the way it _just works_ in real life with actual rays of photons (unless you believe a certain outcome of the [Simulation Argument](https://www.simulation-argument.com/simulation.html)). Of course, I also want it to look amazing and unlike any other game out there. And I've looked, no other game I've found is doing this (probably because it's _really fucking hard_ - more on this later). It also needs to run well.

**Tl;dr**
* It needs to run well on medium spec hardware. No point in looking pretty if it makes the game unplayable.
* It needs to look good (bounced light, shadows, colour blending).
* It should make curation (i.e. levels, environments, _content_) easier, not harder, compared to more standard lighting techniques.

Let's get started...

## The Data

_"The purpose of all programs, and all parts of those programs, is to transform data from one form to another."_ - Jackie Chan, probably (actually I lied it was [Mike Acton](https://www.youtube.com/watch?v=rX0ItVEVjHc))

Let's start by looking at the data we're putting in, and the data we expect to get out the other end, so we can properly reason about the transform we need to do in the middle.

**In** - There are two entities we care about: _Emitters_ and _Occluders_. We care about their position, rotation, shape, emissive (brightness) and colour for emitters, albedo (reflectivity) and colour for occluders.

**Out** - A brightness and colour value for each pixel in the scene, representing the amount of light gathered by that pixel from surrounding emissive surfaces.

We also need to consider the **hardware** (or platform) we're running on. My goal when developing this technique was to eventually make a game that used it as a lighting engine, and the target platform would be PCs with medium-to-high spec graphics cards. This means we have access to the GPU and the potentially powerful parallel pixel processing proficiency (or [PPPPPP](https://soundcloud.com/james-l-jackson/sets/pppppp-the-vvvvvv-soundtrack), soundtrack to the amazing [VVVVVV](https://store.steampowered.com/app/70300/VVVVVV/) by Terry Cavanagh) it has, which we will utilise fully to transform our data from A to B.

_If you're new to shaders or want a refresher, check out [The Book of Shaders](https://thebookofshaders.com/). All the algorithms we'll be exploring are done on the GPU in shader language so some knowledge is expected._

Since the common data format of the GPU is the humble texture, we'll be storing our input data in texture format. Thankfully it just so happens that most game engines come equipped with a simple method of storing spatial and colour information about 2D entities in texture data, it's done by drawing a sprite to the screen! Well, that was easy, let's move on to the fun stuff.

## Hang on...

Ok, there's an important thing we need to do first. By default, when you draw a sprite in most engines


{% highlight ruby  %}
def print_hi(name)
  puts "Hi, #{name}"
end
print_hi('Tom')
#=> prints 'Hi, Tom' to STDOUT.
{% endhighlight %}