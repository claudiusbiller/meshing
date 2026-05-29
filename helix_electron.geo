// this is now foir my electron helix geometry

SetFactory("OpenCASCADE");
// --------------------------------------------------
// Parameter in nondime units like in the solver
// --------------------------------------------------

d = 0.09;           // helix displacement (d_ph/b_ph = 1.8mm / 20mm)    is the same as the radius apparently??? 
turns        = 4;              // number of helix turns inside the box
pitch        = 3.0;            // l_z = l_z_ph/b_ph = 60mm / 20mm
height       = turns * pitch;  // 12.0
n            = 50 * turns;     // spline samples along the helix        
tube_r       = 0.01375;        // wire cross-section radius (a_ph/b_ph = 275um / 20mm)
z_0        = pitch;             // vacuum on each end
box_size   = height + 2*z_0;  // 24.0
b            = 1.0;            // outer cylinder radius (b_ph/b_ph)  

h_wire = tube_r / 4.0;   // ~0.0034, slightly tighter for clean field eval near wire
h_LA   = 0.003;          // 10x finer than before. Elements much smaller than L_A radius
h_far  = 0.08;           // unchanged, vacuum bulk can be coarse

LA  = 0.0346;            // analytic L_A in units of b (= 288 μm / 20 mm) 
// ==================================================
// DOPPELHELIX 
// ==================================================

p = 1; // globaler Punktzähler

// --------------------------------------------------
// HELIX 1 (unten starten → dann nach oben winden)
// --------------------------------------------------

start_pt = p;

// ---------- HELIX ----------
For i In {0:n}
  t = 2*Pi*turns*i/n;

  x = d*Cos(t) ;    
  y = d*Sin(t);
  z = height*i/n + z_0;

  Point(p) = {x,y,z};
  p = p + 1;
EndFor

end_pt = p - 1;

Spline(1) = {start_pt:end_pt};
Wire(1) = {1};

// --------------------------------------------------
// Tangente
// --------------------------------------------------

tx = 0;
ty = d;
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

Disk(10) = {d, 0, z_0, tube_r, tube_r};
Rotate {{ax, ay, az}, {d, 0, z_0}, angle} { Surface{10}; }

// --------------------------------------------------
// Sweep the disk along the helix
// --------------------------------------------------
Extrude { Surface{10}; } Using Wire {1}

// --------------------------------------------------
// Hemispherical caps at the two ends
// --------------------------------------------------
x_end = d*Cos(2*Pi*turns);
y_end = d*Sin(2*Pi*turns);
z_end = height + z_0;

Sphere(1000) = {x_end, y_end, z_end, tube_r};
Sphere(2000) = {d, 0, z_0, tube_r};

BooleanUnion(1001) = {Volume{1};   Delete;} {Volume{1000}; Delete;};
BooleanUnion(2001) = {Volume{1001};Delete;} {Volume{2000}; Delete;};

// --------------------------------------------------
// Outer vacuum cylinder, subtract the wire from it
// --------------------------------------------------
Cylinder(3000) = {0, 0, 0, 0, 0, box_size, b};
BooleanDifference(3001) = {Volume{3000}; Delete;} {Volume{2001};};

// --------------------------------------------------
// Physical groups
// --------------------------------------------------
Physical Volume("HELIX_VOL")              = {2001};
Physical Volume("CYLINDER")               = {3001};
Physical Surface("HELIX_SURF")            = {11};
Physical Surface("SPHERICAL_CAPS_SURF")   = {12, 13};
Physical Surface("CYLINDER_SURF")         = {14, 15, 16};

Delete { Surface{10}; }

// ==================================================
// Mesh sizing fields
// ==================================================
// Field 1+2: fine size near the wire surface (helix + caps)
Field[1] = Distance;
Field[1].SurfacesList = {11, 12, 13};

Field[2] = Threshold;
Field[2].InField   = 1;
Field[2].SizeMin   = h_wire;
Field[2].SizeMax   = h_far;
Field[2].DistMin   = 0;
Field[2].DistMax   = 3*tube_r;

// Field 3+4: intermediate-to-fine sizing near the z-axis (L_A region)
// Distance from the z-axis = sqrt(x^2 + y^2). Use a MathEval field.
Om0 = 2*Pi/pitch;

Field[3] = MathEval;
Field[3].F = Sprintf(
  "Sqrt((x - %g*Cos(%g*(z-%g)))^2 + (y - %g*Sin(%g*(z-%g)))^2)",
  LA, Om0, z_0, LA, Om0, z_0
);

Field[4] = Threshold;
Field[4].InField = 3;
Field[4].SizeMin = h_LA;
Field[4].SizeMax = h_far;
Field[4].DistMin = 0;
Field[4].DistMax = 0.5*(d - LA);   // = 0.028, half the gap to the wire

// Field 5+6: coarse size near the outer cylinder wall (don't need precision there)
Field[5] = Distance;
Field[5].SurfacesList = {14, 15, 16};

Field[6] = Threshold;
Field[6].InField   = 5;
Field[6].SizeMin   = h_far;
Field[6].SizeMax   = h_far;
Field[6].DistMin   = 0;
Field[6].DistMax   = 0.5;

// Take the minimum
Field[10] = Min;
Field[10].FieldsList = {2, 4, 6};
Background Field = 10;

// --------------------------------------------------
// Mesh options
// --------------------------------------------------
Geometry.NumSubEdges = 1000;
Mesh.MeshSizeFromCurvature = 20;
Mesh.MeshSizeFromPoints    = 0;   // rely on fields, not point sizes
Mesh.MeshSizeExtendFromBoundary = 0;
Mesh.SurfaceFaces = 1;
Mesh.VolumeFaces  = 1;
Mesh.Algorithm3D  = 1;
Mesh.Optimize     = 1;
Mesh.OptimizeNetgen = 1;
Mesh.Smoothing    = 20;
