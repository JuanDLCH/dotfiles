// EdgeSync: dos cosas, ambas solo como reacción a lo que hace el usuario.
// 1. Al arrastrar el borde de una ventana, las que comparten ese divisor lo siguen (sin huecos).
// 2. "Acomodar al soltar": cuando el usuario pone una ventana en un sitio (arrastrar, Window →
//    Move & Resize, Fn+Ctrl+flechas…), las que quedaron debajo se recortan por el lado que menos
//    pierden; si no se dejan (tamaño mínimo), la ventana puesta se adapta; y la ventana puesta se
//    estira hasta su vecina o el borde de la pantalla si el hueco es pequeño.
// No hace nada al abrir ventanas. Apps "flotantes" (Settings, Calculadora…) quedan fuera.
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

// Caché: ¿el pid es una app "normal"? (consultarlo en cada vuelta gastaba CPU)
var regularCache: [pid_t: Bool] = [:]
func isRegular(_ pid: pid_t) -> Bool {
    if let r = regularCache[pid] { return r }
    let r = NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular
    regularCache[pid] = r; return r
}

func snapshot() -> [CGWindowID: W] {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    var out: [CGWindowID: W] = [:]
    for w in info {
        guard (w[kCGWindowLayer as String] as? Int) == 0,
              let id = w[kCGWindowNumber as String] as? CGWindowID,
              let pid = w[kCGWindowOwnerPID as String] as? pid_t,
              let b = w[kCGWindowBounds as String] as? [String: CGFloat],
              let x = b["X"], let y = b["Y"], let wd = b["Width"], let ht = b["Height"],
              wd > 20, ht > 20,
              // solo apps normales: los bordes de JankyBorders también son ventanas de nivel 0
              isRegular(pid) else { continue }
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
func setFrame(_ a: AXUIElement, _ r: CGRect, thorough: Bool = false) {
    var p = r.origin, s = r.size
    // tamaño → posición → tamaño: algunas apps (Electron) recortan el tamaño si aún no se movieron
    if thorough, let sv = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(a, kAXSizeAttribute as CFString, sv) }
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
        for w in d.same { if let a = axWindow(w) { ours[w.id] = Date(); setFrame(a, with(w.r, e, val(w.r, e) + delta)) } }
        let oe = opposite(e)
        for w in d.opp { if let a = axWindow(w) { ours[w.id] = Date(); setFrame(a, with(w.r, oe, val(w.r, oe) + delta)) } }
    }
}


// ---------- Acomodar al soltar ----------
let gap: CGFloat = 10          // separación entre ventanas (la del tiling nativo)
let margin: CGFloat = 8        // separación con el borde de la pantalla
let fillMax: CGFloat = 250     // huecos más grandes que esto se respetan (no se rellenan)
let floating: Set<String> = ["com.apple.systempreferences", "com.apple.calculator", "com.apple.ActivityMonitor",
                             "com.apple.archiveutility", "com.apple.screencaptureui", "com.apple.SecurityAgent"]

var ours: [CGWindowID: Date] = [:]   // ventanas que movimos nosotros (para no reaccionar a eso)

