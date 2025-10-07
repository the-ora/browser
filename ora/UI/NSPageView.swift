import SwiftUI

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit
    import os.log

    private let logger = Logger(
        subsystem: "com.orabrowser.app", category: "NSPageView"
    )

    /// A ``NSViewControllerRepresentable`` for showing ``NSPageController``.
    /// Use ``init(selection:pageObjects:idKeyPath:contentView:)`` to initialize a view and add it to a SwiftUI view
    /// hierarchy.
    public struct NSPageView<T: Equatable, V: View>: NSViewControllerRepresentable {
        let selection: Binding<Int>
        let pageObjects: [T]
        let idKeyPath: KeyPath<T, String>

        let onContentPrepared: ((T) -> Void)?
        let contentView: (T) -> V

        /// Construct a ``NSPageView``.
        /// - parameter selection: a binding to the selected index, which should in range of ``pageObjects``
        /// - parameter pageObjects: provides data source
        /// - parameter idKeyPath: key path to access the id of ``T``
        /// - parameter contentView: given a ``T`` from ``pageObjects``, return a view to be displayed
        public init(
            selection: Binding<Int>,
            pageObjects: [T],
            idKeyPath: KeyPath<T, String>,
            onContentPrepared: ((T) -> Void)? = nil,
            @ViewBuilder contentView: @escaping (T) -> V
        ) {
            self.selection = selection
            self.pageObjects = pageObjects
            self.idKeyPath = idKeyPath
            self.onContentPrepared = onContentPrepared
            self.contentView = contentView
        }

        public func makeNSViewController(context: Context) -> some NSViewController {
            let controller = NSPageViewContainerController<T, V>()
            controller.pageObjects = pageObjects
            controller.idFromObject = { object in
                return object[keyPath: idKeyPath]
            }
            controller.objectToView = { object in
                return contentView(object)
            }
            controller.idToObject = { [weak controller] id in
                guard let controller else {
                    return nil
                }
                return controller.pageObjects.first { page in
                    let pageId = page[keyPath: idKeyPath]
                    return pageId == id
                }
            }
            controller.onContentPrepared = onContentPrepared
            controller.onSelectedIndexChanged = { index in
                withTransaction(selection.transaction) {
                    selection.wrappedValue = index
                }
            }
            controller.transitionStyle = .horizontalStrip
            return controller
        }

        public func updateNSViewController(_ nsViewController: some NSViewController, context: Context) {
            guard let controller = nsViewController as? NSPageViewContainerController<T, V> else {
                return
            }

            if controller.pageObjects != pageObjects || controller.selectedIndex != selection.wrappedValue {
                let selectionAnimation = selection.transaction.animation
                let contextAnimation = context.transaction.animation
                let animated = selectionAnimation != nil || contextAnimation != nil
                logger.log(
                    "updateNSViewController new \(selection.wrappedValue), count: \(pageObjects.count), animated: \(animated)"
                )
                logger.log(
                    "updateNSViewController old \(controller.selectedIndex), count: \(controller.pageObjects.count)"
                )

                controller.pageObjects = pageObjects
                controller.updateDataSource()
                controller.updateSelectedIndex(selection.wrappedValue, animated: animated)
            }
        }
    }

    /// A NSView to exposure the ``onStartLiveResize`` and ``onEndLiveResize`` event.
    public class ResizeAwareNSView: NSView {
        public var onEndLiveResize: (() -> Void)?
        public var onStartLiveResize: (() -> Void)?

        override public func viewDidEndLiveResize() {
            super.viewDidEndLiveResize()
            onEndLiveResize?()
        }

        override public func viewWillStartLiveResize() {
            super.viewWillStartLiveResize()
            onStartLiveResize?()
        }
    }

    class NSPageViewContainerController<T, V>: NSPageController, NSPageControllerDelegate
        where V: View
    {
        var pageObjects: [T] = []

        var idFromObject: ((T) -> String)?
        var idToObject: ((String) -> T?)?
        var objectToView: ((T) -> V)?

        var onSelectedIndexChanged: ((Int) -> Void)?
        var onContentPrepared: ((T) -> Void)?
        private var previousBoundsSize: CGSize = .zero

        override func loadView() {
            let view = ResizeAwareNSView()
            view.onStartLiveResize = { [weak self] in
                self?.completeTransition()
            }
            view.onEndLiveResize = { [weak self] in
                self?.completeTransition()
            }
            self.view = view
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            self.delegate = self
            self.updateDataSource()
            self.view.wantsLayer = true
        }

        override func viewDidLayout() {
            super.viewDidLayout()
            for view in self.view.subviews {
                view.frame = self.view.bounds
            }

            let currentSize = self.view.bounds.size
            if currentSize != previousBoundsSize {
                previousBoundsSize = currentSize
                self.completeTransition()
            }
        }

        func updateDataSource() {
            self.arrangedObjects = pageObjects
            logger.log("NSPageView updateDataSource \(self.arrangedObjects.count)")
        }

        func updateSelectedIndex(_ index: Int, animated: Bool) {
            logger.log("NSPageView updateSelectedIndex \(index), animated \(animated)")

            if animated {
                NSAnimationContext.runAnimationGroup { _ in
                    self.animator().selectedIndex = index
                } completionHandler: {
                    self.completeTransition()
                }
            } else {
                self.selectedIndex = index
                self.completeTransition()
            }
        }

        func pageController(
            _ pageController: NSPageController,
            identifierFor object: Any
        ) -> NSPageController.ObjectIdentifier {
            guard let typedObject = object as? T else {
                logger.log("NSPageView identifierFor: unexpected object type")
                return ""
            }
            return idFromObject?(typedObject) ?? ""
        }

        func pageController(
            _ pageController: NSPageController,
            viewControllerForIdentifier identifier: NSPageController.ObjectIdentifier
        ) -> NSViewController {
            let controller = NSPageViewContentController<T, V>()
            controller.content = objectToView
            controller.object = idToObject?(identifier)
            if let object = controller.object {
                onContentPrepared?(object)
            }
            return controller
        }

        func pageController(_ pageController: NSPageController, didTransitionTo object: Any) {
            DispatchQueue.main.async {
                self.onSelectedIndexChanged?(self.selectedIndex)
            }
        }
    }

    class NSPageViewContentController<T, V>: NSViewController where V: View {
        var content: ((T) -> V)?
        var object: T?

        private var hostingView: NSHostingView<AnyView>?

        override func loadView() {
            self.view = NSView()
        }

        override func viewDidLoad() {
            super.viewDidLoad()

            guard let object, let content else {
                return
            }
            let view = content(object)
            let wrappedView = AnyView(view.ignoresSafeArea())
            let hostingView = NSHostingView(rootView: wrappedView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: self.view.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ])
            self.hostingView = hostingView
        }
    }
#endif
