SetFactory("OpenCASCADE");

helix_radius = 9.0;       // d/b * 100
tube_r       = 1.375;     // a/b * 100
pitch        = 300.0;     // Lambda/b * 100
num_turns    = 4;
height       = num_turns * pitch;
n            = 100 * num_turns;
z_vac        = 2 * pitch;
box_size     = height + 2*z_vac;
cyl_radius   = 100.0;     // b/b * 100

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

tx = 0;
ty = helix_radius;
tz = height/(2*Pi*num_turns);
norm = Sqrt(tx*tx + ty*ty + tz*tz);
nx = tx/norm; ny = ty/norm; nz = tz/norm;
ax = -ny;
ay =  nx;
az =  0;
angle = Acos(nz);

Disk(10) = {helix_radius, 0, z_vac, tube_r, tube_r};
Rotate {{ax, ay, az}, {helix_radius, 0, z_vac}, angle} { Surface{10}; }

Extrude { Surface{10}; } Using Wire {1}

// End caps
x1 = helix_radius*Cos(2*Pi*num_turns);
y1 = helix_radius*Sin(2*Pi*num_turns);
z1 = height + z_vac;
Sphere(1000) = {x1, y1, z1, tube_r};
Sphere(2000) = {helix_radius, 0, z_vac, tube_r};

BooleanUnion(1001) = {Volume{1}; Delete;} {Volume{1000}; Delete;};
BooleanUnion(2001) = {Volume{1001}; Delete;} {Volume{2000}; Delete;};

// Outer cylinder, subtract the helix wire
Cylinder(3000) = {0, 0, 0, 0, 0, box_size, cyl_radius};
BooleanDifference(3001) = {Volume{3000}; Delete;} {Volume{2001};};

// Physical groups
Physical Volume("HELIX_VOL", 1)            = {2001};
Physical Volume("CYLINDER", 2)             = {3001};
Physical Surface("HELIX_SURF", 3)          = {11};
Physical Surface("SPHERICAL_CAPS_SURF", 4) = {12, 13};
Physical Surface("CYLINDER_SURF", 5)       = {14, 15, 16};


// Mesh fields
mesh_fine   = tube_r / 2;
mesh_coarse = 10.0;

Field[1] = Distance;
Field[1].SurfacesList = {11, 12, 13};
Field[2] = Threshold;
Field[2].InField   = 1;
Field[2].SizeMin   = mesh_fine;
Field[2].SizeMax   = mesh_coarse;
Field[2].DistMin   = tube_r;
Field[2].DistMax   = 3 * helix_radius;

Field[3] = Distance;
Field[3].SurfacesList = {14, 15, 16};
Field[4] = Threshold;
Field[4].InField   = 3;
Field[4].SizeMin   = mesh_coarse;
Field[4].SizeMax   = mesh_coarse;
Field[4].DistMin   = 0;
Field[4].DistMax   = cyl_radius;

Field[5] = Min;
Field[5].FieldsList = {2, 4};
Background Field = 5;

Mesh.MeshSizeExtendFromBoundary = 0;
Mesh.MeshSizeFromPoints = 0;
Mesh.MeshSizeFromCurvature = 12;