func axFrame(_ a: AXUIElement) -> CGRect? {
    var pv: CFTypeRef?, sv: CFTypeRef?
    guard AXUIElementCopyAttributeValue(a, kAXPositionAttribute as CFString, &pv) == .success,
          AXUIElementCopyAttributeValue(a, kAXSizeAttribute as CFString, &sv) == .success else { return nil }
    var p = CGPoint.zero, s = CGSize.zero
    AXValueGetValue(pv as! AXValue, .cgPoint, &p); AXValueGetValue(sv as! AXValue, .cgSize, &s)
    return CGRect(origin: p, size: s)
}
// Pone la ventana en `r` y devuelve dónde quedó de verdad (la app puede imponer mínimos/máximos)
@discardableResult
func place(_ w: W, _ r: CGRect) -> CGRect {
    guard let a = axWindow(w) else { return w.r }
    ours[w.id] = Date()
    setFrame(a, r, thorough: true)
    func off(_ f: CGRect) -> Bool {
        abs(f.minX - r.minX) > 4 || abs(f.minY - r.minY) > 4 || abs(f.width - r.width) > 4 || abs(f.height - r.height) > 4
    }
    // Algunas apps (Claude, Electron) tardan en aplicar el cambio: esperar y reintentar antes de
    // concluir que es su tamaño mínimo
    var got = axFrame(a) ?? r
    for _ in 0..<3 where off(got) {
        usleep(120_000)
        setFrame(a, r, thorough: true)
        got = axFrame(a) ?? r
    }
    return got
}
func isFloating(_ w: W) -> Bool {
    floating.contains(bundle(w.pid))
}
func visibleRect(at p: CGPoint) -> CGRect? {
    let mainH = NSScreen.screens[0].frame.height
    return NSScreen.screens.map { CGRect(x: $0.visibleFrame.minX, y: mainH - $0.visibleFrame.maxY,
                                         width: $0.visibleFrame.width, height: $0.visibleFrame.height) }
        .first { $0.contains(p) }
}
func intersects(_ a: CGRect, _ b: CGRect) -> Bool {
    overlap(a.minX, a.maxX, b.minX, b.maxX) > 20 && overlap(a.minY, a.maxY, b.minY, b.maxY) > 20
}

// Ventanas que el usuario sacó del mosaico (soltadas sin encajar). Se guardan en un archivo para
// que win-grid (⌥G) también las respete.
let floatingFile = "/tmp/edgesync-floating"
var userFloating: Set<CGWindowID> = Set(((try? String(contentsOfFile: floatingFile, encoding: .utf8)) ?? "")
    .split(separator: "\n").compactMap { CGWindowID($0) })
func saveFloating() {
    try? userFloating.map(String.init).joined(separator: "\n").write(toFile: floatingFile, atomically: true, encoding: .utf8)
}

// Reorganizar el monitor con la prioridad del usuario (igual que ⌥G):
// 1 → pantalla, 2 → mitades, 3 → master izquierda + 2 filas a la derecha, 4 → 2×2.
func regrid(_ vis: CGRect) {
    let ws = snapshot().values.filter { vis.contains(CGPoint(x: $0.r.midX, y: $0.r.midY)) && !isFloating($0) && !userFloating.contains($0.id) }
        .sorted { $0.id < $1.id }
    guard (1...4).contains(ws.count) else { return }
    let v = vis.insetBy(dx: margin, dy: margin)
    let hw = (v.width - gap) / 2, hh = (v.height - gap) / 2
    let L  = CGRect(x: v.minX, y: v.minY, width: hw, height: v.height)
    let R  = CGRect(x: v.minX + hw + gap, y: v.minY, width: hw, height: v.height)
    let TL = CGRect(x: v.minX, y: v.minY, width: hw, height: hh)
    let TR = CGRect(x: v.minX + hw + gap, y: v.minY, width: hw, height: hh)
    let BL = CGRect(x: v.minX, y: v.minY + hh + gap, width: hw, height: hh)
    let BR = CGRect(x: v.minX + hw + gap, y: v.minY + hh + gap, width: hw, height: hh)
    func dist(_ a: CGRect, _ b: CGRect) -> CGFloat { hypot(a.midX - b.midX, a.midY - b.midY) }
    func perms(_ a: [Int]) -> [[Int]] {
        if a.count <= 1 { return [a] }
        var out: [[Int]] = []
        for i in a.indices { var rest = a; rest.remove(at: i); for p in perms(rest) { out.append([a[i]] + p) } }
        return out
    }
    func assign(_ ws: [W], _ cells: [CGRect]) -> [(W, CGRect)] {
        func cost(_ p: [Int]) -> CGFloat { var c: CGFloat = 0; for (i, w) in ws.enumerated() { c += dist(w.r, cells[p[i]]) }; return c }
        let best = perms(Array(cells.indices)).min { cost($0) < cost($1) }!
        return ws.enumerated().map { ($0.element, cells[best[$0.offset]]) }
    }
    var plan: [(W, CGRect)]
    switch ws.count {
    case 1: plan = [(ws[0], v)]
    case 2: plan = assign(ws, [L, R])
    case 3:
        let left = ws.min { $0.r.midX < $1.r.midX }!
        plan = [(left, L)] + assign(ws.filter { $0.id != left.id }, [TR, BR])
    default: plan = assign(ws, [TL, TR, BL, BR])
    }
    for (w, r) in plan { let got = place(w, r); log("  regrid \(w.id) -> \(got)") }
    // Algunas apps vuelven a su tamaño anterior un instante después: revisar y reaplicar
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        let now = snapshot()
        for (w, r) in plan {
            guard let c = now[w.id]?.r else { continue }
            if abs(c.minX - r.minX) > 4 || abs(c.minY - r.minY) > 4 || abs(c.width - r.width) > 4 || abs(c.height - r.height) > 4 {
                let got = place(w, r); log("  regrid (2º intento) \(w.id) -> \(got)")
            }
        }
        prev = snapshot()
    }
}

