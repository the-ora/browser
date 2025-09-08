import os.log
import WebKit

private let logger = Logger(subsystem: "com.orabrowser.ora", category: "FindController")

class FindController: NSObject {
    let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
        super.init()
    }

    // MARK: - Inject mark.js

    func injectMarkJS() {
        guard let jsPath = Bundle.main.path(forResource: "mark", ofType: "js"),
              let jsCode = try? String(contentsOfFile: jsPath, encoding: .utf8)
        else {
            logger.error("mark.js not found or failed to load")
            return
        }

        webView.evaluateJavaScript(jsCode) { _, error in
            if let error {
                logger.error("Error injecting mark.js: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Highlight Text

    func highlight(_ searchTerm: String) {
        let escapedTerm = searchTerm.replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function() {
            // Inject CSS if missing
            if (!document.getElementById('highlight-style')) {
                const style = document.createElement('style');
                style.id = 'highlight-style';
                style.textContent = `
                    mark.search-highlight {
                        background-color: yellow;
                        color: black;
                    }
                    mark.search-highlight.current {
                        background-color: orange !important;
                    }
                `;
                document.head.appendChild(style);
            }

            if (!window.findController) {
                window.findController = {
                    markInstance: new Mark(document.body),
                    matches: [],
                    currentIndex: -1
                };
            }

            // Unmark existing highlights and apply new
            findController.markInstance.unmark({
                done: function() {
                    findController.markInstance.mark('\(escapedTerm)', {
                        className: "search-highlight",
                        separateWordSearch: false,
                        done: function() {
                            findController.matches = Array.from(document.querySelectorAll("mark.search-highlight"));
                            if (findController.matches.length > 0) {
                                findController.currentIndex = 0;
                                let el = findController.matches[0];
                                el.classList.add("current");
                                el.scrollIntoView({behavior: "smooth", block: "center"});
                            }
                        }
                    });
                }
            });
        })();
        """
        webView.evaluateJavaScript(js)
    }

    // MARK: - Next Match

    func nextMatch() {
        let js = """
        (function() {
            const fc = window.findController;
            if (fc && fc.matches.length > 0) {
                fc.matches[fc.currentIndex].classList.remove("current");
                fc.currentIndex = (fc.currentIndex + 1) % fc.matches.length;
                const el = fc.matches[fc.currentIndex];
                el.classList.add("current");
                el.scrollIntoView({behavior: "smooth", block: "center"});
            }
        })();
        """
        webView.evaluateJavaScript(js)
    }

    // MARK: - Previous Match

    func previousMatch() {
        let js = """
        (function() {
            const fc = window.findController;
            if (fc && fc.matches.length > 0) {
                fc.matches[fc.currentIndex].classList.remove("current");
                fc.currentIndex = (fc.currentIndex - 1 + fc.matches.length) % fc.matches.length;
                const el = fc.matches[fc.currentIndex];
                el.classList.add("current");
                el.scrollIntoView({behavior: "smooth", block: "center"});
            }
        })();
        """
        webView.evaluateJavaScript(js)
    }

    // MARK: - Clear All Matches

    func clearMatches() {
        let js = """
        (function() {
            const fc = window.findController;
            if (fc) {
                fc.markInstance.unmark();
                fc.matches = [];
                fc.currentIndex = -1;
            }
        })();
        """
        webView.evaluateJavaScript(js)
    }

    // MARK: - Count Matches

    func countMatches(completion: @escaping (Int) -> Void) {
        let js = """
        (function() {
            return window.findController && findController.matches
                ? findController.matches.length
                : 0;
        })();
        """
        webView.evaluateJavaScript(js) { result, _ in
            let count = result as? Int ?? 0
            completion(count)
        }
    }

    // MARK: - Get Current Match Index

    func getCurrentMatchIndex(completion: @escaping (Int) -> Void) {
        let js = """
        (function() {
            return window.findController
                ? findController.currentIndex + 1
                : 0;
        })();
        """
        webView.evaluateJavaScript(js) { result, _ in
            let index = result as? Int ?? 0
            completion(index)
        }
    }

    // MARK: - Get Match Info

    func getMatchInfo(completion: @escaping (Int, Int) -> Void) {
        let js = """
        (function() {
            if (window.findController) {
                return {
                    total: findController.matches.length,
                    current: findController.currentIndex + 1
                };
            }
            return { total: 0, current: 0 };
        })();
        """
        webView.evaluateJavaScript(js) { result, _ in
            if let dict = result as? [String: Any],
               let total = dict["total"] as? Int,
               let current = dict["current"] as? Int
            {
                completion(current, total)
            } else {
                completion(0, 0)
            }
        }
    }
}
