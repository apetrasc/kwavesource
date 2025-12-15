"""
Lightweight 2D k-Wave simulation example driven by config/config.yaml used in
the MATLAB pipeline (kwavesim / simulation_execution).

Usage:
    python run_2d_simulation.py \
        --config ../../config/config.yaml \
        --output /mnt/sdb/matsubara/tmp/sensor_data.npy \
        --use-gpu

Notes:
- Keeps the geometry simple: a short tone burst emitted from the left edge and
  recorded on the right edge.
- Reads water properties, grid, and simulation parameters from config/config.yaml.
- Optional GPU execution via kspace_first_order_2d_gpu.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import yaml

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
        if config_path.suffix.lower() in {".yaml", ".yml"}:
            return yaml.safe_load(f)
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


def apply_bubble_mask(grid: kWaveGrid, medium: kWaveMedium, cfg: dict) -> None:
    """Optionally embed a bubble at the grid center using properties from cfg."""
    bubble_cfg = cfg.get("bubble")
    if not bubble_cfg:
        return

    # Allow properties to come from either bubble section or medium.bubble defaults
    bubble_defaults = cfg.get("medium", {}).get("bubble", {})
    def pick(key, default=None):
        if key in bubble_cfg:
            return bubble_cfg[key]
        if key in bubble_defaults:
            return bubble_defaults[key]
        return default

    radius_m = float(bubble_cfg.get("radius_m", 2e-4))
    dx = grid.dx
    dy = grid.dy
    radius_px = int(radius_m / min(dx, dy))
    if radius_px < 1:
        radius_px = 1

    cx = grid.N[0] // 2
    cy = grid.N[1] // 2

    x_idx = np.arange(grid.N[0])[:, None]
    y_idx = np.arange(grid.N[1])[None, :]
    r2 = (x_idx - cx) ** 2 + (y_idx - cy) ** 2
    mask2d = r2 <= radius_px**2

    target_shape = tuple(grid.N)

    def to_array(val):
        arr = np.asarray(val)
        if arr.shape == ():  # scalar
            arr = np.full(target_shape, arr, dtype=np.float32)
        else:
            arr = np.broadcast_to(arr, target_shape).astype(np.float32)
        return arr.copy()

    sound_speed = to_array(medium.sound_speed)
    density = to_array(medium.density)
    alpha_coeff = to_array(medium.alpha_coeff)

    sound_speed[mask2d] = pick("sound_speed", sound_speed.flat[0])
    density[mask2d] = pick("density", density.flat[0])
    alpha_coeff[mask2d] = pick("alpha_coeff", alpha_coeff.flat[0])

    medium.sound_speed = sound_speed
    medium.density = density
    medium.alpha_coeff = alpha_coeff
    medium.alpha_power = pick("alpha_power", medium.alpha_power)


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
    # Use a scalar impedance for scaling (take first element)
    ss0 = float(np.asarray(medium.sound_speed).flat[0])
    rho0 = float(np.asarray(medium.density).flat[0])
    impedance = ss0 * rho0 if ss0 and rho0 else 1.0
    burst = make_tone_burst(fs, freq, cycles, strength / impedance)

    # Pad burst to full simulation length (Nt) as required by k-Wave
    Nt = grid.Nt
    signal = np.zeros((Nt,), dtype=np.float32)
    signal[: min(Nt, burst.size)] = burst[:Nt]

    # Broadcast to active source points: shape (num_sources, Nt)
    num_src = int(mask.sum())
    if num_src == 0:
        raise ValueError("Source mask has no active elements.")
    src.p = np.tile(signal, (num_src, 1)).astype(np.float32)
    return src


def build_sensor(grid: kWaveGrid) -> kSensor:
    sensor = kSensor()
    mask = np.zeros(grid.N, dtype=bool)
    # Record along the right boundary
    mask[-2, :] = True
    sensor.mask = mask
    return sensor


def run_simulation(cfg: dict, use_gpu: bool, device: int, output: Path | None) -> np.ndarray:
    # Override save root as requested
    save_root = Path("/mnt/sdb/matsubara/tmp")
    save_root.mkdir(parents=True, exist_ok=True)

    # Resolve device: CLI > YAML > default 0
    device_num = device
    if device_num is None:
        device_num = cfg.get("simulation", {}).get("device_num", 0)

    grid = build_grid(cfg)
    medium = build_medium(cfg)
    apply_bubble_mask(grid, medium, cfg)
    grid.makeTime(medium.sound_speed, cfl=cfg["simulation"]["CFL"], t_end=cfg["simulation"]["t_end"])

    source = build_source(grid, medium, cfg)
    sensor = build_sensor(grid)

    pml_size = cfg["simulation"]["pml_size"]
    sim_options = SimulationOptions(
        pml_inside=False,
        pml_size=pml_size,
        pml_alpha=cfg["simulation"]["pml_alpha"],
        data_cast="single",
        # GPU backend requires on-disk intermediates
        save_to_disk=True,
    )
    exec_options = SimulationExecutionOptions(
        is_gpu_simulation=use_gpu,
        device_num=device_num,
        verbose_level=1,
    )

    if not use_gpu:
        raise RuntimeError(
            "This environment only provides the GPU entry point "
            "`kspace_first_order_2d_gpu`. Please rerun with --use-gpu."
        )

    print(f"Running 2D simulation (GPU={use_gpu}, device={device_num}) ...")
    sensor_data = kspaceFirstOrder2D.kspace_first_order_2d_gpu(
        kgrid=grid,
        medium=medium,
        source=source,
        sensor=sensor,
        simulation_options=sim_options,
        execution_options=exec_options,
    )

    if output is None:
        output = save_root / "sensor_data.npy"
    output.parent.mkdir(parents=True, exist_ok=True)
    np.save(output, sensor_data)
    print(f"Saved sensor data to {output}")

    print(f"Sensor data shape: {getattr(sensor_data, 'shape', type(sensor_data))}")
    return sensor_data


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a 2D k-Wave simulation (tutorial).")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("../../config/config.yaml"),
        help="Path to config file (yaml or json).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Optional path to save sensor data (.npy). Defaults to /mnt/sdb/matsubara/tmp/sensor_data.npy.",
    )
    parser.add_argument("--use-gpu", action="store_true", help="Use GPU backend if available.")
    parser.add_argument(
        "--device",
        type=int,
        default=None,
        help="CUDA device index when using GPU. If omitted, uses simulation.device_num in YAML (default 0).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    cfg = load_config(args.config)
    run_simulation(cfg, use_gpu=args.use_gpu, device=args.device, output=args.output)


if __name__ == "__main__":
    main()