// Hueco que deja una ventana al irse: lo llenan las vecinas de UN lado que lo cubren justo
// (en dwindle, la "hermana"). Se prefiere el lado con una sola vecina.
func fillHole(_ old: CGRect, _ others: [W], _ vis: CGRect) {
    var options: [(Edge, [W])] = []
    for e in Edge.allCases {
        // vecinas al otro lado del borde `e` del hueco
        let side = others.filter { o in
            let g: CGFloat
            switch e {
            case .left:   g = old.minX - o.r.maxX
            case .right:  g = o.r.minX - old.maxX
            case .top:    g = old.minY - o.r.maxY
            case .bottom: g = o.r.minY - old.maxY
            }
            return g >= -tol && g <= maxGap && along(old, o.r, e) > 40
        }
        guard !side.isEmpty else { continue }
        // deben quedar dentro del tramo del hueco y cubrirlo de punta a punta
        let lo = vertical(e) ? old.minY : old.minX, hi = vertical(e) ? old.maxY : old.maxX
        let los = side.map { vertical(e) ? $0.r.minY : $0.r.minX }, his = side.map { vertical(e) ? $0.r.maxY : $0.r.maxX }
        guard los.allSatisfy({ $0 >= lo - align }), his.allSatisfy({ $0 <= hi + align }),
              abs(los.min()! - lo) <= align, abs(his.max()! - hi) <= align else { continue }
        options.append((e, side))
    }
    guard let pick = options.min(by: { $0.1.count < $1.1.count }) else { log("  hueco sin vecinas que lo cubran"); return }
    let e = pick.0
    for o in pick.1 {
        // la vecina estira el borde que da al hueco hasta el lado opuesto del hueco
        let target: CGRect
        switch e {
        case .left:   target = with(o.r, .right, old.maxX)
        case .right:  target = with(o.r, .left, old.minX)
        case .top:    target = with(o.r, .bottom, old.maxY)
        case .bottom: target = with(o.r, .top, old.minY)
        }
        let got = place(o, target)
        log("  llena hueco \(o.id) desde \(e) -> \(got)")
    }
}

