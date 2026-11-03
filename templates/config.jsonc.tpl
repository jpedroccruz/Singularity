{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "file",
    "source": "/usr/share/singularity/templates/singularity-logo.txt",
    "width": 40,
    "height": 20,
    "color": {
      "1": "{{ accent }}"
    },
    "padding": {
      "top": 1,
      "left": 2,
      "right": 3
    }
  },
  "display": {
    "separator": "  ",
    "color": {
      "keys": "{{ accent }}",
      "title": "{{ accent }}"
    },
    "key": {
      "type": "icon"
    },
    "percent": {
      "type": 3
    }
  },
  "modules": [
    "title",
    "break",
    "os",
    "kernel",
    "uptime",
    "packages",
    "shell",
    "break",
    {
      "type": "command",
      "key": "Theme",
      "text": "cat \"${XDG_STATE_HOME:-$HOME/.local/state}/singularity/current-theme\" 2>/dev/null | head -n1 | grep . || echo unknown"
    },
    "de",
    "wm",
    "theme",
    "icons",
    "cursor",
    "font",
    "terminal",
    "break",
    "cpu",
    "gpu",
    "memory",
    {
      "type": "disk",
      "folders": "/"
    },
    "battery"
  ]
}