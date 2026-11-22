# Stage definitions for the shared verified-release-kit runner.
LOCAL_CI_NAME="forge-ios"
LOCAL_CI_STAGES=(tests)
LOCAL_CI_DEFAULT_STAGES=(tests)

stage_tests() {
  require swift "Swift toolchain on Linux (https://www.swift.org/install/linux/)"
  require python3 ""
  swift test
  python3 scripts/validate_project.py --swiftc "$(command -v swiftc)"
}