func settle(_ id: CGWindowID, old: CGRect? = nil) {
    let snap = snapshot()
    guard let t = snap[id], !isFloating(t),
          let vis = visibleRect(at: CGPoint(x: t.r.midX, y: t.r.midY)) else { return }
    axCache = [:]
    var T = t.r
    // ¿Quedó encajada? (pegada a ≥ 2 bordes de la pantalla, como las mitades/cuartos del mosaico
    // nativo). Si no, el usuario la sacó del mosaico: queda flotante.
    let snapTol: CGFloat = 24
    let touching = [abs(T.minX - vis.minX), abs(vis.maxX - T.maxX), abs(T.minY - vis.minY), abs(vis.maxY - T.maxY)]
        .filter { $0 <= snapTol }.count
    let wasFloating = userFloating.contains(id)
    let moved = old.map { abs($0.midX - t.r.midX) > 60 || abs($0.midY - t.r.midY) > 60 } ?? false
    if touching < 2 {
        userFloating.insert(id); saveFloating()
        log("settle \(id): flotante (toca \(touching) bordes)")
        // Salió del mosaico: las que quedan en ese monitor se reorganizan (prioridad del usuario)
        if moved, !wasFloating, let old = old, let ovis = visibleRect(at: CGPoint(x: old.midX, y: old.midY)) { regrid(ovis) }
        return
    }
    userFloating.remove(id); saveFloating()
    // Se movió de un sitio encajado a otro: las vecinas ocupan el hueco que dejó
    if moved, !wasFloating, let old = old, let ovis = visibleRect(at: CGPoint(x: old.midX, y: old.midY)) {
        let there = snap.values.filter { $0.id != id && ovis.contains(CGPoint(x: $0.r.midX, y: $0.r.midY)) && !isFloating($0) && !userFloating.contains($0.id) }
        log("hueco \(old)")
        fillHole(old, there, ovis)
    }
    let others = snapshot().values.filter { $0.id != id && vis.contains(CGPoint(x: $0.r.midX, y: $0.r.midY)) && !isFloating($0) && !userFloating.contains($0.id) }
    log("settle \(id) \(T)")

    // 1. Choques: la de debajo cede por el eje donde pierde menos; si no puede, cede la puesta
    var placed: [CGWindowID: CGRect] = [:]
    for o in others where intersects(T, o.r) {
        var cands: [(CGRect, Edge)] = []
        if o.r.midX < T.midX { cands.append((with(o.r, .right, T.minX - gap), .right)) }
        else                 { cands.append((with(o.r, .left, T.maxX + gap), .left)) }
        if o.r.midY < T.midY { cands.append((with(o.r, .bottom, T.minY - gap), .bottom)) }
        else                 { cands.append((with(o.r, .top, T.maxY + gap), .top)) }
        let ok = cands.filter { $0.0.width >= 120 && $0.0.height >= 120 }
        guard let best = ok.max(by: { $0.0.width * $0.0.height < $1.0.width * $1.0.height }) else { continue }
        var got = place(o, best.0)
        // Por su tamaño mínimo se saldría de la pantalla: que se quede donde estaba
        if got.minX < vis.minX - tol || got.maxX > vis.maxX + tol || got.minY < vis.minY - tol || got.maxY > vis.maxY + tol {
            got = place(o, o.r)
            log("  \(o.id) se saldría de la pantalla: vuelve a \(got)")
        }
        placed[o.id] = got
        log("  cede \(o.id) \(best.1) -> \(got)")
        if intersects(T, got) {   // tamaño mínimo: la puesta se ajusta a lo que quedó
            let before = T
            switch best.1 {
            case .right:  T = with(T, .left, got.maxX + gap)
            case .left:   T = with(T, .right, got.minX - gap)
            case .bottom: T = with(T, .top, got.maxY + gap)
            case .top:    T = with(T, .bottom, got.minY - gap)
            }
            if T.width < 200 || T.height < 200 {   // no aplastar la ventana que el usuario puso
                T = before; log("  mínimo de \(o.id): no cabe, la puesta se queda como está")
            } else {
                log("  mínimo de \(o.id): la puesta queda \(T)")
            }
        }
    }

    // 2. Huecos pequeños: estirar la puesta hasta la vecina o el borde de la pantalla
    let rects = others.map { placed[$0.id] ?? $0.r }
    func bound(_ e: Edge) -> CGFloat {
        switch e {
        case .left:
            return rects.filter { overlap(T.minY, T.maxY, $0.minY, $0.maxY) > 40 && $0.maxX <= T.minX + tol }
                        .map { $0.maxX + gap }.max() ?? vis.minX + margin
        case .right:
            return rects.filter { overlap(T.minY, T.maxY, $0.minY, $0.maxY) > 40 && $0.minX >= T.maxX - tol }
                        .map { $0.minX - gap }.min() ?? vis.maxX - margin
        case .top:
            return rects.filter { overlap(T.minX, T.maxX, $0.minX, $0.maxX) > 40 && $0.maxY <= T.minY + tol }
                        .map { $0.maxY + gap }.max() ?? vis.minY + margin
        case .bottom:
            return rects.filter { overlap(T.minX, T.maxX, $0.minX, $0.maxX) > 40 && $0.minY >= T.maxY - tol }
                        .map { $0.minY - gap }.min() ?? vis.maxY - margin
        }
    }
    for e in Edge.allCases {
        let b = bound(e), cur = val(T, e)
        let grow = (e == .left || e == .top) ? cur - b : b - cur   // > 0: hay hueco
        if grow > 2 && grow <= fillMax { T = with(T, e, b) }
    }
    if T != t.r {
        let got = place(t, T)
        log("  puesta -> \(got)")
    }
}

