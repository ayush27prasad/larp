import Foundation
import Testing

@testable import Larp

struct ZoomTests {
    @Test func stepsInTenths() {
        #expect(Zoom.stepped(1.0, by: 1) == 1.1)
        #expect(Zoom.stepped(1.0, by: -2) == 0.8)
    }

    @Test func returnsExactlyToActualSize() {
        var zoom = 1.0
        for _ in 0..<7 { zoom = Zoom.stepped(zoom, by: 1) }
        for _ in 0..<7 { zoom = Zoom.stepped(zoom, by: -1) }
        #expect(zoom == 1.0)
    }

    @Test func staysWithinRange() {
        #expect(Zoom.stepped(2.95, by: 5) == Zoom.range.upperBound)
        #expect(Zoom.stepped(0.55, by: -5) == Zoom.range.lowerBound)
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
}
