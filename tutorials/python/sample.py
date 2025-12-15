from kwave.kgrid import kWaveGrid

# Create a 2D grid: 2cm × 2cm domain with 100μm resolution
Nx, Ny = 200, 200           # 200 × 200 grid points
dx, dy = 100e-6, 100e-6     # 100 μm spacing

grid = kWaveGrid([Nx, Ny], [dx, dy])

from kwave.kmedium import kWaveMedium

# Simple water-like medium
medium = kWaveMedium(
    sound_speed=1500,  # m/s - speed of sound in water
    density=1000       # kg/m³ - density of water
)

import numpy as np
from kwave.ksource import kSource

# Create initial pressure distribution (photoacoustic-style)
source = kSource()

# Simple circular initial pressure in the center
x_pos = grid.x_vec
y_pos = grid.y_vec
X, Y = np.meshgrid(x_pos, y_pos, indexing='ij')

# 2mm radius circle with 10 kPa initial pressure
radius = 2e-3  # 2 mm
center_x, center_y = 0, 0  # Center of domain

initial_pressure = np.zeros(grid.N, dtype=np.float32)
mask = (X - center_x)**2 + (Y - center_y)**2 <= radius**2
initial_pressure[mask] = 10e3  # 10 kPa

source.p0 = initial_pressure

from kwave.ksensor import kSensor
from kwave.options.simulation_options import SimulationOptions
from kwave.options.simulation_execution_options import SimulationExecutionOptions
from kwave import kspaceFirstOrder2D

# Create sensors around the edge to capture the expanding wave
sensor_mask = np.zeros(grid.N, dtype=bool)
sensor_mask[0, :] = True     # Top edge
sensor_mask[-1, :] = True    # Bottom edge
sensor_mask[:, 0] = True     # Left edge
sensor_mask[:, -1] = True    # Right edge

sensor = kSensor()
sensor.mask = sensor_mask

# Simulation options
simulation_options = SimulationOptions(
    pml_inside=False,
    pml_size=10,
    data_cast='single',
    save_to_disk=True  # Required for GPU simulation
)

# GPU execution options
execution_options = SimulationExecutionOptions(
    is_gpu_simulation=True,
    device_num=0,
    verbose_level=1
)

# Run the simulation using GPU
print("=== GPUシミュレーション開始 ===")
sensor_data = kspaceFirstOrder2D.kspace_first_order_2d_gpu(
    kgrid=grid,
    source=source,
    sensor=sensor,
    medium=medium,
    simulation_options=simulation_options,
    execution_options=execution_options
)

print("✓ シミュレーション完了！")
print(f"センサーデータ形状: {sensor_data.shape if hasattr(sensor_data, 'shape') else type(sensor_data)}")