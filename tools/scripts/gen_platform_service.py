#!/usr/bin/env python3
"""Generate a platform service: abstract-surface QObject base + per-platform
subclass skeletons + compile-time create() factory + CMake backend block.

A "platform service" owns native state and/or emits async results, so it is a
QObject (unlike the stateless free-function hooks in PlatformHooks.h). The base
declares the QML-visible surface (Q_OBJECT, Q_INVOKABLE, signals) and pure or
virtual native operations; each platform TU defines a concrete subclass plus the
single create() for that platform. CMake compiles exactly one TU, so only the
target platform's native code links in — zero runtime dispatch beyond one vtable.

Usage:
    tools/scripts/gen_platform_service.py path/to/schema.json [--out-root .] [--force]

Schema (JSON):
{
  "name": "DocumentPickerService",
  "namespace_hook": false,
  "platforms": ["default", "ios", "android"],   // which TUs to emit
  "includes": ["<QString>"],
  "properties": [
     {"name":"busy","type":"bool","read":"busy","notify":"busyChanged","initial":"false"}
  ],
  "signals": [
     {"name":"documentPicked","args":"const QString& path"}
  ],
  "invokables": [
     {"ret":"void","name":"pickImportDocument","args":"","virtual":true}
  ]
}

This emits declarations and skeletons only — native bodies (ObjC/JNI) are filled
in by hand per platform, since they cannot be generated safely. Existing files
are never overwritten unless --force is passed.

LIMITATION: declared properties emit the Q_PROPERTY line only. Their getter
bodies, backing members, and NOTIFY emissions are left for hand-completion in
the base .cpp (a property's semantics — storage, threading, when to notify — are
service-specific and unsafe to auto-generate). The generator handles the
boilerplate-heavy part (class skeleton, factory, per-platform TUs, CMake block);
property wiring is the small hand-finished remainder.
"""

import argparse
import json
import sys
from pathlib import Path

HEADER_TMPL = """\
#pragma once

{includes}

#include <QObject>
#include <memory>

class QQmlEngine;
class QJSEngine;

// {name} — platform service (base + per-platform subclass + compile-time
// factory). The base is the QML-visible type; platform subclasses live in the
// per-platform translation units and are never registered separately. Exactly
// one create() is compiled (see ViewModels/CMakeLists.txt).
class {name} : public QObject
{{
    Q_OBJECT
{properties}
public:
    explicit {name}(QObject* parent = nullptr);
    ~{name}() override;

    // Compile-time factory. Defined once per platform TU; CMake links exactly
    // one. Returns the platform-appropriate subclass as a base pointer.
    static std::unique_ptr<{name}> create(QObject* parent = nullptr);

{invokable_decls}
signals:
{signal_decls}
protected:
{virtual_decls}
}};
"""

BASE_CPP_TMPL = """\
#include <ViewModels/{name}.h>

{name}::{name}(QObject* parent) : QObject(parent) {{}}
{name}::~{name}() = default;

{wrappers}
"""

PLATFORM_TMPL = """\
// {name}_{plat}.cpp — {plat} backend for {name}.
// Compiled only for this platform (see ViewModels/CMakeLists.txt). Defines the
// concrete subclass and this platform's create(). Fill in native bodies here.

#include <ViewModels/{name}.h>

namespace {{

class {name}{Plat} final : public {name}
{{
public:
    using {name}::{name};

{virtual_overrides}
}};

}} // namespace

std::unique_ptr<{name}> {name}::create(QObject* parent)
{{
    return std::make_unique<{name}{Plat}>(parent);
}}
"""

MM_TMPL = """\
// {name}_{plat}.mm — {plat} backend for {name}.
// Compiled only for this platform (see ViewModels/CMakeLists.txt). Defines the
// concrete subclass and this platform's create(). Fill in native ObjC++ bodies.

#include <ViewModels/{name}.h>

namespace {{

class {name}{Plat} final : public {name}
{{
public:
    using {name}::{name};

{virtual_overrides}
}};

}} // namespace

std::unique_ptr<{name}> {name}::create(QObject* parent)
{{
    return std::make_unique<{name}{Plat}>(parent);
}}
"""


def _param_names(args: str) -> str:
    # The definition re-uses the declared parameter list verbatim.
    return args


def _arg_names(args: str) -> str:
    # Extract bare parameter names for the forwarding call: "const QString& path,
    # int n" -> "path, n". Naive but sufficient for the simple signatures used in
    # service schemas (no function pointers / templates).
    if not args.strip():
        return ""
    names = []
    for part in args.split(","):
        tok = part.strip().rstrip("&*").split()
        if tok:
            names.append(tok[-1].lstrip("&*"))
    return ", ".join(names)


