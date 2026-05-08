#!/usr/bin/env python3
"""Auto-discover local/remote AI providers and populate ~/.config/opencode/local-providers.json.

Usage:
  # Scan localhost for Ollama and LM Studio
  python populate_local_providers.py

  # SSH to a remote GPU box and scan for Ollama, LM Studio, and vLLM (via hf cache)
  python populate_local_providers.py --host gpu-box

  # Custom ports
  python populate_local_providers.py --host gpu-box --port-ollama 11435 --port-vllm 8080
"""

import argparse
import json
import os
import pathlib
import subprocess
import sys
import urllib.error
import urllib.request


def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--host", help="SSH host for remote discovery (scans all three providers on that machine)")
    p.add_argument("--port-ollama", type=int, default=11434)
    p.add_argument("--port-lmstudio", type=int, default=1234)
    p.add_argument("--port-vllm", type=int, default=8000)
    p.add_argument("--modalities", action="store_true",
                   help="Query Hugging Face API for each model's input/output modalities")
    p.add_argument("--dry-run", action="store_true",
                   help="Print what would be written without modifying the file")
    return p.parse_args()


def config_path():
    return pathlib.Path.home() / ".config" / "opencode" / "local-providers.json"


def load_existing():
    p = config_path()
    if p.exists():
        with open(p) as f:
            return json.load(f)
    return {}


def save_config(config, dry_run=False):
    p = config_path()
    if dry_run:
        print(f"\n--- DRY RUN (would write to {p}) ---")
        print(json.dumps(config, indent=2))
        print("--- end ---")
    else:
        p.parent.mkdir(parents=True, exist_ok=True)
        with open(p, "w") as f:
            json.dump(config, f, indent=2)
            f.write("\n")
        print(f"\nWritten to {p}")


def http_json(url, timeout=5):
    req = urllib.request.Request(url)
    req.add_header("Accept", "application/json")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode())


def ssh(host, cmd, timeout=30):
    r = subprocess.run(["ssh", "-o", "ConnectTimeout=10", host, cmd],
                       capture_output=True, text=True, timeout=timeout)
    return r.stdout.strip(), r.stderr.strip(), r.returncode


def resolve_ip(host):
    """Resolve a hostname to an IP. For localhost, return 127.0.0.1."""
    if host in (None, "localhost", "127.0.0.1"):
        return "127.0.0.1"
    cmd = (
        "hostname -I 2>/dev/null || "
        "ip -4 addr show scope global 2>/dev/null | grep inet | awk '{print $2}' | cut -d/ -f1 | head -1 || "
        "ifconfig 2>/dev/null | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1"
    )
    out, _, rc = ssh(host, cmd)
    if rc == 0 and out:
        return out.split()[0]
    return host


def derive_name(model_id):
    """model/mistralai/Mistral-7B-Instruct-v0.1 -> Mistral-7B-Instruct-v0.1
       qwen3.6:27b -> qwen3.6-27b"""
    name = model_id
    if ":" in name:
        base, tag = name.split(":", 1)
        name = f"{base}-{tag}"
    for prefix in ("model/", "hf.co/"):
        if name.startswith(prefix):
            name = name[len(prefix):]
    if "/" in name:
        name = name.split("/")[-1]
    return name


def discover_ollama_local(port):
    try:
        data = http_json(f"http://127.0.0.1:{port}/api/tags")
        return [(m["name"], derive_name(m["name"])) for m in data.get("models", [])]
    except (urllib.error.URLError, OSError, json.JSONDecodeError, KeyError, TypeError):
        return None


def discover_lmstudio_local(port):
    try:
        data = http_json(f"http://127.0.0.1:{port}/v1/models")
        models = [(m["id"], derive_name(m["id"])) for m in data.get("data", [])]
        return models
    except (urllib.error.URLError, OSError, json.JSONDecodeError, KeyError, TypeError):
        return None


def discover_ollama_remote(host, port):
    out, err, rc = ssh(host, f"curl -s --max-time 5 http://localhost:{port}/api/tags")
    if rc != 0 and not out:
        print(f"    SSH error: {err}")
        return None
    try:
        data = json.loads(out)
        return [(m["name"], derive_name(m["name"])) for m in data.get("models", [])]
    except (json.JSONDecodeError, KeyError, TypeError):
        return None


