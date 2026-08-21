import re

SRC = r"C:\Users\jreis\Documents\App-Registro-Ocorrencia\assets\brasil-map-source.svg"
DASH = r"C:\Users\jreis\Documents\App-Registro-Ocorrencia\dashboard.html"

with open(SRC, encoding="utf-8") as f:
    svg = f.read()

assert "</svg>" in svg or "</svg>" in svg.replace("\r\n", "\n")

# Drop the embedded <style> block — dashboard.html already styles .state via
# #brazil-map .state {...} and drives fill per-state from JS; keeping the
# source stylesheet would fight that with its own hover fill.
svg = re.sub(r"<style[^>]*>.*?</style>", "", svg, flags=re.S)

# Tag the root <svg> so our JS/CSS can target it, and drop the fixed pixel
# width/height so CSS (`width:100%; height:auto`) controls the size instead.
svg = svg.replace('id="Layer_1"', 'id="brazil-map"', 1)
svg = re.sub(r'\s+width="[\d.]+px"', "", svg, count=1)
svg = re.sub(r'\s+height="[\d.]+px"', "", svg, count=1)

svg = svg.strip()

assert "id=\"brazil-map\"" in svg
for uf in ["SP", "RJ", "MG", "RS", "BA", "AM", "DF"]:
    assert f'id="{uf}"' in svg, f"missing state id {uf}"

js_const = "const BRAZIL_MAP_SVG = `" + svg.replace("\\", "\\\\").replace("`", "\\`") + "`;\n"

with open(DASH, encoding="utf-8") as f:
    dash = f.read()

marker = "let state = {"
assert marker in dash
assert "const BRAZIL_MAP_SVG" not in dash, "already injected — run only once, or remove old block first"
dash = dash.replace(marker, js_const + "\n" + marker, 1)

with open(DASH, "w", encoding="utf-8") as f:
    f.write(dash)

print("injected, svg length:", len(svg))
