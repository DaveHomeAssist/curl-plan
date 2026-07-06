#!/usr/bin/env node
/* Generates CurlPlan.xcodeproj/project.pbxproj wired to every .swift file in
 * CurlPlan/ (app target) and CurlPlanTests/ (unit-test target, hosted in the app).
 * Classic pbxproj format (objectVersion 56, Xcode 14+). Re-run after adding/removing
 * Swift files:  node generate-xcodeproj.js
 */
const fs = require("fs");
const path = require("path");

const root = __dirname;
const srcDir = path.join(root, "CurlPlan");
const testDir = path.join(root, "CurlPlanTests");
const files = fs.readdirSync(srcDir).filter(f => f.endsWith(".swift")).sort();
const testFiles = fs.existsSync(testDir)
  ? fs.readdirSync(testDir).filter(f => f.endsWith(".swift")).sort() : [];
const hasTests = testFiles.length > 0;

let counter = 1;
const id = () => (counter++).toString(16).toUpperCase().padStart(24, "0");

// structural object ids
const PROJECT = id(), TARGET = id(), GROUP_ROOT = id(), GROUP_SRC = id(),
      GROUP_PRODUCTS = id(), PRODUCT_REF = id(),
      PHASE_SOURCES = id(), PHASE_FRAMEWORKS = id(), PHASE_RESOURCES = id(),
      CFGLIST_PROJ = id(), CFGLIST_TGT = id(),
      CFG_PROJ_DEBUG = id(), CFG_PROJ_RELEASE = id(),
      CFG_TGT_DEBUG = id(), CFG_TGT_RELEASE = id();

// test-target structural ids (only used when hasTests)
const TEST_TARGET = id(), TEST_PRODUCT_REF = id(), TEST_GROUP = id(),
      PHASE_TEST_SOURCES = id(), PHASE_TEST_FRAMEWORKS = id(), PHASE_TEST_RESOURCES = id(),
      CFGLIST_TEST = id(), CFG_TEST_DEBUG = id(), CFG_TEST_RELEASE = id(),
      DEP = id(), PROXY = id();

const fileObjs = files.map(name => ({ name, ref: id(), build: id() }));
const testObjs = testFiles.map(name => ({ name, ref: id(), build: id() }));

const fileRefs = fileObjs.map(f =>
  `\t\t${f.ref} /* ${f.name} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "${f.name}"; sourceTree = "<group>"; };`
).join("\n");
const buildFiles = fileObjs.map(f =>
  `\t\t${f.build} /* ${f.name} in Sources */ = {isa = PBXBuildFile; fileRef = ${f.ref} /* ${f.name} */; };`
).join("\n");
const groupChildren = fileObjs.map(f => `\t\t\t\t${f.ref} /* ${f.name} */,`).join("\n");
const sourcesFiles = fileObjs.map(f => `\t\t\t\t${f.build} /* ${f.name} in Sources */,`).join("\n");

const testFileRefs = testObjs.map(f =>
  `\t\t${f.ref} /* ${f.name} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "${f.name}"; sourceTree = "<group>"; };`
).join("\n");
const testBuildFiles = testObjs.map(f =>
  `\t\t${f.build} /* ${f.name} in Sources */ = {isa = PBXBuildFile; fileRef = ${f.ref} /* ${f.name} */; };`
).join("\n");
const testGroupChildren = testObjs.map(f => `\t\t\t\t${f.ref} /* ${f.name} */,`).join("\n");
const testSourcesFiles = testObjs.map(f => `\t\t\t\t${f.build} /* ${f.name} in Sources */,`).join("\n");

const targetBuildSettings = `
\t\t\t\tASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = NO;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.davehomeassist.CurlPlan;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";`;

const testBuildSettings = `
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.davehomeassist.CurlPlanTests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/CurlPlan.app/CurlPlan";`;

const projDebug = `
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 5.0;`;

const projRelease = `
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = s;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tVALIDATE_PRODUCT = YES;`;

// ---- optional test-target object blocks ----
const testBuildFileSection = hasTests ? "\n" + testBuildFiles : "";
const testFileRefSection = hasTests ? "\n" + testFileRefs +
  `\n\t\t${TEST_PRODUCT_REF} /* CurlPlanTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = CurlPlanTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };` : "";
