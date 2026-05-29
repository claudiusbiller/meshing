"""
Load V_grid.txt produced by GetDP, reshape to a 3D array, mask points
inside the wire, and sanity-check against the analytic log potential.

Geometry (dimensionless, L_0 = b_ph = 20 mm):
  - Outer cylinder radius b = 1.0
  - Wire winding radius   d = 0.09  (around z-axis)
  - Wire cross-section radius a = 0.01375
  - Helix pitch l_z = 3.0, 4 turns from z = z_pad = 6 to z = 18.
  - Box extends z in [0, 24]; padding on either side of the helix.
"""

from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

# --- Geometry parameters (must match helix.geo) ---
d    = 0.09
a    = 0.01375
b    = 1.0
l_z  = 3.0
turns = 4
z_pad = 2 * l_z          # 6.0
height = turns * l_z     # 12.0
box_length = height + 2 * z_pad   # 24.0
omega_0 = 2 * np.pi / l_z

# --- Grid spec (must match the OnGrid line in helix.pro) ---
x_min, x_max, dx = -0.3, 0.3, 0.02
y_min, y_max, dy = -0.3, 0.3, 0.02
z_min, z_max, dz =  0.0, 24.0, 0.05

# Build the axis arrays exactly as GetDP did.
# GetDP's range spec a:b:s gives points a, a+s, a+2s, ... up to the largest <= b.
def gmsh_range(lo, hi, step):
    n = int(round((hi - lo) / step)) + 1
    return lo + step * np.arange(n)

# --- Load V_grid.txt ---
fname = Path("V_grid.txt")
data = np.loadtxt(fname)
print(f"Loaded {data.shape[0]} rows from {fname}")

# Extract actual axes from the data (handles GetDP's half-open upper bound).
x_axis = np.unique(data[:, 0])
y_axis = np.unique(data[:, 1])
z_axis = np.unique(data[:, 2])
Nx, Ny, Nz = len(x_axis), len(y_axis), len(z_axis)
print(f"Grid shape: ({Nx}, {Ny}, {Nz}) = {Nx*Ny*Nz} points")
assert data.shape[0] == Nx * Ny * Nz, "Data is not on a regular grid."

# Columns: x y z V. GetDP's OnGrid varies z fastest, then y, then x.
V = data[:, 3].reshape(Nx, Ny, Nz)

# --- Mask points inside the wire ---
# Wire centerline at z is at (d*cos(omega_0*(z-z_pad)), d*sin(omega_0*(z-z_pad))).
# A grid point (x, y, z) is inside the wire if its distance to the centerline
# (in 3D) is less than `a`. For a thin tube and small `a`, the cylindrical
# distance to the centerline at the same z is a good approximation.
X, Y, Z = np.meshgrid(x_axis, y_axis, z_axis, indexing='ij')
# Helix centerline coordinates at each z (only valid in the helix region).
in_helix_region = (Z >= z_pad) & (Z <= z_pad + height)
phi = omega_0 * (Z - z_pad)
xc = d * np.cos(phi)
yc = d * np.sin(phi)
r_to_wire = np.sqrt((X - xc)**2 + (Y - yc)**2)
inside_wire = in_helix_region & (r_to_wire < a)
print(f"Grid points inside wire: {inside_wire.sum()} "
      f"({100*inside_wire.sum()/V.size:.2f}% of total)")

V_masked = np.where(inside_wire, np.nan, V)

# --- Compare against analytic log potential (in the bulk) ---
# Analytic: V_ana = log(r') / log(a), where r' is distance to the wire
# centerline. This gives V = 1 at r' = a (wire surface) and V = 0 at r' = 1.
# (It assumes a thin wire inside an axisymmetric outer cylinder, which is
# only really valid if the helix is well-resolved in the longitudinal sense
# and we're not too close to the wire. It's a sanity check, not ground truth.)
with np.errstate(divide='ignore', invalid='ignore'):
    V_analytic = np.log(r_to_wire) / np.log(a)
V_analytic = np.where(in_helix_region, V_analytic, np.nan)

# --- Diagnostic plots ---
# 1. z-slice at mid-box (z = 12), showing V and the wire position.
z_mid = z_pad + height / 2     # 12.0
k_mid = int(round((z_mid - z_min) / dz))
print(f"Mid-box slice at z = {z_axis[k_mid]:.3f} (k = {k_mid})")

fig, axes = plt.subplots(1, 3, figsize=(15, 4.5))
vmin, vmax = 0, 1

im0 = axes[0].pcolormesh(x_axis, y_axis, V_masked[:, :, k_mid].T,
                          shading='auto', vmin=vmin, vmax=vmax, cmap='viridis')
phi_mid = omega_0 * (z_axis[k_mid] - z_pad)
xc_mid, yc_mid = d * np.cos(phi_mid), d * np.sin(phi_mid)
axes[0].plot(xc_mid, yc_mid, 'rx', markersize=10, label='wire center')
axes[0].set_aspect('equal'); axes[0].set_xlabel('x'); axes[0].set_ylabel('y')
axes[0].set_title(f'FEM V at z = {z_axis[k_mid]:.2f}')
axes[0].legend()
plt.colorbar(im0, ax=axes[0])