def _prop_line(p):
    parts = [f'Q_PROPERTY({p["type"]} {p["name"]} READ {p["read"]}']
    if p.get("write"):
        parts.append(f'WRITE {p["write"]}')
    if p.get("notify"):
        parts.append(f'NOTIFY {p["notify"]}')
    return "    " + " ".join(parts) + ")"


def generate(schema, out_root: Path, force: bool):
    name = schema["name"]
    plats = schema.get("platforms", ["default"])
    includes = "\n".join(f"#include {i}" for i in schema.get("includes", []))

    props = "\n".join(_prop_line(p) for p in schema.get("properties", []))
    if props:
        props = "\n" + props + "\n"

    # A virtual invokable becomes a public Q_INVOKABLE wrapper that forwards to a
    # protected pure-virtual <name>Impl, so QML binds a stable non-virtual entry
    # point and platform subclasses override only the Impl. This matches the
    # hand-written services (deliverNative/playImpl/pickImportDocumentNative).
    inv_decls = []
    virt_decls = []
    for iv in schema.get("invokables", []):
        sig = f'{iv["ret"]} {iv["name"]}({iv.get("args","")})'
        inv_decls.append(f'    Q_INVOKABLE {sig};')
        if iv.get("virtual"):
            impl_sig = f'{iv["ret"]} {iv["name"]}Impl({iv.get("args","")})'
            virt_decls.append(f'    virtual {impl_sig} = 0;')
    invokable_decls = "\n".join(inv_decls) + ("\n" if inv_decls else "")

    signal_decls = "\n".join(
        f'    void {s["name"]}({s.get("args","")});' for s in schema.get("signals", [])
    ) or "    // (no signals)"

    virtual_decls = "\n".join(virt_decls) or "    // (no platform virtuals)"

    header = HEADER_TMPL.format(
        name=name, includes=includes, properties=props,
        invokable_decls=invokable_decls, signal_decls=signal_decls,
        virtual_decls=virtual_decls,
    )

    inc_dir = out_root / "ViewModels" / "include" / "ViewModels"
    src_dir = out_root / "ViewModels" / "src"
    inc_dir.mkdir(parents=True, exist_ok=True)
    src_dir.mkdir(parents=True, exist_ok=True)

    written = []

    def emit(path: Path, content: str):
        if path.exists() and not force:
            print(f"skip (exists): {path}")
            return
        path.write_text(content)
        written.append(str(path))
        print(f"wrote: {path}")

    emit(inc_dir / f"{name}.h", header)

    # Base .cpp: ctor/dtor + public wrappers forwarding to the Impl virtuals.
    wrappers = "\n".join(
        f'{iv["ret"]} {name}::{iv["name"]}({_param_names(iv.get("args",""))}) '
        f'{{ {"return " if iv["ret"] != "void" else ""}{iv["name"]}Impl({_arg_names(iv.get("args",""))}); }}'
        for iv in schema.get("invokables", []) if iv.get("virtual")
    ) or "// (no wrappers)"
    emit(src_dir / f"{name}.cpp",
         BASE_CPP_TMPL.format(name=name, wrappers=wrappers))

    overrides = "\n".join(
        f'    {iv["ret"]} {iv["name"]}Impl({iv.get("args","")}) override\n    {{\n        // TODO: native {name} impl\n    }}'
        for iv in schema.get("invokables", []) if iv.get("virtual")
    ) or "    // no platform virtuals to override"

    for plat in plats:
        Plat = plat.capitalize()
        is_mm = plat == "ios"
        tmpl = MM_TMPL if is_mm else PLATFORM_TMPL
        ext = "mm" if is_mm else "cpp"
        emit(src_dir / f"{name}_{plat}.{ext}",
             tmpl.format(name=name, plat=plat, Plat=Plat, virtual_overrides=overrides))

    # CMake backend selection block (paste into ViewModels/CMakeLists.txt).
    var = f"_TENJIN_{name.upper().replace('SERVICE','')}_BACKEND"
    print("\n# --- CMake backend block for", name, "---")
    print("if(IOS OR CMAKE_SYSTEM_NAME STREQUAL \"iOS\")")
    print(f"    set({var} src/{name}_ios.mm)" if "ios" in plats else f"    set({var} src/{name}_default.cpp)")
    print("elseif(ANDROID)")
    print(f"    set({var} src/{name}_android.cpp)" if "android" in plats else f"    set({var} src/{name}_default.cpp)")
    print("else()")
    print(f"    set({var} src/{name}_default.cpp)")
    print("endif()")

    return written


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("schema", type=Path)
    ap.add_argument("--out-root", type=Path, default=Path("."))
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    schema = json.loads(args.schema.read_text())
    generate(schema, args.out_root, args.force)
    return 0


if __name__ == "__main__":
    sys.exit(main())