const rootGroupTestChild = hasTests ? `\n\t\t\t\t${TEST_GROUP} /* CurlPlanTests */,` : "";
const productsTestChild = hasTests ? `\n\t\t\t\t${TEST_PRODUCT_REF} /* CurlPlanTests.xctest */,` : "";
const testGroupSection = hasTests ? `
\t\t${TEST_GROUP} /* CurlPlanTests */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
${testGroupChildren}
\t\t\t);
\t\t\tpath = CurlPlanTests;
\t\t\tsourceTree = "<group>";
\t\t};` : "";
const projectTestTarget = hasTests ? `\n\t\t\t\t${TEST_TARGET} /* CurlPlanTests */,` : "";
const targetAttrTest = hasTests ? `
\t\t\t\t\t${TEST_TARGET} = {
\t\t\t\t\t\tCreatedOnToolsVersion = 15.4;
\t\t\t\t\t\tTestTargetID = ${TARGET};
\t\t\t\t\t};` : "";
const testNativeTargetSection = hasTests ? `
\t\t${TEST_TARGET} /* CurlPlanTests */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = ${CFGLIST_TEST} /* Build configuration list for PBXNativeTarget "CurlPlanTests" */;
\t\t\tbuildPhases = (
\t\t\t\t${PHASE_TEST_SOURCES} /* Sources */,
\t\t\t\t${PHASE_TEST_FRAMEWORKS} /* Frameworks */,
\t\t\t\t${PHASE_TEST_RESOURCES} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t${DEP} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = CurlPlanTests;
\t\t\tproductName = CurlPlanTests;
\t\t\tproductReference = ${TEST_PRODUCT_REF} /* CurlPlanTests.xctest */;
\t\t\tproductType = "com.apple.product-type.bundle.unit-test";
\t\t};` : "";
const testPhasesSection = hasTests ? `
\t\t${PHASE_TEST_SOURCES} /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
${testSourcesFiles}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
\t\t${PHASE_TEST_FRAMEWORKS} /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
\t\t${PHASE_TEST_RESOURCES} /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};` : "";
const depSection = hasTests ? `
/* Begin PBXContainerItemProxy section */
\t\t${PROXY} /* PBXContainerItemProxy */ = {
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = ${PROJECT} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = ${TARGET};
\t\t\tremoteInfo = CurlPlan;
\t\t};
/* End PBXContainerItemProxy section */

/* Begin PBXTargetDependency section */
\t\t${DEP} /* PBXTargetDependency */ = {
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = ${TARGET} /* CurlPlan */;
\t\t\ttargetProxy = ${PROXY} /* PBXContainerItemProxy */;
\t\t};
/* End PBXTargetDependency section */
` : "";
const testCfgSection = hasTests ? `
\t\t${CFG_TEST_DEBUG} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {${testBuildSettings}
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t${CFG_TEST_RELEASE} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {${testBuildSettings}
\t\t\t};
\t\t\tname = Release;
\t\t};` : "";
const testCfgListSection = hasTests ? `
\t\t${CFGLIST_TEST} /* Build configuration list for PBXNativeTarget "CurlPlanTests" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t${CFG_TEST_DEBUG} /* Debug */,
\t\t\t\t${CFG_TEST_RELEASE} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};` : "";

