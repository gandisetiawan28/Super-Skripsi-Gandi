import os
import re
import json

# Paths relative to this script (Project Root)
ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
APP_CONSTANTS_PATH = os.path.join(ROOT_DIR, 'super_skripsi_manager', 'lib', 'constants', 'app_constants.dart')
EXTENSION_MANIFEST = os.path.join(ROOT_DIR, 'super_skripsi_extension', 'manifest.json')
ADDIN_PACKAGE = os.path.join(ROOT_DIR, 'super_skripsi_addin', 'package.json')
ADDIN_MANIFEST = os.path.join(ROOT_DIR, 'super_skripsi_addin', 'manifest.xml')

# UI Paths for Version Display
EXTENSION_POPUP = os.path.join(ROOT_DIR, 'super_skripsi_extension', 'popup.html')
ADDIN_APP_JSX = os.path.join(ROOT_DIR, 'super_skripsi_addin', 'src', 'taskpane', 'App.jsx')

def get_constants():
    constants = {}
    if not os.path.exists(APP_CONSTANTS_PATH):
        return None
        
    with open(APP_CONSTANTS_PATH, 'r') as f:
        content = f.read()
        # Extract version
        v_match = re.search(r"currentVersion = '(.*?)'", content)
        if v_match:
            constants['version'] = v_match.group(1)
            
        # Extract app name
        n_match = re.search(r"appName = '(.*?)'", content)
        if n_match:
            constants['name'] = n_match.group(1)
            
    return constants if 'version' in constants else None

def update_extension(constants):
    path = EXTENSION_MANIFEST
    if not os.path.exists(path): return
    
    with open(path, 'r') as f:
        data = json.load(f)
    
    data['version'] = constants['version']
    if 'name' in constants:
        data['name'] = constants['name']
        
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Updated Extension Manifest: {constants['version']}")

def update_addin_package(constants):
    path = ADDIN_PACKAGE
    if not os.path.exists(path): return
    
    with open(path, 'r') as f:
        data = json.load(f)
    
    data['version'] = constants['version']
    # name in package.json is usually slugified, so we don't sync it
    
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Updated Add-in Package: {constants['version']}")

def update_addin_manifest(constants):
    path = ADDIN_MANIFEST
    if not os.path.exists(path): return
    
    # Manifest XML version must be 4 parts: 1.0.0.0
    v = constants['version']
    xml_version = v if v.count('.') == 3 else v + ".0"
    
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Update Version
    content = re.sub(r'<Version>.*?</Version>', f'<Version>{xml_version}</Version>', content)
    
    # Update DisplayName (if exists)
    if 'name' in constants:
        content = re.sub(r'<DisplayName DefaultValue=".*?" />', f'<DisplayName DefaultValue="{constants["name"]}" />', content)
        content = re.sub(r'<bt:String id="GetStarted.Title" DefaultValue=".*?" />', f'<bt:String id="GetStarted.Title" DefaultValue="{constants["name"]}" />', content)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Updated Add-in XML: {xml_version}")

def update_ui_versions(constants):
    v = constants['version']
    
    # 1. Extension Popup HTML
    if os.path.exists(EXTENSION_POPUP):
        with open(EXTENSION_POPUP, 'r', encoding='utf-8') as f:
            content = f.read()
        content = re.sub(r'id="appVersion">v.*?</span>', f'id="appVersion">v{v}</span>', content)
        with open(EXTENSION_POPUP, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated Extension UI Version: v{v}")
        
    # 2. Add-in App.jsx
    if os.path.exists(ADDIN_APP_JSX):
        with open(ADDIN_APP_JSX, 'r', encoding='utf-8') as f:
            content = f.read()
        content = re.sub(r'className="version-tag">v.*?</span>', f'className="version-tag">v{v}</span>', content)
        with open(ADDIN_APP_JSX, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated Add-in UI Version: v{v}")

if __name__ == "__main__":
    print("Synchronizing versions across projects...")
    consts = get_constants()
    if consts:
        update_extension(consts)
        update_addin_package(consts)
        update_addin_manifest(consts)
        update_ui_versions(consts)
        print("\nAll versions and UI displays are now in sync with AppConstants.dart!")
    else:
        print("Error: Could not read AppConstants.dart or version not found.")
