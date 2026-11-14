#!/usr/bin/env python3
"""
App Store Connect API programmatic distribution helper.
Supports TestFlight distribution, build polling, and production App Store submission.
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from typing import Any, Dict, List, Optional

API_BASE = "https://api.appstoreconnect.apple.com/v1"


def get_asc_credentials() -> Dict[str, str]:
    key_id = os.environ.get("ASC_KEY_ID")
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_path = os.environ.get("ASC_KEY_PATH")

    if not key_id or not issuer_id:
        print("ERROR: ASC_KEY_ID and ASC_ISSUER_ID environment variables are required.", file=sys.stderr)
        sys.exit(1)

    if not key_path:
        search_paths = [
            f"{os.environ.get('HOME', '')}/.appstoreconnect/private_keys/AuthKey_{key_id}.p8",
            f"{os.environ.get('HOME', '')}/.private_keys/AuthKey_{key_id}.p8",
            f"./private_keys/AuthKey_{key_id}.p8",
            f"AuthKey_{key_id}.p8",
        ]
        for p in search_paths:
            if os.path.isfile(p):
                key_path = p
                break

    if not key_path or not os.path.isfile(key_path):
        print(f"ERROR: .p8 key file not found. Set ASC_KEY_PATH or place in ~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8", file=sys.stderr)
        sys.exit(1)

    return {"key_id": key_id, "issuer_id": issuer_id, "key_path": key_path}


def generate_jwt() -> str:
    creds = get_asc_credentials()
    # Try xcrun altool first
    try:
        cmd = [
            "xcrun", "altool", "--generate-jwt",
            "--apiKey", creds["key_id"],
            "--apiIssuer", creds["issuer_id"],
            "--p8-file-path", creds["key_path"]
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        for line in res.stdout.strip().splitlines():
            line = line.strip()
            if line.startswith("eyJ") and line.count(".") == 2:
                return line
    except Exception:
        pass

    # Fallback to OpenSSL CLI
    now = int(time.time())
    exp = now + 1200
    def b64url(b: bytes) -> str:
        return base64.urlsafe_b64encode(b).rstrip(b"=").decode("ascii")

    header = b64url(json.dumps({"alg": "ES256", "kid": creds["key_id"], "typ": "JWT"}).encode("utf-8"))
    payload = b64url(json.dumps({"iss": creds["issuer_id"], "iat": now, "exp": exp, "aud": "appstoreconnect-v1"}).encode("utf-8"))
    unsigned = f"{header}.{payload}".encode("ascii")

    # Sign with openssl
    sign_cmd = ["openssl", "dgst", "-sha256", "-sign", creds["key_path"]]
    proc = subprocess.run(sign_cmd, input=unsigned, capture_output=True, check=True)
    der_sig = proc.stdout

    # Convert ASN.1 DER ECDSA signature to raw 64-byte P1363 (r || s)
    # DER: 0x30 <len> 0x02 <r_len> <r> 0x02 <s_len> <s>
    if der_sig[0] == 0x30:
        idx = 2
        if der_sig[idx] == 0x02:
            r_len = der_sig[idx + 1]
            r = der_sig[idx + 2 : idx + 2 + r_len]
            idx = idx + 2 + r_len
            if der_sig[idx] == 0x02:
                s_len = der_sig[idx + 1]
                s = der_sig[idx + 2 : idx + 2 + s_len]
                r = r.lstrip(b"\x00").rjust(32, b"\x00")[-32:]
                s = s.lstrip(b"\x00").rjust(32, b"\x00")[-32:]
                sig_raw = r + s
                sig_b64 = b64url(sig_raw)
                return f"{header}.{payload}.{sig_b64}"

    return f"{header}.{payload}." + b64url(der_sig)


def api_request(method: str, path: str, data: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    url = f"{API_BASE}{path}" if path.startswith("/") else path
    token = generate_jwt()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            resp_body = resp.read().decode("utf-8")
            if not resp_body.strip():
                return {}
            return json.loads(resp_body)
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8")
        print(f"API Error [{e.code}] {method} {url}:\n{err_msg}", file=sys.stderr)
        raise


def get_app(bundle_id: str) -> Dict[str, Any]:
    res = api_request("GET", f"/apps?filter[bundleId]={bundle_id}")
    apps = res.get("data", [])
    if not apps:
        raise RuntimeError(f"No app found in App Store Connect with bundle ID: {bundle_id}")
    return apps[0]


def poll_build_ready(app_id: str, target_version: Optional[str] = None, timeout_mins: int = 25) -> Dict[str, Any]:
    label = f"version {target_version}" if target_version else "latest build"
    print(f"⏳ Waiting for {label} of app {app_id} to finish processing in App Store Connect...")
    start_time = time.time()
    while time.time() - start_time < timeout_mins * 60:
        query = f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=10"
        if target_version:
            query += f"&filter[version]={target_version}"
        res = api_request("GET", query)
        builds = res.get("data", [])
        if not builds:
            print(f"  Build {target_version or ''} not registered in App Store Connect yet. Waiting 20s...")
            time.sleep(20)
            continue

        build = builds[0]
        state = build.get("attributes", {}).get("processingState")
        version = build.get("attributes", {}).get("version")
        build_id = build.get("id")

        print(f"  Build ID: {build_id} (Version: {version}) - Processing State: {state}")
        if state == "VALID":
            print(f"✅ Build {build_id} (Version {version}) is VALID and ready for distribution!")
            return build
        elif state in ("FAILED", "INVALID"):
            raise RuntimeError(f"❌ Build processing failed with state: {state}")

        time.sleep(20)

    raise TimeoutError(f"Build processing did not complete within {timeout_mins} minutes.")


def set_age_rating(app_id: str):
    """Sets standard age rating declaration attributes (e.g. socialMedia=False)."""
    try:
        infos = api_request("GET", f"/apps/{app_id}/appInfos").get("data", [])
        if not infos:
            return
        info_id = infos[0]["id"]
        api_request("PATCH", f"/ageRatingDeclarations/{info_id}", {
            "data": {
                "type": "ageRatingDeclarations",
                "id": info_id,
                "attributes": {
                    "socialMedia": False
                }
            }
        })
        print("  ✓ Age rating declaration updated (socialMedia=False).")
    except Exception as e:
        print(f"  ⚠️ Note on age rating: {e}")


def upload_screenshot_file(set_id: str, file_path: str):
    """Uploads a single screenshot file to an appScreenshotSet via App Store Connect S3 ingestion."""
    import hashlib
    file_size = os.path.getsize(file_path)
    file_name = os.path.basename(file_path)
    with open(file_path, "rb") as f:
        file_bytes = f.read()
    checksum = hashlib.md5(file_bytes).hexdigest()

    # 1. Reserve upload
    payload = {
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileName": file_name, "fileSize": file_size},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}
        }
    }
    res = api_request("POST", "/appScreenshots", payload)
    shot_id = res["data"]["id"]
    ops = res["data"]["attributes"]["uploadOperations"]

    # 2. Upload chunks to Apple S3
    for op in ops:
        url = op["url"]
        offset = op["offset"]
        length = op["length"]
        chunk = file_bytes[offset:offset + length]
        req = urllib.request.Request(url, data=chunk, method="PUT")
        for h in op.get("requestHeaders", []):
            req.add_header(h["name"], h["value"])
        with urllib.request.urlopen(req) as put_resp:
            pass

    # 3. Commit upload
    commit_payload = {
        "data": {
            "type": "appScreenshots",
            "id": shot_id,
            "attributes": {"uploaded": True, "sourceFileChecksum": checksum}
        }
    }
    api_request("PATCH", f"/appScreenshots/{shot_id}", commit_payload)
    print(f"  ✓ Uploaded screenshot {file_name} (ID: {shot_id}).")
    return shot_id


def sync_screenshots(app_id: str, screenshots_base_dir: str):
    """
    Audits and synchronizes screenshot sets for iPhone 6.7\" and iPad 12.9\" Pro (3rd Gen)
    to the active App Store Version localization.
    """
    print(f"\n📸 Auditing & Synchronizing App Store Screenshots from: {screenshots_base_dir}...")

    # 1. Get iOS versions
    versions_res = api_request("GET", f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS")
    versions = versions_res.get("data", [])
    if not versions:
        raise RuntimeError("No iOS App Store Versions found for this app.")

    editable_versions = [v for v in versions if v.get("attributes", {}).get("appStoreState") in ("PREPARE_FOR_SUBMISSION", "REJECTED", "DEVELOPER_REJECTED")]
    target_version = editable_versions[0] if editable_versions else versions[0]

    v_id = target_version["id"]
    v_state = target_version.get("attributes", {}).get("appStoreState")
    v_str = target_version.get("attributes", {}).get("versionString")
    print(f"  Target Version: {v_str} (ID: {v_id}, State: {v_state})")

    # Fetch localizations
    locs_res = api_request("GET", f"/appStoreVersions/{v_id}/appStoreVersionLocalizations")
    locs = locs_res.get("data", [])
    if not locs:
        raise RuntimeError(f"No localizations found for version {v_str}.")

    loc = locs[0]
    loc_id = loc["id"]
    locale = loc.get("attributes", {}).get("locale", "en-US")
    print(f"  Localization: {locale} (ID: {loc_id})")

    # Fetch existing screenshot sets
    existing_sets_res = api_request("GET", f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
    existing_sets = {s.get("attributes", {}).get("screenshotDisplayType"): s for s in existing_sets_res.get("data", [])}

    display_type_mapping = {
        "APP_IPHONE_67": os.path.join(screenshots_base_dir, "iphone_67"),
        "APP_IPHONE_65": os.path.join(screenshots_base_dir, "iphone_65"),
        "APP_IPHONE_55": os.path.join(screenshots_base_dir, "iphone_55"),
        "APP_IPHONE_DUO": os.path.join(screenshots_base_dir, "iphone_duo"),
        "APP_IPAD_PRO_3GEN_129": os.path.join(screenshots_base_dir, "ipad_129"),
    }

    is_editable = v_state in ("PREPARE_FOR_SUBMISSION", "REJECTED", "DEVELOPER_REJECTED")

    for display_type, folder in display_type_mapping.items():
        print(f"\n  Checking Display Type: {display_type} (source: {folder})")
        existing_set = existing_sets.get(display_type)
        set_id = existing_set["id"] if existing_set else None

        if set_id:
            shots_res = api_request("GET", f"/appScreenshotSets/{set_id}/appScreenshots")
            shots = shots_res.get("data", [])
            print(f"    Existing set ID: {set_id} ({len(shots)} screenshots registered)")
            for s in shots:
                s_attrs = s.get("attributes", {})
                s_name = s_attrs.get("fileName")
                s_state = s_attrs.get("assetDeliveryState", {}).get("state")
                s_size = s_attrs.get("fileSize")
                print(f"      - {s_name} [{s_size} bytes] -> State: {s_state}")
        else:
            print(f"    No existing screenshot set on App Store Connect for {display_type}.")

        if not os.path.isdir(folder):
            print(f"    ⚠️ Local folder not found: {folder}. Skipping.")
            continue

        local_files = sorted([f for f in os.listdir(folder) if f.lower().endswith(".png")])
        print(f"    Found {len(local_files)} local screenshots: {local_files}")

        if not is_editable:
            print(f"    ℹ️ Version {v_str} is currently '{v_state}' (locked by Apple Review). Screenshot sets are frozen by App Store Connect.")
            continue

        # If editable, create set if needed and upload
        if not set_id:
            print(f"    Creating screenshot set for {display_type}...")
            create_payload = {
                "data": {
                    "type": "appScreenshotSets",
                    "attributes": {"screenshotDisplayType": display_type},
                    "relationships": {
                        "appStoreVersionLocalization": {
                            "data": {"type": "appStoreVersionLocalizations", "id": loc_id}
                        }
                    }
                }
            }
            new_set = api_request("POST", "/appScreenshotSets", create_payload)
            set_id = new_set["data"]["id"]
            print(f"    ✓ Created screenshot set ID: {set_id}")

        existing_names = set()
        if existing_set:
            shots_res = api_request("GET", f"/appScreenshotSets/{set_id}/appScreenshots")
            existing_names = {s.get("attributes", {}).get("fileName") for s in shots_res.get("data", [])}

        for file_name in local_files:
            file_path = os.path.join(folder, file_name)
            if file_name in existing_names:
                print(f"    ✓ Screenshot already exists on ASC: {file_name}")
                continue
            print(f"    Uploading {file_name}...")
            upload_screenshot_file(set_id, file_path)

    print("\n🎉 Screenshot audit and synchronization completed successfully!")


def distribute_testflight(app_id: str, build_id: str, group_name: Optional[str] = None, whats_new: Optional[str] = None):
    print(f"\n🚀 Distributing build {build_id} to TestFlight...")

    # 1. Set "What to Test" notes if provided
    if whats_new:
        try:
            print("  Updating 'What to Test' notes...")
            loc_res = api_request("GET", f"/builds/{build_id}/betaBuildLocalizations")
            locs = loc_res.get("data", [])
            if locs:
                loc_id = locs[0]["id"]
                api_request("PATCH", f"/betaBuildLocalizations/{loc_id}", {
                    "data": {
                        "type": "betaBuildLocalizations",
                        "id": loc_id,
                        "attributes": {"whatsNew": whats_new}
                    }
                })
            else:
                api_request("POST", "/betaBuildLocalizations", {
                    "data": {
                        "type": "betaBuildLocalizations",
                        "attributes": {"locale": "en-US", "whatsNew": whats_new},
                        "relationships": {
                            "build": {"data": {"type": "builds", "id": build_id}}
                        }
                    }
                })
            print("  ✓ Release notes saved.")
        except Exception as e:
            print(f"  ⚠️ Warning setting release notes: {e}")

    # 2. Get beta groups
    groups_res = api_request("GET", f"/apps/{app_id}/betaGroups")
    groups = groups_res.get("data", [])
    if not groups:
        print("  ⚠️ No TestFlight beta groups found for this app. Build remains available to internal team.")
        return

    target_groups = []
    if group_name:
        target_groups = [g for g in groups if g.get("attributes", {}).get("name", "").lower() == group_name.lower()]
        if not target_groups:
            print(f"  ⚠️ Group '{group_name}' not found. Available groups: {[g['attributes']['name'] for g in groups]}")
            target_groups = groups
    else:
        target_groups = groups

    for g in target_groups:
        gid = g["id"]
        gname = g.get("attributes", {}).get("name", gid)
        is_internal = g.get("attributes", {}).get("isInternalGroup", False)
        if is_internal:
            print(f"  ℹ️ Internal group '{gname}' automatically receives all valid builds.")
            continue

        print(f"  Adding build to TestFlight external group: '{gname}'...")
        payload = {
            "data": [{"type": "builds", "id": build_id}]
        }
        try:
            api_request("POST", f"/betaGroups/{gid}/relationships/builds", payload)
            print(f"  ✓ Added to '{gname}'.")
        except Exception as e:
            print(f"  ⚠️ Note for group '{gname}': {e}")

    print("🎉 TestFlight distribution complete!")


def distribute_production(app_id: str, build_id: str, version_string: Optional[str] = None, whats_new: Optional[str] = None, submit_review: bool = False):
    print(f"\n🚀 Preparing Production App Store Release for build {build_id}...")

    # 1. Find App Store Version in editable state (PREPARE_FOR_SUBMISSION, REJECTED, DEVELOPER_REJECTED)
    versions_res = api_request("GET", f"/apps/{app_id}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,REJECTED,DEVELOPER_REJECTED")
    versions = versions_res.get("data", [])
    if not versions:
        # Fallback to inspecting all iOS versions
        all_versions = api_request("GET", f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS").get("data", [])
        versions = [v for v in all_versions if v.get("attributes", {}).get("appStoreState") in ("PREPARE_FOR_SUBMISSION", "REJECTED", "DEVELOPER_REJECTED")]
    version_obj = None

    if versions:
        version_obj = versions[0]
        v_str = version_obj.get("attributes", {}).get("versionString")
        print(f"  Found pending App Store Version: {v_str} (ID: {version_obj['id']})")
    elif version_string:
        print(f"  No editable version found. Creating App Store Version {version_string}...")
        create_payload = {
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "platform": "IOS",
                    "versionString": version_string,
                    "releaseType": "AFTER_APPROVAL"
                },
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}}
                }
            }
        }
        created = api_request("POST", "/appStoreVersions", create_payload)
        version_obj = created.get("data")
    else:
        raise RuntimeError("No App Store version in 'PREPARE_FOR_SUBMISSION' state found. Provide --version-string to create one.")

    version_id = version_obj["id"]

    # 2. Attach build to App Store Version
    print(f"  Attaching build {build_id} to App Store version {version_id}...")
    api_request("PATCH", f"/appStoreVersions/{version_id}/relationships/build", {
        "data": {"type": "builds", "id": build_id}
    })
    print("  ✓ Build attached to App Store Version.")

    # 3. Update "What's New" release notes if provided
    if whats_new:
        try:
            print("  Updating App Store 'What's New' release notes...")
            locs_res = api_request("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")
            locs = locs_res.get("data", [])
            for loc in locs:
                loc_id = loc["id"]
                api_request("PATCH", f"/appStoreVersionLocalizations/{loc_id}", {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": loc_id,
                        "attributes": {"whatsNew": whats_new}
                    }
                })
            print("  ✓ Release notes updated.")
        except Exception as e:
            print(f"  ⚠️ Warning setting App Store release notes: {e}")

    # 4. Submit for review if requested
    if submit_review:
        print("\n📤 Submitting App Store Version for Review...")
        set_age_rating(app_id)
        try:
            # Check for existing submission with unresolved issues first (resubmission flow)
            unresolved_subs = api_request("GET", f"/apps/{app_id}/reviewSubmissions?filter[state]=UNRESOLVED_ISSUES").get("data", [])
            if unresolved_subs:
                sub_id = unresolved_subs[0]["id"]
                print(f"  Resubmitting existing submission with unresolved issues: {sub_id}")
            else:
                # Query existing open review submission or create a new one
                open_subs = api_request("GET", f"/apps/{app_id}/reviewSubmissions?filter[state]=READY_FOR_REVIEW").get("data", [])
                if open_subs:
                    sub_id = open_subs[0]["id"]
                else:
                    sub_res = api_request("POST", "/reviewSubmissions", {
                        "data": {
                            "type": "reviewSubmissions",
                            "attributes": {"platform": "IOS"},
                            "relationships": {
                                "app": {"data": {"type": "apps", "id": app_id}}
                            }
                        }
                    })
                    sub_id = sub_res.get("data", {}).get("id")

                # Check if version item already attached
                items = api_request("GET", f"/reviewSubmissions/{sub_id}/items").get("data", [])
                attached = any(item.get("relationships", {}).get("appStoreVersion", {}).get("data", {}).get("id") == version_id for item in items)
                if not attached:
                    api_request("POST", "/reviewSubmissionItems", {
                        "data": {
                            "type": "reviewSubmissionItems",
                            "relationships": {
                                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}
                            }
                        }
                    })

            api_request("PATCH", f"/reviewSubmissions/{sub_id}", {
                "data": {
                    "type": "reviewSubmissions",
                    "id": sub_id,
                    "attributes": {"submitted": True}
                }
            })
            print("🎉 Successfully submitted to App Store Review!")
        except Exception as e:
            print(f"  Falling back to legacy submission endpoint: {e}")
            api_request("POST", "/appStoreVersionSubmissions", {
                "data": {
                    "type": "appStoreVersionSubmissions",
                    "relationships": {
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}
                    }
                }
            })
            print("🎉 Successfully submitted to App Store Review!")
    else:
        print("ℹ️ Submission omitted (use --submit-review to automatically submit for Apple review).")


def main():
    parser = argparse.ArgumentParser(description="App Store Connect Programmatic Distribution Tool")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # status
    p_status = subparsers.add_parser("status", help="Check app status and latest builds")
    p_status.add_argument("--bundle-id", default=os.environ.get("APP_BUNDLE_ID", "club.foodshare.audiobookphile"))

    # testflight
    p_tf = subparsers.add_parser("testflight", help="Distribute latest build to TestFlight")
    p_tf.add_argument("--bundle-id", default=os.environ.get("APP_BUNDLE_ID", "club.foodshare.audiobookphile"))
    p_tf.add_argument("--build-id", help="Specific build ID (if omitted, polls for build)")
    p_tf.add_argument("--build-version", help="Build number to wait for (e.g. 302)")
    p_tf.add_argument("--group", help="TestFlight beta group name (default: all groups)")
    p_tf.add_argument("--whats-new", help="What to test release notes")

    # production
    p_prod = subparsers.add_parser("production", help="Attach build to App Store Version and submit")
    p_prod.add_argument("--bundle-id", default=os.environ.get("APP_BUNDLE_ID", "club.foodshare.audiobookphile"))
    p_prod.add_argument("--build-id", help="Specific build ID (if omitted, polls for build)")
    p_prod.add_argument("--build-version", help="Build number to wait for (e.g. 302)")
    p_prod.add_argument("--version-string", help="Version string to create if none exists (e.g. 1.0.1)")
    p_prod.add_argument("--whats-new", help="What's new in this version release notes")
    p_prod.add_argument("--submit-review", "--submit", dest="submit_review", action="store_true", help="Submit to App Store review")

    # next-build-number
    p_num = subparsers.add_parser("next-build-number", help="Get next build number from App Store Connect")
    p_num.add_argument("--bundle-id", default=os.environ.get("APP_BUNDLE_ID", "club.foodshare.audiobookphile"))

    # screenshots
    p_shots = subparsers.add_parser("screenshots", help="Audit and sync App Store screenshots")
    p_shots.add_argument("--bundle-id", default=os.environ.get("APP_BUNDLE_ID", "club.foodshare.audiobookphile"))
    p_shots.add_argument("--dir", default="build/screenshots", help="Path to build/screenshots directory")

    args = parser.parse_args()

    app = get_app(args.bundle_id)
    app_id = app["id"]
    app_name = app.get("attributes", {}).get("name")
    if args.command != "next-build-number":
        print(f"📱 Connected to App Store Connect: {app_name} (ID: {app_id}, Bundle: {args.bundle_id})")

    if args.command == "next-build-number":
        builds_res = api_request("GET", f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=1")
        builds = builds_res.get("data", [])
        if builds:
            latest = builds[0].get("attributes", {}).get("version", "0")
            try:
                print(int(latest) + 1)
                return
            except ValueError:
                pass
        print(1)
        return

    elif args.command == "status":
        builds_res = api_request("GET", f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=5")
        print("\n📦 Recent Builds:")
        for b in builds_res.get("data", []):
            attrs = b.get("attributes", {})
            print(f"  - Build {b['id']}: Version {attrs.get('version')} (State: {attrs.get('processingState')}, Uploaded: {attrs.get('uploadedDate')})")

        groups_res = api_request("GET", f"/apps/{app_id}/betaGroups")
        print("\n👥 TestFlight Groups:")
        for g in groups_res.get("data", []):
            attrs = g.get("attributes", {})
            print(f"  - {attrs.get('name')} (Internal: {attrs.get('isInternalGroup')}, ID: {g['id']})")

        versions_res = api_request("GET", f"/apps/{app_id}/appStoreVersions")
        print("\n🏪 App Store Versions:")
        for v in versions_res.get("data", []):
            attrs = v.get("attributes", {})
            print(f"  - Version {attrs.get('versionString')} (State: {attrs.get('appStoreState')}, ID: {v['id']})")

    elif args.command == "testflight":
        build_id = args.build_id
        if not build_id:
            build = poll_build_ready(app_id, target_version=args.build_version)
            build_id = build["id"]
        distribute_testflight(app_id, build_id, group_name=args.group, whats_new=args.whats_new)

    elif args.command == "production":
        build_id = args.build_id
        if not build_id:
            build = poll_build_ready(app_id, target_version=args.build_version)
            build_id = build["id"]
        distribute_production(app_id, build_id, version_string=args.version_string, whats_new=args.whats_new, submit_review=args.submit_review)

    elif args.command == "screenshots":
        shots_dir = os.path.abspath(args.dir)
        sync_screenshots(app_id, shots_dir)


if __name__ == "__main__":
    main()

