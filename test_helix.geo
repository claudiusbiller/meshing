SetFactory("OpenCASCADE");
// --------------------------------------------------
// Parameter (non-dimensional, L0 = b = 20mm)
// --------------------------------------------------
r            = 0.09;          // helix winding radius (d/b)
tube_r       = 0.01375;       // tube cross-section radius (a/b)
pitch        = 3.0;           // Lambda/b
turns        = 4;
height       = turns * pitch;        // 12.0
n            = 100 * turns;          // 400 spline samples
z_0          = 2 * pitch;            // 6.0; vacuum on each end
box_size     = height + 2*z_0;       // 24.0
displacement = 0.09;                  // off-axis offset of helix winding center
dr           = 0.5;                  // gap from helix winding axis to cyl wall
cyl_radius   = displacement + dr;    // 1.0  (matches first file)
mesh_size    = 0.05;
// ==================================================
// HELIX (off-axis, winding center at (displacement, 0))
// ==================================================
p = 1;
start1 = p;
For i In {0:n}
  t = 2*Pi*turns*i/n;
  x = r*Cos(t) + displacement;
  y = r*Sin(t);
  z = height*i/n + z_0;
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
ty = r;
tz = height/(2*Pi*turns);
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
Disk(10) = {r + displacement, 0, z_0, tube_r, tube_r};
Rotate {{ax, ay, az}, {r + displacement, 0, z_0}, angle} { Surface{10}; }
// --------------------------------------------------
// Sweep
// --------------------------------------------------
Extrude { Surface{10}; } Using Wire {1}
// --------------------------------------------------
// Halbkugeln an den Enden
// --------------------------------------------------
x1 = r*Cos(2*Pi*turns) + displacement;
y1 = r*Sin(2*Pi*turns);
z1 = height + z_0;
Sphere(1000) = {x1, y1, z1, tube_r};
Sphere(2000) = {r + displacement, 0, z_0, tube_r};
BooleanUnion(1001) = {Volume{1}; Delete;} {Volume{1000}; Delete;};
BooleanUnion(2001) = {Volume{1001}; Delete;} {Volume{2000}; Delete;};
Cylinder(3000) = {0, 0, 0, 0, 0, box_size, cyl_radius};
BooleanDifference(3001) = {Volume{3000}; Delete;} {Volume{2001};};
// Physical groups
Physical Volume("HELIX_VOL")              = {2001};
Physical Volume("CYLINDER")               = {3001};
Physical Surface("HELIX_SURF")            = {11};
Physical Surface("SPHERICAL_CAPS_SURF")   = {12, 13};
Physical Surface("CYLINDER_SURF")         = {14, 15, 16};
// --------------------------------------------------
// Cleanup
// --------------------------------------------------
Delete { Surface{10}; }
// --------------------------------------------------
// Mesh fields
// --------------------------------------------------
Field[1] = Distance;
Field[1].SurfacesList = {11, 12, 13};
Field[2] = Threshold;
Field[2].InField   = 1;
Field[2].SizeMin   = mesh_size;
Field[2].SizeMax   = 2*mesh_size;
Field[2].DistMin   = 0;
Field[2].DistMax   = 3*r;
Field[3] = Distance;
Field[3].SurfacesList = {14, 15, 16};
Field[4] = Threshold;
Field[4].InField   = 3;
Field[4].SizeMin   = 3*mesh_size;
Field[4].SizeMax   = 3*mesh_size;
Field[4].DistMin   = 0;
Field[4].DistMax   = dr/2;
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