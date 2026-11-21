import Foundation
import Testing

@testable import Larp

struct ZoomTests {
    @Test func stepsInTenths() {
        #expect(Zoom.stepped(1.0, by: 1, in: .content) == 1.1)
        #expect(Zoom.stepped(1.0, by: -2, in: .content) == 0.8)
    }

    @Test func returnsExactlyToActualSize() {
        var zoom = 1.0
        for _ in 0..<7 { zoom = Zoom.stepped(zoom, by: 1, in: .content) }
        for _ in 0..<7 { zoom = Zoom.stepped(zoom, by: -1, in: .content) }
        #expect(zoom == 1.0)
    }

    @Test func appZoomStaysBetween90And150Percent() {
        #expect(Zoom.stepped(1.4, by: 5, in: .app) == 1.5)
        #expect(Zoom.stepped(1.0, by: -5, in: .app) == 0.9)
    }

    @Test func fileAndTerminalZoomRangeWider() {
        #expect(Zoom.stepped(2.9, by: 5, in: .content) == 3.0)
        #expect(Zoom.stepped(0.6, by: -5, in: .content) == 0.5)
    }

    @Test func clampsALevelStoredBeforeTheLimits() {
        #expect(Zoom.clamped(3.0, in: .app) == 1.5)
        #expect(Zoom.clamped(0.5, in: .app) == 0.9)
        #expect(Zoom.clamped(1.2, in: .app) == 1.2)
    }

    @Test func formatsAsPercent() {
        #expect(Zoom.percent(1.25) == "125%")
    }
}

@MainActor
struct TerminalZoomTests {
    @Test func zoomsOneSessionOnly() {
        let store = TerminalStore()
        let first = store.newSession(in: URL(fileURLWithPath: "/tmp"))
        let second = store.newSession(in: URL(fileURLWithPath: "/tmp"))

        store.zoom(first.id, by: 2)

        #expect(store.sessions.first { $0.id == first.id }?.zoom == 1.2)
        #expect(store.sessions.first { $0.id == second.id }?.zoom == 1.0)
    }

    @Test func stopsAtTheContentLimit() {
        let store = TerminalStore()
        let session = store.newSession(in: URL(fileURLWithPath: "/tmp"))

        store.zoom(session.id, by: 40)

        #expect(store.sessions.first?.zoom == Zoom.Scope.content.range.upperBound)
    }
}
