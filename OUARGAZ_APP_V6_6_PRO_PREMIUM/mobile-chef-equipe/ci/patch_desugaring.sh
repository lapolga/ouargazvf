#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# patch_desugaring.sh
# Active le "core library desugaring" dans le build Gradle de l'app Android,
# APRÈS la régénération du dossier android par `flutter create`.
#
# Gère AUTOMATIQUEMENT les deux formats selon la version de Flutter :
#   - android/app/build.gradle      (Groovy DSL  — Flutter <= 3.24)
#   - android/app/build.gradle.kts  (Kotlin DSL  — Flutter >= 3.27)
#
# Idempotent : peut être exécuté plusieurs fois sans dupliquer les blocs.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

KTS="android/app/build.gradle.kts"
GROOVY="android/app/build.gradle"

if [ -f "$KTS" ]; then
  GRADLE_FILE="$KTS"; DSL="kotlin"
elif [ -f "$GROOVY" ]; then
  GRADLE_FILE="$GROOVY"; DSL="groovy"
else
  echo "❌ Aucun build.gradle(.kts) trouvé dans android/app/. Lancez d'abord 'flutter create'."
  ls -la android/app/ || true
  exit 1
fi

echo "🔧 Patch desugaring sur $GRADLE_FILE (DSL: $DSL)"
cp "$GRADLE_FILE" "${GRADLE_FILE}.bak"

python3 - "$GRADLE_FILE" "$DSL" << 'PYEOF'
import re, sys

path, dsl = sys.argv[1], sys.argv[2]
src = open(path, encoding="utf-8").read()

if dsl == "kotlin":
    DESUGAR_DEP   = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")'
    ENABLE_LINE   = "        isCoreLibraryDesugaringEnabled = true"
    COMPILE_BLOCK = (
        "    compileOptions {\n"
        "        isCoreLibraryDesugaringEnabled = true\n"
        "        sourceCompatibility = JavaVersion.VERSION_17\n"
        "        targetCompatibility = JavaVersion.VERSION_17\n"
        "    }\n"
    )
    has_enable = "isCoreLibraryDesugaringEnabled" in src
else:  # groovy
    DESUGAR_DEP   = "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'"
    ENABLE_LINE   = "        coreLibraryDesugaringEnabled true"
    COMPILE_BLOCK = (
        "    compileOptions {\n"
        "        coreLibraryDesugaringEnabled true\n"
        "        sourceCompatibility JavaVersion.VERSION_17\n"
        "        targetCompatibility JavaVersion.VERSION_17\n"
        "    }\n"
    )
    has_enable = "coreLibraryDesugaringEnabled" in src

# 1) compileOptions dans android { ... }
if not has_enable:
    if re.search(r"compileOptions\s*\{", src):
        src = re.sub(r"(compileOptions\s*\{)", r"\1\n" + ENABLE_LINE, src, count=1)
    else:
        src = re.sub(r"(android\s*\{)", r"\1\n" + COMPILE_BLOCK, src, count=1)

# 2) dépendance coreLibraryDesugaring dans dependencies { ... }
if "desugar_jdk_libs" not in src:
    m = re.search(r"\ndependencies\s*\{", src)
    if m:
        src = re.sub(r"(\ndependencies\s*\{)", r"\1\n    " + DESUGAR_DEP, src, count=1)
    else:
        src = src.rstrip() + "\n\ndependencies {\n    " + DESUGAR_DEP + "\n}\n"

open(path, "w", encoding="utf-8").write(src)
print("✓ %s patché (%s)" % (path, dsl))
PYEOF

echo "───────── Aperçu compileOptions / dependencies ─────────"
grep -n "CoreLibraryDesugaringEnabled\|desugar_jdk_libs\|compileOptions\|^dependencies" "$GRADLE_FILE" || true
echo "✅ Patch desugaring terminé"
