// ==================================================
// Electrostatic problem on the helix waveguide
// Solves in vacuum only; wire is a Dirichlet boundary.
// Solution V is the unit-voltage Green's function:
//   V_physical(x) = V_0_ph * V_solved(x)
// ==================================================

Group {
  // Physical entities from helix.geo
  HelixSurf         = Region[3];   // HELIX_SURF       (wire side surface)
  SphericalCapsSurf = Region[4];   // SPHERICAL_CAPS_SURF
  BoxSurf           = Region[5];   // CYLINDER_SURF    (outer cylinder + end disks)
  HelixVol          = Region[1];   // HELIX_VOL        (interior of wire, not solved)
  VacuumVol         = Region[2];   // CYLINDER         (vacuum domain, this is where we solve)

  // Solve only in vacuum
  Vol_Ele           = Region[{VacuumVol}];

  // Dirichlet boundaries enclosing the vacuum domain
  Sur_Dirichlet_Ele = Region[{HelixSurf, SphericalCapsSurf, BoxSurf}];

  // Full Hgrad domain (volume + boundary nodes)
  Dom_Hgrad_v_Ele   = Region[{Vol_Ele, Sur_Dirichlet_Ele}];
}

Function {
  eps0 = 8.8541878128e-12;
  epsilon[VacuumVol]         = 1.0 * eps0;
  epsilon[HelixSurf]         = 1.0 * eps0;
  epsilon[SphericalCapsSurf] = 1.0 * eps0;
  epsilon[BoxSurf]           = 1.0 * eps0;
}

Constraint {
  { Name Dirichlet_Ele; Type Assign;
    Case {
      { Region HelixSurf;         Value 1.; }
      { Region SphericalCapsSurf; Value 1.; }
      { Region BoxSurf;           Value 0.; }
    }
  }
}

FunctionSpace {
  { Name Hgrad_v_Ele; Type Form0;
    BasisFunction {
      { Name sn; NameOfCoef vn; Function BF_Node;
        Support Dom_Hgrad_v_Ele; Entity NodesOf[All]; }
    }
    Constraint {
      { NameOfCoef vn; EntityType NodesOf; NameOfConstraint Dirichlet_Ele; }
    }
  }
}

Jacobian {
  { Name Vol; Case { { Region All; Jacobian Vol; } } }
  { Name Sur; Case { { Region All; Jacobian Sur; } } }
}

Integration {
  { Name Int;
    Case {
      { Type Gauss;
        Case {
          { GeoElement Tetrahedron; NumberOfPoints 4; }
          { GeoElement Triangle;    NumberOfPoints 4; }
        }
      }
    }
  }
}

Formulation {
  { Name Electrostatics_v; Type FemEquation;
    Quantity {
      { Name v; Type Local; NameOfSpace Hgrad_v_Ele; }
    }
    Equation {
      Integral { [ epsilon[] * Dof{d v} , {d v} ];
                 In Vol_Ele; Jacobian Vol; Integration Int; }
    }
  }
}

Resolution {
  { Name EleSta_v;
    System {
      { Name Sys_Ele; NameOfFormulation Electrostatics_v; }
    }
    Operation {
      Generate[Sys_Ele];
      Solve[Sys_Ele];
      SaveSolution[Sys_Ele];
    }
  }
}

PostProcessing {
  { Name EleSta_v; NameOfFormulation Electrostatics_v;
    Quantity {
      { Name v; Value {
          Term { [ {v} ]; In Dom_Hgrad_v_Ele; Jacobian Vol; }
        }
      }
      { Name e; Value {
          Term { [ -{d v} ]; In Dom_Hgrad_v_Ele; Jacobian Vol; }
        }
      }
    }
  }
}

PostOperation {
  { Name Map; NameOfPostProcessing EleSta_v;
    Operation {
      Print[ v, OnElementsOf Vol_Ele, File "potential.pos" ];
      Print[ e, OnElementsOf Vol_Ele, File "efield.pos" ];

      // Grid output for downstream Python use.
      // x, y span the cylinder diameter [-1, 1]; z spans the box [0, 24].
      // Resolution: 0.02 in x,y => 101 points each; 0.05 in z => 481 points.
      // Total: 101 * 101 * 481 ≈ 4.9M samples. Adjust if too heavy.
      Print[ v, OnGrid { $A, $B, $C }
            //{ -1.0:1.0:0.02, -1.0:1.0:0.02, 0:24:0.05 },
            { -0.3:0.3:0.02, -0.3:0.3:0.02, 0:24:0.05 },
            File "V_grid.txt", Format SimpleTable ];
    }
  }
}
