#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
swiftc -warnings-as-errors Sources/Model/*.swift Sources/Platform/DockStateStore.swift Sources/Application/DockSession.swift Tests/main.swift -o .build/model-tests
.build/model-tests
swiftc -warnings-as-errors Sources/Model/*.swift Sources/Platform/AppCatalog.swift Sources/Platform/DockDragPayload.swift Tests/AppInputs/main.swift -o .build/input-tests
.build/input-tests
swiftc -warnings-as-errors Sources/Model/*.swift Sources/Application/DockAction.swift Sources/Platform/AppCatalog.swift Sources/Platform/DockDragPayload.swift Sources/Presentation/DockAppearance.swift Sources/Presentation/DockItem.swift Sources/Presentation/DockLayout.swift Tests/Presentation/main.swift -o .build/presentation-tests
.build/presentation-tests
swiftc -warnings-as-errors Sources/Model/MaximizedWindowArea.swift Tests/WindowSpace/main.swift -o .build/window-space-tests
.build/window-space-tests
