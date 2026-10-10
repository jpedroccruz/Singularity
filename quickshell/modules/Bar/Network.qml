import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root

  property color iconColor: "#FFA376"
  property color mutedColor: "#765B50"
  property color panelColor: "#17100B"
  property color selectorColor: "#2A1D18"
  property color menuColor: "#211711"
  property color borderColor: "#493025"

  // ---------- estado ----------

  property string device: ""
  property string wifiDevice: ""
  property string linkType: ""          // "wifi" | "ethernet" | ""
  property bool wifiEnabled: true

  property string ssid: ""
  property int signalPct: 0
  property int freqMhz: 0
  property string connName: ""
  property string gateway: ""
  property string ipAddress: ""

  property string dnsProvider: "dhcp"   // dhcp | cloudflare | google | custom
  property string customDns: ""
  property bool bandAuto: true

  property real rxBytes: 0
  property real txBytes: 0
  property real rxRate: 0
  property real txRate: 0
  property double lastTime: 0

  property string pingText: "--"
  property string lossText: "--"

  property var networks: []

  property string notice: ""
  property string phrase: "ORDENANDO QUADROS"

  property string connectingSsid: ""
  property string passwordSsid: ""
  property string connectError: ""
  property string connectErrorSsid: ""
  property bool customDnsEditing: false
  property bool qrVisible: false
  property bool reopening: false

  // teste de velocidade
  property bool speedOpen: false
  property string speedPhase: "idle"    // idle | starting | download | upload | done | error
  property real dlLive: 0
  property real ulLive: 0
  property real dlFinal: 0
  property real ulFinal: 0
  property var meter: ({ n: 0, bytes: 0, ns: 0 })
  property string speedError: ""
  property double phaseStart: 0
  property real phaseProgress: 0
  readonly property int speedDuration: 10   // segundos por fase

  // Fonte dos números do teste de velocidade. Qualquer fonte instalada
  // funciona; as condensadas ("Oswald", "Barlow Condensed") ficam parecidas
  // com os testes clássicos.
  property string numberFont: "Rubik"

  // evita que o polling sobrescreva uma mudança que acabou de ser feita
  property double holdUntil: 0

  readonly property bool connected: ipAddress !== ""
  readonly property bool isWifi: linkType === "wifi"
  readonly property bool inputActive: passwordSsid !== "" || customDnsEditing

  readonly property var phrases: [
    "ORDERING FRAMES",
    "STACKING PACKETS",
    "TUNING SIGNALS",
    "ROUTING BITS",
    "HUNTING FREQUENCIES",
    "WAVING TO THE ROUTER"
  ]

  readonly property var knownList: networks.filter(n => n.known)
  readonly property var otherList: networks.filter(n => !n.known)

  readonly property string title: {
    if (!connected) return "Desconectado"
    if (isWifi) return ssid || connName || "Wi-Fi"
    return connName || "Ethernet"
  }

  // ---------- helpers ----------

  function signalSymbol(pct) {
    if (pct > 60) return "wifi"
    if (pct > 30) return "wifi_2_bar"
    return "wifi_1_bar"
  }

  function networkSymbol() {
    if (connected && linkType === "ethernet") return "lan"
    if (!wifiEnabled || !connected) return "wifi_off"
    return signalSymbol(signalPct)
  }

  function bandLabel(f) {
    if (!f) return "--"
    if (f < 3000) return "2.4GHZ"
    if (f < 5925) return "5GHZ"
    return "6GHZ"
  }

  function formatRate(b) {
    const mb = b / 1048576
    if (mb >= 1) return mb.toFixed(1) + " MB/s"
    return (b / 1024).toFixed(1) + " KB/s"
  }

  function formatBytes(b) {
    const gb = b / 1073741824
    if (gb >= 1) return gb.toFixed(2) + " GB"
    const mb = b / 1048576
    if (mb >= 1) return mb.toFixed(1) + " MB"
    return (b / 1024).toFixed(0) + " KB"
  }

  function speedStatus() {
    if (speedPhase === "starting") return "PREPARANDO..."
    if (speedPhase === "download") return "TESTANDO DOWNLOAD..."
    if (speedPhase === "upload") return "TESTANDO UPLOAD..."
    if (speedPhase === "done") return "TESTE CONCLUÍDO"
    if (speedPhase === "error")
      return speedError !== "" ? "FALHA NO TESTE (" + speedError + ")" : "FALHA NO TESTE"
    return "PRONTO"
  }

  // ---------- parsing ----------

  function parseStatus(text) {
    const kv = {}

    for (const line of text.split("\n")) {
      const i = line.indexOf("=")
      if (i > 0) kv[line.slice(0, i)] = line.slice(i + 1).trim()
    }

    const dev = kv.dev || ""
    const rx = parseFloat(kv.rx) || 0
    const tx = parseFloat(kv.tx) || 0
    const now = Date.now()

    if (dev !== "" && dev === root.device
        && root.lastTime > 0 && rx >= root.rxBytes && tx >= root.txBytes) {
      const dt = (now - root.lastTime) / 1000

      if (dt > 0) {
        root.rxRate = (rx - root.rxBytes) / dt
        root.txRate = (tx - root.txBytes) / dt
      }
    } else {
      root.rxRate = 0
      root.txRate = 0
    }

    root.lastTime = now
    root.rxBytes = rx
    root.txBytes = tx

    root.device = dev
    root.wifiDevice = kv.wdev || ""
    root.linkType = kv.type === "wifi" ? "wifi"
      : kv.type === "ethernet" ? "ethernet" : ""
    root.gateway = kv.gw || ""
    root.ipAddress = kv.ip || ""
    root.connName = kv.conn && kv.conn !== "--" ? kv.conn : ""

    if (kv.active) {
      const p = kv.active.split(":")
      root.signalPct = parseInt(p[1]) || 0
      root.freqMhz = parseInt(p[2]) || 0
      root.ssid = p.slice(3).join(":").replace(/\\:/g, ":")
    } else {
      root.signalPct = 0
      root.freqMhz = 0
      root.ssid = ""
    }

    if (now < root.holdUntil) return

    root.wifiEnabled = kv.radio !== "disabled"

    const dns = kv.dns || ""

    if (dns === "") root.dnsProvider = "dhcp"
    else if (dns.indexOf("1.1.1.1") >= 0) root.dnsProvider = "cloudflare"
    else if (dns.indexOf("8.8.8.8") >= 0) root.dnsProvider = "google"
    else root.dnsProvider = "custom"

    root.customDns = root.dnsProvider === "custom"
      ? dns.replace(/,/g, " ") : ""

    root.bandAuto = (kv.band || "") === ""
  }

  function parsePing(text) {
    const loss = text.match(/(\d+(?:\.\d+)?)% packet loss/)
    const rtt = text.match(/=\s*[\d.]+\/([\d.]+)\//)

    root.pingText = rtt ? Math.round(parseFloat(rtt[1])) + " ms" : "--"
    root.lossText = loss ? Math.round(parseFloat(loss[1])) + "%" : "--"
  }

  function parseList(text) {
    const parts = text.split("---KNOWN---")
    const scan = parts[0] || ""
    const saved = parts[1] || ""

    const known = {}

    for (const line of saved.split("\n")) {
      if (!line.endsWith(":802-11-wireless")) continue

      const name = line
        .slice(0, line.length - ":802-11-wireless".length)
        .replace(/\\:/g, ":")

      known[name] = true
    }

    const best = {}

    for (const line of scan.split("\n")) {
      if (!line.trim()) continue

      const p = line.split(":")
      const ssid = p.slice(3).join(":").replace(/\\:/g, ":")

      if (!ssid) continue

      const entry = {
        ssid: ssid,
        signal: parseInt(p[1]) || 0,
        secure: !!p[2] && p[2] !== "--",
        inUse: p[0] === "*",
        known: !!known[ssid]
      }

      const old = best[ssid]

      if (!old || entry.inUse || (!old.inUse && entry.signal > old.signal))
        best[ssid] = entry
    }

    const list = Object.keys(best).map(k => best[k])

    list.sort((a, b) => {
      if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
      return b.signal - a.signal
    })

    root.networks = list
  }

  // ---------- ações ----------

  function refreshStatus() {
    if (!statusProcess.running)
      statusProcess.running = true
  }

  function refreshPing() {
    if (!pingProcess.running && root.connected)
      pingProcess.running = true
  }

  function refreshList() {
    if (root.wifiDevice === "" || !root.wifiEnabled) return
    if (listProcess.running) return

    listProcess.command = [
      "sh", "-c", listScript, "sh", root.wifiDevice
    ]
    listProcess.running = true
  }

  function refreshAll() {
    refreshStatus()
    refreshPing()
    refreshList()
  }

  function runAction(cmd) {
    root.holdUntil = Date.now() + 2500

    actionProcess.command = cmd
    actionProcess.running = true
  }

  function toggleWifi() {
    root.wifiEnabled = !root.wifiEnabled
    runAction(["nmcli", "radio", "wifi", root.wifiEnabled ? "on" : "off"])

    if (!root.wifiEnabled)
      root.networks = []
  }

  function toggleBand() {
    if (!root.isWifi || root.connName === "") return

    const lockBand = root.freqMhz > 0 && root.freqMhz < 3000 ? "bg" : "a"
    const band = root.bandAuto ? lockBand : ""

    root.bandAuto = !root.bandAuto

    runAction([
      "sh", "-c",
      "nmcli connection modify \"$1\" 802-11-wireless.band \"$2\" "
        + "&& nmcli connection up \"$1\"",
      "sh", root.connName, band
    ])
  }

  function applyDns(provider, custom) {
    if (root.connName === "") return

    let dns = ""
    let ignoreAuto = "no"

    if (provider === "cloudflare") {
      dns = "1.1.1.1 1.0.0.1"
      ignoreAuto = "yes"
    } else if (provider === "google") {
      dns = "8.8.8.8 8.8.4.4"
      ignoreAuto = "yes"
    } else if (provider === "custom") {
      dns = custom
      ignoreAuto = "yes"
    }

    root.dnsProvider = provider
    root.customDns = provider === "custom" ? custom : ""

    runAction([
      "sh", "-c",
      "nmcli connection modify \"$1\" ipv4.dns \"$2\" ipv4.ignore-auto-dns \"$3\" "
        + "&& nmcli device reapply \"$4\"",
      "sh", root.connName, dns, ignoreAuto, root.device
    ])
  }

  function pickDns(provider) {
    if (provider === "custom") {
      root.customDnsEditing = true
      beginInput()
      return
    }

    root.customDnsEditing = false
    applyDns(provider, "")
  }

  function connectTo(ssid, password) {
    if (root.wifiDevice === "") return

    root.connectingSsid = ssid
    root.connectError = ""
    root.connectErrorSsid = ""

    connectProcess.ssid = ssid

    const cmd = ["nmcli", "device", "wifi", "connect", ssid]

    if (password !== "") {
      cmd.push("password")
      cmd.push(password)
    }

    cmd.push("ifname")
    cmd.push(root.wifiDevice)

    connectProcess.command = cmd
    connectProcess.running = true
  }

  function askPassword(ssid) {
    root.passwordSsid = ssid
    beginInput()
  }

  function cancelInput() {
    root.passwordSsid = ""
    root.customDnsEditing = false
  }

  // grabFocus só vale quando a janela é mostrada, então reabre o popup
  // para que os campos de texto recebam o teclado.
  function beginInput() {
    root.reopening = true
    popup.visible = false

    Qt.callLater(function() {
      popup.visible = true
      root.reopening = false
    })
  }

  function toggleQr() {
    if (root.qrVisible) {
      hideQr()
      return
    }

    if (!root.isWifi || qrProcess.running) return

    qrProcess.command = [
      "sh", "-c", qrScript, "sh", root.connName, root.ssid
    ]
    qrProcess.running = true
  }

  function hideQr() {
    root.qrVisible = false
    cleanupProcess.running = true
  }

  function showNotice(text, seconds) {
    root.notice = text
    noticeTimer.interval = seconds * 1000
    noticeTimer.restart()
  }

  // ---------- teste de velocidade ----------

  function openSpeedTest() {
    if (!root.connected) {
      root.showNotice("SEM CONEXÃO", 4)
      return
    }

    root.refreshPing()
    popup.visible = false

    root.speedOpen = true
    root.startSpeedTest()
  }

  function closeSpeedTest() {
    root.speedOpen = false

    if (speedProcess.running)
      speedProcess.running = false

    root.speedPhase = "idle"
  }

  function startSpeedTest() {
    if (speedProcess.running) return

    root.dlLive = 0
    root.ulLive = 0
    root.dlFinal = 0
    root.ulFinal = 0
    root.meter = { n: 0, bytes: 0, ns: 0 }
    root.phaseProgress = 0
    root.speedError = ""
    root.speedPhase = "starting"

    speedProcess.command = [
      "sh", "-c", speedScript, "sh", root.device, String(root.speedDuration)
    ]
    speedProcess.running = true
  }

  function meterAverage(fallback) {
    if (root.meter.ns > 0)
      return root.meter.bytes * 8000 / root.meter.ns

    return fallback
  }

  function onSpeedSample(kind, bytes, ns) {
    if (ns <= 0) return

    const inst = bytes * 8000 / ns   // Mbps

    const m = root.meter
    m.n += 1

    // ignora ~1,5 s iniciais (rampa do TCP) na média final
    if (m.n > 6) {
      m.bytes += bytes
      m.ns += ns
    }

    // média móvel: o ponteiro sobe e oscila como nos testes clássicos
    if (kind === "D")
      root.dlLive = root.dlLive * 0.6 + inst * 0.4
    else
      root.ulLive = root.ulLive * 0.6 + inst * 0.4
  }

  function onSpeedLine(line) {
    const p = line.trim().split(" ")

    if (p[0] === "PHASE_D") {
      root.meter = { n: 0, bytes: 0, ns: 0 }
      root.phaseStart = Date.now()
      root.phaseProgress = 0
      root.speedPhase = "download"
    } else if (p[0] === "D" || p[0] === "U") {
      root.onSpeedSample(p[0], parseFloat(p[1]), parseFloat(p[2]))
    } else if (p[0] === "PHASE_U") {
      root.dlFinal = root.meterAverage(root.dlLive)
      root.dlLive = root.dlFinal
      root.meter = { n: 0, bytes: 0, ns: 0 }
      root.phaseStart = Date.now()
      root.phaseProgress = 0
      root.speedPhase = "upload"
    } else if (p[0] === "DONE") {
      root.ulFinal = root.meterAverage(root.ulLive)
      root.ulLive = root.ulFinal
      root.speedPhase = "done"
    } else if (p[0] === "ERR") {
      root.speedError = p[1] ? "HTTP " + p[1] : ""
      root.speedPhase = "error"
    }
  }

  // ---------- scripts ----------

  readonly property string statusScript: `
dev=""
for d in $(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}'); do
  t=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: -v d="$d" '$1==d{print $2; exit}')
  if [ "$t" = wifi ] || [ "$t" = ethernet ]; then dev="$d"; break; fi
done
wdev=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')
[ -z "$dev" ] && dev="$wdev"
echo "dev=$dev"
echo "wdev=$wdev"
echo "radio=$(nmcli radio wifi 2>/dev/null)"
if [ -n "$dev" ]; then
  echo "type=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: -v d="$dev" '$1==d{print $2; exit}')"
  echo "gw=$(ip route show default dev "$dev" 2>/dev/null | awk '{print $3; exit}')"
  echo "ip=$(ip -4 -o addr show dev "$dev" 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}')"
  echo "rx=$(cat /sys/class/net/$dev/statistics/rx_bytes 2>/dev/null)"
  echo "tx=$(cat /sys/class/net/$dev/statistics/tx_bytes 2>/dev/null)"
  conn=$(nmcli -g GENERAL.CONNECTION device show "$dev" 2>/dev/null)
  echo "conn=$conn"
  if [ -n "$conn" ] && [ "$conn" != "--" ]; then
    echo "dns=$(nmcli -g ipv4.dns connection show "$conn" 2>/dev/null)"
    echo "band=$(nmcli -g 802-11-wireless.band connection show "$conn" 2>/dev/null)"
  fi
  nmcli -t -f ACTIVE,SIGNAL,FREQ,SSID device wifi list ifname "$dev" 2>/dev/null | awk -F: '$1=="yes"{print "active=" $0; exit}'
fi
`

  readonly property string listScript: `
nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list ifname "$1" 2>/dev/null
echo "---KNOWN---"
nmcli -t -f NAME,TYPE connection show 2>/dev/null
`

  readonly property string qrScript: `
umask 077
conn="$1"
ssid="$2"
command -v qrencode >/dev/null || exit 2
pw=$(nmcli -s -g 802-11-wireless-security.psk connection show "$conn" 2>/dev/null)
esc() { printf '%s' "$1" | sed 's/[\\\\;,:"]/\\\\&/g'; }
if [ -n "$pw" ]; then
  data="WIFI:T:WPA;S:$(esc "$ssid");P:$(esc "$pw");;"
else
  data="WIFI:T:nopass;S:$(esc "$ssid");;"
fi
rm -f /tmp/qs-wifi-qr.png
qrencode -s 6 -m 2 -o /tmp/qs-wifi-qr.png "$data"
`

  // Mede a vazão lendo os contadores da interface a cada ~250 ms
  // enquanto 4 conexões paralelas baixam / enviam dados (Cloudflare).
  // Saída: PHASE_D, "D bytes ns", PHASE_U, "U bytes ns", DONE.
  readonly property string speedScript: `
dev="$1"
dur="$2"
[ -z "$dur" ] && dur=10
rxf="/sys/class/net/$dev/statistics/rx_bytes"
txf="/sys/class/net/$dev/statistics/tx_bytes"
[ -n "$dev" ] && [ -r "$rxf" ] || { echo ERR; exit 1; }

# teste prévio: confirma que o servidor responde antes de medir
code=$(curl -s -o /dev/null --connect-timeout 5 --max-time 3 -w "%{http_code}" "https://speed.cloudflare.com/__down?bytes=200000000")
[ "$code" = 200 ] || { echo "ERR $code"; exit 1; }

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
head -c 25000000 /dev/zero > "$tmp"

measure() {
  prev=$(cat "$1")
  pt=$(date +%s%N)
  end=$((pt + dur * 1000000000))
  while [ "$(date +%s%N)" -lt "$end" ]; do
    sleep 0.25
    cur=$(cat "$1")
    ct=$(date +%s%N)
    echo "$2 $((cur - prev)) $((ct - pt))"
    prev=$cur
    pt=$ct
  done
}

echo PHASE_D
for k in 1 2 3 4 5 6; do
  timeout "$dur" sh -c 'while :; do curl -sf -o /dev/null --connect-timeout 5 --max-time 20 "https://speed.cloudflare.com/__down?bytes=200000000" || sleep 1; done' &
done
measure "$rxf" D
wait

echo PHASE_U
for k in 1 2 3 4 5 6; do
  timeout "$dur" sh -c 'while :; do curl -sf -o /dev/null --connect-timeout 5 --max-time 20 -X POST --data-binary @"$0" "https://speed.cloudflare.com/__up" || sleep 1; done' "$tmp" &
done
measure "$txf" U
wait

echo DONE
`

  implicitWidth: indicator.implicitWidth + 18
  implicitHeight: 30
  color: "transparent"

  Component.onCompleted: refreshStatus()

  // ---------- medidor (ponteiro) ----------
  //
  // Escala não linear, igual aos testes clássicos:
  // 0 · 5 · 10 · 50 · 100 · 250 · 500 · 750 · 1000 Mbps,
  // com os rótulos igualmente espaçados em um arco de 270°.

  component SpeedGauge: Item {
    id: gauge

    property real value: 0
    property bool active: false
    property string iconName: "arrow_circle_down"
    property string numberFont: "Rubik"
    property color accent: "#FFA376"
    property color accentDark: "#765B50"
    property color trackColor: "#2A1D18"
    property color dimColor: "#765B50"

    readonly property var marks: [0, 5, 10, 50, 100, 250, 500, 750, 1000]
    readonly property real startAngle: Math.PI * 0.75
    readonly property real totalAngle: Math.PI * 1.5
    readonly property real gaugeRadius: Math.min(width, height) / 2 - 2
    readonly property color numberColor: Qt.lighter(accent, 1.5)
    readonly property real numSize: Math.max(30, gaugeRadius * 0.28)

    property real animated: value
    readonly property string numStr: animated.toFixed(2)

    Behavior on animated {
      NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    opacity: (active || value > 0) ? 1 : 0.5

    Behavior on opacity {
      NumberAnimation { duration: 200 }
    }

    onAnimatedChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    function fraction(v) {
      const n = marks.length - 1

      if (v <= 0) return 0
      if (v >= marks[n]) return 1

      for (let i = 0; i < n; i++) {
        if (v <= marks[i + 1])
          return (i + (v - marks[i]) / (marks[i + 1] - marks[i])) / n
      }

      return 1
    }

    function css(c, a) {
      return "rgba(" + Math.round(c.r * 255) + ","
        + Math.round(c.g * 255) + ","
        + Math.round(c.b * 255) + "," + a + ")"
    }

    Canvas {
      id: canvas
      anchors.fill: parent

      onPaint: {
        const ctx = getContext("2d")
        ctx.reset()

        const R = gauge.gaugeRadius
        const cx = width / 2
        const cy = height / 2
        const lw = R * 0.15
        const r = R - lw / 2
        const start = gauge.startAngle
        const total = gauge.totalAngle
        const f = gauge.fraction(gauge.animated)

        // trilho
        ctx.beginPath()
        ctx.arc(cx, cy, r, start, start + total, false)
        ctx.lineWidth = lw
        ctx.lineCap = "butt"
        ctx.strokeStyle = gauge.css(gauge.trackColor, 1)
        ctx.stroke()

        // marcas da escala (a cada rótulo + 3 intermediárias)
        const steps = 32

        for (let i = 0; i <= steps; i++) {
          const ang = start + total * i / steps
          const major = i % 4 === 0
          const r1 = R * 0.80
          const r2 = R * (major ? 0.73 : 0.77)
          const lit = f >= i / steps - 0.0001

          ctx.beginPath()
          ctx.moveTo(cx + Math.cos(ang) * r1, cy + Math.sin(ang) * r1)
          ctx.lineTo(cx + Math.cos(ang) * r2, cy + Math.sin(ang) * r2)
          ctx.lineWidth = major ? 2 : 1
          ctx.strokeStyle = lit
            ? gauge.css(gauge.accent, major ? 0.95 : 0.55)
            : gauge.css(gauge.dimColor, major ? 0.85 : 0.4)
          ctx.stroke()
        }

        if (f > 0.002) {
          // brilho suave dentro do arco, como nos testes clássicos
          const rg = ctx.createRadialGradient(cx, cy, 0, cx, cy, r - lw / 2)
          rg.addColorStop(0, gauge.css(gauge.accent, 0))
          rg.addColorStop(1, gauge.css(gauge.accent, 0.14))

          ctx.beginPath()
          ctx.moveTo(cx, cy)
          ctx.arc(cx, cy, r - lw / 2, start, start + total * f, false)
          ctx.closePath()
          ctx.fillStyle = rg
          ctx.fill()

          // arco preenchido com halo
          const grad = ctx.createLinearGradient(0, height, width, 0)
          grad.addColorStop(0, gauge.css(gauge.accentDark, 1))
          grad.addColorStop(1, gauge.css(gauge.accent, 1))

          ctx.shadowColor = gauge.css(gauge.accent, 0.55)
          ctx.shadowBlur = 18

          ctx.beginPath()
          ctx.arc(cx, cy, r, start, start + total * f, false)
          ctx.lineWidth = lw
          ctx.strokeStyle = grad
          ctx.stroke()

          ctx.shadowBlur = 0
          ctx.shadowColor = "rgba(0,0,0,0)"
        }

        // ponteiro: leque que some perto do centro
        const needle = gauge.numberColor
        const a = start + total * f

        ctx.save()
        ctx.translate(cx, cy)
        ctx.rotate(a)

        const ng = ctx.createLinearGradient(R * 0.06, 0, R * 0.58, 0)
        ng.addColorStop(0, gauge.css(needle, 0))
        ng.addColorStop(1, gauge.css(needle, 1))

        ctx.beginPath()
        ctx.moveTo(R * 0.06, -1.5)
        ctx.lineTo(R * 0.58, -R * 0.028)
        ctx.lineTo(R * 0.58, R * 0.028)
        ctx.lineTo(R * 0.06, 1.5)
        ctx.closePath()
        ctx.fillStyle = ng
        ctx.fill()
        ctx.restore()

        // cubo do ponteiro
        ctx.beginPath()
        ctx.arc(cx, cy, R * 0.035, 0, Math.PI * 2, false)
        ctx.fillStyle = gauge.css(needle, 0.9)
        ctx.fill()

        ctx.beginPath()
        ctx.arc(cx, cy, R * 0.07, 0, Math.PI * 2, false)
        ctx.lineWidth = 1.5
        ctx.strokeStyle = gauge.css(gauge.accent, 0.35)
        ctx.stroke()
      }
    }

    // rótulos da escala
    Repeater {
      model: gauge.marks

      delegate: Text {
        readonly property real ang:
          gauge.startAngle + gauge.totalAngle * index / (gauge.marks.length - 1)

        x: gauge.width / 2 + Math.cos(ang) * gauge.gaugeRadius * 0.62 - width / 2
        y: gauge.height / 2 + Math.sin(ang) * gauge.gaugeRadius * 0.62 - height / 2

        text: modelData
        color: gauge.animated >= modelData ? gauge.accent : gauge.dimColor
        font.family: "Rubik"
        font.bold: true
        font.pixelSize: Math.max(11, gauge.gaugeRadius * 0.082)
      }
    }

    // Medidas de uma célula de dígito: cada caractere ocupa a mesma
    // largura, então o número não "dança" enquanto o valor muda.
    TextMetrics {
      id: digitMetrics
      font.family: gauge.numberFont
      font.weight: Font.Medium
      font.pixelSize: gauge.numSize
      text: "8"
    }

    TextMetrics {
      id: dotMetrics
      font.family: gauge.numberFont
      font.weight: Font.Medium
      font.pixelSize: gauge.numSize
      text: "."
    }

    Row {
      id: numberRow
      anchors.horizontalCenter: parent.horizontalCenter
      y: gauge.height / 2 + gauge.gaugeRadius * 0.50

      Repeater {
        model: gauge.numStr.length

        delegate: Item {
          readonly property string ch: gauge.numStr.charAt(index)

          width: ch === "." ? dotMetrics.advanceWidth : digitMetrics.advanceWidth
          height: digitMetrics.height

          Text {
            anchors.centerIn: parent
            text: parent.ch
            color: gauge.numberColor
            font.family: gauge.numberFont
            font.weight: Font.Medium
            font.pixelSize: gauge.numSize
          }
        }
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      y: numberRow.y + numberRow.height - 2
      spacing: 6

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: gauge.iconName
        color: gauge.accent
        font.family: "Material Symbols Rounded"
        font.pixelSize: Math.max(14, gauge.gaugeRadius * 0.085)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Mbps"
        color: gauge.dimColor
        font.family: "Rubik"
        font.pixelSize: Math.max(12, gauge.gaugeRadius * 0.07)
      }
    }
  }

  // ---------- processos ----------

  Process {
    id: statusProcess
    command: ["sh", "-c", root.statusScript]

    stdout: StdioCollector {
      onStreamFinished: root.parseStatus(this.text)
    }
  }

  Process {
    id: pingProcess
    command: ["ping", "-c", "4", "-i", "0.2", "-W", "1", "1.1.1.1"]

    stdout: StdioCollector {
      onStreamFinished: root.parsePing(this.text)
    }
  }

  Process {
    id: listProcess

    stdout: StdioCollector {
      onStreamFinished: root.parseList(this.text)
    }
  }

  Process {
    id: rescanProcess
    command: ["nmcli", "device", "wifi", "rescan"]

    onExited: root.refreshList()
  }

  Process {
    id: actionProcess

    onExited: refreshTimer.restart()
  }

  Process {
    id: connectProcess
    property string ssid: ""

    onExited: (exitCode, exitStatus) => {
      root.connectingSsid = ""

      if (exitCode !== 0) {
        root.connectError = "Falha ao conectar. Verifique a senha."
        root.connectErrorSsid = ssid
      } else {
        root.passwordSsid = ""
      }

      root.refreshAll()
    }
  }

  Process {
    id: speedProcess

    stdout: SplitParser {
      onRead: data => root.onSpeedLine(data)
    }

    onExited: (exitCode, exitStatus) => {
      if (root.speedOpen && root.speedPhase !== "done")
        root.speedPhase = "error"
    }
  }

  Process {
    id: qrProcess

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        qrImage.source = ""
        qrImage.source = "file:///tmp/qs-wifi-qr.png"
        root.qrVisible = true
      } else if (exitCode === 2) {
        root.showNotice("INSTALE O QRENCODE", 5)
      } else {
        root.showNotice("FALHA AO GERAR QR", 5)
      }
    }
  }

  Process {
    id: cleanupProcess
    command: ["rm", "-f", "/tmp/qs-wifi-qr.png"]
  }

  // ---------- timers ----------

  Timer {
    id: statusTimer
    interval: popup.visible ? 1500 : 5000
    running: true
    repeat: true
    onTriggered: root.refreshStatus()
  }

  Timer {
    id: pingTimer
    interval: 5000
    running: popup.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshPing()
  }

  Timer {
    id: listTimer
    interval: 6000
    running: popup.visible
    repeat: true
    onTriggered: root.refreshList()
  }

  Timer {
    id: refreshTimer
    interval: 400
    onTriggered: root.refreshAll()
  }

  Timer {
    id: phaseTimer
    interval: 100
    running: root.speedOpen
      && (root.speedPhase === "download" || root.speedPhase === "upload")
    repeat: true

    onTriggered: root.phaseProgress = Math.min(
      1, (Date.now() - root.phaseStart) / (root.speedDuration * 1000)
    )
  }

  Timer {
    id: noticeTimer
    onTriggered: root.notice = ""
  }

  Timer {
    id: closeTimer
    interval: 180

    onTriggered: {
      if (!mouseArea.containsMouse && !panelHover.hovered && !root.inputActive)
        popup.visible = false
    }
  }

  // ---------- indicador da barra ----------

  Text {
    id: indicator
    anchors.centerIn: parent
    text: root.networkSymbol()
    color: root.connected ? root.iconColor : root.mutedColor
    font.family: "Material Symbols Rounded"
    font.pixelSize: 18
  }

  Rectangle {
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: indicator.implicitWidth
    height: 2
    radius: height / 2
    color: root.iconColor
    visible: mouseArea.containsMouse
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onEntered: closeTimer.stop()

    onExited: closeTimer.restart()

    onClicked: popup.visible = !popup.visible
  }

  // ---------- janela do teste de velocidade ----------
  //
  // Para o blur, o compositor precisa de uma regra para o namespace
  // "speedtest" (veja o exemplo de Hyprland na mensagem).

  PanelWindow {
    id: overlay

    visible: root.speedOpen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "speedtest"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    readonly property real gaugeSize: Math.max(
      220, Math.min((width - 260) / 2, height * 0.5, 480)
    )

    onVisibleChanged: {
      if (visible) fadeIn.restart()
    }

    FocusScope {
      id: scope
      anchors.fill: parent
      focus: true

      Keys.onEscapePressed: root.closeSpeedTest()

      NumberAnimation {
        id: fadeIn
        target: scope
        property: "opacity"
        from: 0
        to: 1
        duration: 180
      }

      Rectangle {
        anchors.fill: parent
        color: Qt.alpha(root.panelColor, 0.55)
      }

      // impede cliques de passarem para as janelas de trás
      MouseArea {
        anchors.fill: parent
      }

      Rectangle {
        id: card
        anchors.centerIn: parent
        implicitWidth: cardContent.implicitWidth + 80
        implicitHeight: cardContent.implicitHeight + 72
        radius: 20
        color: Qt.alpha(root.panelColor, 0.84)
        border.width: 2
        border.color: root.iconColor

        ColumnLayout {
          id: cardContent
          anchors.fill: parent
          anchors.leftMargin: 40
          anchors.rightMargin: 40
          anchors.topMargin: 34
          anchors.bottomMargin: 34
          spacing: 26

          // cabeçalho
          RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
              implicitWidth: 46
              implicitHeight: 46
              radius: 10
              color: root.selectorColor
              border.width: 1
              border.color: root.borderColor

              Text {
                anchors.centerIn: parent
                text: "speed"
                color: root.iconColor
                font.family: "Material Symbols Rounded"
                font.pixelSize: 26
              }
            }

            ColumnLayout {
              spacing: 3

              Text {
                text: "Teste de velocidade"
                color: root.iconColor
                font.family: "Rubik"
                font.pixelSize: 22
                font.bold: true
              }

              RowLayout {
                spacing: 8

                Rectangle {
                  id: statusDot
                  implicitWidth: 8
                  implicitHeight: 8
                  radius: 4
                  color: root.speedPhase === "error"
                    ? root.mutedColor : root.iconColor

                  SequentialAnimation on opacity {
                    running: speedProcess.running
                    loops: Animation.Infinite

                    NumberAnimation { to: 0.25; duration: 600 }
                    NumberAnimation { to: 1; duration: 600 }

                    onRunningChanged: {
                      if (!running) statusDot.opacity = 1
                    }
                  }
                }

                Text {
                  text: root.speedStatus()
                  color: root.mutedColor
                  font.family: "Rubik"
                  font.pixelSize: 12
                  font.letterSpacing: 1.5
                }
              }
            }

            Item {
              Layout.fillWidth: true
            }

            Rectangle {
              implicitWidth: 42
              implicitHeight: 42
              radius: 8
              color: root.selectorColor
              border.width: 1
              border.color: closeMouse.containsMouse
                ? root.iconColor : root.borderColor

              Text {
                anchors.centerIn: parent
                text: "close"
                color: root.iconColor
                font.family: "Material Symbols Rounded"
                font.pixelSize: 22
              }

              MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeSpeedTest()
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: root.borderColor
          }

          // medidores
          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 56

            ColumnLayout {
              spacing: 10

              RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Text {
                  text: "arrow_downward"
                  color: root.speedPhase === "download"
                    ? root.iconColor : root.mutedColor
                  font.family: "Material Symbols Rounded"
                  font.pixelSize: 20
                }

                Text {
                  text: "Download"
                  color: root.speedPhase === "download"
                    ? root.iconColor : root.mutedColor
                  font.family: "Rubik"
                  font.pixelSize: 17
                  font.bold: true
                }
              }

              Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: overlay.gaugeSize * 0.7
                implicitHeight: 4
                radius: 2
                color: root.selectorColor

                Rectangle {
                  height: parent.height
                  radius: 2
                  color: root.iconColor
                  width: parent.width * (
                    root.speedPhase === "download" ? root.phaseProgress
                    : (root.speedPhase === "upload"
                       || root.speedPhase === "done") ? 1 : 0
                  )
                }
              }

              SpeedGauge {
                Layout.preferredWidth: overlay.gaugeSize
                Layout.preferredHeight: overlay.gaugeSize
                value: root.dlLive
                active: root.speedPhase === "download"
                iconName: "arrow_circle_down"
                numberFont: root.numberFont
                accent: root.iconColor
                accentDark: root.mutedColor
                trackColor: root.selectorColor
                dimColor: root.mutedColor
              }
            }

            ColumnLayout {
              spacing: 10

              RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Text {
                  text: "arrow_upward"
                  color: root.speedPhase === "upload"
                    ? root.iconColor : root.mutedColor
                  font.family: "Material Symbols Rounded"
                  font.pixelSize: 20
                }

                Text {
                  text: "Upload"
                  color: root.speedPhase === "upload"
                    ? root.iconColor : root.mutedColor
                  font.family: "Rubik"
                  font.pixelSize: 17
                  font.bold: true
                }
              }

              Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: overlay.gaugeSize * 0.7
                implicitHeight: 4
                radius: 2
                color: root.selectorColor

                Rectangle {
                  height: parent.height
                  radius: 2
                  color: root.iconColor
                  width: parent.width * (
                    root.speedPhase === "upload" ? root.phaseProgress
                    : root.speedPhase === "done" ? 1 : 0
                  )
                }
              }

              SpeedGauge {
                Layout.preferredWidth: overlay.gaugeSize
                Layout.preferredHeight: overlay.gaugeSize
                value: root.ulLive
                active: root.speedPhase === "upload"
                iconName: "arrow_circle_up"
                numberFont: root.numberFont
                accent: root.iconColor
                accentDark: root.mutedColor
                trackColor: root.selectorColor
                dimColor: root.mutedColor
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: root.borderColor
          }

          // rodapé
          RowLayout {
            Layout.fillWidth: true
            spacing: 28

            ColumnLayout {
              spacing: 2

              Text {
                text: "PING"
                color: root.mutedColor
                font.family: "Rubik"
                font.pixelSize: 11
                font.letterSpacing: 1
              }

              Text {
                text: root.pingText
                color: root.iconColor
                font.family: root.numberFont
                font.weight: Font.Medium
                font.pixelSize: 20
              }
            }

            ColumnLayout {
              spacing: 2

              Text {
                text: "REDE"
                color: root.mutedColor
                font.family: "Rubik"
                font.pixelSize: 11
                font.letterSpacing: 1
              }

              Text {
                text: root.title
                color: root.iconColor
                font.family: "Rubik"
                font.pixelSize: 16
              }
            }

            ColumnLayout {
              spacing: 2

              Text {
                text: "SERVIDOR"
                color: root.mutedColor
                font.family: "Rubik"
                font.pixelSize: 11
                font.letterSpacing: 1
              }

              Text {
                text: "Cloudflare"
                color: root.iconColor
                font.family: "Rubik"
                font.pixelSize: 16
              }
            }

            Item {
              Layout.fillWidth: true
            }

            Rectangle {
              implicitWidth: 160
              implicitHeight: 44
              radius: 8
              color: speedProcess.running
                ? root.selectorColor
                : (againMouse.containsMouse ? Qt.lighter(root.iconColor, 1.12)
                                            : root.iconColor)
              border.width: 1
              border.color: speedProcess.running
                ? root.borderColor : root.iconColor

              RowLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                  text: speedProcess.running ? "hourglass_top" : "refresh"
                  color: speedProcess.running
                    ? root.iconColor : root.panelColor
                  font.family: "Material Symbols Rounded"
                  font.pixelSize: 20
                }

                Text {
                  text: speedProcess.running ? "Testando..." : "Refazer teste"
                  color: speedProcess.running
                    ? root.iconColor : root.panelColor
                  font.family: "Rubik"
                  font.pixelSize: 14
                  font.bold: true
                }
              }

              MouseArea {
                id: againMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !speedProcess.running
                cursorShape: Qt.PointingHandCursor
                onClicked: root.startSpeedTest()
              }
            }

            Rectangle {
              implicitWidth: 110
              implicitHeight: 44
              radius: 8
              color: closeBtnMouse.containsMouse
                ? root.borderColor : "transparent"
              border.width: 1
              border.color: root.borderColor

              Text {
                anchors.centerIn: parent
                text: "Fechar"
                color: root.iconColor
                font.family: "Rubik"
                font.pixelSize: 14
              }

              MouseArea {
                id: closeBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeSpeedTest()
              }
            }
          }
        }
      }
    }
  }

  // ---------- delegate das redes ----------

  Component {
    id: networkDelegate

    ColumnLayout {
      id: item
      Layout.fillWidth: true
      spacing: 4

      property bool asking: root.passwordSsid === modelData.ssid

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 46
        radius: 4

        color: modelData.inUse
          ? root.selectorColor
          : (rowMouse.containsMouse ? root.menuColor : "transparent")

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 14
          spacing: 12

          Text {
            text: root.signalSymbol(modelData.signal)
            color: root.iconColor
            font.family: "Material Symbols Rounded"
            font.pixelSize: 20
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              Layout.fillWidth: true
              text: modelData.ssid
              color: root.iconColor
              font.family: "Rubik"
              font.pixelSize: 14
              elide: Text.ElideRight
            }

            Text {
              visible: text !== ""
              text: root.connectingSsid === modelData.ssid
                ? "Conectando..."
                : (modelData.inUse ? "Conectado" : "")
              color: root.mutedColor
              font.family: "Rubik"
              font.pixelSize: 12
            }
          }

          Text {
            visible: modelData.secure
            text: "lock"
            color: root.mutedColor
            font.family: "Material Symbols Rounded"
            font.pixelSize: 18
          }
        }

        MouseArea {
          id: rowMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onClicked: {
            if (modelData.inUse) return

            root.connectError = ""

            if (modelData.known || !modelData.secure)
              root.connectTo(modelData.ssid, "")
            else
              root.askPassword(modelData.ssid)
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        visible: item.asking
        spacing: 8

        TextField {
          id: passwordField

          Layout.fillWidth: true
          implicitHeight: 38
          echoMode: TextInput.Password
          placeholderText: "Senha da rede"
          placeholderTextColor: root.mutedColor
          color: root.iconColor
          selectionColor: root.borderColor
          selectedTextColor: root.iconColor
          font.family: "Rubik"
          font.pixelSize: 13
          leftPadding: 12

          background: Rectangle {
            color: root.selectorColor
            radius: 6
            border.width: 1
            border.color: passwordField.activeFocus
              ? root.iconColor : root.borderColor
          }

          onVisibleChanged: if (visible) forceActiveFocus()
          Component.onCompleted: if (visible) forceActiveFocus()

          onAccepted: root.connectTo(modelData.ssid, text)
          Keys.onEscapePressed: root.cancelInput()
        }

        Rectangle {
          implicitWidth: 38
          implicitHeight: 38
          radius: 6
          color: root.selectorColor
          border.width: 1
          border.color: connectMouse.containsMouse
            ? root.iconColor : root.borderColor

          Text {
            anchors.centerIn: parent
            text: "arrow_forward"
            color: root.iconColor
            font.family: "Material Symbols Rounded"
            font.pixelSize: 20
          }

          MouseArea {
            id: connectMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.connectTo(modelData.ssid, passwordField.text)
          }
        }
      }

      Text {
        Layout.fillWidth: true
        visible: root.connectError !== ""
          && root.connectErrorSsid === modelData.ssid
        text: root.connectError
        color: root.iconColor
        font.family: "Rubik"
        font.pixelSize: 12
        leftPadding: 4
      }
    }
  }

  // ---------- popup ----------

  PopupWindow {
    id: popup

    anchor.item: root
    anchor.rect.x: root.width / 2 - implicitWidth / 2
    anchor.rect.y: root.height + 6

    implicitWidth: 390
    implicitHeight: panel.implicitHeight + 4

    visible: false
    color: "transparent"
    grabFocus: root.inputActive

    onVisibleChanged: {
      if (visible) {
        root.phrase = root.phrases[
          Math.floor(Math.random() * root.phrases.length)
        ]

        root.refreshStatus()

        if (root.wifiDevice !== "" && root.wifiEnabled)
          rescanProcess.running = true
      } else if (!root.reopening) {
        root.cancelInput()
        root.connectError = ""

        if (root.qrVisible)
          root.hideQr()
      }
    }

    Rectangle {
      id: panel
      anchors.fill: parent

      color: root.panelColor
      border.width: 2
      border.color: root.iconColor
      radius: 10

      implicitHeight: content.implicitHeight + 28

      HoverHandler {
        id: panelHover

        onHoveredChanged: {
          if (hovered)
            closeTimer.stop()
          else
            closeTimer.restart()
        }
      }

      ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 16

        // CABEÇALHO

        RowLayout {
          Layout.fillWidth: true
          spacing: 12

          Text {
            text: root.networkSymbol()
            color: root.connected ? root.iconColor : root.mutedColor
            font.family: "Material Symbols Rounded"
            font.pixelSize: 34
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              Layout.fillWidth: true
              text: root.title
              color: root.iconColor
              font.family: "Rubik"
              font.pixelSize: 17
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              Layout.fillWidth: true
              text: root.notice !== "" ? root.notice : root.phrase
              color: root.mutedColor
              font.family: "Rubik"
              font.pixelSize: 11
              font.letterSpacing: 1.5
              elide: Text.ElideRight
            }
          }

          // QR code
          Rectangle {
            visible: root.isWifi
            implicitWidth: 38
            implicitHeight: 38
            radius: 4
            color: root.qrVisible ? root.borderColor : root.selectorColor
            border.width: 1
            border.color: qrMouse.containsMouse
              ? root.iconColor : root.borderColor

            Text {
              anchors.centerIn: parent
              text: "qr_code_2"
              color: root.iconColor
              font.family: "Material Symbols Rounded"
              font.pixelSize: 22
            }

            MouseArea {
              id: qrMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleQr()
            }
          }

          // teste de velocidade (abre a janela em tela cheia)
          Rectangle {
            visible: root.connected
            implicitWidth: 38
            implicitHeight: 38
            radius: 4
            color: root.selectorColor
            border.width: 1
            border.color: speedMouse.containsMouse
              ? root.iconColor : root.borderColor

            Text {
              anchors.centerIn: parent
              text: "speed"
              color: root.iconColor
              font.family: "Material Symbols Rounded"
              font.pixelSize: 22
            }

            MouseArea {
              id: speedMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openSpeedTest()
            }
          }

          // liga/desliga Wi-Fi
          Rectangle {
            visible: root.wifiDevice !== ""
            implicitWidth: 46
            implicitHeight: 24
            radius: 4
            color: root.selectorColor
            border.width: 1
            border.color: root.borderColor

            Rectangle {
              width: 20
              height: 16
              radius: 3
              y: 4
              x: root.wifiEnabled ? parent.width - width - 4 : 4
              color: root.wifiEnabled ? root.iconColor : root.mutedColor

              Behavior on x {
                NumberAnimation { duration: 120 }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleWifi()
            }
          }
        }

        // QR CODE

        Rectangle {
          visible: root.qrVisible
          Layout.alignment: Qt.AlignHCenter
          implicitWidth: 196
          implicitHeight: 196
          radius: 8
          color: "#FFFFFF"

          Image {
            id: qrImage
            anchors.centerIn: parent
            width: 180
            height: 180
            fillMode: Image.PreserveAspectFit
            smooth: false
            cache: false
          }
        }

        // ESTATÍSTICAS

        GridLayout {
          Layout.fillWidth: true
          visible: root.connected
          columns: 4
          columnSpacing: 12
          rowSpacing: 6

          Text {
            text: "Ping"
            color: root.mutedColor
            font.family: "Rubik"
            font.pixelSize: 13
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: root.pingText
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 13
          }
          Text {
            text: "Loss"
            color: root.mutedColor
            font.family: "Rubik"
            font.pixelSize: 13
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: root.lossText
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 13
          }

          Text {
            text: "Receiving"
            color: root.mutedColor
            font.family: "Rubik"
            font.pixelSize: 13
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: root.formatRate(root.rxRate)
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 13
          }
          Text {
            text: "Sending"
            color: root.mutedColor
            font.family: "Rubik"
            font.pixelSize: 13
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: root.formatRate(root.txRate)
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 13
          }

          Text {
            text: "Download"
            color: root.mutedColor
            font.family: "Rubik"
            font.pixelSize: 13
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: root.formatBytes(root.rxBytes)
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 13
          }
          Text {
            text: "Upload"
            color: root.mutedColor
            font.family: "Rubik"
            font.pixelSize: 13
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: root.formatBytes(root.txBytes)
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 13
          }

          Text {
            text: "IP Address"
            color: root.mutedColor
            font.family: "Rubik"
            font.pixelSize: 13
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: root.ipAddress
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 13
          }
          Text {
            text: "Gateway"
            color: root.mutedColor
            font.family: "Rubik"
            font.pixelSize: 13
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: root.gateway || "--"
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 13
          }
        }

        Rectangle {
          Layout.fillWidth: true
          visible: root.isWifi
          height: 1
          color: root.borderColor
        }

        // BANDA WI-FI

        RowLayout {
          Layout.fillWidth: true
          visible: root.isWifi
          spacing: 10

          Text {
            Layout.fillWidth: true
            text: "WI-FI BAND: " + root.bandLabel(root.freqMhz)
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 12
            font.letterSpacing: 0.5
          }

          Text {
            text: "AUTOMATIC"
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 12
            font.letterSpacing: 0.5
          }

          Rectangle {
            implicitWidth: 38
            implicitHeight: 20
            radius: 4
            color: root.selectorColor
            border.width: 1
            border.color: root.borderColor

            Rectangle {
              width: 16
              height: 12
              radius: 3
              y: 4
              x: root.bandAuto ? parent.width - width - 4 : 4
              color: root.bandAuto ? root.iconColor : root.mutedColor

              Behavior on x {
                NumberAnimation { duration: 120 }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleBand()
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          visible: root.connected
          height: 1
          color: root.borderColor
        }

        // PROVEDOR DE DNS

        ColumnLayout {
          Layout.fillWidth: true
          visible: root.connected && root.connName !== ""
          spacing: 10

          Text {
            text: "DNS PROVIDER"
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 12
            font.letterSpacing: 0.5
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            uniformCellSizes: true

            Repeater {
              model: [
                { id: "dhcp", label: "DHCP" },
                { id: "cloudflare", label: "Cloudflare" },
                { id: "google", label: "Google" },
                { id: "custom", label: "Custom" }
              ]

              delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: 4

                property bool selected: root.dnsProvider === modelData.id

                color: selected
                  ? root.borderColor
                  : (dnsMouse.containsMouse ? root.menuColor : "transparent")
                border.width: 1
                border.color: selected ? root.iconColor : root.borderColor

                Text {
                  anchors.centerIn: parent
                  width: parent.width - 8
                  horizontalAlignment: Text.AlignHCenter
                  text: modelData.label
                  color: root.iconColor
                  font.family: "Rubik"
                  font.pixelSize: 13
                  elide: Text.ElideRight
                }

                MouseArea {
                  id: dnsMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.pickDns(modelData.id)
                }
              }
            }
          }

          TextField {
            id: customDnsField

            Layout.fillWidth: true
            implicitHeight: 38
            visible: root.customDnsEditing
            text: root.customDns
            placeholderText: "Ex.: 9.9.9.9 149.112.112.112"
            placeholderTextColor: root.mutedColor
            color: root.iconColor
            selectionColor: root.borderColor
            selectedTextColor: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 13
            leftPadding: 12

            background: Rectangle {
              color: root.selectorColor
              radius: 6
              border.width: 1
              border.color: customDnsField.activeFocus
                ? root.iconColor : root.borderColor
            }

            onVisibleChanged: if (visible) forceActiveFocus()

            onAccepted: {
              const value = text.trim().replace(/[,\s]+/g, " ")

              if (value !== "")
                root.applyDns("custom", value)

              root.customDnsEditing = false
            }

            Keys.onEscapePressed: root.cancelInput()
          }
        }

        // REDES

        Text {
          visible: root.wifiDevice !== "" && !root.wifiEnabled
          Layout.fillWidth: true
          text: "Wi-Fi Off"
          color: root.mutedColor
          font.family: "Rubik"
          font.pixelSize: 13
        }

        Flickable {
          id: netFlick

          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(netColumn.implicitHeight, 230)
          visible: root.wifiDevice !== "" && root.wifiEnabled
            && root.networks.length > 0

          contentWidth: width
          contentHeight: netColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          ScrollIndicator.vertical: ScrollIndicator {}

          ColumnLayout {
            id: netColumn
            width: netFlick.width
            spacing: 6

            Text {
              visible: root.knownList.length > 0
              text: "KNOWN NETWORKS"
              color: root.mutedColor
              font.family: "Rubik"
              font.pixelSize: 11
              font.letterSpacing: 0.5
            }

            Repeater {
              model: root.knownList
              delegate: networkDelegate
            }

            Text {
              visible: root.otherList.length > 0
              Layout.topMargin: 8
              text: "OTHER NETWORKS"
              color: root.mutedColor
              font.family: "Rubik"
              font.pixelSize: 11
              font.letterSpacing: 0.5
            }

            Repeater {
              model: root.otherList
              delegate: networkDelegate
            }
          }
        }
      }
    }
  }
}
