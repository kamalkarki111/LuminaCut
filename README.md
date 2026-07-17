# LuminaCut — AI Video Editor for Mac

A full-featured **native macOS** video editor (CapCut / VN / Meta Edits–class workflow) built with **SwiftUI + AVFoundation**, with a built-in **Kimi AI chat** panel that drives the timeline from natural language.

Same product architecture as **Lumina** (photo editor): dark modern chrome, tool rails, inspector, center stage, right-side AI chat.

## Features

| Area | Capabilities |
|------|----------------|
| **Media** | Import video, images, audio · library grid · click to timeline |
| **Timeline** | Multi-track (Video, Overlay, Text, Effects, Audio, Music) · drag clips · snap · zoom |
| **Edit** | Split at playhead · delete · duplicate · trim in/out · speed 0.25×–4× |
| **Audio** | Volume · mute · fade in/out |
| **Transform** | Scale · position · rotation · opacity · flip · PiP overlay |
| **Color** | Brightness, contrast, sat, warmth, highlights, shadows, vignette, fade, B&W |
| **Looks** | 12 cinematic grades (Cinematic, Noir, Vintage, Teal & Orange, …) |
| **Transitions** | Dissolve, fade black/white, wipe, slide, zoom, flash |
| **Effects** | Glitch, VHS, grain, blur, shake, flash, duotone, neon, … |
| **Text** | Titles on text track with size/position |
| **Canvas** | 16:9, 9:16, 1:1, 4:3, 4:5, 21:9 · 24/30/60 fps |
| **Export** | MP4 · 1080p / 720p / Medium / HEVC presets |
| **History** | Undo / redo |
| **AI Chat** | Right panel · Kimi · offline fallback |

## Run

```bash
cd LuminaCut
./scripts/run.sh        # release .app
# or
swift build && swift run
open Package.swift      # Xcode
```

## Kimi AI

1. Get a key at [platform.kimi.ai](https://platform.kimi.ai)  
2. **LuminaCut → Settings…** → paste key  
3. Chat examples:
   - *Split at playhead*
   - *Slow motion 0.5x*
   - *Apply cinematic look*
   - *Add dissolve transition*
   - *Add text "My Story"*
   - *Set canvas to 9:16*
   - *Warm up colors*
   - *Mute this clip*

## Shortcuts

| Key | Action |
|-----|--------|
| ⌘I | Import media |
| ⌘B | Split at playhead |
| ⌘D | Duplicate |
| ⌫ | Delete clip |
| Space | Play / pause |
| ← / → | Step frame |
| ⌘Z / ⌘⇧Z | Undo / redo |
| ⌘⇧E | Export |
| ⌘↵ | Send AI message |

## Architecture

```
LuminaCut/
├── Package.swift
└── Sources/LuminaCut/
    ├── App/
    ├── Models/          # Project, tracks, clips, effects, AI commands
    ├── Services/        # Import, composition, playback, export, Kimi
    ├── ViewModels/      # Editor + Chat
    └── Views/           # Library, Preview, Timeline, Inspector, Chat
```

- **Composition**: `AVMutableComposition` + `AVMutableVideoComposition`  
- **Playback**: `AVPlayer` with `AVPlayerView`  
- **AI**: Moonshot OpenAI-compatible chat → structured timeline actions  

## License

Personal / educational use. Bring your own Kimi API key.