def discover_lmstudio_remote(host, port):
    out, err, rc = ssh(host, f"curl -s --max-time 5 http://localhost:{port}/v1/models")
    if rc != 0 and not out:
        print(f"    SSH error: {err}")
        return None
    try:
        data = json.loads(out)
        return [(m["id"], derive_name(m["id"])) for m in data.get("data", [])]
    except (json.JSONDecodeError, KeyError, TypeError):
        return None


def discover_vllm_remote(host):
    cmd = (
        ". ~/.local/venv/bin/activate 2>/dev/null && "
        "python3 -c \""
        "from huggingface_hub import scan_cache_dir; "
        "import json; "
        "repos = [{\\\"id\\\": r.repo_id, \\\"type\\\": r.repo_type} for r in scan_cache_dir().repos]; "
        "print(json.dumps(repos))\""
    )
    out, err, rc = ssh(host, cmd)
    if rc != 0 or not out:
        if err:
            print(f"    SSH/stderr: {err}")
        if out:
            print(f"    stdout: {out[:200]}")
        return None
    try:
        repos = json.loads(out)
    except json.JSONDecodeError:
        return None

    models = []
    for repo in repos:
        if repo.get("type") == "model":
            rid = repo.get("id", "")
            if rid:
                models.append((rid, derive_name(rid)))
    return models


PIPELINE_MODALITIES = {
    "text-generation":            {"input": ["text"], "output": ["text"]},
    "image-text-to-text":         {"input": ["text", "image"], "output": ["text"]},
    "image-to-text":              {"input": ["image"], "output": ["text"]},
    "text-to-image":              {"input": ["text"], "output": ["image"]},
    "text-to-audio":              {"input": ["text"], "output": ["audio"]},
    "automatic-speech-recognition": {"input": ["audio"], "output": ["text"]},
    "text-to-video":              {"input": ["text"], "output": ["video"]},
    "image-to-image":             {"input": ["image"], "output": ["image"]},
    "audio-to-audio":             {"input": ["audio"], "output": ["audio"]},
    "any-to-any":                 {"input": ["text", "image", "audio"], "output": ["text", "image", "audio"]},
}


def fetch_pipeline_tag(model_id):
    """Return pipeline_tag from HF Hub API, or None."""
    try:
        data = http_json(f"https://huggingface.co/api/models/{model_id}", timeout=10)
        return data.get("pipeline_tag")
    except (urllib.error.URLError, OSError, json.JSONDecodeError, KeyError):
        return None


KNOWN_ORGS = {
    "qwen": "Qwen", "llama": "meta-llama", "mistral": "mistralai",
    "gemma": "google", "phi": "microsoft", "deepseek": "deepseek-ai",
    "command": "CohereForAI", "dolphin": "cognitivecomputations",
    "yi": "01-ai", "falcon": "tiiuae", "mixtral": "mistralai",
    "codellama": "codellama", "openchat": "openchat", "orca": "microsoft",
    "vicuna": "lmsys", "wizard": "WizardLM", "zephyr": "HuggingFaceH4",
    "tinyllama": "TinyLlama", "starcoder": "bigcode", "stablelm": "stabilityai",
    "solar": "upstage", "nomic": "nomic-ai", "dbrx": "databricks",
    "nemotron": "nvidia", "laguna": "poolside",
}


def resolve_modalities(model_id):
    """Try to find modalities for any model ID (HF, Ollama, LM Studio) via HF Hub API."""
    # Model ID already has HF-style org/name
    if "/" in model_id:
        tag = fetch_pipeline_tag(model_id)
        if tag and tag in PIPELINE_MODALITIES:
            return PIPELINE_MODALITIES[tag], tag
        return None, tag

    # Strip Ollama-style tag like :latest, :27b, :q4_K_M
    base = model_id.split(":")[0] if ":" in model_id else model_id
    ollama_tag = model_id.split(":")[1] if ":" in model_id else ""

    # Build candidate HF IDs
    candidates = []

    # Try with known org prefix
    base_lower = base.lower()
    for key, org in KNOWN_ORGS.items():
        if base_lower.startswith(key):
            # Base without tag (lower + title)
            candidates.append(f"{org}/{base}")
            # Base title-cased
            tc = base[0].upper() + base[1:] if base else base
            candidates.append(f"{org}/{tc}")
            # If Ollama tag looks like a param size (e.g. 27b, 7b, 70b), append it
            if ollama_tag and any(c.isdigit() for c in ollama_tag):
                candidates.append(f"{org}/{tc}-{ollama_tag.upper()}")
            break

    # Also try the base name as-is
    candidates.append(base)
    if ollama_tag and any(c.isdigit() for c in ollama_tag):
        candidates.append(f"{base}-{ollama_tag}")

    for candidate in candidates:
        tag = fetch_pipeline_tag(candidate)
        if tag and tag in PIPELINE_MODALITIES:
            return PIPELINE_MODALITIES[tag], tag

    return None, tag if candidates else None


