#!/usr/bin/env -S nix shell nixpkgs#python3 nixpkgs#p7zip --command python3

"""Update script for claude-desktop package.

This script automates version updates by:
- Detecting the latest version from Claude download URLs
- Downloading both x86_64 and aarch64 installers
- Extracting version from installer contents
- Calculating SHA256 hashes
- Updating package.nix with new version and hashes
"""

import hashlib
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def check_url_accessible(url: str) -> bool:
    """Check if a URL is accessible.

    Args:
        url: URL to check

    Returns:
        True if URL is accessible, False otherwise
    """
    try:
        req = Request(url, method="HEAD")
        req.add_header("User-Agent", "Mozilla/5.0")
        with urlopen(req, timeout=10) as response:
            return response.status == 200
    except (URLError, HTTPError, TimeoutError):
        return False


def download_file(url: str, dest_path: Path) -> None:
    """Download a file from URL to destination path.

    Args:
        url: URL to download from
        dest_path: Destination file path
    """
    req = Request(url)
    req.add_header("User-Agent", "Mozilla/5.0")

    with urlopen(req, timeout=30) as response:
        dest_path.write_bytes(response.read())


def calculate_file_hash(file_path: Path) -> str:
    """Calculate SHA256 hash of a file in SRI format.

    Args:
        file_path: Path to file

    Returns:
        Hash in SRI format (sha256-...)
    """
    sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(8192):
            sha256.update(chunk)

    # Convert to base64 for SRI format
    import base64

    hash_b64 = base64.b64encode(sha256.digest()).decode("ascii")
    return f"sha256-{hash_b64}"


def extract_version_from_installer(installer_path: Path) -> str | None:
    """Extract version from Windows installer using 7z.

    Args:
        installer_path: Path to the .exe installer

    Returns:
        Version string if found, None otherwise
    """
    try:
        # List contents and look for version in NuGet package name
        result = subprocess.run(
            ["7z", "l", str(installer_path)],
            check=True,
            capture_output=True,
            text=True,
        )

        # Look for patterns like "AnthropicClaude-1.0.1217"
        match = re.search(r"AnthropicClaude-(\d+\.\d+\.\d+)", result.stdout)
        if match:
            return match.group(1)

        # Try extracting to find .nupkg files
        with tempfile.TemporaryDirectory() as temp_extract_dir:
            extract_path = Path(temp_extract_dir)
            subprocess.run(
                ["7z", "x", "-y", str(installer_path), f"-o{extract_path}"],
                check=True,
                capture_output=True,
            )

            # Find .nupkg files
            nupkg_files = list(extract_path.glob("AnthropicClaude-*.nupkg"))
            if nupkg_files:
                nupkg_name = nupkg_files[0].name
                match = re.search(r"AnthropicClaude-(\d+\.\d+\.\d+)", nupkg_name)
                if match:
                    return match.group(1)

    except subprocess.CalledProcessError:
        pass

    return None


