# CCBuddy - Claude Code Usage Monitor

A native macOS menu bar app to monitor your Claude Code usage in real-time.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Real-time Monitoring**: Track your Claude Code token usage in real-time
- **Dual Mode Support**:
  - **Pro/Max Plan**: 5-hour rolling window with usage percentage and time remaining
  - **API Mode**: Pay-as-you-go with daily, weekly, monthly, and all-time cost tracking
- **Cost Tracking**: See estimated costs and projected spending
- **Multi-Model Display**: Shows all Claude models used (Opus 4.5, Sonnet 4, Haiku, etc.)
- **Glass UI Design**: Beautiful translucent interface with customizable transparency
- **Menu Bar Integration**: Quick access from your macOS menu bar
- **Auto Refresh**: Configurable refresh intervals (1s, 5s, 10s, 30s, 1min, 5min)
- **File Watching**: Detects changes to Claude Code logs instantly
- **Customizable Font Size**: Small, Medium, or Large text options
- **Privacy First**: All data stays local, no network requests

## Screenshots

### Pro/Max Mode
```
┌────────────────────────────────────────┐
│ ▊▊▊  CCBuddy   Pro              10s   │
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
│  ↻ Refresh   ⚙ Settings   ⏻ Quit      │
└────────────────────────────────────────┘
```

### API Mode
```
┌────────────────────────────────────────┐
│ ▊▊▊  CCBuddy   API              10s   │
├────────────────────────────────────────┤
│  📄 Tokens Used              55.5M     │
│  🕐 Today                   $74.04     │
│  📅 This Week              $243.27     │
│  📆 This Month             $243.27     │
│  💵 All Time               $549.12     │
│  💻 Model           Claude Opus 4.5    │
│                     Claude Sonnet 4    │
├────────────────────────────────────────┤
│  ↻ Refresh   ⚙ Settings   ⏻ Quit      │
└────────────────────────────────────────┘
```

## Requirements

- macOS 14.0 (Sonoma) or later
- Claude Code installed and configured
- Swift 5.9+ (for building from source)

## Installation

### Build from Source

1. Clone the repository:
```bash
git clone https://github.com/anthropics/ccbuddy-app.git
cd ccbuddy-app
```

2. Build with Swift Package Manager:
```bash
swift build -c release
```

3. Run the app:
```bash
swift run
```

Or copy the built binary to your Applications folder.

## How It Works

CCBuddy reads Claude Code's local JSONL log files located at:
```
~/.claude/projects/
```

Each session is stored as a JSONL file containing message history with token usage information:

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

## Configuration

Access settings from the popover menu → Settings:

### General
- **Usage Mode**: Pro/Max Plan or API (Pay-as-you-go)
- **Launch at Login**: Start automatically when you log in
- **Refresh Interval**: 10s / 30s / 1min / 5min / Manual
- **Menu Bar Display**: Percentage / Tokens / Cost / Icon only

### Appearance
- **Glass Transparency**: 0-100% transparency level
- **Material Style**: Ultra Thin / Thin / Regular / Thick / Ultra Thick
- **Font Size**: Small / Medium / Large

### Notifications
- **Enable Alerts**: Get notified at usage thresholds
- **Alert Threshold**: 50% / 75% / 90%

## Token Pricing

CCBuddy uses the official Anthropic pricing (as of December 2024):

| Model | Input | Output | Cache Write | Cache Read |
|-------|-------|--------|-------------|------------|
| Claude Opus 4.5 | $5/M | $25/M | $6.25/M | $0.50/M |
| Claude Opus 4 | $15/M | $75/M | $18.75/M | $1.50/M |
| Claude Sonnet 4/4.5 | $3/M | $15/M | $3.75/M | $0.30/M |
| Claude Haiku 4.5 | $1/M | $5/M | $1.25/M | $0.10/M |
| Claude Haiku 3.5 | $0.80/M | $4/M | $1/M | $0.08/M |

*Note: Sonnet 4/4.5 has tiered pricing - higher rates apply after 200K tokens.*

## Project Structure

```
CCBuddy/
├── CCBuddyApp.swift              # App entry point & AppDelegate
├── Models/
│   ├── ClaudeMessage.swift       # JSONL message parsing
│   ├── UsageStats.swift          # Usage statistics
│   └── ModelPricing.swift        # Token pricing calculations
├── Services/
│   ├── JSONLParser.swift         # File parser
│   ├── UsageCalculator.swift     # Statistics calculator
│   └── FileWatcher.swift         # File change detection
├── ViewModels/
│   └── UsageViewModel.swift      # Main view model & settings
├── Views/
│   ├── PopoverView.swift         # Main popover UI
│   └── SettingsView.swift        # Settings panel
└── Utilities/
    ├── Constants.swift           # App constants
    └── Extensions.swift          # Swift extensions
```

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
