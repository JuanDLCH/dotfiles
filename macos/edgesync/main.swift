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

// Vecinas pegadas a cada borde de `w` en la foto inicial
struct Neighbours { var right: [W] = [], left: [W] = [], below: [W] = [], above: [W] = [] }
// Monitor (coordenadas arriba-izquierda) que contiene un punto
func screenRect(at p: CGPoint) -> CGRect? {
    let mainH = NSScreen.screens[0].frame.height
    return NSScreen.screens.map { CGRect(x: $0.frame.minX, y: mainH - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height) }
        .first { $0.contains(p) }
}
func neighbours(of w: W, in all: [CGWindowID: W]) -> Neighbours {
    var n = Neighbours()
    let r = w.r
    let scr = screenRect(at: CGPoint(x: r.midX, y: r.midY))
    for o in all.values where o.id != w.id {
        // solo ventanas del mismo monitor (la del monitor de al lado también queda "pegada")
        if let scr = scr, !scr.contains(CGPoint(x: o.r.midX, y: o.r.midY)) { continue }
        let q = o.r
        let vOv = overlap(r.minY, r.maxY, q.minY, q.maxY) > 40
        let hOv = overlap(r.minX, r.maxX, q.minX, q.maxX) > 40
        if vOv, q.minX - r.maxX >= -tol, q.minX - r.maxX <= maxGap { n.right.append(o) }
        if vOv, r.minX - q.maxX >= -tol, r.minX - q.maxX <= maxGap { n.left.append(o) }
        if hOv, q.minY - r.maxY >= -tol, q.minY - r.maxY <= maxGap { n.below.append(o) }
        if hOv, r.minY - q.maxY >= -tol, r.minY - q.maxY <= maxGap { n.above.append(o) }
    }
    return n
}

// Estado del arrastre
var dragging = false
var baseline: [CGWindowID: W] = [:]
var target: W? = nil              // ventana que el usuario está redimensionando (foto inicial)
var near = Neighbours()
var lastApplied: CGRect? = nil

func apply(_ now: CGRect) {
    guard let t = target, now != lastApplied else { return }
    lastApplied = now
    let b = t.r
    let dR = now.maxX - b.maxX, dL = now.minX - b.minX, dB = now.maxY - b.maxY, dT = now.minY - b.minY
    if abs(dR) > 0.5 { for n in near.right { if let a = axWindow(n) {
        let gap = n.r.minX - b.maxX
        setFrame(a, CGRect(x: now.maxX + gap, y: n.r.minY, width: n.r.maxX - now.maxX - gap, height: n.r.height)) } } }
    if abs(dL) > 0.5 { for n in near.left { if let a = axWindow(n) {
        let gap = b.minX - n.r.maxX
        setFrame(a, CGRect(x: n.r.minX, y: n.r.minY, width: now.minX - gap - n.r.minX, height: n.r.height)) } } }
    if abs(dB) > 0.5 { for n in near.below { if let a = axWindow(n) {
        let gap = n.r.minY - b.maxY
        setFrame(a, CGRect(x: n.r.minX, y: now.maxY + gap, width: n.r.width, height: n.r.maxY - now.maxY - gap)) } } }
    if abs(dT) > 0.5 { for n in near.above { if let a = axWindow(n) {
        let gap = b.minY - n.r.maxY
        setFrame(a, CGRect(x: n.r.minX, y: n.r.minY, width: n.r.width, height: now.minY - gap - n.r.minY)) } } }
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
                target = b; near = neighbours(of: b, in: baseline)
                log("resize \(id) base=\(b.r) vecinas r\(near.right.count) l\(near.left.count) b\(near.below.count) a\(near.above.count)")
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
