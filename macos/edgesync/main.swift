// EdgeSync: al arrastrar el borde de una ventana, las ventanas pegadas a ese borde se ajustan
// (crecen o se achican) para que no queden huecos ni se monten. Solo actúa mientras arrastras
// con el botón izquierdo y la ventana cambia de TAMAÑO (mover una ventana no hace nada).
// Necesita permiso de Accesibilidad. Log de depuración si existe /tmp/edgesync.debug.
import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ e: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

let maxGap: CGFloat = 40     // separación máxima para considerar dos ventanas "pegadas"
let tol: CGFloat = 3

func log(_ m: @autoclosure () -> String) {
    guard FileManager.default.fileExists(atPath: "/tmp/edgesync.debug") else { return }
    let line = m() + "\n"
    if let h = FileHandle(forWritingAtPath: "/tmp/edgesync.log") { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile() }
    else { FileManager.default.createFile(atPath: "/tmp/edgesync.log", contents: line.data(using: .utf8)) }
}

struct W { let id: CGWindowID; let pid: pid_t; let r: CGRect }

func snapshot() -> [CGWindowID: W] {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    var out: [CGWindowID: W] = [:]
    for w in info {
        guard (w[kCGWindowLayer as String] as? Int) == 0,
              let id = w[kCGWindowNumber as String] as? CGWindowID,
              let pid = w[kCGWindowOwnerPID as String] as? pid_t,
              let b = w[kCGWindowBounds as String] as? [String: CGFloat],
              let x = b["X"], let y = b["Y"], let wd = b["Width"], let ht = b["Height"],
              wd > 80, ht > 80 else { continue }
        out[id] = W(id: id, pid: pid, r: CGRect(x: x, y: y, width: wd, height: ht))
    }
    return out
}

var axCache: [CGWindowID: AXUIElement] = [:]
func axWindow(_ w: W) -> AXUIElement? {
    if let a = axCache[w.id] { return a }
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(w.pid), kAXWindowsAttribute as CFString, &v) == .success,
          let wins = v as? [AXUIElement] else { return nil }
    for a in wins {
        var id: CGWindowID = 0
        if _AXUIElementGetWindow(a, &id) == .success, id == w.id { axCache[w.id] = a; return a }
    }
    return nil
}
func setFrame(_ a: AXUIElement, _ r: CGRect) {
    var p = r.origin, s = r.size
    if let pv = AXValueCreate(.cgPoint, &p) { AXUIElementSetAttributeValue(a, kAXPositionAttribute as CFString, pv) }
    if let sv = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(a, kAXSizeAttribute as CFString, sv) }
}

func overlap(_ a0: CGFloat, _ a1: CGFloat, _ b0: CGFloat, _ b1: CGFloat) -> CGFloat { min(a1, b1) - max(a0, b0) }

// Monitor (coordenadas arriba-izquierda) que contiene un punto
func screenRect(at p: CGPoint) -> CGRect? {
    let mainH = NSScreen.screens[0].frame.height
    return NSScreen.screens.map { CGRect(x: $0.frame.minX, y: mainH - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height) }
        .first { $0.contains(p) }
}

// ---------- Divisores ----------
// Un borde arrastrado es un "divisor": lo comparten la ventana arrastrada y las alineadas con ella
// en la misma columna/fila (mismo lado), y las del otro lado lo tocan. Al moverlo, todas siguen.
// Ej.: Safari | (Claude arriba / Kitty abajo). Mover el borde izquierdo de Kitty mueve también el
// de Claude y el derecho de Safari.
enum Edge: CaseIterable { case left, right, top, bottom }
let align: CGFloat = 14      // diferencia máxima para considerar dos bordes "alineados"

func val(_ r: CGRect, _ e: Edge) -> CGFloat {
    switch e { case .left: return r.minX; case .right: return r.maxX; case .top: return r.minY; case .bottom: return r.maxY }
}
func opposite(_ e: Edge) -> Edge {
    switch e { case .left: return .right; case .right: return .left; case .top: return .bottom; case .bottom: return .top }
}
func vertical(_ e: Edge) -> Bool { e == .left || e == .right }   // divisor vertical (izq/der)
// Solapamiento en el eje a lo largo del divisor
func along(_ a: CGRect, _ b: CGRect, _ e: Edge) -> CGFloat {
    vertical(e) ? overlap(a.minY, a.maxY, b.minY, b.maxY) : overlap(a.minX, a.maxX, b.minX, b.maxX)
}
// Separación entre dos ventanas apiladas a lo largo del divisor (Claude encima de Kitty)
func stackGap(_ a: CGRect, _ b: CGRect, _ e: Edge) -> CGFloat {
    vertical(e) ? max(b.minY - a.maxY, a.minY - b.maxY) : max(b.minX - a.maxX, a.minX - b.maxX)
}
// Nuevo rectángulo con el borde `e` en `v` (el borde opuesto queda fijo)
func with(_ r: CGRect, _ e: Edge, _ v: CGFloat) -> CGRect {
    switch e {
    case .left:   return CGRect(x: v, y: r.minY, width: r.maxX - v, height: r.height)
    case .right:  return CGRect(x: r.minX, y: r.minY, width: v - r.minX, height: r.height)
    case .top:    return CGRect(x: r.minX, y: v, width: r.width, height: r.maxY - v)
    case .bottom: return CGRect(x: r.minX, y: r.minY, width: r.width, height: v - r.minY)
    }
}

