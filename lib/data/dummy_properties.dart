import '../models/property.dart';

/// Local dummy dataset standing in for a future `/api/properties`
/// endpoint. Swapping this out later just means replacing this
/// static list with a repository call that returns `List<Property>`.
///
/// Coordinates are real Yogyakarta-area locations so the venues show
/// up correctly on the actual map / satellite imagery.
final List<Property> dummyProperties = [
  const Property(
    id: 'p1',
    name: 'Grand Ballroom',
    location: 'Malioboro, Yogyakarta',
    type: 'Ballroom',
    capacity: 500,
    area: 800,
    latitude: -7.7928,
    longitude: 110.3654,
    description:
        'An elegant ballroom with high ceilings and crystal chandeliers, '
        'ideal for weddings, galas, and large corporate events.',
  ),
  const Property(
    id: 'p2',
    name: 'Convention Hall',
    location: 'Jogja Expo Center area, Yogyakarta',
    type: 'Convention Hall',
    capacity: 1000,
    area: 1500,
    latitude: -7.8117,
    longitude: 110.3922,
    description:
        'A large, flexible convention hall designed for exhibitions, '
        'conferences, and multi-day events with modular seating.',
  ),
  const Property(
    id: 'p3',
    name: 'Outdoor Venue',
    location: 'Kalasan, Sleman, Yogyakarta',
    type: 'Outdoor',
    capacity: 300,
    area: 1200,
    latitude: -7.7511,
    longitude: 110.4406,
    description:
        'An open-air garden venue surrounded by lush greenery, perfect '
        'for sunset ceremonies and festival-style gatherings.',
  ),
  const Property(
    id: 'p4',
    name: 'Exhibition Area',
    location: 'Sleman, Yogyakarta',
    type: 'Exhibition',
    capacity: 800,
    area: 2000,
    latitude: -7.7706,
    longitude: 110.3789,
    description:
        'A column-free exhibition space with adaptable lighting rigs, '
        'built for trade shows and product launches.',
  ),
  const Property(
    id: 'p5',
    name: 'Meeting Room A',
    location: 'Kraton area, Yogyakarta',
    type: 'Meeting Room',
    capacity: 50,
    area: 100,
    latitude: -7.8054,
    longitude: 110.3644,
    description:
        'A compact, well-lit meeting room equipped for board meetings, '
        'workshops, and small team offsites.',
  ),
  const Property(
    id: 'p6',
    name: 'Event Space',
    location: 'Condongcatur, Yogyakarta',
    type: 'Event Space',
    capacity: 250,
    area: 450,
    latitude: -7.7492,
    longitude: 110.3897,
    description:
        'A versatile indoor event space with movable partitions, '
        'suited for pop-up events, launches, and mid-size gatherings.',
  ),
  // The only venue with a real 3D model so far (exported from Blender).
  // TODO: location, coordinates, capacity and description below are
  // placeholders - replace them with the real data. The marker is
  // currently placed at the initial map centre so it is easy to spot.
  const Property(
    id: 'p7',
    name: 'Teras Kantor TechnoGIS',
    location: 'TechnoGIS Office',
    type: 'Event Space',
    capacity: 30,
    area: 110, // rough footprint of the 3D model (about 11 m x 10 m)
    latitude: -7.7830,
    longitude: 110.3900,
    description:
        'An office terrace with brick flooring, wooden furniture, and '
        'string lights - a relaxed setting for small gatherings and '
        'networking events.',
    modelAssetPath: 'assets/models/TerasKantorTechnoGIS_web.glb',
  ),
];
