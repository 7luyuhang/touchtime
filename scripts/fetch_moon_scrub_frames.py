#!/usr/bin/env python3
"""
Fetch fine-grained moon scrub frames from NASA SVS "Moon Phase and
Libration, 2026" (https://svs.gsfc.nasa.gov/5587/) and generate the
moon_scrub_XXX imagesets that MoonPhaseDetailsView scrubs through.

The app picks a frame from the instantaneous moon age computed by
Shared/MoonAstronomy.swift (Duffett-Smith). To make that mapping exact,
this script ports the same age formula, locates a new moon inside an
eclipse-free synodic month, and samples the hourly SVS frames uniformly
in *age* rather than in time: frame k shows age k * (29.530589 / 118).
Sampling by age matters because the Moon's elongation rate varies by
roughly +/-20% between perigee and apogee within a month.

The chosen cycle (2026-04-17 -> 2026-05-16, full moon around May 1) stays
clear of 2026's lunar eclipses (Mar 3 total, Aug 28 partial), so no frame
shows the Earth's shadow when the set is reused for other months.

Output: touchtime/Assets.xcassets/moonPhase/moon_scrub_000.imageset ...
moon_scrub_117.imageset (app target only; the widget keeps the 30 daily
moon_age_XX images). Frames are recompressed as JPEG quality 60: JPEG
passes through actool unchanged, whereas HEIF makes actool add a large
RGB555 fallback per image that inflates Assets.car several-fold.
Downloads are cached in scripts/.moon_scrub_cache/ so reruns only
regenerate the imagesets.

Usage: python3 scripts/fetch_moon_scrub_frames.py
Requires: macOS (sips does the JPEG recompression) and network access.
"""

import json
import math
import shutil
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

FRAME_COUNT = 118
SYNODIC_DAYS = 29.530589
JPEG_QUALITY = "60"

# First hour scanned when locating the cycle's new moon (must be shortly
# before it; the April 2026 new moon falls on the 17th).
SEARCH_START = datetime(2026, 4, 15, tzinfo=timezone.utc)

YEAR_START = datetime(2026, 1, 1, tzinfo=timezone.utc)
FRAME_URL = (
    "https://svs.gsfc.nasa.gov/vis/a000000/a005500/a005587/"
    "frames/730x730_1x1_30p/moon.{:04d}.jpg"
)

REPO_ROOT = Path(__file__).resolve().parent.parent
CACHE_DIR = REPO_ROOT / "scripts" / ".moon_scrub_cache"
ASSET_DIR = REPO_ROOT / "touchtime" / "Assets.xcassets" / "moonPhase"


def moon_age_days(date: datetime) -> float:
    """Port of MoonAstronomy.snapshot(for:).ageDays — keep in sync."""
    julian_day = date.timestamp() / 86400.0 + 2440587.5 + 63.8 / 86400.0
    d = julian_day - 2451545.0

    rad = math.radians

    sun_mean_anomaly = (360.0 / 365.242191 * d + 280.466069 - 282.938346) % 360.0
    sun_equation_of_centre = 360.0 / math.pi * 0.016708 * math.sin(rad(sun_mean_anomaly))
    sun_longitude = (sun_mean_anomaly + sun_equation_of_centre + 282.938346) % 360.0

    mean_longitude = (13.176339686 * d + 218.316433) % 360.0
    mean_anomaly = (mean_longitude - 0.1114041 * d - 83.353451) % 360.0

    annual_equation = 0.1858 * math.sin(rad(sun_mean_anomaly))
    evection = 1.2739 * math.sin(rad(2 * (mean_longitude - sun_longitude) - mean_anomaly))
    corrected_anomaly = mean_anomaly + evection - annual_equation - 0.37 * math.sin(rad(sun_mean_anomaly))
    equation_of_centre = 6.2886 * math.sin(rad(corrected_anomaly)) + 0.214 * math.sin(rad(2 * corrected_anomaly))
    corrected_longitude = mean_longitude + evection + equation_of_centre - annual_equation
    variation = 0.6583 * math.sin(rad(2 * (corrected_longitude - sun_longitude)))
    true_longitude = corrected_longitude + variation

    age_degrees = (true_longitude - sun_longitude) % 360.0
    return age_degrees / 12.1907


