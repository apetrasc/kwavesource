"""
Lightweight 2D k-Wave simulation example driven by the config.json used in
the MATLAB pipeline (kwavesim / simulation_execution).

Usage:
    python run_2d_simulation.py \
        --config ../../config.json \
        --output sensor_data.npy \
        --use-gpu

Notes:
- Keeps the geometry simple: a short tone burst emitted from the left edge and
  recorded on the right edge.
- Reads water properties, grid, and simulation parameters from config.json.
- Optional GPU execution via kspace_first_order_2d_gpu.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Tuple

import numpy as np
from kwave import kspaceFirstOrder2D
from kwave.kgrid import kWaveGrid
from kwave.kmedium import kWaveMedium
from kwave.ksource import kSource
from kwave.ksensor import kSensor
from kwave.options.simulation_execution_options import SimulationExecutionOptions
from kwave.options.simulation_options import SimulationOptions


def load_config(config_path: Path) -> dict:
    with config_path.open("r", encoding="utf-8") as f:
        return json.load(f)


def build_grid(cfg: dict) -> kWaveGrid:
    Nx, Ny = cfg["grid"]["Nx"], cfg["grid"]["Ny"]
    dx, dy = cfg["grid"]["dx"], cfg["grid"]["dy"]
    return kWaveGrid([Nx, Ny], [dx, dy])


def build_medium(cfg: dict) -> kWaveMedium:
    water = cfg["medium"]["water"]
    return kWaveMedium(
        sound_speed=water["sound_speed"],
        density=water["density"],
        alpha_coeff=water["alpha_coeff"],
        alpha_power=water["alpha_power"],
        BonA=water["BonA"],
    )


def make_tone_burst(fs: float, freq: float, cycles: int, amplitude: float) -> np.ndarray:
    duration = cycles / freq
    t = np.arange(0, duration, 1.0 / fs)
    envelope = np.hanning(t.size) if t.size > 1 else 1.0
    signal = amplitude * np.sin(2 * np.pi * freq * t) * envelope
    return signal.astype(np.float32)


def build_source(grid: kWaveGrid, medium: kWaveMedium, cfg: dict) -> kSource:
    src = kSource()
    mask = np.zeros(grid.N, dtype=bool)
    # Narrow line source on the left boundary
    mask[2, grid.N[1] // 2 - 1 : grid.N[1] // 2 + 2] = True
    src.p_mask = mask

    # Create tone burst
    freq = cfg["source"]["tone_burst_freq"]
    cycles = cfg["source"]["tone_burst_cycles"]
    strength = cfg["source"]["source_strength"]
    fs = 1.0 / grid.dt
    burst = make_tone_burst(fs, freq, cycles, strength / (medium.sound_speed * medium.density))

    # Broadcast to active source points (time x points)
    src.p = np.repeat(burst[:, None], mask.sum(), axis=1)
    return src


def build_sensor(grid: kWaveGrid) -> kSensor:
    sensor = kSensor()
    mask = np.zeros(grid.N, dtype=bool)
    # Record along the right boundary
    mask[-2, :] = True
    sensor.mask = mask
    return sensor


def run_simulation(cfg: dict, use_gpu: bool, device: int, output: Path | None) -> np.ndarray:
    grid = build_grid(cfg)
    medium = build_medium(cfg)
    grid.makeTime(medium.sound_speed, cfl=cfg["simulation"]["CFL"], t_end=cfg["simulation"]["t_end"])

    source = build_source(grid, medium, cfg)
    sensor = build_sensor(grid)

    pml_size = cfg["simulation"]["pml_size"]
    sim_options = SimulationOptions(
        pml_inside=False,
        pml_size=pml_size,
        pml_alpha=cfg["simulation"]["pml_alpha"],
        data_cast="single",
        save_to_disk=False,
    )
    exec_options = SimulationExecutionOptions(
        is_gpu_simulation=use_gpu,
        device_num=device,
        verbose_level=1,
    )

    runner = (
        kspaceFirstOrder2D.kspace_first_order_2d_gpu
        if use_gpu
        else kspaceFirstOrder2D.kspace_first_order_2d
    )

    print(f"Running 2D simulation (GPU={use_gpu}, device={device}) ...")
    sensor_data = runner(
        kgrid=grid,
        medium=medium,
        source=source,
        sensor=sensor,
        simulation_options=sim_options,
        execution_options=exec_options,
    )

    if output:
        output.parent.mkdir(parents=True, exist_ok=True)
        np.save(output, sensor_data)
        print(f"Saved sensor data to {output}")

    print(f"Sensor data shape: {getattr(sensor_data, 'shape', type(sensor_data))}")
    return sensor_data


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a 2D k-Wave simulation (tutorial).")
    parser.add_argument("--config", type=Path, default=Path("../../config.json"), help="Path to config.json.")
    parser.add_argument("--output", type=Path, default=None, help="Optional path to save sensor data (.npy).")
    parser.add_argument("--use-gpu", action="store_true", help="Use GPU backend if available.")
    parser.add_argument("--device", type=int, default=0, help="CUDA device index when using GPU.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    cfg = load_config(args.config)
    run_simulation(cfg, use_gpu=args.use_gpu, device=args.device, output=args.output)


if __name__ == "__main__":
    main()

