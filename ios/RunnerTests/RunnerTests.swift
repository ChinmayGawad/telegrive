import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testBackgroundCoverStaysWhenPrivateCloses() {
    let privacy = PrivacySnapshot()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
    privacy.configure(enabled: true)
    privacy.resign(window: window)
    XCTAssertEqual(window.subviews.count, 1)
    privacy.configure(enabled: false)
    privacy.foregroundReady(privacy.generation)
    XCTAssertEqual(window.subviews.count, 1)
    privacy.activate(window: window)
    privacy.foregroundReady(privacy.generation)
    XCTAssertTrue(window.subviews.isEmpty)
  }

  func testStaleForegroundAcknowledgementCannotUncoverNextCycle() {
    let privacy = PrivacySnapshot()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
    privacy.resign(window: window)
    let stale = privacy.generation
    privacy.activate(window: window)
    privacy.resign(window: window)
    privacy.activate(window: window)
    privacy.foregroundReady(stale)
    XCTAssertEqual(window.subviews.count, 1)
    privacy.foregroundReady(privacy.generation)
    XCTAssertTrue(window.subviews.isEmpty)
  }

  func testUnprotectedSceneDoesNotCover() {
    let privacy = PrivacySnapshot()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
    privacy.configure(enabled: false)
    privacy.resign(window: window)
    privacy.activate(window: window)
    XCTAssertTrue(window.subviews.isEmpty)
  }

}