def frame_number(date: datetime) -> int:
    """SVS frame numbers are the 1-based hour of the year."""
    return int((date - YEAR_START).total_seconds() // 3600) + 1


def locate_cycle_hours() -> list[tuple[datetime, float]]:
    """Hourly (time, age) samples from the cycle's new moon to the next wrap."""
    ages = []
    t = SEARCH_START
    previous_age = moon_age_days(t)
    # Find the wrap into the new cycle
    while True:
        t += timedelta(hours=1)
        age = moon_age_days(t)
        if age < previous_age:
            break
        previous_age = age
    # Collect the whole cycle until the age wraps again
    start = t
    samples = [(t, moon_age_days(t))]
    while True:
        t += timedelta(hours=1)
        age = moon_age_days(t)
        if age < samples[-1][1]:
            break
        samples.append((t, age))
    print(f"New moon cycle starts {start:%Y-%m-%d %H:%M} UTC, {len(samples)} hourly samples")
    return samples


def pick_frames(samples: list[tuple[datetime, float]]) -> list[tuple[datetime, float]]:
    """For each target age k * SYNODIC/118, the hourly sample closest in age."""
    picks = []
    for k in range(FRAME_COUNT):
        target = k * SYNODIC_DAYS / FRAME_COUNT
        best = min(samples, key=lambda sample: abs(sample[1] - target))
        picks.append(best)
    return picks


def download(frame: int, destination: Path) -> None:
    if destination.exists():
        return
    url = FRAME_URL.format(frame)
    request = urllib.request.Request(url, headers={"User-Agent": "touchtime-asset-fetch"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                data = response.read()
            destination.write_bytes(data)
            time.sleep(0.25)  # be polite to the SVS server
            return
        except Exception as error:  # noqa: BLE001 - retry any transient failure
            if attempt == 2:
                raise
            print(f"  retrying frame {frame}: {error}")
            time.sleep(2)


def write_imageset(index: int, source_jpg: Path) -> int:
    name = f"moon_scrub_{index:03d}"
    imageset = ASSET_DIR / f"{name}.imageset"
    if imageset.exists():
        shutil.rmtree(imageset)
    imageset.mkdir(parents=True)

    jpeg = imageset / f"{name}.jpg"
    subprocess.run(
        ["sips", "-s", "format", "jpeg", "-s", "formatOptions", JPEG_QUALITY,
         str(source_jpg), "--out", str(jpeg)],
        check=True, capture_output=True,
    )

    contents = {
        "images": [
            {"filename": jpeg.name, "idiom": "universal", "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (imageset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    return jpeg.stat().st_size


def main() -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    samples = locate_cycle_hours()
    picks = pick_frames(samples)

    manifest = []
    total_bytes = 0
    for index, (date, age) in enumerate(picks):
        frame = frame_number(date)
        cached = CACHE_DIR / f"moon.{frame:04d}.jpg"
        print(f"[{index + 1:3d}/{FRAME_COUNT}] frame {frame} — {date:%Y-%m-%d %H:%M} UTC, age {age:.3f} d")
        download(frame, cached)
        total_bytes += write_imageset(index, cached)
        manifest.append({
            "index": index,
            "frame": frame,
            "utc": date.strftime("%Y-%m-%dT%H:%M"),
            "age_days": round(age, 4),
        })

    (CACHE_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Done: {FRAME_COUNT} imagesets, {total_bytes / 1024 / 1024:.1f} MB of JPEG in {ASSET_DIR}")


if __name__ == "__main__":
    main()
