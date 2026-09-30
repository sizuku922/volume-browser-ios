import SwiftUI
import WebKit

@main
struct VolumeBrowserApp: App {
    var body: some Scene {
        WindowGroup { BrowserView() }
    }
}

struct BrowserView: View {
    @State private var urlText = "https://www.asmr.one/works"
    @State private var boost: Double = 1.0
    @StateObject private var model = BrowserModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("URL", text: $urlText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)
                Button("開く") {
                    var value = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.contains("://") { value = "https://" + value }
                    model.load(value)
                }
            }
            .padding(8)

            WebContainer(model: model, boost: boost)

            VStack(spacing: 6) {
                HStack {
                    Text("音量ブースト")
                    Spacer()
                    Text("\(Int(boost * 100))%").monospacedDigit()
                }
                Slider(value: $boost, in: 1...4, step: 0.25)
                HStack {
                    Text("100%")
                    Spacer()
                    Text("200%")
                    Spacer()
                    Text("300%")
                    Spacer()
                    Text("400%")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial)
        }
        .onAppear { model.load(urlText) }
    }
}

final class BrowserModel: ObservableObject {
    weak var webView: WKWebView?

    func load(_ value: String) {
        guard let url = URL(string: value) else { return }
        webView?.load(URLRequest(url: url))
    }

    func setBoost(_ value: Double) {
        let js = "window.__VB_SET_GAIN && window.__VB_SET_GAIN(\(value));"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
}

struct WebContainer: UIViewRepresentable {
    @ObservedObject var model: BrowserModel
    let boost: Double

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(
            source: Self.injectedJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        config.userContentController = controller

        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        model.webView = view
        return view
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        model.webView = webView
        model.setBoost(boost)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let model: BrowserModel
        init(model: BrowserModel) { self.model = model }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.webView = webView
            model.setBoost(1.0)
        }
    }

    static let injectedJS = #"""
    (() => {
      if (window.__VB_INSTALLED) return;
      window.__VB_INSTALLED = true;

      let gainValue = 1.0;
      let ctx = null;
      const connected = new WeakSet();
      const nodes = new WeakMap();

      function ensureContext() {
        if (!ctx) {
          const C = window.AudioContext || window.webkitAudioContext;
          if (!C) return null;
          ctx = new C();
        }
        if (ctx.state === 'suspended') ctx.resume().catch(()=>{});
        return ctx;
      }

      function connect(el) {
        if (!(el instanceof HTMLMediaElement) || connected.has(el)) return;
        const c = ensureContext();
        if (!c) return;

        try {
          const source = c.createMediaElementSource(el);
          const gain = c.createGain();
          const compressor = c.createDynamicsCompressor();

          compressor.threshold.value = -2;
          compressor.knee.value = 8;
          compressor.ratio.value = 8;
          compressor.attack.value = 0.003;
          compressor.release.value = 0.12;

          source.connect(gain).connect(compressor).connect(c.destination);
          gain.gain.value = gainValue;

          connected.add(el);
          nodes.set(el, gain);
        } catch (_) {}
      }

      function scan(root = document) {
        root.querySelectorAll?.('audio,video').forEach(connect);
        if (root instanceof HTMLMediaElement) connect(root);
      }

      window.__VB_SET_GAIN = (v) => {
        gainValue = Math.max(1, Math.min(4, Number(v) || 1));
        ensureContext();

        document.querySelectorAll('audio,video').forEach(el => {
          const node = nodes.get(el);
          if (node) node.gain.value = gainValue;
          else connect(el);
        });
      };

      const obs = new MutationObserver(muts => {
        muts.forEach(m => m.addedNodes.forEach(n => {
          if (n.nodeType === 1) scan(n);
        }));
      });

      obs.observe(document.documentElement, {subtree:true, childList:true});

      const wake = () => {
        ensureContext();
        scan();
      };
      document.addEventListener('click', wake, true);
      document.addEventListener('touchstart', wake, {capture:true, passive:true});

      setInterval(scan, 1500);
      scan();
    })();
    """#
}
