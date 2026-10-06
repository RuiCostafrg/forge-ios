#!/usr/bin/env python3
"""Validate project references, bundled data, plist/XML, assets, and Swift syntax."""
import argparse
import hashlib
import json
import plistlib
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def parse_project(text):
    text = re.sub(r'^//.*$', '', text, flags=re.MULTILINE)
    tokens = re.findall(r'"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,]+', text)
    position = 0
    def take(expected=None):
        nonlocal position
        token = tokens[position]; position += 1
        if expected is not None:
            assert token == expected, (expected, token)
        return token
    def value():
        token = take()
        if token == '{':
            result = {}
            while tokens[position] != '}':
                key = take(); key = json.loads(key) if key.startswith('"') else key
                take('='); result[key] = value(); take(';')
            take('}'); return result
        if token == '(':
            result = []
            while tokens[position] != ')':
                result.append(value()); take(',')
            take(')'); return result
        if token.startswith('"'): return json.loads(token)
        return int(token) if token.isdigit() else token
    result = value()
    assert position == len(tokens)
    return result

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--swiftc', default=shutil.which('swiftc'))
    args = parser.parse_args()
    project = parse_project((ROOT / 'Forge.xcodeproj/project.pbxproj').read_text())
    objects = project['objects']
    root = objects[project['rootObject']]
    assert root['isa'] == 'PBXProject'
    targets = {objects[key]['name']: objects[key] for key in root['targets']}
    assert set(targets) == {'Forge', 'ForgeTests'}
    for obj in objects.values():
        if obj['isa'] == 'PBXFileReference' and obj.get('sourceTree') == '<group>':
            assert (ROOT / obj['path']).exists(), obj['path']
        if obj['isa'] == 'PBXBuildFile': assert obj['fileRef'] in objects
        for key in ['children', 'buildPhases', 'buildConfigurations', 'files', 'dependencies', 'targets']:
            for reference in obj.get(key, []): assert reference in objects
    sources = []
    resources = []
    for key in targets['Forge']['buildPhases']:
        phase = objects[key]
        files = [objects[objects[build]['fileRef']]['path'] for build in phase['files']]
        if phase['isa'] == 'PBXSourcesBuildPhase': sources = files
        if phase['isa'] == 'PBXResourcesBuildPhase': resources = files
    expected = sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / 'Forge').rglob('*.swift'))
    assert sorted(sources) == expected
    test_phase = next(objects[key] for key in targets['ForgeTests']['buildPhases'] if objects[key]['isa'] == 'PBXSourcesBuildPhase')
    test_sources = [objects[objects[build]['fileRef']]['path'] for build in test_phase['files']]
    assert sorted(test_sources) == sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / 'Tests/ForgeCoreTests').rglob('*.swift'))
    assert 'Forge/Resources/SeedHistory.json' in resources
    for path in [ROOT / 'Forge/Info.plist', ROOT / 'Forge/Resources/PrivacyInfo.xcprivacy']:
        with path.open('rb') as file: plistlib.load(file)
    scheme = ET.parse(ROOT / 'Forge.xcodeproj/xcshareddata/xcschemes/Forge.xcscheme')
    for reference in scheme.findall('.//BuildableReference'):
        assert reference.attrib['BlueprintIdentifier'] in objects
    ET.parse(ROOT / 'Forge.xcodeproj/project.xcworkspace/contents.xcworkspacedata')
    history = (ROOT / 'Forge/Resources/TrainingHistory.md').read_text()
    fixture = (ROOT / 'Tests/ForgeCoreTests/Fixtures/TrainingHistory.md').read_text()
    assert history == fixture
    seed = json.loads((ROOT / 'Forge/Resources/SeedHistory.json').read_text())
    report = json.loads((ROOT / 'IMPORT_REPORT.json').read_text())
    assert seed['schemaVersion'] == 1 and seed['historyImported']
    assert seed['originalHistory'] == history
    assert len(seed['sessions']) == report['entries']
    assert len({session['id'] for session in seed['sessions']}) == len(seed['sessions'])
    assert all(session['needsReview'] for session in seed['sessions'])
    assert [day['weekday'] for day in seed['program']] == list(range(1, 8))
    sets = [item for session in seed['sessions'] for exercise in session['exercises'] for item in exercise['sets']]
    assert len(sets) == report['explicitSets']
    assert all(0 <= item['weight'] <= 2000 and 0 <= item['reps'] <= 1000 for item in sets)
    assert sum(session.get('date') is not None for session in seed['sessions']) == report['fullDates']
    assert not any(re.search(r'URLSession|import\s+(CloudKit|Firebase)|https?://', (ROOT / path).read_text()) for path in sources)
    icon = ROOT / 'Forge/Assets.xcassets/AppIcon.appiconset'
    assert (icon / json.loads((icon / 'Contents.json').read_text())['images'][0]['filename']).exists()
    if args.swiftc:
        subprocess.run([args.swiftc, '-frontend', '-parse', *[str(ROOT / source) for source in sources]], check=True)
    print(f'Project validation passed: {len(sources)} Swift files, {len(resources)} resources, {report["entries"]} history entries, {len(sets)} explicit sets.')
    print('Original history SHA-256:', hashlib.sha256(history.encode()).hexdigest())
    print('Native Apple SDK build and simulator validation still require Xcode.')

if __name__ == '__main__': main()
