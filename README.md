#Welcome to my procedural terrain addon

So this is a project ive been working on for about 5 months now, I am pretty proud of its release however it will likely not be 100% perfect, please report any bugs you find.

If you are experiencing crashing, before reporting it, please try and switch to the 64x branch of gmod as it is more stable. Source physics isn't exactly happy when generating map wide objects, this addon is quite literally pushing source to its limits.

##H#ow to use:
- Go to gm_flatgrass, this mod replaces it with the custom terrain!
- Access the custom menu by typing terrain_menu in console, or by going into the utilities tab and clicking the button.
- You must be superadmin to use the menu!
- There are plenty of options in the menu, I will just let you figure out how to use its features, it should be pretty simple.
- The "submit button" actually changes the terrain, this is important, do not mix it up with the "test changes" button, which just alters the visual for your viewing.
- As of now you cannot save your changes for later use, I will hopefully implement a save / load feature in the future.

###Custom materials that can be used with blendmap:
- gm_construct/construct_sand
- ground/snow01 (may need ep2, not sure)
- hunter/myplastic
- phoenix_storms/ps_grass
- most materials from material tool
- most .vmt files on your client

###Features
- Better performance than other displacement forest maps such as gm_fork
- Imported models, no dependeces required!
- All chunk, blending, foliage, and tree shading complete in under 10 seconds (with my specs)
- Lightmap calculations complete in under a minute (with my specs)
- Lakes / Water System
- Custom entity that acts as a displacement
- Custom lightmap with generated shading
- Customizable blendmap between 2 textures
- Custom Lighting
- No uv/texture stretching
- Trees & grass foliage
- Lots of options in the menu including a optional user-created LUA heightmap function
- Mutliplayer Support

###Bugs I am aware of:
- Tree and Rock collision can be wonky with high ping
- Having a weak computer and being on the 32 bit branch of gmod may cause crashes, easiest solution is to switch to 64 bit if you haven't already
edit: I implemented a possible working quickfix for this issue by simply not generating client physics if you're on 32 bit. (but either way, please switch to 64 bit)

Special Thanks:
DefaultOS - LOTS of help from this guy, helped with implementation of a lightmap & blend texture, as well as optimizations reguarding to trees, thx a lot man
Impulse - helped import models / water material

extra stuff:
discord: https://discord.gg/cmQvg2AHgP
patreon: https://www.patreon.com/meegmod
pls donate i need a new ssd, current one is failing :(

