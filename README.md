# SwiftUI-Presentation-Coordinator

A **stack-driven coordinator** for managing SwiftUI modal presentations  
(`sheet`, `bottom sheet`, `transparent full-screen overlay`)  
with **consistent dismiss rules** and **nested presentation support**.

This repository is intentionally **small and focused**.  
It exists to demonstrate *how* modal presentation logic can be structured in SwiftUI — not to provide a full UI framework.

# Demo  
<p align="center">
  <img 
    src="https://github.com/blackman5566/SwiftUI-Presentation-Coordinator/blob/main/demo.gif" 
    alt="Notification Demo" 
    width="320"
  />
</p>

---

---

## Why this exists

SwiftUI works well for simple cases, but presentation logic becomes difficult when you need:

- Multiple modal types (`sheet`, custom bottom sheet, overlay-style alerts)
- Nested presentations (A → B → C)
- Predictable dismiss behavior
- Views that don’t want to own `@State isPresented`

This project explores one core idea:

> **Treat modal presentation as a stack, not as scattered state flags.**

---

## Core Idea

Each modal presentation is represented as a **Route** in a stack.

- The stack index = presentation **level**
- Presenting pushes a new route
- Dismissing level `N` removes `N...top`

```
Level 0 ─ Sheet
Level 1 ─ Bottom Sheet
Level 2 ─ Alert Overlay
```

Views only express *intent* (“present this view”).  
The Coordinator decides *how* and *where* it is presented.

---

## Architecture Overview

### 1. Coordinator
- Owns a `routeStack`
- Handles `present` and dismiss rules
- Does not depend on concrete view types

### 2. CoordinatorViewModifier
- A **recursive ViewModifier**
- Each instance is responsible for one stack level
- Enables unlimited nested modal presentation

### 3. BottomSheetModifier
- Custom bottom sheet built on `.presentationDetents`
- Automatically adapts its height to content

### 4. TransparentFullScreen
- UIKit-based workaround for transparent `fullScreenCover`
- Enables overlay-style alerts and popups

---

## Demo App

The demo app is intentionally minimal.

It demonstrates:
- Sheet / Bottom Sheet / Alert Overlay
- Nested modal flow (Level 1 → Level 2 → Level 3)
- Stack-based dismiss behavior

### How to try it

1. Run the demo app
2. Open nested modals
3. Dismiss a lower level and observe how upper levels are removed automatically

---

## Basic Usage

### 1. Attach the modifier once

```swift
RootView()
    .modifier(CoordinatorViewModifier())
```

You only attach this **once**, usually at the app root.

---

### 2. Present from anywhere

```swift
Coordinator.shared.present(type: .sheet) { isPresented in
    MyModalView(isPresented: isPresented)
}
```

No `@State isPresented`, no `@Environment(\.dismiss)`.

---

### 3. Nested presentation

```swift
Coordinator.shared.present(type: .bottomSheet) { _ in
    NextLevelView()
}
```

Each nested modal is handled by the next recursive modifier.

---

### 4. Dismiss behavior

- Swipe down or programmatic dismiss triggers:
  - `dismiss level N → remove N...top`
- Optional `onDismiss` callbacks allow cleanup logic

---

## What this is *not*

This project is **not**:
- A navigation framework
- A UI component library
- A replacement for `NavigationStack`

It focuses **only** on modal presentation.

---

## Inspiration

This demo is inspired by the approach used in  
**unstoppable-wallet-ios**.

While reading the project, I found their way of handling SwiftUI modal presentation both practical and interesting.  
I extracted the core idea and rebuilt it as a **smaller, learnable demo**, focusing on:

- stack / level–based modal management
- recursive ViewModifier rendering
- centralized present/dismiss rules

> This repository is a simplified educational extraction, not a copy of the original project.

---

## When should you use this pattern?

This pattern makes sense when:
- Your app has complex modal flows
- You need predictable dismiss behavior
- You want to keep views declarative and stateless

If your app only presents a single sheet, this is probably unnecessary.

---

## Trade-offs

- Uses `AnyView` for type erasure
- `TransparentFullScreen` relies on UIKit view hierarchy behavior
- Designed for clarity and learning, not maximum abstraction

---

## License

MIT  
Use it, adapt it, or extract parts you find useful.
