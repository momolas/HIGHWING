import Foundation
import Testing
@testable import GroundSdk
@testable import ArsdkEngine

struct DroneKitBugProTests {

    @Test("OpenGL HMD shader resources are bundled and readable via GroundSdk")
    func shaderResourcesBundled() throws {
        let shaderNames = ["distortionShader", "streamShader", "textureShader"]
        let extensions = ["vsh", "fsh"]

        // Verify via GGLShaderLoader's bundle resolution
        final class DummyShaderOwner: GGLShaderLoader {
            var programId: UInt32 = 0
        }
        _ = DummyShaderOwner()

        let groundSdkBundle = Bundle(for: GroundSdk.self)
        let candidateBundles: [Bundle] = {
            var bundles: [Bundle] = [groundSdkBundle, .main]
            if let resourceURL = groundSdkBundle.resourceURL,
               let subBundleURL = try? FileManager.default.contentsOfDirectory(
                   at: resourceURL,
                   includingPropertiesForKeys: nil
               ).first(where: { $0.lastPathComponent.hasSuffix("GroundSdk.bundle") }),
               let subBundle = Bundle(url: subBundleURL) {
                bundles.insert(subBundle, at: 0)
            }
            for bundle in Bundle.allBundles {
                if let url = bundle.url(forResource: "DroneKit_GroundSdk", withExtension: "bundle"),
                   let modBundle = Bundle(url: url) {
                    bundles.insert(modBundle, at: 0)
                }
            }
            return bundles
        }()

        for name in shaderNames {
            for ext in extensions {
                let url = candidateBundles.lazy.compactMap {
                    $0.url(forResource: name, withExtension: ext)
                }.first
                let resolvedURL = try #require(url, "Missing shader resource \(name).\(ext) in bundle")
                let contents = try String(contentsOf: resolvedURL, encoding: .utf8)
                #expect(!contents.isEmpty)
            }
        }
    }

    @Test("Unaligned Data binary loads and CockpitRessources odd offset decoding do not trap")
    func unalignedCockpitResourcesAndDataExtensions() throws {
        // Construct a synthetic buffer with odd offsets (e.g., offset 1, 3, 5)
        var raw = Data([0xAA, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC])
        #expect(raw.int8Data(atOffset: 1) == 0x12)
        // At odd offset 1: 0x12345678 in bigEndian
        #expect(raw.int32Data(atOffset: 1, bigEndian: false) == 0x12345678)

        let slice = raw.subDataNoCopy(offset: 1, size: 4)
        #expect(slice.count == 4)
        #expect(Array(slice) == [0x12, 0x34, 0x56, 0x78])

        // Empty slice edge case
        let emptySlice = raw.subDataNoCopy(offset: 100, size: 0)
        #expect(emptySlice.isEmpty)

        // PudStreamDecoder unaligned primitive loads
        raw.append(contentsOf: [0x00, 0x00, 0x80, 0x3F]) // 1.0f in little-endian at offset 7
        #expect(raw.getFloat32(at: 7) == 1.0)
        #expect(raw.getInt(at: 1, size: 2) != 0)
        #expect(raw.getInt(at: 1, size: 4) != 0)
    }

    @Test("WebSocket Frame decoding supports non-zero startIndex Data slices")
    func webSocketFrameSliceDecoding() throws {
        // Prefix 3 padding bytes so the slice has startIndex == 3
        var buffer = Data([0xFF, 0xFE, 0xFD])
        // WebSocket frame: FIN=1, opcode=1 (text), MASK=0, len=4, payload="test"
        buffer.append(contentsOf: [0x81, 0x04, 0x74, 0x65, 0x73, 0x74])

        let slice = buffer[3..<buffer.endIndex]
        #expect(slice.startIndex == 3)

        let frame = try #require(WebSocketClientSession.Frame(data: slice))
        #expect(frame.fin == true)
        #expect(frame.opCode == .text)
        #expect(String(data: frame.payload, encoding: .utf8) == "test")
    }

    @Test("PilotingCommand.Encoder and GimbalControlCommandEncoder are thread-safe under concurrent access")
    func concurrentCommandEncoders() async {
        let pilotingEncoder = PilotingCommand.Encoder.AnafiCopter()
        let gimbalEncoder = GimbalFeatureGimbal.GimbalControlCommandEncoder()
        gimbalEncoder.setInitialStabilizations([.pitch: true, .roll: false, .yaw: false])

        await withTaskGroup(of: Void.self) { group in
            // Writer task simulating MainThread updates
            group.addTask {
                for i in 0..<250 {
                    _ = pilotingEncoder.set(roll: i % 50)
                    _ = pilotingEncoder.set(pitch: -(i % 50))
                    _ = pilotingEncoder.set(yaw: i % 25)
                    _ = pilotingEncoder.set(gaz: i % 100)
                    gimbalEncoder.control(
                        mode: .position,
                        yaw: Double(i % 10),
                        pitch: Double(-(i % 20)),
                        roll: 0.0
                    )
                    gimbalEncoder.set(
                        stabilization: (i % 2 == 0),
                        targetAttitude: Double(i % 15),
                        onAxis: .pitch
                    )
                    if i % 40 == 0 {
                        pilotingEncoder.reset()
                        gimbalEncoder.reset()
                        gimbalEncoder.setInitialStabilizations([.pitch: true, .roll: true, .yaw: false])
                    }
                }
            }

            // Reader task simulating pomp_loop encoding
            group.addTask {
                for _ in 0..<250 {
                    _ = pilotingEncoder.encoder()
                    _ = gimbalEncoder.encoder()
                }
            }
        }

        pilotingEncoder.reset()
        #expect(pilotingEncoder.pilotingCommand.roll == 0)
        #expect(pilotingEncoder.pilotingCommand.pitch == 0)
    }

    @Test("GlRenderSinkCore breaks backend retain cycle upon close()")
    func glRenderSinkCoreRetainCycleBrokenOnClose() {
        final class MockRenderSinkBackend: GlRenderSinkBackend {
            var renderZone: CGRect = .zero
            var scaleType: GlRenderSinkScaleType = .fit
            var paddingFill: GlRenderSinkPaddingFill = .none
            var zebrasEnabled: Bool = false
            var zebrasThreshold: Double = 0
            var histogramsEnabled: Bool = false
            weak var textureLoader: TextureLoader?
            weak var overlayer: Overlayer?
            var sink: GlRenderSinkCore?
            var didClose = false

            func start() -> Bool { true }
            func stop() -> Bool { true }
            func renderFrame() {}
            func close() {
                didClose = true
                sink = nil
            }
        }

        final class DummyListener: GlRenderSinkListener {
            func onRenderingMayStart(renderer: GlRenderSink) {}
            func onRenderingMustStop(renderer: GlRenderSink) {}
            func onFrameReady(renderer: GlRenderSink) {}
            func onPreferredFpsChanged(renderer: GlRenderSink, fps: Float) {}
            func onContentZoneChange(contentZone: CGRect) {}
        }

        weak var weakBackend: MockRenderSinkBackend?
        weak var weakSink: GlRenderSinkCore?

        do {
            let listener = DummyListener()
            let config = GlRenderSinkCore.Config(listener: listener)
            let backend = MockRenderSinkBackend()
            let sink = GlRenderSinkCore(config: config, backend: backend)
            backend.sink = sink

            weakBackend = backend
            weakSink = sink

            sink.close()
            #expect(backend.didClose == true)
        }

        #expect(weakBackend == nil)
        #expect(weakSink == nil)
    }
}
