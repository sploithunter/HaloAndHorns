#!/usr/bin/env python3

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Remove a near-white background from a pet reference image.")
    parser.add_argument("input", help="Input PNG/JPG reference image")
    parser.add_argument("output", help="Output transparent PNG")
    parser.add_argument("--threshold", type=int, default=242, help="RGB threshold for white background pixels")
    parser.add_argument("--softness", type=int, default=20, help="Feather range below the threshold")
    parser.add_argument(
        "--mode",
        choices=["edge-white", "ring-white", "all-white", "edge-green", "ring-green"],
        default="edge-white",
        help=(
            "edge-white: background connected to image edges; "
            "ring-white: edge background plus center hole (for ring/frame UI art); "
            "all-white: every near-white pixel; "
            "edge-green: green-screen background connected to image edges; "
            "ring-green: green-screen edge background plus center hole."
        ),
    )
    parser.add_argument(
        "--green-min",
        type=int,
        default=120,
        help="Minimum green channel for green-screen key (edge-green mode)",
    )
    parser.add_argument(
        "--green-dominance",
        type=int,
        default=40,
        help="Required green excess over max(red, blue) for green-screen key",
    )
    return parser.parse_args()


def background_alpha(red: int, green: int, blue: int, threshold: int, softness: int) -> int:
    whiteness = min(red, green, blue)
    if whiteness >= threshold:
        return 0
    if softness <= 0 or whiteness <= threshold - softness:
        return 255

    return int(255 * (threshold - whiteness) / softness)


def is_background_candidate(red: int, green: int, blue: int, threshold: int, softness: int) -> bool:
    return min(red, green, blue) >= threshold - softness


def is_green_screen_candidate(
    red: int,
    green: int,
    blue: int,
    min_green: int,
    dominance: int,
    softness: int,
) -> bool:
    return green >= min_green - softness and (green - max(red, blue)) >= dominance - softness


def is_blue_screen_candidate(
    red: int,
    green: int,
    blue: int,
    min_blue: int,
    dominance: int,
    softness: int,
) -> bool:
    return blue >= min_blue - softness and (blue - max(red, green)) >= dominance - softness


def green_screen_alpha(
    red: int,
    green: int,
    blue: int,
    min_green: int,
    dominance: int,
    softness: int,
) -> int:
    excess = green - max(red, blue)
    if green < min_green - softness or excess <= 0:
        return 255
    if excess >= dominance and green >= min_green:
        return 0
    if softness <= 0:
        return 255

    green_headroom = green - (min_green - softness)
    excess_headroom = excess - (dominance - softness)
    score = min(green_headroom, excess_headroom)
    if score <= 0:
        return 255
    if score >= softness:
        return 0
    return int(255 * (softness - score) / softness)


def blue_screen_alpha(
    red: int,
    green: int,
    blue: int,
    min_blue: int,
    dominance: int,
    softness: int,
) -> int:
    excess = blue - max(red, green)
    if blue < min_blue - softness or excess <= 0:
        return 255
    if excess >= dominance and blue >= min_blue:
        return 0
    if softness <= 0:
        return 255

    blue_headroom = blue - (min_blue - softness)
    excess_headroom = excess - (dominance - softness)
    score = min(blue_headroom, excess_headroom)
    if score <= 0:
        return 255
    if score >= softness:
        return 0
    return int(255 * (softness - score) / softness)


def despill_green(red: int, green: int, blue: int, alpha: int) -> tuple[int, int, int]:
    spill = max(0, green - max(red, blue))
    if spill <= 0 or alpha <= 0:
        return red, green, blue
    reduction = spill * alpha // 255
    return red, max(red, blue, green - reduction), blue


def despill_blue(red: int, green: int, blue: int, alpha: int) -> tuple[int, int, int]:
    spill = max(0, blue - max(red, green))
    if spill <= 0 or alpha <= 0:
        return red, green, blue
    reduction = spill * alpha // 255
    return red, green, max(red, green, blue - reduction)


def flood_connected_background(
    image: Image.Image,
    threshold: int,
    softness: int,
    seeds: list[tuple[int, int]],
    *,
    candidate=None,
) -> set[tuple[int, int]]:
    width, height = image.size
    pixels = image.load()
    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()

    def is_candidate(red: int, green: int, blue: int) -> bool:
        if candidate is not None:
            return candidate(red, green, blue)
        return is_background_candidate(red, green, blue, threshold, softness)

    def enqueue(x: int, y: int) -> None:
        if (x, y) in seen:
            return
        red, green, blue, _alpha = pixels[x, y]
        if not is_candidate(red, green, blue):
            return
        seen.add((x, y))
        queue.append((x, y))

    for seed in seeds:
        if 0 <= seed[0] < width and 0 <= seed[1] < height:
            enqueue(seed[0], seed[1])

    while queue:
        x, y = queue.popleft()
        for next_x, next_y in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= next_x < width and 0 <= next_y < height:
                enqueue(next_x, next_y)

    return seen


