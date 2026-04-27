🧱 EVANOPOLIS Modular Diorama — Prompt System
🎯 Goal

Generate 6 coherent low-poly diorama images representing energy sources, suitable for image-to-3D conversion, with:

simple geometry
clear silhouettes
minimal noise
consistent style


🧩 MASTER PROMPT (use in ALL generations)
A low-poly 3D modular diorama tile for a strategy board game.

Style:
- minimal low-poly geometry
- clean, simple shapes
- no small details, no clutter
- no textures, only flat colors with subtle gradients
- soft neutral daylight lighting
- soft shadows
- everything grounded, no floating objects

Composition:
- slightly asymmetrical
- main subject is slightly off-center
- clear silhouette, easy to read
- one strong hero element

Base:
— regular octagonal base with exactly 8 equal-length straight sides 
— a perfect geometric octagon, like a stop sign shape. The octagon should be flat, thick, and uniform with sharp edges. NOT a rounded shape, NOT a square with cut corners — a true standard octagon.
- hard-surface board game tile
- very clean and minimal base geometry
- base is not the focus and should be easy to replace
- flat top surface



Constraints:
- no people
- no vehicles
- no roads
- no text or logos
- no micro details or noise
- the base must be a perfect regular octagon viewed from above

Camera:
- three-quarter isometric view
- centered framing
- white background


⚡ TILE PROMPTS

Append ONE of these to the master prompt.


💧 1. Ciudad del Este — Hydroelectric
Scene:
A stylized hydroelectric dam as the main element.

Details:
- large geometric concrete dam
- water reservoir behind the dam
- water flowing through or over the dam
- a few simple rocks
- minimal lush greenery

Color mood:
- soft blues and gentle greens
- calm and flowing

🌋 2. El Salvador — Geothermal / Volcano
Scene:
An active volcano as the central hero element.

Details:
- simple مخروط volcano shape
- glowing lava in the crater
- small lava flow
- a few steam vents
- minimal tropical vegetation
- small geothermal facility elements

Color mood:
- warm reds and oranges
- contrast with tropical greens
- energetic and volcanic

☢️ 3. Angra dos Reis — Nuclear
Scene:
A nuclear power plant as the main element.

Details:
- two large cooling towers
- soft stylized steam clouds
- a small industrial building
- simple shoreline water
- minimal greenery

Color mood:
- light grays
- soft yellow accents
- clean industrial look

☀️ 4. Atacama — Solar
Scene:
A solar farm in a desert.

Details:
- a few large tilted solar panel arrays
- flat desert terrain
- a few rocks
- minimal cactus plants
- small simple buildings

Color mood:
- sandy yellows
- soft sky blue accents
- bright and arid

❄️ 5. Irkutsk — Cold Hydro / Icy Geothermal
Scene:
A cold landscape with icy geothermal vents.

Details:
- snow-covered terrain
- icy vents emitting soft steam
- small frozen water area
- minimal industrial elements
- a few snow-covered rocks

Color mood:
- icy blues
- muted grays
- cold and sparse

🌬️ 6. Patagonia — Wind
Scene:
A wind energy landscape.

Details:
- two or three large wind turbines
- wide open terrain
- very sparse vegetation
- small simple structure
- optional simple fence

Color mood:
- soft greens
- pale blues
- open and airy


🧠 Practical Tips (important)
🔁 Generate multiple variations

For each tile:

generate 3–5 images
pick the cleanest one
🎯 What to look for

Choose images with:

clean silhouette
minimal geometry noise
readable shapes
simple base
🧱 Blender step (your final pipeline)
Delete generated base
Replace with your perfect octagon mesh
Align + scale
Export clean game asset
🚀 Optional (advanced mode)

If later you want cleaner meshes:

👉 remove the base entirely:

floating diorama terrain chunk, no base

Then build all bases in Blender.

🧾 Final Verdict

This setup gives you:

consistency ✅
simplicity ✅
mesh-friendly outputs ✅
production-ready pipeline ✅

If you want next step, I can help you:

define a Blender snapping template for all 6 tiles
or tune prompts specifically for your target generator (Midjourney, DALL·E, etc.)

You're very close to a full asset pipeline now 👍
