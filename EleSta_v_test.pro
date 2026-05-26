
Group {
  // Geometrie (aus dem .msh)
  HelixSurf = Region[3]; // HELIX_SURF
  sphericalCapsSurf = Region[4]; // SPHERICAL_CAPS_SURF
  BoxSurf  = Region[5]; // CYLINDER_SURF

  HelixVol  = Region[1]; // HELIX_VOL
  VacuumVol  = Region[2]; // CYLINDER

  Vol_Ele = Region[{HelixVol, VacuumVol}];
  Vol_Vacuum = Region[{VacuumVol}];
  Sur_Dirichlet_Ele = Region[{HelixSurf, sphericalCapsSurf, BoxSurf}];

  Dom_Hgrad_v_Ele = Region[{Vol_Ele, Sur_Dirichlet_Ele}];
}

Function {
  eps0 = 8.8541878128e-12;

  // Materialeigenschaften
  //epsilon[HelixVol] = 1.0e6 * eps0;  // Kupfer, als guter Leiter
  epsilon[HelixVol] = 1.0 * eps0;  // Kupfer, als guter Leiter
  epsilon[VacuumVol] = 1.0 * eps0;    // Luft
  epsilon[HelixSurf] = 1.0 * eps0;
  epsilon[sphericalCapsSurf] = 1.0 * eps0;
  epsilon[BoxSurf] = 1.0 * eps0;
}

Constraint {
  { Name Dirichlet_Ele; Type Assign;
    Case {
      { Region HelixSurf; Value 1.; }
      { Region sphericalCapsSurf;  Value 1.; }
      { Region BoxSurf;  Value 0.; }
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
  { Name Vol;
    Case { { Region All; Jacobian Vol; } }
  }
  { Name Sur;
    Case { { Region All; Jacobian Sur; } }
  }
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
      { Name capacitance; Value {
          Integral {
            [ epsilon[] * SquNorm[{d v}] ];
            In Vol_Vacuum; Jacobian Vol; Integration Int;
          }
        }
      }
      { Name normals; Value {
          Term { [ Normal[]]; In HelixSurf; Jacobian Sur; }
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

      Print[ v, OnGrid { $A, $B, $C }
            { -15:15:1.0, -15:15:1.0, 0:2400:20 },
            File "V_grid.txt", Format SimpleTable ];
    }
  }
}