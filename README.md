# CCBuddy - Claude Code Usage Monitor

Native macOS menu bar app to monitor Claude Code token usage and cost in real time. Runs locally (no network), supports Pro/Max (5-hour window) and API (pay-as-you-go) modes, and uses a glass-effect popover UI.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- Real-time monitoring: FileWatcher (~0.5s) plus periodic mod-time check (default 10s) and manual refresh
- Dual modes:
  - Pro/Max: 5-hour rolling window, usage %, time remaining, burn rate, projected cost
  - API: Today/week/month/all-time cost, no time-based limits
- Cost tracking: Estimated + projected spending with tiered pricing support
- Multi-model display: Opus, Sonnet, Haiku models, deduped by request/message ids
- Glass UI: Translucent popover with history charts (daily/weekly/monthly)
- Menu bar integration: Multiple display modes (percentage, tokens, cost, icon)
- Configurable: Refresh interval (1s/5s/10s/30s/60s/manual), glass opacity, material style, font size
- Privacy-first: All parsing and calculations are local; no network access

## Screenshots

### Pro/Max mode (example)
```
┌────────────────────────────────────────┐
│ ▊▊▊  CCBuddy   Pro               10s   │
├────────────────────────────────────────┤
│  Session Progress                 35%  │
│  ████████████░░░░░░░░░░░░░░░░░░░░░░░░  │
│                                        │
│  📄 Tokens Used               7.4M     │
│  💲 Session Cost            $3.1725    │
│  🕐 Time Remaining            3:58     │
│  📈 Projected Cost          $22.10     │
│  🔥 Burn Rate            186.2K/min    │
│  💻 Model           Claude Opus 4.5    │
├────────────────────────────────────────┤
│  ↻ Refresh   ⚙ Settings   ⏻ Quit       │
└────────────────────────────────────────┘
```

### API mode (example)
```
┌────────────────────────────────────────────────────────────┐
│ ▊▊▊  CCBuddy                API                 8 secs ago │
├────────────────────────────────────────────────────────────┤
│  📄 Tokens Used                                100.8M      │
│  🕐 Today                                     $101.31      │
│  📅 This Week                                 $419.27      │
│  📆 This Month                                $803.25      │
│  💵 All Time                                 $1022.41      │
│                                                            │
│  💻 Model                          Claude Haiku 4.5        │
│                                    Claude Opus 4.5         │
│                                  Claude Sonnet 4.5         │
├────────────────────────────────────────────────────────────┤
│  Usage History                Daily   Weekly   Monthly     │
│                                                            │
│   150M ┤                        ████ 143.5M                │
│   120M ┤                                   █ 100.8M        │
│    90M ┤              ████ 96.8M                           │
│    60M ┤        ████ 88.2M                                 │
│    30M ┤                    █ 22.6M                        │
│     0  ┼───────────────────────────────────────────────────│
│         12/5   12/6   12/7   12/8   12/9   12/10   Today   │
│                                                            │
│  Totals: 452.0M tokens · $531.1525 cost                    │
├────────────────────────────────────────────────────────────┤
│  ↻ Refresh           ⚙ Settings              ⏻ Quit        │
└────────────────────────────────────────────────────────────┘
```

## Requirements

- macOS 14.0 (Sonoma) or later
- Claude Code installed/configured
- Swift 5.9+ (to build from source)

## Installation

### Build from source
```bash
git clone https://github.com/anthropics/ccbuddy-app.git
cd ccbuddy-app
swift build -c release
swift run
```

### Build a DMG (optional)
```bash
./create-icon.sh   # first time only
./build-dmg.sh
open CCBuddy-1.0.0.dmg
```

## How it works

Data lives at `~/.claude/projects/`.

1) FileWatcher marks data dirty on any JSONL change (~0.5s).  
2) Timer (default 10s) runs a quick mod-time check if not already dirty.  
3) JSONLParser loads sessions; UsageCalculator computes stats with tiered pricing.  
4) UsageViewModel caches sessions and publishes formatted data for SwiftUI views.

Each message line looks like:

```json
{
  "type": "assistant",
  "sessionId": "xxx-xxx-xxx",
  "timestamp": "2025-12-02T13:03:29.591Z",
  "message": {
    "model": "claude-opus-4-5-20251101",
    "usage": {
      "input_tokens": 9,
      "cache_creation_input_tokens": 5095,
      "cache_read_input_tokens": 12610,
      "output_tokens": 5
    }
  }
}
```

## Settings

Open the popover → Settings:

- Usage mode: Pro/Max or API
- Refresh interval: 1s / 5s / 10s / 30s / 60s / Manual (default 10s)
- Menu bar display: Percentage / Tokens / Cost / Icon
- Glass: opacity slider, material style
- Font size: Small / Medium / Large

## Token pricing (LiteLLM 2025)

| Model | Input | Output | Cache Write | Cache Read |
|-------|-------|--------|-------------|------------|
| Claude Opus 4.5 | $5/M | $25/M | $6.25/M | $0.50/M |
| Claude Opus 4 | $15/M | $75/M | $18.75/M | $1.50/M |
| Claude Sonnet 4/4.5 | $3/M | $15/M | $3.75/M | $0.30/M |
| Claude Haiku 4.5 | $1/M | $5/M | $1.25/M | $0.10/M |
| Claude Haiku 3.5 | $0.80/M | $4/M | $1/M | $0.08/M |

*Sonnet 4/4.5 is tiered: higher rates after 200K tokens. Opus 4.5 uses the newer $5/$25 pricing.*

## Project structure

```
CCBuddy/
├── CCBuddyApp.swift              # App entry + AppDelegate
├── Models/                       # ClaudeMessage, UsageStats, ModelPricing
├── Services/                     # JSONLParser, UsageCalculator, FileWatcher
├── ViewModels/                   # UsageViewModel
├── Views/                        # PopoverView, SettingsView
└── Utilities/                    # Constants, extensions
```

## Roadmap
- Usage alerts at thresholds (50/75/90%)
- Launch at login
- History export
- Keyboard shortcuts
- Sparkle auto-update

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Built with SwiftUI and AppKit
- Uses Claude Code's local JSONL format
- Pricing data from [Anthropic's official pricing](https://www.anthropic.com/pricing)

## Related Projects

- [ccusage (CLI)](https://github.com/ryoppippi/ccusage) - CLI tool for usage analysis
- [Claude Code](https://claude.ai/claude-code) - Anthropic's AI coding assistant