def edge_connected_background(image: Image.Image, threshold: int, softness: int) -> set[tuple[int, int]]:
    width, height = image.size
    seeds: list[tuple[int, int]] = []
    for x in range(width):
        seeds.extend([(x, 0), (x, height - 1)])
    for y in range(height):
        seeds.extend([(0, y), (width - 1, y)])
    return flood_connected_background(image, threshold, softness, seeds)


def edge_connected_green_screen(
    image: Image.Image,
    min_green: int,
    dominance: int,
    softness: int,
) -> set[tuple[int, int]]:
    width, height = image.size
    seeds: list[tuple[int, int]] = []
    for x in range(width):
        seeds.extend([(x, 0), (x, height - 1)])
    for y in range(height):
        seeds.extend([(0, y), (width - 1, y)])

    def candidate(red: int, green: int, blue: int) -> bool:
        return is_green_screen_candidate(red, green, blue, min_green, dominance, softness)

    return flood_connected_background(image, 0, 0, seeds, candidate=candidate)


def edge_connected_blue_screen(
    image: Image.Image,
    min_blue: int,
    dominance: int,
    softness: int,
) -> set[tuple[int, int]]:
    width, height = image.size
    seeds: list[tuple[int, int]] = []
    for x in range(width):
        seeds.extend([(x, 0), (x, height - 1)])
    for y in range(height):
        seeds.extend([(0, y), (width - 1, y)])

    def candidate(red: int, green: int, blue: int) -> bool:
        return is_blue_screen_candidate(red, green, blue, min_blue, dominance, softness)

    return flood_connected_background(image, 0, 0, seeds, candidate=candidate)


def ring_connected_background(image: Image.Image, threshold: int, softness: int) -> set[tuple[int, int]]:
    width, height = image.size
    center_x = width // 2
    center_y = height // 2
    center_seeds = [
        (center_x, center_y),
        (center_x - 1, center_y),
        (center_x + 1, center_y),
        (center_x, center_y - 1),
        (center_x, center_y + 1),
    ]
    outer = edge_connected_background(image, threshold, softness)
    inner = flood_connected_background(image, threshold, softness, center_seeds)
    return outer | inner


def ring_connected_green_screen(
    image: Image.Image,
    min_green: int,
    dominance: int,
    softness: int,
) -> set[tuple[int, int]]:
    width, height = image.size
    center_x = width // 2
    center_y = height // 2
    center_seeds = [
        (center_x, center_y),
        (center_x - 1, center_y),
        (center_x + 1, center_y),
        (center_x, center_y - 1),
        (center_x, center_y + 1),
    ]

    def candidate(red: int, green: int, blue: int) -> bool:
        return is_green_screen_candidate(red, green, blue, min_green, dominance, softness)

    outer = edge_connected_green_screen(image, min_green, dominance, softness)
    inner = flood_connected_background(image, 0, 0, center_seeds, candidate=candidate)
    return outer | inner


def main() -> None:
    args = parse_args()
    source = Path(args.input)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    image = Image.open(source).convert("RGBA")
    pixels = []
    background_mask = None
    if args.mode == "edge-white":
        background_mask = edge_connected_background(image, args.threshold, args.softness)
    elif args.mode == "ring-white":
        background_mask = ring_connected_background(image, args.threshold, args.softness)
    elif args.mode == "ring-green":
        background_mask = ring_connected_green_screen(
            image,
            args.green_min,
            args.green_dominance,
            args.softness,
        )
    elif args.mode == "edge-green":
        background_mask = edge_connected_green_screen(
            image,
            args.green_min,
            args.green_dominance,
            args.softness,
        )

    for index, (red, green, blue, alpha) in enumerate(image.getdata()):
        if background_mask is not None:
            x = index % image.width
            y = index // image.width
            if (x, y) not in background_mask:
                pixels.append((red, green, blue, alpha))
                continue

            if args.mode == "edge-green":
                next_alpha = min(
                    alpha,
                    green_screen_alpha(
                        red,
                        green,
                        blue,
                        args.green_min,
                        args.green_dominance,
                        args.softness,
                    ),
                )
                red, green, blue = despill_green(red, green, blue, next_alpha)
                pixels.append((red, green, blue, next_alpha))
                continue

            if args.mode == "ring-green":
                next_alpha = min(
                    alpha,
                    green_screen_alpha(
                        red,
                        green,
                        blue,
                        args.green_min,
                        args.green_dominance,
                        args.softness,
                    ),
                )
                red, green, blue = despill_green(red, green, blue, next_alpha)
                pixels.append((red, green, blue, next_alpha))
                continue

        next_alpha = min(alpha, background_alpha(red, green, blue, args.threshold, args.softness))
        pixels.append((red, green, blue, next_alpha))

    image.putdata(pixels)
    image.save(output)
    print(output)


if __name__ == "__main__":
    main()
