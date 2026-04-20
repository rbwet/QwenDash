# QwenDash

A native macOS dashboard for chatting with a local Qwen model, with a live "synapse map" that pretends to show your query firing through the network while the model thinks.

It's a little over-the-top. That's the point.

<p align="center">
  <img src="docs/screenshot.png" alt="QwenDash screenshot" width="900">
</p>

## Why this exists

I wanted a nicer face on top of LM Studio than a browser tab. So I built one.

QwenDash is pure SwiftUI, talks to LM Studio's OpenAI-compatible endpoint over streaming SSE, and renders a vaguely-plausible animated graph of nodes and pulses whenever you send a message. It doesn't peek inside the model — the animation is a theatrical stand-in, not a real activation trace. But it feels alive, and that turns out to matter more than you'd think when you're staring at a chat window for hours.

## What you get

- **Native SwiftUI app.** No Electron, no browser, no 300MB of Chromium. Launches instantly.
- **Synapse map.** Your query tokens appear as cyan nodes on the left and fire pulses into a drifting cluster of "hidden" nodes in the middle. As the model streams back, magenta nodes pop in on the right, each one trailing a pulse from the cluster. Edges glow, things cross-chatter, the cluster looks busy.
- **Streaming chat.** Token-by-token output with a proper stop button. Cancel mid-thought, clear the conversation, start over.
- **Live stats bar.** Connection state, model id, request latency, tokens/sec.
- **Cyberpunk-glass look.** Dark backdrop, radial neon glows, ultra-thin material panels, monospaced labels. Not subtle.

## Requirements

- macOS 14 (Sonoma) or newer, Apple Silicon
- Xcode 15 or newer
- [LM Studio](https://lmstudio.ai) running a Qwen model locally

I developed this against `mlx-community/Qwen3-*` variants but anything LM Studio exposes via its OpenAI-compatible server will work — the model id is auto-detected.

## Getting started

### 1. Spin up LM Studio

Open LM Studio, load a model, hop over to the **Developer** tab (the `</>` icon in the left rail), and flip the server toggle **on**. It'll bind to `http://localhost:1234` by default.

Quick sanity check from a terminal:

```bash
curl http://localhost:1234/v1/models
```

If you see your model in the JSON, you're good.

### 2. Run QwenDash

Easiest path is through Xcode:

```bash
git clone https://github.com/<your-handle>/QwenDash.git
cd QwenDash
open Package.swift
```

That opens the SwiftPM project straight in Xcode. Hit **⌘R** to build and run.

Or from the command line:

```bash
swift run QwenDash
```

Either way, the window comes up, auto-connects to LM Studio, and you can start typing.

## Using it

- Type in the glass input at the bottom.
- **⌘⏎** to send. Plain `⏎` adds a newline.
- While the model is streaming, the send button flips amber with a stop icon — tap it to abort the request.
- **Clear** (top-right of the conversation panel) wipes the chat and resets the graph.
- That's basically it. There's no settings screen, no accounts, no telemetry. It's a toy.

## Tuning the vibe

All the knobs live in a handful of files. If you want to reskin it or change behaviour, start here:

| File | What's in it |
| --- | --- |
| `Sources/QwenDash/Theme.swift` | Palette, neon accents, fonts, glass panels, panel labels |
| `Sources/QwenDash/Models/SynapseGraph.swift` | Hidden cluster size, edge density, pulse speed/intensity, output column cap |
| `Sources/QwenDash/Views/SynapseMapView.swift` | Node/edge/pulse rendering, background grid, scanline, curve shape |
| `Sources/QwenDash/Models/LMStudioClient.swift` | `baseURL`, temperature, max tokens — change the URL if LM Studio runs on a different port |
| `Sources/QwenDash/ContentView.swift` | Overall layout, backdrop gradients |

## File layout

```
QwenDash/
├── Package.swift
├── README.md
└── Sources/QwenDash/
    ├── QwenDashApp.swift         # @main entry, window + activation policy
    ├── ContentView.swift         # dashboard layout + cyber backdrop
    ├── Theme.swift               # palette, fonts, GlassPanel, PanelLabel
    ├── Models/
    │   ├── ChatMessage.swift
    │   ├── ChatViewModel.swift   # streaming, stats, graph orchestration
    │   ├── LMStudioClient.swift  # OpenAI-compatible SSE streaming
    │   └── SynapseGraph.swift    # nodes, edges, pulses, tick()
    └── Views/
        ├── StatsBar.swift        # top status row
        ├── SynapseMapView.swift  # Canvas + TimelineView neural map
        ├── ChatView.swift        # message bubbles, streaming cursor
        └── InputBar.swift        # glass text input + send button
```

## Troubleshooting

**"Can't reach LM Studio at `localhost:1234`."**
Make sure the server is toggled on in the Developer tab and that a model is actually loaded. A loaded-but-not-served model will not respond.

**The synapse map just sits there.**
It's supposed to. The graph only animates when there's activity — send a message and it'll come alive.

**The app launches but I can't type in the input.**
SwiftPM executables can boot as background processes that never become the key window, which quietly swallows every keystroke. The app's `AppDelegate` already forces `.regular` activation policy and makes the window key on launch, so this shouldn't happen — but if you ever rip the delegate out, that's the bug you'll hit.

**I want a proper `.app` with a Dock icon and an app bundle.**
Create a fresh Xcode "macOS App" project and drop everything under `Sources/QwenDash/` into it. The source is self-contained, no external dependencies.

## A note on the "synapse map"

It's **not** a real activation trace. I'm not hooking into Qwen's internals to sample attention weights or hidden states. It's a stylised representation driven by:

1. The tokens you send (split crudely on whitespace/punctuation).
2. The deltas streamed back from LM Studio.
3. A bit of randomness and decay to keep things breathing.

If someone wants to wire it up to actual telemetry from a running model, the graph API in `SynapseGraph.swift` is small and approachable — `ingestUserQuery`, `ingestAssistantToken`, and a `tick(dt:)` pump. PRs welcome.

## License

MIT. Do whatever you want with it.

---

Built in a weekend because LM Studio's UI is fine but I wanted something that felt like a piece of kit from a cyberpunk desk.