const pbx = `// !$*UTF8*$!
{
\tarchiveVersion = 1;
\tclasses = {
\t};
\tobjectVersion = 56;
\tobjects = {

/* Begin PBXBuildFile section */
${buildFiles}${testBuildFileSection}
/* End PBXBuildFile section */
${depSection}
/* Begin PBXFileReference section */
\t\t${PRODUCT_REF} /* CurlPlan.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = CurlPlan.app; sourceTree = BUILT_PRODUCTS_DIR; };
${fileRefs}${testFileRefSection}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t${PHASE_FRAMEWORKS} /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t${GROUP_ROOT} = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t${GROUP_SRC} /* CurlPlan */,${rootGroupTestChild}
\t\t\t\t${GROUP_PRODUCTS} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};
\t\t${GROUP_SRC} /* CurlPlan */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
${groupChildren}
\t\t\t);
\t\t\tpath = CurlPlan;
\t\t\tsourceTree = "<group>";
\t\t};${testGroupSection}
\t\t${GROUP_PRODUCTS} /* Products */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t${PRODUCT_REF} /* CurlPlan.app */,${productsTestChild}
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t${TARGET} /* CurlPlan */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = ${CFGLIST_TGT} /* Build configuration list for PBXNativeTarget "CurlPlan" */;
\t\t\tbuildPhases = (
\t\t\t\t${PHASE_SOURCES} /* Sources */,
\t\t\t\t${PHASE_FRAMEWORKS} /* Frameworks */,
\t\t\t\t${PHASE_RESOURCES} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = CurlPlan;
\t\t\tproductName = CurlPlan;
\t\t\tproductReference = ${PRODUCT_REF} /* CurlPlan.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};${testNativeTargetSection}
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t${PROJECT} /* Project object */ = {
\t\t\tisa = PBXProject;
\t\t\tattributes = {
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1540;
\t\t\t\tLastUpgradeCheck = 1540;
\t\t\t\tTargetAttributes = {
\t\t\t\t\t${TARGET} = {
\t\t\t\t\t\tCreatedOnToolsVersion = 15.4;
\t\t\t\t\t};${targetAttrTest}
\t\t\t\t};
\t\t\t};
\t\t\tbuildConfigurationList = ${CFGLIST_PROJ} /* Build configuration list for PBXProject "CurlPlan" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = ${GROUP_ROOT};
\t\t\tproductRefGroup = ${GROUP_PRODUCTS} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t${TARGET} /* CurlPlan */,${projectTestTarget}
\t\t\t);
\t\t};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t${PHASE_RESOURCES} /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t${PHASE_SOURCES} /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
${sourcesFiles}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};${testPhasesSection}
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t${CFG_PROJ_DEBUG} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {${projDebug}
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t${CFG_PROJ_RELEASE} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {${projRelease}
\t\t\t};
\t\t\tname = Release;
\t\t};
\t\t${CFG_TGT_DEBUG} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {${targetBuildSettings}
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t${CFG_TGT_RELEASE} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {${targetBuildSettings}
\t\t\t};
\t\t\tname = Release;
\t\t};${testCfgSection}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t${CFGLIST_PROJ} /* Build configuration list for PBXProject "CurlPlan" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t${CFG_PROJ_DEBUG} /* Debug */,
\t\t\t\t${CFG_PROJ_RELEASE} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
\t\t${CFGLIST_TGT} /* Build configuration list for PBXNativeTarget "CurlPlan" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t${CFG_TGT_DEBUG} /* Debug */,
\t\t\t\t${CFG_TGT_RELEASE} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};${testCfgListSection}
/* End XCConfigurationList section */
\t};
\trootObject = ${PROJECT} /* Project object */;
}
`;

const projDir = path.join(root, "CurlPlan.xcodeproj");
fs.mkdirSync(projDir, { recursive: true });
fs.writeFileSync(path.join(projDir, "project.pbxproj"), pbx);

// Shared scheme so the app is runnable + testable on first open.
const buildableRef =
  `<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${TARGET}" BuildableName="CurlPlan.app" BlueprintName="CurlPlan" ReferencedContainer="container:CurlPlan.xcodeproj"></BuildableReference>`;
const testables = hasTests ? `
         <TestableReference skipped="NO">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${TEST_TARGET}" BuildableName="CurlPlanTests.xctest" BlueprintName="CurlPlanTests" ReferencedContainer="container:CurlPlan.xcodeproj"></BuildableReference>
         </TestableReference>` : "";
const scheme = `<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1540" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            ${buildableRef}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
      <Testables>${testables}
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         ${buildableRef}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         ${buildableRef}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES">
   </ArchiveAction>
</Scheme>
`;
const schemeDir = path.join(projDir, "xcshareddata", "xcschemes");
fs.mkdirSync(schemeDir, { recursive: true });
fs.writeFileSync(path.join(schemeDir, "CurlPlan.xcscheme"), scheme);

console.log(`Wrote CurlPlan.xcodeproj: ${files.length} app Swift files` +
  (hasTests ? ` + ${testFiles.length} test files (CurlPlanTests target)` : ""));
files.forEach(f => console.log("  app  - " + f));
testFiles.forEach(f => console.log("  test - " + f));
