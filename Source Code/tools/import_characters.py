# SI assistance metadata: This code used the help of SI.
from __future__ import annotations

import argparse
import json
import re
import struct
from pathlib import Path

CHARACTERS = {
    "astronaut": [0, 7, 8, 14],
    "protagonist": [4, 5, 9, 10],
    "girl": [2, 15, 16, 17],
    "dot": [1, 11, 12, 13],
    "antagonist": [22, 23, 24, 25],
    "child": [18, 19, 20, 21],
    "protagonist_duel_head": [6],
    "protagonist_duel": [4, 5, 9, 6],
    "protagonist_second_expression": [26],
}

FALLBACKS = {
    "970cm00.dat": "73200b-f1.dat",
    "bl_36060.dat": "11256.dat",
    "bl_973pb6495c01.dat": "973pb6495c01.dat",
    "bl_973pb5304c01.dat": "973.dat",
    "bl_973c00.dat": "973.dat",
    "bl_973pb5304c01_torso.dat": "973.dat",
    "bl_973pb5433c01_torso.dat": "973.dat",
    "bl_3626pb3758.dat": "3626bpc44.dat",
    "bl_7370.dat": "10055.dat",
    "bl_1685.dat": "12893p01.dat",
}

def normalize(name: str) -> str:
    return " ".join(name.replace("\\", "/").split()).casefold()

def clean_part_name(name: str) -> str:
    name = Path(name.replace("\\", "/")).name.strip()
    name = re.sub(r"\s+copy(?:\s+\d+)?$", "", name, flags=re.IGNORECASE)
    return name

def parse_ldconfig(path: Path) -> dict[str, str]:
    colors = {"16": "FFFFFF", "24": "000000"}
    pattern = re.compile(r"0\s+!COLOUR\s+.+?\s+CODE\s+(\d+)\s+VALUE\s+#([0-9A-Fa-f]{6})")
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = pattern.match(line)
        if match:
            colors[match.group(1)] = match.group(2).upper()
    return colors

def read_mpd(path: Path) -> tuple[list[str], dict[str, list[str]]]:
    blocks: dict[str, list[str]] = {}
    current = ""
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.upper().startswith("0 FILE "):
            current = normalize(line[7:])
            blocks[current] = []
        elif line.upper().startswith("0 NOFILE"):
            current = ""
        elif current:
            blocks[current].append(line)
    return blocks.get(normalize("Characters.io"), []), blocks

def matrix_multiply(a: tuple[list[list[float]], list[float]], b: tuple[list[list[float]], list[float]]) -> tuple[list[list[float]], list[float]]:
    am, at = a
    bm, bt = b
    m = [[sum(am[r][k] * bm[k][c] for k in range(3)) for c in range(3)] for r in range(3)]
    t = [at[r] + sum(am[r][k] * bt[k] for k in range(3)) for r in range(3)]
    return m, t

IDENTITY = ([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]], [0.0, 0.0, 0.0])