// Detectar "el usuario puso una ventana": cambió de sitio/tamaño, no lo hicimos nosotros, es de la
// app activa, el botón está suelto y lleva ~0.3 s quieta (el tiling nativo termina tras soltar).
var prev: [CGWindowID: W] = [:]
var pending: (id: CGWindowID, r: CGRect, since: Date, old: CGRect)? = nil
var pollCount = 0

// Flotante enfocada = como Settings en AutoRaise: pausar AutoRaise para que pasar el mouse por
// otras ventanas no la tape. Se reanuda al enfocar (clic) una ventana del mosaico.
var autoRaisePaused = false
func signalAutoRaise(_ sig: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
    p.arguments = [sig, "-x", "AutoRaise"]
    try? p.run(); p.waitUntilExit()
}
// Ventana enfocada: su id y si es un diálogo (Guardar, confirmaciones, alertas de la app)
func focusedWindow() -> (id: CGWindowID, dialog: Bool)? {
    var app: CFTypeRef?, win: CFTypeRef?
    guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute as CFString, &app) == .success,
          AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedWindowAttribute as CFString, &win) == .success else { return nil }
    let w = win as! AXUIElement
    var id: CGWindowID = 0
    guard _AXUIElementGetWindow(w, &id) == .success else { return nil }
    var sub: CFTypeRef?
    AXUIElementCopyAttributeValue(w, kAXSubroleAttribute as CFString, &sub)
    let dialog = ["AXDialog", "AXSystemDialog", "AXFloatingWindow"].contains(sub as? String ?? "")
    return (id, dialog)
}
func syncAutoRaise() {
    let want = focusedWindow().map { userFloating.contains($0.id) || $0.dialog } ?? autoRaisePaused
    if want != autoRaisePaused {
        signalAutoRaise(want ? "-STOP" : "-CONT")
        autoRaisePaused = want
        // screenshot-area.sh mira este archivo para no reanudar AutoRaise si lo pausamos nosotros
        if want { FileManager.default.createFile(atPath: "/tmp/edgesync-autoraise-paused", contents: nil) }
        else { try? FileManager.default.removeItem(atPath: "/tmp/edgesync-autoraise-paused") }
        log("AutoRaise \(want ? "pausado (flotante o diálogo enfocado)" : "activo")")
    }
}

// ¿La ventana dejó de existir? (cerrada). Cambiar de escritorio, minimizar u ocultar la app la
// quita de la pantalla pero sigue existiendo.
func windowExists(_ id: CGWindowID) -> Bool {
    let l = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]] ?? []
    return !l.isEmpty
}

// ---------- Diálogos nuevos: foco + mouse encima ----------
// Avisos del sistema (no son apps "normales", por eso van aparte de snapshot())
let popupBundles: Set<String> = ["com.apple.UserNotificationCenter", "com.apple.coreservices.uiagent",
    "com.apple.accessibility.universalAccessAuthWarn", "com.apple.CoreServicesUIAgent", "com.apple.SecurityAgent",
    "com.apple.LocalAuthentication.UIAgent", "com.apple.Installer"]