def add_modalities(models):
    """For each (model_id, name) pair, query HF Hub API. Returns (models, modalities_map)."""
    modalities_map = {}
    for model_id, name in models:
        mods, tag = resolve_modalities(model_id)
        if mods:
            modalities_map[model_id] = mods
            print(f"      {model_id} -> {tag}")
        else:
            print(f"      {model_id} -> unknown (tag={tag or 'none'})")
    return models, modalities_map


def upsert_provider(providers, key, name, base_url, models, modalities_map=None):
    if key in providers:
        providers[key]["name"] = name
        providers[key].setdefault("options", {})
        providers[key]["options"]["baseURL"] = base_url
        providers[key]["models"] = _build_models(models, modalities_map)
    else:
        providers[key] = {
            "npm": "@ai-sdk/openai-compatible",
            "name": name,
            "options": {"baseURL": base_url},
            "models": _build_models(models, modalities_map),
        }


def _build_models(models, modalities_map=None):
    result = {}
    for mid, dname in models:
        entry = {"name": dname}
        if modalities_map and mid in modalities_map:
            entry["modalities"] = modalities_map[mid]
        result[mid] = entry
    return result


def main():
    args = parse_args()

    config = load_existing()
    config.setdefault("provider", {})
    providers = config["provider"]

    if args.host:
        print(f"Scanning remote host {args.host} ...")
        host = args.host
        ip = resolve_ip(host)
        print(f"  IP: {ip}")

        print(f"  Ollama (port {args.port_ollama}) ...")
        models = discover_ollama_remote(host, args.port_ollama)
        if models is not None:
            modalities_map = {}
            if args.modalities:
                print("    querying HF Hub for modalities...")
                models, modalities_map = add_modalities(models)
            upsert_provider(providers, "ollama", "Ollama (auto)",
                            f"http://{ip}:{args.port_ollama}/v1", models, modalities_map)
            print(f"    {len(models)} model(s)")
        else:
            print("    not found")

        print(f"  LM Studio (port {args.port_lmstudio}) ...")
        models = discover_lmstudio_remote(host, args.port_lmstudio)
        if models is not None:
            modalities_map = {}
            if args.modalities:
                print("    querying HF Hub for modalities...")
                models, modalities_map = add_modalities(models)
            upsert_provider(providers, "lmstudio", "LM Studio (auto)",
                            f"http://{ip}:{args.port_lmstudio}/v1", models, modalities_map)
            print(f"    {len(models)} model(s)")
        else:
            print("    not found")

        print(f"  vLLM via hf cache (port {args.port_vllm}) ...")
        models = discover_vllm_remote(host)
        if models is not None:
            modalities_map = {}
            if args.modalities:
                print("    querying HF Hub for modalities...")
                models, modalities_map = add_modalities(models)
            upsert_provider(providers, "vllm", "vLLM (auto)",
                            f"http://{ip}:{args.port_vllm}/v1", models, modalities_map)
            print(f"    {len(models)} model(s)")
        else:
            print("    not found")
    else:
        print("Scanning localhost ...")

        print(f"  Ollama (port {args.port_ollama}) ...")
        models = discover_ollama_local(args.port_ollama)
        if models is not None:
            modalities_map = {}
            if args.modalities:
                print("    querying HF Hub for modalities...")
                models, modalities_map = add_modalities(models)
            upsert_provider(providers, "ollama", "Ollama (auto)",
                            f"http://127.0.0.1:{args.port_ollama}/v1", models, modalities_map)
            print(f"    {len(models)} model(s)")
        else:
            print("    not found")

        print(f"  LM Studio (port {args.port_lmstudio}) ...")
        models = discover_lmstudio_local(args.port_lmstudio)
        if models is not None:
            modalities_map = {}
            if args.modalities:
                print("    querying HF Hub for modalities...")
                models, modalities_map = add_modalities(models)
            upsert_provider(providers, "lmstudio", "LM Studio (auto)",
                            f"http://127.0.0.1:{args.port_lmstudio}/v1", models, modalities_map)
            print(f"    {len(models)} model(s)")
        else:
            print("    not found")

    save_config(config, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
