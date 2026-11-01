import AppKit
import SwiftUI

/// Hosts every open shell at once and shows the active one.
///
/// Switching tabs must not restart a shell, so the views are kept alive in a
/// container and merely hidden. Rebuilding them per selection — the obvious
/// SwiftUI approach — would kill and respawn the process on every tab switch.
struct TerminalStack: NSViewRepresentable {
    let store: TerminalStore

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        store.containerView = container
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        let coordinator = context.coordinator
        let live = Set(store.sessions.map(\.id))

        // Terminate and drop shells whose tab has closed.
        for (id, host) in coordinator.hosts where !live.contains(id) {
            host.terminate()
            host.removeFromSuperview()
            coordinator.hosts[id] = nil
        }

        for session in store.sessions {
            let host = coordinator.hosts[session.id] ?? {
                let host = TerminalHostView()
                host.onExit = { [weak store] cleanly in
                    store?.shellExited(session.id, cleanly: cleanly)
                }
                host.startShell(in: session.workingDirectory)
                coordinator.hosts[session.id] = host
                return host
            }()

            if host.superview !== container {
                host.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(host)
                NSLayoutConstraint.activate([
                    host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    host.topAnchor.constraint(equalTo: container.topAnchor),
                    host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            }
            host.isHidden = session.id != store.activeSessionID
        }

        // Typing should land in the tab you just switched to.
        if let activeID = store.activeSessionID,
           let host = coordinator.hosts[activeID],
           container.window != nil {
            host.focusTerminal()
        }
    }

    static func dismantleNSView(_ container: NSView, coordinator: Coordinator) {
        coordinator.hosts.values.forEach { $0.terminate() }
        coordinator.hosts.removeAll()
    }

    /// VSplitView divides space by each child's ideal height; a representable
    /// reports none, so without this the terminal takes half the window.
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSView,
        context: Context
    ) -> CGSize? {
        CGSize(width: proposal.width ?? 600, height: proposal.height ?? 220)
    }

    @MainActor
    final class Coordinator {
        var hosts: [TerminalSession.ID: TerminalHostView] = [:]
    }
}
