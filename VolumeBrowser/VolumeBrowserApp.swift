import SwiftUI
import WebKit

@main
struct VolumeBrowserApp: App {
    var body: some Scene {
        WindowGroup {
            BrowserView()
                .ignoresSafeArea()
        }
    }
}

struct BrowserView: View {
    @State private var boost: Double = 1.0
    @State private var showControls = true
    @StateObject private var model = BrowserModel()

    var body: some View {
        ZStack {
            WebContainer(model: model, boost: boost)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Button { model.goBack() } label: {
                        Image(systemName: "chevron.left")
                    }
                    Button { model.goForward() } label: {
                        Image(systemName: "chevron.right")
                    }
                    Button { model.reload() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showControls.toggle()
                        }
                    } label: {
                        Image(systemName: showControls ? "speaker.wave.2.fill" : "speaker.wave.2")
                    }
                }
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)

                Spacer()

                if showControls {
                    VStack(spacing: 7) {
                        HStack {
                            Text("音量ブースト")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(Int(boost * 100))%")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                        }

                        Slider(value: $boost, in: 1...3, step: 0.25)

                        HStack {
                            ForEach([1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0], id: \.self) { value in
                                Button("\(Int(value * 100))") {
                                    boost = value
                                }
                                .font(.caption2.weight(.medium))
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(.ultraThinMaterial)
                }
            }
            .ignoresSafeArea(edges: .all)
        }
        .preferredColorScheme(nil)
    }
}

final class BrowserModel: ObservableObject {
    weak var webView: WKWebView?

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }

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
        config.websiteDataStore = .default()

        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(
            source: Self.injectedJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        config.userContentController = controller

        let view = WKWebView(frame: .zero, configuration: config)

        // Make the site behave like a real iPhone Safari page instead of a desktop web view.
        view.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true

        model.webView = view
        if let url = URL(string: "https://www.asmr.one/works") {
            view.load(URLRequest(url: url))
        }
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
            webView.evaluateJavaScript(Self.viewportFix, completionHandler: nil)
        }

        static let viewportFix = """
        (() => {
          let meta = document.querySelector('meta[name="viewport"]');
          if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            document.head.appendChild(meta);
          }
          meta.content = 'width=device-width, initial-scale=1, maximum-scale=1, viewport-fit=cover';
          document.documentElement.style.width = '100%';
          document.body.style.width = '100%';
          document.body.style.margin = '0';
        })();
        """
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
        gainValue = Math.max(1, Math.min(3, Number(v) || 1));
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
