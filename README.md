# QwenDash

A native SwiftUI dashboard for talking to a locally-running Qwen model (via LM Studio), with a live "synapse map" that visualises your query firing through the network as the model thinks.

Dark cyberpunk-glass aesthetic. Built for Apple Silicon Macs.

## What you're getting

- A neon-on-glass dashboard that looks like a Blade Runner terminal.
- Above the chat, a **synapse map**: input tokens on the left, an animated "hidden activation" cluster in the middle, and an output column that lights up as the model streams tokens. Pulses travel along curved edges like synapses firing.
- Live stats: connection dot, loaded model id, request latency, tokens-per-second.
- Streaming chat (OpenAI-compatible API), with a Clear button and a Stop button.

## Prereqs

1. macOS 14 (Sonoma) or newer, Apple Silicon.
2. **Xcode 15+** installed (for the Swift toolchain and SwiftUI).
3. **LM Studio** with a Qwen model downloaded (you're already on `mlx-community/Qwen3.6-35B-A3B-nvfp4` — perfect).

## Start LM Studio's local server

1. Open LM Studio.
2. Load the Qwen model you downloaded.
3. Go to the **Developer** tab (the `</>` icon on the left rail).
4. Toggle **"Status: Running"** to ON. It should bind to `http://localhost:1234`.
5. Make sure **"CORS"** is enabled if you hit any browser/network issues later (not needed for this native app, but good hygiene).

Verify the server is live:

```bash
curl http://localhost:1234/v1/models
```

You should see your Qwen model id in the JSON. QwenDash will auto-detect and use it.

## Run the dashboard

The easiest path:

```bash
cd /path/to/QwenDash
open Package.swift
```

That opens the SwiftPM project directly in Xcode. Then press **⌘R** to build and run. Xcode launches the app, it connects to LM Studio, and you can start chatting.

Or, from the terminal (headless build, app window will still appear):

```bash
cd /path/to/QwenDash
swift run QwenDash
```

## Using it

- Type your query in the glass input at the bottom.
- **⌘⏎** to send. (Plain Enter adds a newline.)
- Watch the synapse map:
  - Your tokens appear as cyan nodes on the left and fire pulses into the hidden cluster.
  - The cluster cross-fires in violet while the model streams.
  - Magenta nodes pop in on the right as response tokens arrive — each with pulses from the cluster.
- The button turns amber with a stop icon while streaming — click it to abort.
- **Clear** at the top of the conversation panel resets everything.

## Customisation pointers

Everything worth tuning lives in a small number of files:

- **`Sources/QwenDash/Theme.swift`** — colour palette, neon accents, fonts, glass panel style.
- **`Sources/QwenDash/Models/SynapseGraph.swift`** — hidden cluster size, edge density, pulse speed/intensity, output column cap.
- **`Sources/QwenDash/Views/SynapseMapView.swift`** — node/edge/pulse rendering, background grid + scanline, curve shape.
- **`Sources/QwenDash/Models/LMStudioClient.swift`** — base URL, temperature, max tokens. Change `baseURL` if LM Studio runs on a different port.
- **`Sources/QwenDash/ContentView.swift`** — overall layout, backdrop gradients.

## Troubleshooting

**"Can't reach LM Studio at localhost:1234"** — make sure the server is toggled on in LM Studio's Developer tab, and that a model is loaded.

**Nothing animates** — the synapse map only lights up in response to activity. Send a query and watch it fire.

**Streaming stalls immediately** — some LM Studio builds need `"stream": true` explicitly accepted; this app already sends that. If you still see issues, check the LM Studio server logs in the Developer tab.

**App builds as a CLI-looking tool** — that's normal for SwiftPM executables. Opening `Package.swift` in Xcode is the cleanest way to run it with a proper window. If you want a bundled `.app` with an icon and Dock presence, create a new Xcode "macOS App" project, drop all the Swift files under `Sources/QwenDash/` into it, and build there instead.

## File layout

```
QwenDash/
├── Package.swift
├── README.md
└── Sources/QwenDash/
    ├── QwenDashApp.swift        # @main entry, window setup
    ├── ContentView.swift        # dashboard layout + cyber backdrop
    ├── Theme.swift              # palette, fonts, GlassPanel, PanelLabel
    ├── Models/
    │   ├── ChatMessage.swift
    │   ├── ChatViewModel.swift  # streaming, stats, graph orchestration
    │   ├── LMStudioClient.swift # OpenAI-compatible SSE streaming
    │   └── SynapseGraph.swift   # nodes, edges, pulses, tick()
    └── Views/
        ├── StatsBar.swift       # top status row
        ├── SynapseMapView.swift # Canvas + TimelineView neural map
        ├── ChatView.swift       # message bubbles, streaming cursor
        └── InputBar.swift       # glass text input + send button
```

Have fun.
