// win-grid: reparte en partes iguales las ventanas (no flotantes) del monitor bajo el mouse,
// según dónde está cada una. 1 → pantalla, 2 → mitades, 3 → izquierda + dos apiladas a la
// derecha, 4 → cuadrícula 2×2 (cada una al cuarto más cercano). Con más de 4 no hace nada.
// Lo ejecuta skhd (Option+G) y usa su permiso de Accesibilidad.
import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ e: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

let gap: CGFloat = 10, margin: CGFloat = 8
let floating: Set<String> = ["com.apple.systempreferences", "com.apple.calculator", "com.apple.ActivityMonitor",
                             "com.apple.archiveutility", "com.apple.screencaptureui", "com.apple.SecurityAgent"]

struct W { let id: CGWindowID; let pid: pid_t; let r: CGRect }

// Monitor bajo el mouse (coordenadas arriba-izquierda)
let mainH = NSScreen.screens[0].frame.height
func tl(_ f: NSRect) -> CGRect { CGRect(x: f.minX, y: mainH - f.maxY, width: f.width, height: f.height) }
let m = NSEvent.mouseLocation
guard let screen = NSScreen.screens.first(where: { NSMouseInRect(m, $0.frame, false) }) else { exit(1) }
let full = tl(screen.frame)
let vis = tl(screen.visibleFrame).insetBy(dx: margin, dy: margin)

// Ventanas visibles de ese monitor
let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
// Ventanas que el usuario sacó del mosaico (las guarda EdgeSync): no se tocan
let userFloating = Set(((try? String(contentsOfFile: "/tmp/edgesync-floating", encoding: .utf8)) ?? "")
    .split(separator: "\n").compactMap { CGWindowID($0) })
var wins: [W] = []
for w in info {
    guard (w[kCGWindowLayer as String] as? Int) == 0,
          let id = w[kCGWindowNumber as String] as? CGWindowID,
          let pid = w[kCGWindowOwnerPID as String] as? pid_t,
          let b = w[kCGWindowBounds as String] as? [String: CGFloat],
          let x = b["X"], let y = b["Y"], let wd = b["Width"], let ht = b["Height"], wd > 20, ht > 20 else { continue }
    let r = CGRect(x: x, y: y, width: wd, height: ht)
    // solo apps normales (las de JankyBorders y otras sin Dock también son ventanas de nivel 0)
    guard full.contains(CGPoint(x: r.midX, y: r.midY)),
          let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular,
          !floating.contains(app.bundleIdentifier ?? ""), !userFloating.contains(id) else { continue }
    wins.append(W(id: id, pid: pid, r: r))
}
if CommandLine.arguments.contains("-v") { for w in wins { print(w.id, w.pid, NSRunningApplication(processIdentifier: w.pid)?.localizedName ?? "?", w.r) } }
guard (1...4).contains(wins.count) else { exit(0) }

// Celdas
let hw = (vis.width - gap) / 2, hh = (vis.height - gap) / 2
let L  = CGRect(x: vis.minX, y: vis.minY, width: hw, height: vis.height)
let R  = CGRect(x: vis.minX + hw + gap, y: vis.minY, width: hw, height: vis.height)
let TL = CGRect(x: vis.minX, y: vis.minY, width: hw, height: hh)
let TR = CGRect(x: vis.minX + hw + gap, y: vis.minY, width: hw, height: hh)
let BL = CGRect(x: vis.minX, y: vis.minY + hh + gap, width: hw, height: hh)
let BR = CGRect(x: vis.minX + hw + gap, y: vis.minY + hh + gap, width: hw, height: hh)

func dist(_ a: CGRect, _ b: CGRect) -> CGFloat { hypot(a.midX - b.midX, a.midY - b.midY) }
// Reparto que minimiza lo que se mueven las ventanas (prueba todas las combinaciones, son ≤ 24)
func assign(_ ws: [W], _ cells: [CGRect]) -> [(W, CGRect)] {
    func perms(_ a: [Int]) -> [[Int]] {
        if a.count <= 1 { return [a] }
        var out: [[Int]] = []
        for i in a.indices {
            var rest = a; rest.remove(at: i)
            for p in perms(rest) { out.append([a[i]] + p) }
        }
        return out
    }
    func cost(_ p: [Int]) -> CGFloat {
        var c: CGFloat = 0
        for (i, w) in ws.enumerated() { c += dist(w.r, cells[p[i]]) }
        return c
    }
    let best = perms(Array(cells.indices)).min { cost($0) < cost($1) }!
    return ws.enumerated().map { ($0.element, cells[best[$0.offset]]) }
}

var plan: [(W, CGRect)]
switch wins.count {
case 1: plan = [(wins[0], vis)]
case 2: plan = assign(wins, [L, R])
case 3:
    let left = wins.min { $0.r.midX < $1.r.midX }!
    plan = [(left, L)] + assign(wins.filter { $0.id != left.id }, [TR, BR])
default: plan = assign(wins, [TL, TR, BL, BR])
}

for (w, r) in plan {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(w.pid), kAXWindowsAttribute as CFString, &v) == .success,
          let axs = v as? [AXUIElement],
          let a = axs.first(where: { var id: CGWindowID = 0; return _AXUIElementGetWindow($0, &id) == .success && id == w.id }) else { continue }
    var p = r.origin, s = r.size
    // tamaño → posición → tamaño: algunas apps recortan el tamaño si aún no se han movido
    if let sv = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(a, kAXSizeAttribute as CFString, sv) }
    if let pv = AXValueCreate(.cgPoint, &p) { AXUIElementSetAttributeValue(a, kAXPositionAttribute as CFString, pv) }
    if let sv = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(a, kAXSizeAttribute as CFString, sv) }
}