var seenPopups: Set<CGWindowID> = []
var bundleCache: [pid_t: String] = [:]
func bundle(_ pid: pid_t) -> String {
    if let b = bundleCache[pid] { return b }
    let b = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
    bundleCache[pid] = b; return b
}
var popupsPrimed = false
var popupTurn = false

func focusAndPoint(pid: pid_t, id: CGWindowID, rect: CGRect) {
    NSRunningApplication(processIdentifier: pid)?.activate()
    var v: CFTypeRef?
    if AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &v) == .success,
       let wins = v as? [AXUIElement],
       let a = wins.first(where: { var wid: CGWindowID = 0; return _AXUIElementGetWindow($0, &wid) == .success && wid == id }) {
        AXUIElementPerformAction(a, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(a, kAXMainAttribute as CFString, kCFBooleanTrue)
    }
    CGWarpMouseCursorPosition(CGPoint(x: rect.midX, y: rect.midY))
    CGAssociateMouseAndMouseCursorPosition(1)
    log("diálogo \(id): foco + mouse")
}

func isDialog(_ w: W) -> Bool {
    guard let a = axWindow(w) else { return false }
    var sub: CFTypeRef?
    AXUIElementCopyAttributeValue(a, kAXSubroleAttribute as CFString, &sub)
    return ["AXDialog", "AXSystemDialog"].contains(sub as? String ?? "")
}

func checkDialogs(_ snap: [CGWindowID: W]) {
    // 1. Diálogos nuevos dentro de las apps
    if !prev.isEmpty {
        for (id, w) in snap where prev[id] == nil && isDialog(w) {
            focusAndPoint(pid: w.pid, id: id, rect: w.r)
            return
        }
    }
    // 2. Avisos del sistema nuevos (cualquier nivel de ventana); cada 2ª vuelta basta
    popupTurn.toggle()
    if !popupTurn { return }
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    var current: Set<CGWindowID> = []
    var fresh: (pid_t, CGWindowID, CGRect)? = nil
    for w in info {
        guard let id = w[kCGWindowNumber as String] as? CGWindowID,
              let pid = w[kCGWindowOwnerPID as String] as? pid_t,
              let b = w[kCGWindowBounds as String] as? [String: CGFloat],
              let x = b["X"], let y = b["Y"], let wd = b["Width"], let ht = b["Height"], wd > 60, ht > 40,
              popupBundles.contains(bundle(pid)) else { continue }
        current.insert(id)
        if !seenPopups.contains(id) && fresh == nil { fresh = (pid, id, CGRect(x: x, y: y, width: wd, height: ht)) }
    }
    if popupsPrimed, let f = fresh { focusAndPoint(pid: f.0, id: f.1, rect: f.2) }
    seenPopups = current; popupsPrimed = true
}

func watch() {
    syncAutoRaise()
    let now = Date()
    var snap = snapshot()
    defer { prev = snap }
    checkDialogs(snap)
    // Se cerró una ventana del mosaico: las que quedan en ese monitor se reorganizan
    var regridded = false
    for (id, w) in prev where snap[id] == nil && !windowExists(id) {
        let wasFloating = userFloating.remove(id) != nil
        if wasFloating { saveFloating() }
        if wasFloating || isFloating(w) || regridded { continue }
        if let vis = visibleRect(at: CGPoint(x: w.r.midX, y: w.r.midY)) {
            log("cerrada \(id) \(w.r): reorganizar")
            axCache = [:]
            regrid(vis); regridded = true
        }
    }
    if regridded { snap = snapshot(); pending = nil; return }
    ours = ours.filter { now.timeIntervalSince($0.value) < 1.0 }
    if let p = pending {
        guard let c = snap[p.id] else { pending = nil; return }
        if c.r != p.r { pending = (p.id, c.r, now, p.old); return }
        if now.timeIntervalSince(p.since) >= 0.3 { pending = nil; settle(p.id, old: p.old); prev = snapshot() }
        return
    }
    let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
    for (id, w) in snap {
        guard let old = prev[id], ours[id] == nil, w.pid == front else { continue }
        if abs(w.r.minX - old.r.minX) > 2 || abs(w.r.minY - old.r.minY) > 2 ||
           abs(w.r.width - old.r.width) > 2 || abs(w.r.height - old.r.height) > 2 {
            pending = (id, w.r, now, old.r); return
        }
    }
}

