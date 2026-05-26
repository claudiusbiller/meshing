SetFactory("OpenCASCADE");

// --------------------------------------------------
// Parameter (non-dimensional units, L0 = b = 0.02 m)
// --------------------------------------------------
helix_radius  = 0.09;          // d/b = 1.8mm / 20mm
tube_r        = 0.01375;       // a/b = 275um / 20mm
pitch         = 3.0;           // Lambda/b = 60mm / 20mm
num_turns     = 4;
height        = num_turns * pitch;        // 12.0
n             = 100 * num_turns;          // 400 spline samples
z_vac         = 2 * pitch;                // 6.0; vacuum on each end
box_size      = height + 2*z_vac;         // 24.0
cyl_radius    = 1.0;                       // b/b
mesh_size     = 0.05;

// ==================================================
// HELIX
// ==================================================
p = 1;
start1 = p;
For i In {0:n}
  t = 2*Pi*num_turns*i/n;
  x = helix_radius*Cos(t);
  y = helix_radius*Sin(t);
  z = height*i/n + z_vac;
  Point(p) = {x, y, z};
  p = p + 1;
EndFor
end1 = p - 1;
Spline(1) = {start1:end1};
Wire(1) = {1};

// --------------------------------------------------
// Tangent at start
// --------------------------------------------------
tx = 0;
ty = helix_radius;
tz = height/(2*Pi*num_turns);
norm = Sqrt(tx*tx + ty*ty + tz*tz);
nx = tx/norm;
ny = ty/norm;
nz = tz/norm;
ax = -ny;
ay =  nx;
az =  0;
angle = Acos(nz);

// --------------------------------------------------
// Querschnitt
// --------------------------------------------------
Disk(10) = {helix_radius, 0, z_vac, tube_r, tube_r};
Rotate {{ax, ay, az}, {helix_radius, 0, z_vac}, angle} { Surface{10}; }

// --------------------------------------------------
// Sweep
// --------------------------------------------------
Extrude { Surface{10}; } Using Wire {1}

// --------------------------------------------------
// Halbkugeln an den Enden
// --------------------------------------------------
x1 = helix_radius*Cos(2*Pi*num_turns);
y1 = helix_radius*Sin(2*Pi*num_turns);
z1 = height + z_vac;
Sphere(1000) = {x1, y1, z1, tube_r};
Sphere(2000) = {helix_radius, 0, z_vac, tube_r};
BooleanUnion(1001) = {Volume{1}; Delete;} {Volume{1000}; Delete;};
BooleanUnion(2001) = {Volume{1001}; Delete;} {Volume{2000}; Delete;};

Cylinder(3000) = {0, 0, 0, 0, 0, box_size, cyl_radius};
BooleanDifference(3001) = {Volume{3000}; Delete;} {Volume{2001};};

// Physikalische Volumes
Physical Volume("HELIX_VOL")   = {2001};
Physical Volume("CYLINDER")    = {3001};

// Physikalische Surfaces
Physical Surface("HELIX_SURF")            = {11};
Physical Surface("SPHERICAL_CAPS_SURF")   = {12, 13};
Physical Surface("CYLINDER_SURF")         = {14, 15, 16};

// --------------------------------------------------
// Cleanup
// --------------------------------------------------
Delete { Surface{10}; }

// --------------------------------------------------
// Mesh Einstellungen
// --------------------------------------------------
Field[1] = Distance;
Field[1].SurfacesList = {11, 12, 13};
Field[2] = Threshold;
Field[2].InField   = 1;
Field[2].SizeMin   = mesh_size;
Field[2].SizeMax   = 2*mesh_size;
Field[2].DistMin   = 0;
Field[2].DistMax   = 3*helix_radius;

Field[3] = Distance;
Field[3].SurfacesList = {14, 15, 16};
Field[4] = Threshold;
Field[4].InField   = 3;
Field[4].SizeMin   = 3*mesh_size;
Field[4].SizeMax   = 3*mesh_size;
Field[4].DistMin   = 0;
Field[4].DistMax   = helix_radius/2;

Field[5] = Min;
Field[5].FieldsList = {2, 4};
Background Field = 5;

Geometry.NumSubEdges = 1000;
Mesh.MeshSizeFromCurvature = 20;
Mesh.SurfaceFaces = 1;
Mesh.VolumeFaces = 1;
Mesh.Algorithm3D = 1;
Mesh.Optimize = 1;
Mesh.OptimizeNetgen = 1;
Mesh.Smoothing = 20;