def transform_point(transform: tuple[list[list[float]], list[float]], p: list[float]) -> list[float]:
    m, t = transform
    return [sum(m[r][k] * p[k] for k in range(3)) + t[r] for r in range(3)]

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--library", type=Path, default=Path.home() / "AppData/Local/Temp/ldraw-parts-library/ldraw")
    parser.add_argument("--source", type=Path, default=Path("Characters.ldr"))
    parser.add_argument("--output", type=Path, default=Path("assets/models/characters"))
    args = parser.parse_args()

    main_lines, embedded = read_mpd(args.source)
    library_files: dict[str, Path] = {}
    for folder in [args.library / "parts", args.library / "parts/s", args.library / "p", args.library / "p/8", args.library / "p/48"]:
        if folder.exists():
            for path in folder.glob("*.dat"):
                library_files.setdefault(normalize(path.name), path)
    colors = parse_ldconfig(args.library / "LDConfig.ldr")
    top_instances = [line.split() for line in main_lines if line.strip().startswith("1 ")]
    args.output.mkdir(parents=True, exist_ok=True)
    def resolve(name: str) -> list[str] | Path | None:
        key = normalize(name)
        if key in embedded:
            return embedded[key]
        basename = clean_part_name(name).casefold()
        fallback = FALLBACKS.get(basename)
        if fallback:
            key = normalize(fallback)
            found = library_files.get(key)
            if found:
                return found
        found = library_files.get(normalize(basename))
        if found:
            return found
        if basename.startswith("bl_"):
            return library_files.get(normalize(basename[3:]))
        return None

    def category(name: str) -> str:
        base = clean_part_name(name).casefold()
        if base.startswith("bl_"):
            base = base[3:]
        if base.startswith(("73200", "970c")):
            return "Legs"
        if base.startswith(("973", "76382")):
            return "Torso"
        if base.startswith(("3626", "974")):
            return "Head"
        if base.startswith(("53981", "86035", "12893", "36060", "7370", "1685", "10055")):
            return "Hair"
        return "Torso"

    def add_instance(lines: list[str], fallback_color: str, base: tuple[list[list[float]], list[float]], components: dict[str, dict[str, list[list[float]]]], group: str, stack: tuple[str, ...]) -> None:
        for line in lines:
            fields = line.strip().split()
            if not fields or fields[0].startswith("0"):
                continue
            kind = fields[0]
            if kind == "1" and len(fields) >= 15:
                color_code = fields[1] if fields[1] not in ("16", "24") else fallback_color
                local = ([[float(v) for v in fields[5:8]], [float(v) for v in fields[8:11]], [float(v) for v in fields[11:14]]], [float(v) for v in fields[2:5]])
                child_transform = matrix_multiply(base, local)
                target_name = " ".join(fields[14:])
                part_name = clean_part_name(target_name).casefold()
                child_group = group
                if group == "Torso" and part_name in ("3818.dat", "3819.dat", "3820.dat"):
                    child_x = transform_point(child_transform, [0.0, 0.0, 0.0])[0]
                    child_group = "ArmL" if part_name == "3818.dat" or (part_name == "3820.dat" and child_x < -20.0) else "ArmR"
                    if part_name == "3819.dat":
                        child_group = "ArmR"
                elif group == "Legs" and part_name.startswith(("3816", "3817")):
                    child_group = "LegL" if part_name.startswith("3816") else "LegR"
                resolved = resolve(target_name)
                if resolved is None:
                    continue
                target_key = normalize(target_name)
                if target_key in stack:
                    continue
                if isinstance(resolved, Path):
                    child_lines = resolved.read_text(encoding="utf-8", errors="replace").splitlines()
                else:
                    child_lines = resolved
                add_instance(child_lines, color_code, child_transform, components, child_group, (*stack, target_key))
            elif kind in ("3", "4"):
                color_code = fields[1] if fields[1] not in ("16", "24") else fallback_color
                points = [[float(fields[i]), float(fields[i + 1]), float(fields[i + 2])] for i in range(2, len(fields), 3)]
                if len(points) < (3 if kind == "3" else 4):
                    continue
                points = [transform_point(base, p) for p in points]
                points = [[point[0], -point[1], -point[2]] for point in points]
                triangles = [points[:3]] if kind == "3" else [points[:3], [points[0], points[2], points[3]]]
                components.setdefault(group, {}).setdefault(color_code, []).extend(triangles)

    for role, indexes in CHARACTERS.items():
        components: dict[str, dict[str, list[list[float]]]] = {}
        for index in indexes:
            if index >= len(top_instances):
                continue
            fields = top_instances[index]
            color_code = fields[1]
            local = ([[float(v) for v in fields[5:8]], [float(v) for v in fields[8:11]], [float(v) for v in fields[11:14]]], [0.0, 0.0, 0.0])
            name = " ".join(fields[14:])
            resolved = resolve(name)
            if resolved is None:
                print(f"Skipping missing source part: {name}")
                continue
            lines = resolved.read_text(encoding="utf-8", errors="replace").splitlines() if isinstance(resolved, Path) else resolved
            group = category(name)
            if role == "protagonist" and index == 9:
                color_code = "6"
            if role == "protagonist_duel" and index == 6:
                group = "Head"
            add_instance(lines, color_code, local, components, group, (normalize(name),))
        def component_points(group: str) -> list[list[float]]:
            return [p for triangles in components.get(group, {}).values() for triangle in triangles for p in triangle]
        leg_points = component_points("Legs") + component_points("LegL") + component_points("LegR")
        torso_points = component_points("Torso")
        head_points = component_points("Head")
        hair_points = component_points("Hair")
        if role == "protagonist_duel_head":
            leg_points = []
            torso_points = []
            hair_points = []
        if not torso_points and role != "protagonist_duel_head":
            print(f"No torso geometry generated for {role}")
        def bounds(points: list[list[float]]) -> tuple[list[float], list[float]]:
            return ([min(p[axis] for p in points) for axis in range(3)], [max(p[axis] for p in points) for axis in range(3)])
        if not any((leg_points, torso_points, head_points, hair_points)):
            print(f"No geometry generated for {role}")
            continue
        leg_bounds = bounds(leg_points) if leg_points else ([0.0, 0.0, 0.0], [0.0, 0.0, 0.0])
        torso_bounds = bounds(torso_points) if torso_points else ([0.0, 0.0, 0.0], [0.0, 0.0, 0.0])
        head_bounds = bounds(head_points) if head_points else ([0.0, 0.0, 0.0], [0.0, 0.0, 0.0])
        hair_bounds = bounds(hair_points) if hair_points else ([0.0, 0.0, 0.0], [0.0, 0.0, 0.0])
        leg_height = leg_bounds[1][1] - leg_bounds[0][1]
        torso_height = torso_bounds[1][1] - torso_bounds[0][1]
        head_height = head_bounds[1][1] - head_bounds[0][1]
        hair_height = hair_bounds[1][1] - hair_bounds[0][1]
        torso_center_x = (torso_bounds[0][0] + torso_bounds[1][0]) * 0.5
        torso_center_z = (torso_bounds[0][2] + torso_bounds[1][2]) * 0.5
        leg_offset = [-((leg_bounds[0][0] + leg_bounds[1][0]) * 0.5), -leg_bounds[0][1], -((leg_bounds[0][2] + leg_bounds[1][2]) * 0.5)]
        torso_base = max(0.0, leg_height - min(5.0, leg_height * 0.1))
        torso_offset = [torso_center_x - (torso_bounds[0][0] + torso_bounds[1][0]) * 0.5, torso_base - torso_bounds[0][1], torso_center_z - (torso_bounds[0][2] + torso_bounds[1][2]) * 0.5]
        head_base = torso_base + torso_height - min(7.0, torso_height * 0.14)
        head_offset = [torso_center_x - (head_bounds[0][0] + head_bounds[1][0]) * 0.5, head_base - head_bounds[0][1], torso_center_z - (head_bounds[0][2] + head_bounds[1][2]) * 0.5]
        hair_base = head_base + head_height - min(8.0, head_height * 0.26)
        hair_offset = [torso_center_x - (hair_bounds[0][0] + hair_bounds[1][0]) * 0.5, hair_base - hair_bounds[0][1], torso_center_z - (hair_bounds[0][2] + hair_bounds[1][2]) * 0.5]
        height = max(leg_height, torso_base + torso_height, head_base + head_height, hair_base + hair_height, 1.0)
        target_height = 1.34 if role == "child" else (0.42 if not leg_points and not torso_points else 1.62)
        root_scale = target_height / (height * 0.008)
        binary = bytearray()
        buffer_views: list[dict] = []
        accessors: list[dict] = []
        materials: list[dict] = []
        meshes: list[dict] = []
        nodes: list[dict] = [{"name": role, "children": [], "scale": [root_scale] * 3}]
        component_offsets = {"Legs": leg_offset, "LegL": leg_offset, "LegR": leg_offset, "Torso": torso_offset, "ArmL": torso_offset, "ArmR": torso_offset, "Head": head_offset, "Hair": hair_offset}

        def add_binary(data: bytes, target: int) -> tuple[int, int]:
            while len(binary) % 4:
                binary.append(0)
            offset = len(binary)
            binary.extend(data)
            view_id = len(buffer_views)
            buffer_views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(data), "target": target})
            return view_id, offset

        triangle_count = 0
        for group, by_color in components.items():
            if not by_color:
                continue
            offset = component_offsets.get(group, [0.0, 0.0, 0.0])
            group_points = [p for triangles in by_color.values() for triangle in triangles for p in triangle]
            group_bounds = bounds(group_points)
            pivot = [0.0, 0.0, 0.0]
            if group in ("Torso", "Head", "ArmL", "ArmR", "LegL", "LegR"):
                pivot = [(group_bounds[0][0] + group_bounds[1][0]) * 0.5, group_bounds[1][1], (group_bounds[0][2] + group_bounds[1][2]) * 0.5]
                if group == "Torso":
                    pivot[1] = torso_base + torso_height * 0.45
                elif group == "Head":
                    pivot[1] = head_base + head_height * 0.35
            primitives: list[dict] = []
            for color_code, triangles in by_color.items():
                code_hex = colors.get(color_code, "FFFFFF")
                positions: list[float] = []
                normals: list[float] = []
                for tri in triangles:
                    converted = [[(p[axis] - pivot[axis]) * 0.008 for axis in range(3)] for p in tri]
                    a, b, c = converted
                    ab = [b[i] - a[i] for i in range(3)]
                    ac = [c[i] - a[i] for i in range(3)]
                    normal = [ab[1] * ac[2] - ab[2] * ac[1], ab[2] * ac[0] - ab[0] * ac[2], ab[0] * ac[1] - ab[1] * ac[0]]
                    length = max(sum(v * v for v in normal) ** 0.5, 1e-9)
                    normal = [v / length for v in normal]
                    for point in converted:
                        positions.extend(point)
                        normals.extend(normal)
                position_view, _ = add_binary(struct.pack("<%sf" % len(positions), *positions), 34962)
                normal_view, _ = add_binary(struct.pack("<%sf" % len(normals), *normals), 34962)
                position_accessor = len(accessors)
                accessors.append({"bufferView": position_view, "componentType": 5126, "count": len(positions) // 3, "type": "VEC3", "min": [min(positions[i::3]) for i in range(3)], "max": [max(positions[i::3]) for i in range(3)]})
                normal_accessor = len(accessors)
                accessors.append({"bufferView": normal_view, "componentType": 5126, "count": len(normals) // 3, "type": "VEC3"})
                def linear(channel: int) -> float:
                    value = channel / 255.0
                    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
                rgb = [linear(int(code_hex[i:i + 2], 16)) for i in (0, 2, 4)]
                material_id = len(materials)
                materials.append({"name": f"LDraw {color_code} ABS", "pbrMetallicRoughness": {"baseColorFactor": rgb + [1.0], "metallicFactor": 0.0, "roughnessFactor": 0.34}, "doubleSided": True})
                primitives.append({"attributes": {"POSITION": position_accessor, "NORMAL": normal_accessor}, "material": material_id, "mode": 4})
                triangle_count += len(triangles)
            mesh_id = len(meshes)
            meshes.append({"name": f"{role} {group}", "primitives": primitives})
            node_id = len(nodes)
            node = {"name": group, "mesh": mesh_id}
            node["translation"] = [(pivot[axis] + offset[axis]) * 0.008 for axis in range(3)]
            nodes.append(node)
            nodes[0]["children"].append(node_id)
        gltf = {"asset": {"version": "2.0", "generator": "SI-assisted LDraw character importer", "extras": {"si_assistance": "This character model was generated with SI assistance."}}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": nodes, "meshes": meshes, "materials": materials, "accessors": accessors, "bufferViews": buffer_views, "buffers": [{"byteLength": len(binary)}]}
        json_chunk = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
        json_chunk += b" " * ((4 - len(json_chunk) % 4) % 4)
        binary.extend(b"\0" * ((4 - len(binary) % 4) % 4))
        total_length = 12 + 8 + len(json_chunk) + 8 + len(binary)
        glb = struct.pack("<4sII", b"glTF", 2, total_length)
        glb += struct.pack("<I4s", len(json_chunk), b"JSON") + json_chunk
        glb += struct.pack("<I4s", len(binary), b"BIN\0") + binary
        (args.output / f"{role}.glb").write_bytes(glb)
        print(f"Built {role}: {triangle_count} triangles at {target_height:.2f} m")

if __name__ == "__main__":
    main()