struct Divider { var same: [W] = []; var opp: [W] = [] }   // same: sin la ventana arrastrada

func divider(of t: W, _ e: Edge, in all: [W]) -> Divider {
    let line = val(t.r, e)
    // Mismo lado: cadena de ventanas con ese borde alineado, apiladas una tras otra
    var group = [t]
    var changed = true
    while changed {
        changed = false
        for o in all where !group.contains(where: { $0.id == o.id }) {
            guard abs(val(o.r, e) - line) <= align else { continue }
            if group.contains(where: { let g = stackGap($0.r, o.r, e); return g >= -tol && g <= maxGap }) {
                group.append(o); changed = true
            }
        }
    }
    // Otro lado: tocan la línea y se solapan con alguna del grupo
    let oe = opposite(e)
    let sign: CGFloat = (e == .right || e == .bottom) ? 1 : -1   // hacia dónde queda el otro lado
    var d = Divider()
    d.same = group.filter { $0.id != t.id }
    for o in all where !group.contains(where: { $0.id == o.id }) {
        let gap = (val(o.r, oe) - line) * sign
        guard gap >= -tol, gap <= maxGap else { continue }
        if group.contains(where: { along($0.r, o.r, e) > 40 }) { d.opp.append(o) }
    }
    // Sin nadie al otro lado es el borde de la pantalla, no un divisor: no arrastrar a las alineadas
    if d.opp.isEmpty { d.same = [] }
    return d
}

// Estado del arrastre
var dragging = false
var baseline: [CGWindowID: W] = [:]
var target: W? = nil              // ventana que el usuario está redimensionando (foto inicial)
var dividers: [Edge: Divider] = [:]
var lastApplied: CGRect? = nil

func findDividers(_ t: W) {
    let scr = screenRect(at: CGPoint(x: t.r.midX, y: t.r.midY))
    // solo ventanas del mismo monitor (la del monitor de al lado también queda "pegada")
    let all = baseline.values.filter { o in scr.map { $0.contains(CGPoint(x: o.r.midX, y: o.r.midY)) } ?? true }
    dividers = [:]
    for e in Edge.allCases { dividers[e] = divider(of: t, e, in: all) }
}

func apply(_ now: CGRect) {
    guard let t = target, now != lastApplied else { return }
    lastApplied = now
    for e in Edge.allCases {
        let delta = val(now, e) - val(t.r, e)
        guard abs(delta) > 0.5, let d = dividers[e] else { continue }
        for w in d.same { if let a = axWindow(w) { setFrame(a, with(w.r, e, val(w.r, e) + delta)) } }
        let oe = opposite(e)
        for w in d.opp { if let a = axWindow(w) { setFrame(a, with(w.r, oe, val(w.r, oe) + delta)) } }
    }
}

func tick() {
    let down = CGEventSource.buttonState(.combinedSessionState, button: .left)
    if down && !dragging {
        dragging = true; baseline = snapshot(); target = nil; lastApplied = nil; axCache = [:]
        log("click, permiso=\(AXIsProcessTrusted())")
        return
    }
    if !down && dragging {
        // fin del arrastre: un último ajuste con el tamaño final
        if let t = target, let now = snapshot()[t.id]?.r { apply(now); log("fin \(t.id) \(now)") }
        dragging = false; target = nil
        return
    }
    guard dragging else { return }
    let cur = snapshot()
    if target == nil {
        // la primera ventana que cambia de TAMAÑO durante el arrastre es la que el usuario agarró
        for (id, b) in baseline {
            guard let c = cur[id] else { continue }
            if abs(c.r.width - b.r.width) > 1 || abs(c.r.height - b.r.height) > 1 {
                target = b; findDividers(b)
                log("resize \(id) base=\(b.r) " + Edge.allCases.map { "\($0): mismo \(dividers[$0]!.same.count) otro \(dividers[$0]!.opp.count)" }.joined(separator: ", "))
                break
            }
        }
    }
    if let t = target, let now = cur[t.id]?.r { apply(now) }
}

// Pedir el permiso: macOS agrega EdgeSync a Accesibilidad con su firma actual (tras recompilar,
// quitar la entrada vieja con − y reiniciar el servicio).
let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(opts) {
    FileHandle.standardError.write("EdgeSync necesita permiso de Accesibilidad\n".data(using: .utf8)!)
}
Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in tick() }
RunLoop.main.run()
