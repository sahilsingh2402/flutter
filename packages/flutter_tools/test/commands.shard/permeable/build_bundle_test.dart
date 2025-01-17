// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/targets/common.dart';
import 'package:flutter_tools/src/build_system/targets/icon_tree_shaker.dart';
import 'package:flutter_tools/src/bundle.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/build_bundle.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/reporting/reporting.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_tools/src/globals_null_migrated.dart' as globals;

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/fakes.dart';
import '../../src/test_build_system.dart';
import '../../src/test_flutter_command_runner.dart';

void main() {
  Cache.disableLocking();
  Directory tempDir;
  MockBundleBuilder mockBundleBuilder;

  setUp(() {
    tempDir = globals.fs.systemTempDirectory.createTempSync('flutter_tools_packages_test.');

    mockBundleBuilder = MockBundleBuilder();
    when(
      mockBundleBuilder.build(
        platform: anyNamed('platform'),
        buildInfo: anyNamed('buildInfo'),
        mainPath: anyNamed('mainPath'),
        manifestPath: anyNamed('manifestPath'),
        applicationKernelFilePath: anyNamed('applicationKernelFilePath'),
        depfilePath: anyNamed('depfilePath'),
        assetDirPath: anyNamed('assetDirPath'),
      ),
    ).thenAnswer((_) => Future<void>.value());
  });

  tearDown(() {
    tryToDelete(tempDir);
  });

  Future<BuildBundleCommand> runCommandIn(String projectPath, { List<String> arguments }) async {
    final BuildBundleCommand command = BuildBundleCommand(bundleBuilder: mockBundleBuilder);
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>[
      'bundle',
      ...?arguments,
      '--target=$projectPath/lib/main.dart',
      '--no-pub'
    ]);
    return command;
  }

  testUsingContext('bundle getUsage indicate that project is a module', () async {
    final String projectPath = await createProject(tempDir,
        arguments: <String>['--no-pub', '--template=module']);

    final BuildBundleCommand command = await runCommandIn(projectPath);

    expect(await command.usageValues,
        containsPair(CustomDimensions.commandBuildBundleIsModule, 'true'));
  });

  testUsingContext('bundle getUsage indicate that project is not a module', () async {
    final String projectPath = await createProject(tempDir,
        arguments: <String>['--no-pub', '--template=app']);

    final BuildBundleCommand command = await runCommandIn(projectPath);

    expect(await command.usageValues,
        containsPair(CustomDimensions.commandBuildBundleIsModule, 'false'));
  });

  testUsingContext('bundle getUsage indicate the target platform', () async {
    final String projectPath = await createProject(tempDir,
        arguments: <String>['--no-pub', '--template=app']);

    final BuildBundleCommand command = await runCommandIn(projectPath);

    expect(await command.usageValues,
        containsPair(CustomDimensions.commandBuildBundleTargetPlatform, 'android-arm'));
  });

  testUsingContext('bundle fails to build for Windows if feature is disabled', () async {
    globals.fs.file('lib/main.dart').createSync(recursive: true);
    globals.fs.file('pubspec.yaml').createSync(recursive: true);
    globals.fs.file('.packages').createSync(recursive: true);
    final CommandRunner<void> runner = createTestCommandRunner(BuildBundleCommand()
        ..bundleBuilder = MockBundleBuilder());

    expect(() => runner.run(<String>[
      'bundle',
      '--no-pub',
      '--target-platform=windows-x64',
    ]), throwsToolExit());
  }, overrides: <Type, Generator>{
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
    FeatureFlags: () => TestFeatureFlags(isWindowsEnabled: false),
  });

  testUsingContext('bundle fails to build for Linux if feature is disabled', () async {
    globals.fs.file('lib/main.dart').createSync(recursive: true);
    globals.fs.file('pubspec.yaml').createSync();
    globals.fs.file('.packages').createSync();
    final CommandRunner<void> runner = createTestCommandRunner(BuildBundleCommand()
        ..bundleBuilder = MockBundleBuilder());

    expect(() => runner.run(<String>[
      'bundle',
      '--no-pub',
      '--target-platform=linux-x64',
    ]), throwsToolExit());
  }, overrides: <Type, Generator>{
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
    FeatureFlags: () => TestFeatureFlags(isLinuxEnabled: false),
  });

  testUsingContext('bundle fails to build for macOS if feature is disabled', () async {
    globals.fs.file('lib/main.dart').createSync(recursive: true);
    globals.fs.file('pubspec.yaml').createSync();
    globals.fs.file('.packages').createSync();
    final CommandRunner<void> runner = createTestCommandRunner(BuildBundleCommand()
        ..bundleBuilder = MockBundleBuilder());

    expect(() => runner.run(<String>[
      'bundle',
      '--no-pub',
      '--target-platform=darwin-x64',
    ]), throwsToolExit());
  }, overrides: <Type, Generator>{
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
    FeatureFlags: () => TestFeatureFlags(isMacOSEnabled: false),
  });

  testUsingContext('bundle can build for Windows if feature is enabled', () async {
    globals.fs.file('lib/main.dart').createSync(recursive: true);
    globals.fs.file('pubspec.yaml').createSync();
    globals.fs.file('.packages').createSync();
    final CommandRunner<void> runner = createTestCommandRunner(BuildBundleCommand()
        ..bundleBuilder = MockBundleBuilder());

    await runner.run(<String>[
      'bundle',
      '--no-pub',
      '--target-platform=windows-x64',
    ]);
  }, overrides: <Type, Generator>{
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
    FeatureFlags: () => TestFeatureFlags(isWindowsEnabled: true),
  });

  testUsingContext('bundle can build for Linux if feature is enabled', () async {
    globals.fs.file('lib/main.dart').createSync(recursive: true);
    globals.fs.file('pubspec.yaml').createSync();
    globals.fs.file('.packages').createSync();
    final CommandRunner<void> runner = createTestCommandRunner(BuildBundleCommand()
        ..bundleBuilder = MockBundleBuilder());

    await runner.run(<String>[
      'bundle',
      '--no-pub',
      '--target-platform=linux-x64',
    ]);
  }, overrides: <Type, Generator>{
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
    FeatureFlags: () => TestFeatureFlags(isLinuxEnabled: true),
  });

  testUsingContext('bundle can build for macOS if feature is enabled', () async {
    globals.fs.file('lib/main.dart').createSync(recursive: true);
    globals.fs.file('pubspec.yaml').createSync();
    globals.fs.file('.packages').createSync();
    final CommandRunner<void> runner = createTestCommandRunner(BuildBundleCommand()
        ..bundleBuilder = MockBundleBuilder());

    await runner.run(<String>[
      'bundle',
      '--no-pub',
      '--target-platform=darwin-x64',
    ]);
  }, overrides: <Type, Generator>{
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
    FeatureFlags: () => TestFeatureFlags(isMacOSEnabled: true),
  });

  testUsingContext('passes track widget creation through', () async {
    globals.fs.file('lib/main.dart').createSync(recursive: true);
    globals.fs.file('pubspec.yaml').createSync();
    globals.fs.file('.packages').createSync();
    final CommandRunner<void> runner = createTestCommandRunner(BuildBundleCommand());

    await runner.run(<String>[
      'bundle',
      '--no-pub',
      '--debug',
      '--target-platform=android-arm',
      '--track-widget-creation'
    ]);
  }, overrides: <Type, Generator>{
    BuildSystem: () => TestBuildSystem.all(BuildResult(success: true), (Target target, Environment environment) {
      expect(environment.defines, <String, String>{
        kBuildMode: 'debug',
        kTargetPlatform: 'android-arm',
        kTargetFile: globals.fs.path.join('lib', 'main.dart'),
        kTrackWidgetCreation: 'true',
        kFileSystemScheme: 'org-dartlang-root',
        kIconTreeShakerFlag: 'false',
        kDeferredComponents: 'false'
      });
    }),
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
  });

  testUsingContext('passes dart-define through', () async {
    globals.fs.file('lib/main.dart').createSync(recursive: true);
    globals.fs.file('pubspec.yaml').createSync();
    globals.fs.file('.packages').createSync();
    final CommandRunner<void> runner = createTestCommandRunner(BuildBundleCommand());

    await runner.run(<String>[
      'bundle',
      '--no-pub',
      '--debug',
      '--target-platform=android-arm',
      '--dart-define=foo=bar'
    ]);
  }, overrides: <Type, Generator>{
    BuildSystem: () => TestBuildSystem.all(BuildResult(success: true), (Target target, Environment environment) {
      expect(environment.defines, <String, String>{
        kBuildMode: 'debug',
        kTargetPlatform: 'android-arm',
        kTargetFile: globals.fs.path.join('lib', 'main.dart'),
        kTrackWidgetCreation: 'true',
        kFileSystemScheme: 'org-dartlang-root',
        kDartDefines: 'Zm9vPWJhcg==',
        kIconTreeShakerFlag: 'false',
        kDeferredComponents: 'false'
      });
    }),
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
  });

  testUsingContext('passes filesystem-scheme through', () async {
    globals.fs.file('lib/main.dart').createSync(recursive: true);
    globals.fs.file('pubspec.yaml').createSync();
    globals.fs.file('.packages').createSync();
    final CommandRunner<void> runner = createTestCommandRunner(BuildBundleCommand());

    await runner.run(<String>[
      'bundle',
      '--no-pub',
      '--debug',
      '--target-platform=android-arm',
      '--filesystem-scheme=org-dartlang-root2',
    ]);
  }, overrides: <Type, Generator>{
    BuildSystem: () => TestBuildSystem.all(BuildResult(success: true), (Target target, Environment environment) {
      expect(environment.defines, <String, String>{
        kBuildMode: 'debug',
        kTargetPlatform: 'android-arm',
        kTargetFile: globals.fs.path.join('lib', 'main.dart'),
        kTrackWidgetCreation: 'true',
        kFileSystemScheme: 'org-dartlang-root2',
        kIconTreeShakerFlag: 'false',
        kDeferredComponents: 'false'
      });
    }),
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
  });

  testUsingContext('passes filesystem-roots through', () async {
    globals.fs.file('lib/main.dart').createSync(recursive: true);
    globals.fs.file('pubspec.yaml').createSync();
    globals.fs.file('.packages').createSync();
    final CommandRunner<void> runner = createTestCommandRunner(BuildBundleCommand());

    await runner.run(<String>[
      'bundle',
      '--no-pub',
      '--debug',
      '--target-platform=android-arm',
      '--filesystem-root=test1,test2'
    ]);
  }, overrides: <Type, Generator>{
    BuildSystem: () => TestBuildSystem.all(BuildResult(success: true), (Target target, Environment environment) {
      expect(environment.defines, <String, String>{
        kBuildMode: 'debug',
        kTargetPlatform: 'android-arm',
        kTargetFile: globals.fs.path.join('lib', 'main.dart'),
        kTrackWidgetCreation: 'true',
        kFileSystemScheme: 'org-dartlang-root',
        kFileSystemRoots: 'test1,test2',
        kIconTreeShakerFlag: 'false',
        kDeferredComponents: 'false'
      });
    }),
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
  });

  testUsingContext('passes extra frontend-options through', () async {
    globals.fs.file('lib/main.dart').createSync(recursive: true);
    globals.fs.file('pubspec.yaml').createSync();
    globals.fs.file('.packages').createSync();
    final CommandRunner<void> runner = createTestCommandRunner(BuildBundleCommand());

    await runner.run(<String>[
      'bundle',
      '--no-pub',
      '--debug',
      '--target-platform=android-arm',
      '--extra-front-end-options=--testflag,--testflag2'
    ]);
  }, overrides: <Type, Generator>{
    BuildSystem: () => TestBuildSystem.all(BuildResult(success: true), (Target target, Environment environment) {
      expect(environment.defines, <String, String>{
        kBuildMode: 'debug',
        kTargetPlatform: 'android-arm',
        kTargetFile: globals.fs.path.join('lib', 'main.dart'),
        kTrackWidgetCreation: 'true',
        kFileSystemScheme: 'org-dartlang-root',
        kExtraFrontEndOptions: '--testflag,--testflag2',
        kIconTreeShakerFlag: 'false',
        kDeferredComponents: 'false'
      });
    }),
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
  });

  testUsingContext('passes extra gen_snapshot-options through', () async {
    globals.fs.file('lib/main.dart').createSync(recursive: true);
    globals.fs.file('pubspec.yaml').createSync();
    globals.fs.file('.packages').createSync();
    final CommandRunner<void> runner = createTestCommandRunner(BuildBundleCommand());

    await runner.run(<String>[
      'bundle',
      '--no-pub',
      '--debug',
      '--target-platform=android-arm',
      '--extra-gen-snapshot-options=--testflag,--testflag2'
    ]);
  }, overrides: <Type, Generator>{
    BuildSystem: () => TestBuildSystem.all(BuildResult(success: true), (Target target, Environment environment) {
      expect(environment.defines, <String, String>{
        kBuildMode: 'debug',
        kTargetPlatform: 'android-arm',
        kTargetFile: globals.fs.path.join('lib', 'main.dart'),
        kTrackWidgetCreation: 'true',
        kFileSystemScheme: 'org-dartlang-root',
        kExtraGenSnapshotOptions: '--testflag,--testflag2',
        kIconTreeShakerFlag: 'false',
        kDeferredComponents: 'false'
      });
    }),
    FileSystem: () => MemoryFileSystem.test(),
    ProcessManager: () => FakeProcessManager.any(),
  });
}

class MockBundleBuilder extends Mock implements BundleBuilder {}
