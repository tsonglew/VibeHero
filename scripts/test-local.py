#!/usr/bin/env python3
"""Run XCTest with an explicit local compiler and framework installation.

This supplements `swift test` when Command Line Tools lack XCTest. It compiles
the app as a testable library, excluding its application entry point, then runs
the existing XCTestCase classes in a temporary executable. It never changes
xcode-select, accepts a license, or writes into the package's .build directory.
"""

import argparse
from pathlib import Path
import platform
import subprocess
import sys
import tempfile


RUNNER_SOURCE = r'''
import AppKit
import ObjectiveC
import XCTest

let pattern = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".*"
let matcher: NSRegularExpression
do {
    matcher = try NSRegularExpression(pattern: pattern)
} catch {
    fputs("Invalid suite expression: \(error)\n", stderr)
    exit(2)
}

let capacity = objc_getClassList(nil, 0)
guard capacity > 0 else {
    fputs("Unable to discover XCTestCase classes.\n", stderr)
    exit(2)
}
let classes = UnsafeMutablePointer<AnyClass>.allocate(capacity: Int(capacity))
let count = objc_getClassList(AutoreleasingUnsafeMutablePointer(classes), capacity)
let testClasses = (0..<Int(min(count, capacity))).compactMap { index -> XCTestCase.Type? in
    let candidate: AnyClass = classes[index]
    // Some private Objective-C classes cannot handle Swift's type queries.
    // Inspect their runtime name first and only cast this test module's classes.
    guard String(cString: class_getName(candidate)).contains("VibeHeroLocalTests") else { return nil }
    return candidate as? XCTestCase.Type
}
    .sorted { NSStringFromClass($0) < NSStringFromClass($1) }
classes.deallocate()

let suite = XCTestSuite(name: "VibeHero local tests")
for testClass in testClasses {
    let name = NSStringFromClass(testClass)
    let range = NSRange(name.startIndex..<name.endIndex, in: name)
    if matcher.firstMatch(in: name, range: range) != nil {
        suite.addTest(testClass.defaultTestSuite)
    }
}
guard suite.testCaseCount > 0 else {
    fputs("No XCTest cases match the requested suite expression.\n", stderr)
    exit(2)
}
suite.run()
exit(suite.testRun?.hasSucceeded == true ? 0 : 1)
'''


def arguments():
    clt = Path("/Library/Developer/CommandLineTools")
    xctest = Path("/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--swiftc", type=Path, default=clt / "usr/bin/swiftc")
    parser.add_argument("--sdk", type=Path, default=clt / "SDKs/MacOSX.sdk")
    parser.add_argument("--xctest-frameworks", type=Path, default=xctest / "Library/Frameworks")
    parser.add_argument("--xctest-libraries", type=Path, default=xctest / "usr/lib")
    parser.add_argument("--target", default=f"{platform.machine()}-apple-macosx14.0")
    parser.add_argument("--suite", help="Regular expression selecting XCTestCase class names")
    parser.add_argument("--timeout", type=int, default=120, help="Test execution timeout in seconds")
    parser.add_argument("--keep-temp", action="store_true", help="Keep temporary binaries and logs")
    return parser.parse_args()


def execute(label, command, directory, timeout):
    print(f"{label}...", flush=True)
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    (directory / f"{label}.log").write_text(result.stdout)
    if result.stdout:
        print(result.stdout, end="" if result.stdout.endswith("\n") else "\n", flush=True)
    if result.returncode:
        raise subprocess.CalledProcessError(result.returncode, command)


def run(args, directory):
    sources = sorted(str(path) for path in (args.project / "Sources/VibeHero").rglob("*.swift") if path.name != "main.swift")
    tests = sorted(str(path) for path in (args.project / "Tests/VibeHeroTests").rglob("*.swift"))
    if not sources or not tests:
        raise ValueError("The project must contain Sources/VibeHero and Tests/VibeHeroTests Swift files.")
    required = [
        args.swiftc,
        args.sdk,
        args.xctest_frameworks / "XCTest.framework",
        args.xctest_libraries / "XCTest.swiftmodule",
        args.xctest_libraries / "libXCTestSwiftSupport.dylib",
    ]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise ValueError("Missing compiler/SDK/XCTest paths; provide explicit path options:\n" + "\n".join(missing))
    if args.timeout <= 0:
        raise ValueError("--timeout must be positive.")

    print(f"Temporary build: {directory}", flush=True)
    base = [str(args.swiftc), "-target", args.target, "-sdk", str(args.sdk), "-swift-version", "6"]
    execute("Compile application", [
        *base, "-parse-as-library", "-enable-testing", "-module-name", "VibeHero",
        "-emit-module", "-emit-module-path", str(directory / "VibeHero.swiftmodule"),
        "-emit-library", "-o", str(directory / "libVibeHero.dylib"), *sources,
    ], directory, timeout=180)

    main = directory / "main.swift"
    main.write_text(RUNNER_SOURCE)
    runtime_paths = []
    for path in [args.xctest_frameworks, args.xctest_libraries, directory]:
        runtime_paths.extend(["-Xlinker", "-rpath", "-Xlinker", str(path)])
    execute("Compile tests", [
        *base, "-module-name", "VibeHeroLocalTests", "-I", str(directory), "-L", str(directory), "-lVibeHero",
        "-F", str(args.xctest_frameworks), "-I", str(args.xctest_libraries), "-L", str(args.xctest_libraries),
        "-framework", "XCTest", "-lXCTestSwiftSupport", *runtime_paths,
        "-o", str(directory / "runner"), *tests, str(main),
    ], directory, timeout=180)
    execute("Run tests", [str(directory / "runner"), args.suite or ".*"], directory, timeout=args.timeout)


def main():
    args = arguments()
    temporary = None
    try:
        if args.keep_temp:
            directory = Path(tempfile.mkdtemp(prefix="vibehero-local-tests-"))
        else:
            temporary = tempfile.TemporaryDirectory(prefix="vibehero-local-tests-")
            directory = Path(temporary.name)
        run(args, directory)
        return 0
    except subprocess.CalledProcessError as error:
        print(f"Local test command failed (exit {error.returncode}).", file=sys.stderr)
        return error.returncode if error.returncode > 0 else 128 - error.returncode
    except subprocess.TimeoutExpired as error:
        if error.output:
            print(error.output.decode(errors="replace") if isinstance(error.output, bytes) else error.output, file=sys.stderr)
        print(f"Local test command exceeded {error.timeout} seconds.", file=sys.stderr)
        return 124
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 2
    finally:
        if temporary is not None:
            temporary.cleanup()


if __name__ == "__main__":
    sys.exit(main())
