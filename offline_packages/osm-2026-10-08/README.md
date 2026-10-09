# Optional OSM city packages

Derived regional databases © OpenStreetMap contributors, ODbL 1.0.
Full license and source/hash metadata accompany each package. Source:
https://download.geofabrik.de/asia/gcc-states.html

Snapshot: 2026-10-08T20:21:06Z. Input SHA-256:
37ddf4a1c62bf695297173744a9ff7524ae51cd4c421a75cfa5de110b80166eb

The extracted databases are distributed under ODbL 1.0. This directory supplies
the derived data in reusable form, not only a rendered image. Each city has
simplified roads and larger building outlines. Native MapLibre renders the
local geometry; there are no public tile server, glyph or sprite requests.
Some OSM multipolygon relations and small buildings are outside this extractor's
scope. This is a regional overview, not survey data or pedestrian navigation.

The travel catalog has 2,928 named community records. `nameTr` keeps the available
source name (Turkish/English/local); no Turkish translation is invented.
`isSourceSnapshot=true` distinguishes source collection time from field checking.
Phone numbers/opening hours are not imported as independently verified facts.
No sacred boundary, closed/open gate, current crowd or approved pilgrimage route
is inferred from OSM coordinates.

Regenerate with `tools/build_osm_travel.py` and `osmium==4.2.0` (optional build
dependency, not a mobile runtime dependency). New data gets a new directory and
manifest pins; never replace an already pinned version silently.