def main() -> None:
    """Update claude-desktop package."""
    script_dir = Path(__file__).parent.resolve()
    package_file = script_dir / "package.nix"

    if not package_file.exists():
        print(f"ERROR: Package file not found: {package_file}")
        sys.exit(1)

    # Read current package.nix to get current version and URL pattern
    content = package_file.read_text()

    # Extract current version
    version_match = re.search(r'version\s*=\s*"([^"]+)"', content)
    if not version_match:
        print("ERROR: Could not find version in package.nix")
        sys.exit(1)

    current_version = version_match.group(1)
    print(f"Current version: {current_version}")

    # Extract x64CommitHash
    x64_commit_match = re.search(r'x64CommitHash\s*=\s*"([^"]+)"', content)
    if not x64_commit_match:
        print("ERROR: Could not find x64CommitHash in package.nix")
        sys.exit(1)

    current_commit_hash = x64_commit_match.group(1)
    print(f"Current x64CommitHash: {current_commit_hash}")

    # Extract URL pattern for x86_64
    x64_url_match = re.search(
        r'x86_64-linux\s*=\s*fetchurl\s*\{[^}]*url\s*=\s*"([^"]+)"',
        content,
        re.MULTILINE | re.DOTALL,
    )

    if not x64_url_match:
        print("ERROR: Could not find x86_64-linux URL in package.nix")
        sys.exit(1)

    x64_url_template = x64_url_match.group(1)

    # Substitute ${version} and ${x64CommitHash} placeholders
    x64_url = x64_url_template.replace("${version}", current_version)
    x64_url = x64_url.replace("${x64CommitHash}", current_commit_hash)

    # Use fixed arm64 URL (not versioned)
    arm64_url = "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-arm64/Claude-Setup-arm64.exe"

    print(f"\nChecking installers...")
    print(f"x64 URL: {x64_url}")

    # Check if URLs are accessible
    if not check_url_accessible(x64_url):
        print("ERROR: Cannot access x64 installer")
        sys.exit(1)
    print("✓ x64 installer is accessible")

    if not check_url_accessible(arm64_url):
        print("ERROR: Cannot access arm64 installer")
        sys.exit(1)
    print("✓ arm64 installer is accessible")

    # Download and extract version
    print("\nExtracting version from installer...")
    version = None

    with tempfile.TemporaryDirectory() as temp_dir:
        installer_path = Path(temp_dir) / "claude-setup.exe"

        try:
            print("Downloading x64 installer...")
            download_file(x64_url, installer_path)

            if installer_path.exists():
                version = extract_version_from_installer(installer_path)
                if version:
                    print(f"✓ Detected version: {version}")
        except Exception as e:
            print(f"Warning: Failed to extract version: {e}")

    if not version:
        print("ERROR: Could not detect version from installer")
        sys.exit(1)

    if version == current_version:
        print(f"\nVersion {version} is already up to date!")
        sys.exit(0)

    print(f"\nNew version available: {current_version} → {version}")

    # Calculate hashes for both platforms
    print("\nCalculating hashes...")

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)

        # Download x64
        x64_file = temp_path / "claude-x64.exe"
        print("Downloading x64 installer...")
        download_file(x64_url, x64_file)
        x64_hash = calculate_file_hash(x64_file)
        print(f"✓ x64 hash: {x64_hash}")

        # Download arm64
        arm64_file = temp_path / "claude-arm64.exe"
        print("Downloading arm64 installer...")
        download_file(arm64_url, arm64_file)
        arm64_hash = calculate_file_hash(arm64_file)
        print(f"✓ arm64 hash: {arm64_hash}")

    # Update package.nix
    print("\nUpdating package.nix...")

    # Update version
    content = re.sub(r'version\s*=\s*"[^"]+"', f'version = "{version}"', content)
    print(f"✓ Updated version to {version}")

    # Update x64 hash
    content = re.sub(
        r'(x86_64-linux\s*=\s*fetchurl\s*\{[^}]*hash\s*=\s*")sha256-[A-Za-z0-9+/=]+"',
        rf'\1{x64_hash}"',
        content,
        flags=re.MULTILINE | re.DOTALL,
    )
    print("✓ Updated x64 hash")

    # Update arm64 hash
    content = re.sub(
        r'(aarch64-linux\s*=\s*fetchurl\s*\{[^}]*hash\s*=\s*")sha256-[A-Za-z0-9+/=]+"',
        rf'\1{arm64_hash}"',
        content,
        flags=re.MULTILINE | re.DOTALL,
    )
    print("✓ Updated arm64 hash")

    # Write updated content
    package_file.write_text(content)

    print(f"\n✓ Update complete! {current_version} → {version}")
    print("\nPlease verify the changes and test the build:")
    print("  NIXPKGS_ALLOW_UNFREE=1 nix build .#claude-desktop --impure")


if __name__ == "__main__":
    main()
