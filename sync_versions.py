import os
import re
import json

# Paths relative to this script (Project Root)
ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
PUBSPEC_PATH = os.path.join(ROOT_DIR, 'super_skripsi_manager', 'pubspec.yaml')
APP_CONSTANTS_PATH = os.path.join(ROOT_DIR, 'super_skripsi_manager', 'lib', 'constants', 'app_constants.dart')
EXTENSION_MANIFEST = os.path.join(ROOT_DIR, 'super_skripsi_extension', 'manifest.json')
ADDIN_PACKAGE = os.path.join(ROOT_DIR, 'super_skripsi_addin', 'package.json')
ADDIN_MANIFEST = os.path.join(ROOT_DIR, 'super_skripsi_addin', 'manifest.xml')

# UI Paths for Version Display
EXTENSION_POPUP = os.path.join(ROOT_DIR, 'super_skripsi_extension', 'popup.html')
ADDIN_APP_JSX = os.path.join(ROOT_DIR, 'super_skripsi_addin', 'src', 'taskpane', 'App.jsx')

def get_version_from_pubspec():
    if not os.path.exists(PUBSPEC_PATH):
        print(f"Error: {PUBSPEC_PATH} not found.")
        return None
        
    with open(PUBSPEC_PATH, 'r') as f:
        content = f.read()
        # Regex to find version: 1.1.7+1
        match = re.search(r'version:\s*([^\s+]+)', content)
        if match:
            return match.group(1).strip()
    return None

def update_app_constants(version):
    if not os.path.exists(APP_CONSTANTS_PATH): return
    
    with open(APP_CONSTANTS_PATH, 'r') as f:
        content = f.read()
    
    # Update currentVersion = 'X.X.X'
    new_content = re.sub(r"currentVersion = '(.*?)'", f"currentVersion = '{version}'", content)
    
    with open(APP_CONSTANTS_PATH, 'w') as f:
        f.write(new_content)
    print(f"Updated AppConstants.dart: {version}")

def update_extension(version):
    path = EXTENSION_MANIFEST
    if not os.path.exists(path): return
    
    with open(path, 'r') as f:
        data = json.load(f)
    
    data['version'] = version
    
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Updated Extension Manifest: {version}")

def update_addin_package(version):
    path = ADDIN_PACKAGE
    if not os.path.exists(path): return
    
    with open(path, 'r') as f:
        data = json.load(f)
    
    data['version'] = version
    
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Updated Add-in Package: {version}")

def update_addin_manifest(version):
    path = ADDIN_MANIFEST
    if not os.path.exists(path): return
    
    # Manifest XML version must be 4 parts: 1.0.0.0
    xml_version = version if version.count('.') == 3 else version + ".0"
    
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    content = re.sub(r'<Version>.*?</Version>', f'<Version>{xml_version}</Version>', content)
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Updated Add-in XML: {xml_version}")

def update_ui_versions(version):
    # 1. Extension Popup HTML
    if os.path.exists(EXTENSION_POPUP):
        with open(EXTENSION_POPUP, 'r', encoding='utf-8') as f:
            content = f.read()
        content = re.sub(r'id="appVersion">v.*?</span>', f'id="appVersion">v{version}</span>', content)
        with open(EXTENSION_POPUP, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated Extension UI Version: v{version}")
        
    # 2. Add-in App.jsx
    if os.path.exists(ADDIN_APP_JSX):
        with open(ADDIN_APP_JSX, 'r', encoding='utf-8') as f:
            content = f.read()
        content = re.sub(r'className="version-tag">v.*?</span>', f'className="version-tag">v{version}</span>', content)
        with open(ADDIN_APP_JSX, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated Add-in UI Version: v{version}")

def update_iss_version(version):
    path = os.path.join(ROOT_DIR, 'super_sk_manager', 'windows', 'installer', 'super_skripsi_setup.iss')
    # Try alternate path if not found
    if not os.path.exists(path):
        path = os.path.join(ROOT_DIR, 'super_skripsi_manager', 'windows', 'installer', 'super_skripsi_setup.iss')
        
    if not os.path.exists(path): return
    
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Update #define MyAppVersion "X.X.X" (only if it's the fallback version)
    new_content = re.sub(r'#define MyAppVersion "(.*?)"', f'#define MyAppVersion "{version}"', content)
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f"Updated Inno Setup Script: {version}")

if __name__ == "__main__":
    print("Synchronizing versions using pubspec.yaml as source of truth...")
    version = get_version_from_pubspec()
    if version:
        update_app_constants(version)
        update_iss_version(version)
        update_extension(version)
        update_addin_package(version)
        update_addin_manifest(version)
        update_ui_versions(version)
        print(f"\nSuccess! All projects are now in sync with version: {version}")
    else:
        print("Error: Could not read version from pubspec.yaml.")
