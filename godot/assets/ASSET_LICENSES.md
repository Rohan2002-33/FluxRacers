# Third-party asset licenses

These assets are included under the Creative Commons CC0 1.0 Universal
dedication. Poly Haven states that its asset library is CC0; attribution is not
required. Credits are listed here for provenance.

License: <https://creativecommons.org/publicdomain/zero/1.0/>
Poly Haven license information: <https://polyhaven.com/license>

| Asset | Type | Creator | Source |
| --- | --- | --- | --- |
| Asphalt Track | 1K diffuse, OpenGL normal, and roughness maps | Dimitrios Savva | <https://polyhaven.com/a/asphalt_track> |
| Aerial Grass Rock | 1K diffuse, OpenGL normal, and roughness maps | Rob Tuytel | <https://polyhaven.com/a/aerial_grass_rock> |
| Shrub 03 | 1K glTF model and textures | Rico Cilliers | <https://polyhaven.com/a/shrub_03> |
| Shrub 04 | 1K glTF model and textures | Rico Cilliers | <https://polyhaven.com/a/shrub_04> |

The downloaded files were checked against the MD5 digests published by the
Poly Haven asset API. Only the listed files from these asset packages are
included.

## Project-authored environment geometry

The coconut and date palms beside the racing road are generated from original
procedural 3D geometry in `../scripts/race_palm_tree.gd`; they are not
third-party downloads. Their tapered trunks, individual fronds, and fruit
clusters are built as mesh surfaces at runtime. No external palm model or
unverified asset license is included.

## Vehicle

The race vehicle uses the Car Concept glTF sample, optimized by the Khronos
Group from a public-domain concept-car model by Unity Fan. The Khronos sample
asset is licensed CC BY 4.0, excluding Khronos and 3D Commerce logos:

- Creator: Eric Chadwick, 2024; Darmstadt Graphics Group GmbH.
- Source: <https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/CarConcept>
- Original public-domain model: <https://sketchfab.com/3d-models/free-concept-car-004-public-domain-cc0-4cba124633eb494eadc3bb0c4660ad7e>
- License: <https://creativecommons.org/licenses/by/4.0/>
- Required attribution: "Car Concept" by Eric Chadwick / Darmstadt Graphics Group GmbH, CC BY 4.0; based on the public-domain concept-car model by Unity Fan.

The game removes the steering emblem and license-plate nodes from the imported
scene so excluded logos and trademarks are not rendered. The GLB's scene
orientation and scale are adapted for the racing track. The runtime uses a
build-time optimized scene generated from this source with
`../tools/bake_race_assets.gd`; this keeps the same geometry and Garage paint
support without merging the source model's many meshes on the phone.

## Traffic vehicles

Selected 3D vehicles and their shared color atlas are from Kenney's Car Kit 3.1
(created April 2, 2026). The package is dedicated to the public domain under
CC0 1.0; attribution is not required. The included models are used as textured,
GPU-instanced traffic, with each vehicle fitted to its own collision dimensions.

- Creator: Kenney.
- Source: <https://kenney.nl/assets/car-kit>
- License: <https://creativecommons.org/publicdomain/zero/1.0/>
- Included formats: glTF Binary (GLB) and the package's `Textures/colormap.png`.
- Selected models: ambulance, delivery van, fire truck, garbage truck,
  sports hatchback, police cruiser, race car, sports sedan, luxury SUV, SUV,
  taxi, flatbed truck, delivery truck, and passenger van.
  The source GLBs are merged and dimensioned into the runtime `.res` meshes by
  `../tools/bake_race_assets.gd`; these generated resources retain the CC0 atlas
  and are shipped alongside the source files.

Race music, engine, road ambience, and horn samples are original project-authored
audio assets; no third-party sound recordings are included.