var moving = false   // este arrastre es mover la ventana, no redimensionarla: no seguir

// Redimensionar de verdad deja quieto el borde opuesto en cada eje. Si se mueven ambos bordes de un
// eje (mover la ventana, salir del mosaico nativo, ⌥ + arrastrar con encaje), no es redimensionar.
func isEdgeResize(_ b: CGRect, _ c: CGRect) -> Bool {
    let l = abs(c.minX - b.minX) > 1, r = abs(c.maxX - b.maxX) > 1
    let t = abs(c.minY - b.minY) > 1, bo = abs(c.maxY - b.maxY) > 1
    return !(l && r) && !(t && bo) && (l || r || t || bo)
}
func restoreFollowers() {
    for d in dividers.values { for w in d.same + d.opp { place(w, w.r) } }
}

func tick() {
    let down = CGEventSource.buttonState(.combinedSessionState, button: .left)
    if down && !dragging {
        dragging = true; baseline = snapshot(); target = nil; lastApplied = nil; axCache = [:]; dividers = [:]
        // ⌥ + arrastrar es el atajo nativo para mover/encajar ventanas
        moving = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate)
        log("click, permiso=\(AXIsProcessTrusted()) mover=\(moving)")
        return
    }
    if !down && dragging {
        // fin del arrastre: un último ajuste con el tamaño final
        if let t = target, !moving, let now = snapshot()[t.id]?.r, isEdgeResize(t.r, now) { apply(now); log("fin \(t.id) \(now)") }
        dragging = false; target = nil; moving = false
        prev = baseline   // para que watch() vea lo que cambió durante el arrastre
        return
    }
    guard dragging else {
        pollCount += 1
        if pollCount % 6 == 0 { watch() }   // ~240 ms
        return
    }
    if moving { return }
    let cur = snapshot()
    if target == nil {
        // la primera ventana que cambia durante el arrastre es la que el usuario agarró
        for (id, b) in baseline {
            guard let c = cur[id], c.r != b.r else { continue }
            if !isEdgeResize(b.r, c.r) { moving = true; log("mover \(id)"); return }
            target = b; findDividers(b)
            log("resize \(id) base=\(b.r) " + Edge.allCases.map { "\($0): mismo \(dividers[$0]!.same.count) otro \(dividers[$0]!.opp.count)" }.joined(separator: ", "))
            break
        }
    }
    if let t = target, let now = cur[t.id]?.r {
        if !isEdgeResize(t.r, now) {   // resultó ser mover: devolver a las vecinas
            moving = true; restoreFollowers(); target = nil; log("era mover: vecinas restauradas")
            return
        }
        apply(now)
    }
}

// Pedir el permiso: macOS agrega EdgeSync a Accesibilidad con su firma actual (tras recompilar,
// quitar la entrada vieja con − y reiniciar el servicio).
let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(opts) {
    FileHandle.standardError.write("EdgeSync necesita permiso de Accesibilidad\n".data(using: .utf8)!)
}
try? FileManager.default.removeItem(atPath: "/tmp/edgesync-autoraise-paused")
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { n in
    if let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
        regularCache[app.processIdentifier] = nil; bundleCache[app.processIdentifier] = nil
    }
}
signalAutoRaise("-CONT")   // por si EdgeSync se cerró con AutoRaise en pausa
Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { _ in tick() }
RunLoop.main.run()
