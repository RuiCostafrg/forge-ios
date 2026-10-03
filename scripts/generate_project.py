#!/usr/bin/env python3
"""Generate the checked-in Xcode project with no XcodeGen or external dependencies."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
objects = {}

def uid(label):
    return hashlib.sha256(label.encode()).hexdigest()[:24].upper()

def add(label, **values):
    key = uid(label)
    objects[key] = values
    return key

def ref(path, kind):
    return add('ref:' + path, isa='PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>')

def build(ref_id, label):
    return add('build:' + label, isa='PBXBuildFile', fileRef=ref_id)

app_sources = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'Forge').rglob('*.swift'))
source_refs = [ref(p, 'sourcecode.swift') for p in app_sources]
resources = ['Forge/Resources/TrainingHistory.md', 'Forge/Resources/SeedHistory.json', 'Forge/Resources/PrivacyInfo.xcprivacy', 'Forge/Assets.xcassets']
types = ['net.daringfireball.markdown', 'text.json', 'text.xml', 'folder.assetcatalog']
resource_refs = [ref(p, t) for p, t in zip(resources, types)]
info_ref = ref('Forge/Info.plist', 'text.plist.xml')
test_source = ref('Tests/ForgeCoreTests/ForgeCoreTests.swift', 'sourcecode.swift')
readme_ref = ref('README.md', 'net.daringfireball.markdown')
app_product = add('product:app', isa='PBXFileReference', explicitFileType='wrapper.application', includeInIndex=0, path='Forge.app', sourceTree='BUILT_PRODUCTS_DIR')
test_product = add('product:tests', isa='PBXFileReference', explicitFileType='wrapper.cfbundle', includeInIndex=0, path='ForgeTests.xctest', sourceTree='BUILT_PRODUCTS_DIR')
app_group = add('group:app', isa='PBXGroup', children=source_refs + resource_refs + [info_ref], name='Forge', sourceTree='<group>')
test_group = add('group:tests', isa='PBXGroup', children=[test_source], name='Tests', sourceTree='<group>')
products_group = add('group:products', isa='PBXGroup', children=[app_product, test_product], name='Products', sourceTree='<group>')
main_group = add('group:main', isa='PBXGroup', children=[app_group, test_group, readme_ref, products_group], sourceTree='<group>')
app_sources_phase = add('phase:app:sources', isa='PBXSourcesBuildPhase', buildActionMask=2147483647, files=[build(r, p) for r, p in zip(source_refs, app_sources)], runOnlyForDeploymentPostprocessing=0)
app_resources_phase = add('phase:app:resources', isa='PBXResourcesBuildPhase', buildActionMask=2147483647, files=[build(r, p) for r, p in zip(resource_refs, resources)], runOnlyForDeploymentPostprocessing=0)
app_frameworks_phase = add('phase:app:frameworks', isa='PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
test_sources_phase = add('phase:tests:sources', isa='PBXSourcesBuildPhase', buildActionMask=2147483647, files=[build(test_source, 'test-source')], runOnlyForDeploymentPostprocessing=0)
test_frameworks_phase = add('phase:tests:frameworks', isa='PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)

common = {'CLANG_ENABLE_MODULES': 'YES', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0', 'SDKROOT': 'iphoneos', 'SWIFT_VERSION': '5.0', 'ENABLE_USER_SCRIPT_SANDBOXING': 'YES'}
app_common = {'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon', 'CODE_SIGN_STYLE': 'Automatic', 'CURRENT_PROJECT_VERSION': '1', 'MARKETING_VERSION': '1.0', 'GENERATE_INFOPLIST_FILE': 'NO', 'INFOPLIST_FILE': 'Forge/Info.plist', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.yourname.Forge', 'PRODUCT_NAME': '$(TARGET_NAME)', 'TARGETED_DEVICE_FAMILY': '1', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'SUPPORTS_MACCATALYST': 'NO', 'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/Frameworks'], 'ENABLE_PREVIEWS': 'YES'}
test_common = {'CODE_SIGN_STYLE': 'Automatic', 'CURRENT_PROJECT_VERSION': '1', 'MARKETING_VERSION': '1.0', 'GENERATE_INFOPLIST_FILE': 'YES', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.yourname.ForgeTests', 'PRODUCT_NAME': '$(TARGET_NAME)', 'TARGETED_DEVICE_FAMILY': '1', 'TEST_HOST': '$(BUILT_PRODUCTS_DIR)/Forge.app/Forge', 'BUNDLE_LOADER': '$(TEST_HOST)', 'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']}

def configs(label, base):
    values = []
    for name in ['Debug', 'Release']:
        settings = dict(base)
        settings.update({'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if name == 'Debug' else '-O', 'DEBUG_INFORMATION_FORMAT': 'dwarf' if name == 'Debug' else 'dwarf-with-dsym'})
        if name == 'Debug':
            settings.update({'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG', 'ENABLE_TESTABILITY': 'YES', 'ONLY_ACTIVE_ARCH': 'YES'})
        else:
            settings['SWIFT_COMPILATION_MODE'] = 'wholemodule'
        values.append(add('config:' + label + name, isa='XCBuildConfiguration', buildSettings=settings, name=name))
    return add('configlist:' + label, isa='XCConfigurationList', buildConfigurations=values, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')

project_config = configs('project', common)
app_config = configs('app', app_common)
test_config = configs('tests', test_common)
app_target = add('target:app', isa='PBXNativeTarget', buildConfigurationList=app_config, buildPhases=[app_sources_phase, app_frameworks_phase, app_resources_phase], buildRules=[], dependencies=[], name='Forge', productName='Forge', productReference=app_product, productType='com.apple.product-type.application')
proxy = add('proxy:app', isa='PBXContainerItemProxy', containerPortal=uid('project'), proxyType=1, remoteGlobalIDString=app_target, remoteInfo='Forge')
dependency = add('dependency:app', isa='PBXTargetDependency', target=app_target, targetProxy=proxy)
test_target = add('target:tests', isa='PBXNativeTarget', buildConfigurationList=test_config, buildPhases=[test_sources_phase, test_frameworks_phase], buildRules=[], dependencies=[dependency], name='ForgeTests', productName='ForgeTests', productReference=test_product, productType='com.apple.product-type.bundle.unit-test')
project = add('project', isa='PBXProject', attributes={'BuildIndependentTargetsInParallel': 'YES', 'LastUpgradeCheck': '1600', 'TargetAttributes': {app_target: {'CreatedOnToolsVersion': '16.0'}, test_target: {'CreatedOnToolsVersion': '16.0', 'TestTargetID': app_target}}}, buildConfigurationList=project_config, compatibilityVersion='Xcode 14.0', developmentRegion='en', hasScannedForEncodings=0, knownRegions=['en', 'Base'], mainGroup=main_group, productRefGroup=products_group, projectDirPath='', projectRoot='', targets=[app_target, test_target])

def encode(value, depth=0):
    indent = '\t' * depth
    if isinstance(value, dict):
        return '{\n' + ''.join('\t' * (depth + 1) + json.dumps(str(k)) + ' = ' + encode(v, depth + 1) + ';\n' for k, v in value.items()) + indent + '}'
    if isinstance(value, list):
        return '(\n' + ''.join('\t' * (depth + 1) + encode(v, depth + 1) + ',\n' for v in value) + indent + ')'
    if isinstance(value, int):
        return str(value)
    return json.dumps(value)

project_dir = ROOT / 'Forge.xcodeproj'
project_dir.mkdir(exist_ok=True)
(project_dir / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + encode({'archiveVersion': 1, 'classes': {}, 'objectVersion': 56, 'objects': objects, 'rootObject': project}) + '\n')
scheme_dir = project_dir / 'xcshareddata/xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)

def reference(key, name, product):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{key}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:Forge.xcodeproj"/>'

app_ref = reference(app_target, 'Forge', 'Forge.app')
test_ref = reference(test_target, 'ForgeTests', 'ForgeTests.xctest')
(scheme_dir / 'Forge.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry>
    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{test_ref}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference></Testables></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
workspace = project_dir / 'project.xcworkspace'
workspace.mkdir(exist_ok=True)
(workspace / 'contents.xcworkspacedata').write_text('<?xml version="1.0" encoding="UTF-8"?><Workspace version="1.0"><FileRef location="self:"/></Workspace>\n')
print(f'Generated {project_dir.name}: {len(app_sources)} app sources, 1 test source, {len(resources)} resources.')
