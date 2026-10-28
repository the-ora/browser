import AppKit
@testable import Ora
import Testing

@MainActor
struct BrowserPageHostViewTests {
    @Test func attachingFirstContentViewAddsSubview() {
        let host = makeHost()
        let contentView = TrackingContentView()

        host.host(contentView: contentView)

        #expect(host.subviews.count == 1)
        #expect(host.subviews.first === contentView)
        #expect(host.hostedContentView === contentView)
        #expect(contentView.frame == host.bounds)
    }

    @Test func switchingContentViewsDetachesOldViewAndAttachesNewView() {
        let host = makeHost()
        let firstContentView = TrackingContentView()
        let secondContentView = TrackingContentView()

        host.host(contentView: firstContentView)
        host.host(contentView: secondContentView)

        #expect(host.subviews.count == 1)
        #expect(host.subviews.first === secondContentView)
        #expect(host.hostedContentView === secondContentView)
        #expect(firstContentView.superview == nil)
        #expect(secondContentView.superview === host)
    }

    @Test func updatingWithSameContentViewIsANoOp() {
        let host = makeHost()
        let contentView = TrackingContentView()

        host.host(contentView: contentView)
        let transitionCountAfterFirstAttach = contentView.superviewTransitions

        host.host(contentView: contentView)

        #expect(host.subviews.count == 1)
        #expect(host.subviews.first === contentView)
        #expect(contentView.superviewTransitions == transitionCountAfterFirstAttach)
    }

    @Test func clearingContentViewRemovesHostedSubview() {
        let host = makeHost()
        let contentView = TrackingContentView()

        host.host(contentView: contentView)
        host.host(contentView: nil)

        #expect(host.subviews.isEmpty)
        #expect(host.hostedContentView == nil)
        #expect(contentView.superview == nil)
    }

    @Test func attachingContentViewFromAnotherHostReparentsItCleanly() {
        let firstHost = makeHost()
        let secondHost = makeHost()
        let contentView = TrackingContentView()

        firstHost.host(contentView: contentView)
        secondHost.host(contentView: contentView)

        #expect(firstHost.subviews.isEmpty)
        #expect(firstHost.hostedContentView == nil)
        #expect(secondHost.subviews.count == 1)
        #expect(secondHost.subviews.first === contentView)
        #expect(secondHost.hostedContentView === contentView)
        #expect(contentView.superview === secondHost)
        #expect(contentView.removeFromSuperviewCalls == 1)
    }

    @Test func switchingToAStaleSubviewAlreadyAttachedToTheSameHostDoesNotReparentIt() {
        let host = makeHost()
        let firstContentView = TrackingContentView()
        let staleContentView = TrackingContentView()

        host.host(contentView: firstContentView)
        host.addSubview(staleContentView)

        let staleSuperviewTransitions = staleContentView.superviewTransitions

        host.host(contentView: staleContentView)

        #expect(host.subviews.count == 1)
        #expect(host.subviews.first === staleContentView)
        #expect(host.hostedContentView === staleContentView)
        #expect(firstContentView.superview == nil)
        #expect(staleContentView.superview === host)
        #expect(staleContentView.superviewTransitions == staleSuperviewTransitions)
        #expect(staleContentView.removeFromSuperviewCalls == 0)
    }

    @Test func cancelOperationStopsAtTheHostInsteadOfReachingTheWindow() {
        let host = makeHost()
        let nextResponder = CancelOperationSpy()
        host.nextResponder = nextResponder
        var handlerCalls = 0
        host.cancelOperationHandler = { handlerCalls += 1 }

        host.cancelOperation(nil)

        #expect(handlerCalls == 1)
        #expect(nextResponder.cancelOperationCalls == 0)
    }

    @Test func escapeStopsAPageThatIsLoading() {
        let host = makeHost()
        let page = LoadingPageSpy(isLoading: true)
        host.cancelOperationHandler = BrowserPageView.cancelOperationHandler(for: page)

        host.cancelOperation(nil)

        #expect(page.stopLoadingCalls == 1)
    }

    @Test func escapeLeavesALoadedPageAlone() {
        let host = makeHost()
        let page = LoadingPageSpy(isLoading: false)
        host.cancelOperationHandler = BrowserPageView.cancelOperationHandler(for: page)

        host.cancelOperation(nil)

        #expect(page.stopLoadingCalls == 0)
    }

    private func makeHost() -> BrowserPageHostView {
        BrowserPageHostView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }
}

private final class TrackingContentView: NSView {
    var superviewTransitions = 0
    var removeFromSuperviewCalls = 0

    override func removeFromSuperview() {
        removeFromSuperviewCalls += 1
        super.removeFromSuperview()
    }

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        superviewTransitions += 1
        super.viewWillMove(toSuperview: newSuperview)
    }
}

/// Records `cancelOperation(_:)` calls that reach it through the responder chain.
private final class CancelOperationSpy: NSResponder {
    private(set) var cancelOperationCalls = 0

    override func cancelOperation(_ sender: Any?) {
        cancelOperationCalls += 1
    }
}

/// A page that records whether Escape stopped it.
private final class LoadingPageSpy: LoadingStoppable {
    let isLoading: Bool
    private(set) var stopLoadingCalls = 0

    init(isLoading: Bool) {
        self.isLoading = isLoading
    }

    func stopLoading() {
        stopLoadingCalls += 1
    }
}