im1 = axes[1].pcolormesh(x_axis, y_axis, V_analytic[:, :, k_mid].T,
                          shading='auto', vmin=vmin, vmax=vmax, cmap='viridis')
axes[1].plot(xc_mid, yc_mid, 'rx', markersize=10)
axes[1].set_aspect('equal'); axes[1].set_xlabel('x'); axes[1].set_ylabel('y')
axes[1].set_title(f'Analytic log(r\')/log(a) at z = {z_axis[k_mid]:.2f}')
plt.colorbar(im1, ax=axes[1])

diff = V_masked[:, :, k_mid] - V_analytic[:, :, k_mid]
im2 = axes[2].pcolormesh(x_axis, y_axis, diff.T, shading='auto',
                         cmap='RdBu_r', vmin=-0.2, vmax=0.2)
axes[2].plot(xc_mid, yc_mid, 'kx', markersize=10)
axes[2].set_aspect('equal'); axes[2].set_xlabel('x'); axes[2].set_ylabel('y')
axes[2].set_title('FEM − Analytic')
plt.colorbar(im2, ax=axes[2])

plt.tight_layout()
plt.savefig('V_slice_check.png', dpi=150)
print("Saved V_slice_check.png")

# 2. V along the z-axis (x = y = 0). This is where L_A sits.
i0 = np.argmin(np.abs(x_axis))
j0 = np.argmin(np.abs(y_axis))
V_axis = V[i0, j0, :]
fig2, ax = plt.subplots(figsize=(9, 4))
ax.plot(z_axis, V_axis, label='FEM V(0, 0, z)')
ax.axvspan(z_pad, z_pad + height, alpha=0.15, color='orange', label='helix region')
ax.set_xlabel('z'); ax.set_ylabel('V on axis')
ax.set_title('V along the z-axis')
ax.legend(); ax.grid(True)
plt.tight_layout()
plt.savefig('V_on_axis.png', dpi=150)
print("Saved V_on_axis.png")

# 3. Quick stats.
print(f"\nV stats in helix region (excl. wire interior):")
mask = in_helix_region & ~inside_wire
print(f"  min: {np.nanmin(V_masked[mask]):.4f}")
print(f"  max: {np.nanmax(V_masked[mask]):.4f}")
print(f"  mean: {np.nanmean(V_masked[mask]):.4f}")
print(f"  V on axis, helix region: "
      f"min {V_axis[(z_axis >= z_pad) & (z_axis <= z_pad + height)].min():.4f}, "
      f"max {V_axis[(z_axis >= z_pad) & (z_axis <= z_pad + height)].max():.4f}")

# --- Save the cleaned array for downstream use ---
np.savez_compressed('V_grid.npz',
                     V=V, V_masked=V_masked,
                     x_axis=x_axis, y_axis=y_axis, z_axis=z_axis,
                     inside_wire=inside_wire,
                     params=dict(d=d, a=a, b=b, l_z=l_z, turns=turns,
                                  z_pad=z_pad, omega_0=omega_0))
print("\nSaved V_grid.npz for downstream use.")

# Find L_A from analytic formula and plot V there.
# (L_A is on the line through the z-axis, opposite the wire's average position.)
# Or just sweep a few x values:
fig3, ax = plt.subplots(figsize=(9, 5))
for xq in [0.0, -0.05, -0.09, 0.05]:
    iq = np.argmin(np.abs(x_axis - xq))
    jq = np.argmin(np.abs(y_axis - 0.0))
    ax.plot(z_axis, V[iq, jq, :], label=f'x={x_axis[iq]:.3f}')
ax.axvspan(z_pad, z_pad + height, alpha=0.15, color='orange')
ax.set_xlabel('z'); ax.set_ylabel('V')
ax.legend(); ax.grid(True)
plt.tight_layout()
plt.savefig('V_along_z_lines.png', dpi=150)

# Add to the script
# LA_analytic = 0.0006815135234820441 # from your Python script's LA calculation
LA_analytic  = 0.034075676174102204
# Better: a separate plot of V(x, 0, z=12) along x
fig4, ax4 = plt.subplots(figsize=(9, 4.5))
k_mid = np.argmin(np.abs(z_axis - 12.0))
j0 = np.argmin(np.abs(y_axis - 0.0))
ax4.plot(x_axis, V[:, j0, k_mid], label='FEM V(x, 0, z=12)')
ax4.set_xlabel('x'); ax4.set_ylabel('V')
ax4.grid(True); ax4.legend()
ax4.axvline(LA_analytic, color='red', linestyle='--', label=f'L_A analytic = {LA_analytic:.4f}')
ax4.axvline(-LA_analytic, color='orange', linestyle='--', label=f'-L_A = {-LA_analytic:.4f}')
ax4.legend()
plt.tight_layout()
plt.savefig('V_along_x.png', dpi=150)