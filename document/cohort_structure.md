# Cohort object — deployment structure

This document describes the **intended hierarchy** for one player cohort: an **invisible anchor** (position, velocity, orientation) that owns a formation of soldier units. Each soldier is an independent physics body whose position is maintained relative to the cohort center.

---

## Hierarchy (tree)

```
Cohort container
├── Cohort anchor (invisible — world position, velocity, visual angle)
│   ├── Joystick steering input
│   └── Formation parameters (move speed, dead zone, aim-driven flag)
├── Soldier slot 1 (leader — index 0)
│   ├── Canonical slot (unrotated formation offset from cohort center)
│   ├── Local offset (current position relative to cohort center, physics-synced)
│   ├── Soldier container (see soldier_structure.md)
│   │   ├── Core body container
│   │   │   └── … (design parts + contact zone)
│   │   ├── Attack body container
│   │   │   └── … (attack parts + attack zone)
│   │   ├── Detection zone image
│   │   └── Center dot image
│   └── Contact body (Forge2D — polygon or circle from soldier's contact zone)
├── Soldier slot 2
│   ├── Canonical slot
│   ├── Local offset
│   ├── Soldier container
│   └── Contact body
├── …
└── Soldier slot N
    ├── Canonical slot
    ├── Local offset
    ├── Soldier container
    └── Contact body
```

---

## Current implementation note

In the current Flutter / Forge2D implementation, **Soldier slot 1 (index 0)** doubles as the cohort anchor — there is no separate invisible body. The leader soldier's physics body receives joystick steering directly, and all other soldiers compute formation targets relative to the leader's position. This means soldier 1's `localOffset` is always `(0, 0)`.

---

## Lifecycle

### 1. Deployment phase (inventory → war)

```
CohortDeployment
├── PlacedSoldier 0 (leader — first selected, defines cohort anchor)
│   ├── inventoryIndex
│   ├── type (SoldierType)
│   ├── localOffset (formation position in cohort space)
│   ├── soldierDesign? (SoldierDesign — polygon visual + contact hull)
│   └── cohortPalette (SoldierDesignPalette — color theme)
├── PlacedSoldier 1
│   └── (same fields)
├── …
└── PlacedSoldier N
    └── (same fields)
```

### 2. Runtime phase (war scene)

```
CohortRuntime
├── visualAngle — radians, instant orientation from joystick aim
├── localMoveSpeed — px/s soldier movement toward formation target
├── stickDeadZone — normalized threshold below which aim is held
├── aimDrivenFormation — if false, soldiers stay at canonical slots (enemy cohorts)
├── CohortSoldier 0 (leader)
│   ├── SoldierModel (visual — shape type, design, palette, paint size)
│   ├── SoldierContact (collision — hull polygon vertices + circumscribed radius)
│   ├── canonicalSlot (unrotated formation position in cohort space)
│   └── localOffset (current position relative to cohort center)
├── CohortSoldier 1
│   └── (same layers)
├── …
└── CohortSoldier N
    └── (same layers)
```

### 3. Physics phase (Forge2D bodies in war scene)

```
CohortWarGame
├── _leaderBody → playerSoldierBodies[0].body (receives joystick steering)
├── SoldierContactBody 0 (leader — polygon or circle shape)
├── SoldierContactBody 1 (formation PD forces toward rotated canonical slot)
├── …
├── SoldierContactBody N
├── EnemySoldier 0 (independent — no cohort, chases on detection)
│   ├── CohortSoldier (visual + contact)
│   └── SoldierContactBody (polygon or circle)
├── …
└── EnemySoldier M
    ├── CohortSoldier
    └── SoldierContactBody
```

---

## Node reference

### Cohort container

- **Role:** A deployable group of soldiers that moves and fights as one unit.
- **Transform:** World position (cohort center), velocity (joystick-driven), visual angle (aim direction).
- **Convention:** All soldier positions are expressed in **cohort space** (relative to cohort center). Cohort axes match screen axes: +x right, +y down. Default forward is `(0, -1)` (up on screen).

### Cohort anchor

- **Role:** The invisible pivot of the formation. Receives joystick input and defines the origin for all formation slot calculations.
- **Steering:** Joystick → normalized stick → force applied to anchor body → velocity → position.
- **Orientation:** `visualAngle = atan2(aim.x, -aim.y)` updates instantly each frame. Formation targets rotate by this angle.

### Soldier slot

- **Role:** One member of the formation.
- **Canonical slot:** The soldier's unrotated position in cohort space, set during deployment (inventory drag). This is the "home" position when visual angle is 0.
- **Formation target:** At runtime, `R(visualAngle) × canonicalSlot` gives the rotated target. The soldier's physics body is driven toward this target via PD (proportional-derivative) forces when the cohort is moving.
- **Local offset:** The soldier's actual current position relative to the cohort center. In war, this is synced from `body.position - leaderBody.position` each frame.
- **Children:** Each slot contains a full **Soldier container** (see `soldier_structure.md`) and a **Contact body** (Forge2D physics shape).

### Enemy soldiers

- **Role:** Independent units with no cohort grouping.
- **Behavior:** Each enemy has its own `CohortSoldier` (visual + contact) and `SoldierContactBody`. When stationary and a player enters detection range, the enemy chases toward the detected player. No formation forces — enemies act individually.

---

## Formation mechanics

| Parameter | Value | Description |
|-----------|-------|-------------|
| **cohortMaxSpeed** | 220 | Maximum cohort velocity (world units/s) |
| **steeringGain** | 7 | Force multiplier for joystick → leader acceleration |
| **soldierFormationGain** | 12 | PD position gain for formation keeping |
| **soldierFormationVelDamp** | 2√(gain) × 0.56 | PD velocity damping (critically damped at 56%) |
| **localMoveSpeed** | 90 | Soldier move speed for non-physics formation (inventory scene) |
| **stickDeadZone** | 0.06 | Normalized stick length below which aim is held |

### Formation update loop (per frame)

1. Snapshot all body velocities (for overshoot clamping).
2. **Steer** leader body via joystick force.
3. **Update** `CohortRuntime` — compute `visualAngle` from aim, no position integration (physics owns positions).
4. **Update** range entry maps (detection + attack timestamps for all soldier pairs).
5. **Apply formation forces** — for each non-chasing soldier, PD force toward `leaderPos + R(angle) × canonicalSlot`.
6. **Apply chase forces** — neutral stick + enemy in detection → soldier steers toward enemy.
7. **Forge2D step** — physics integration, collision resolution.
8. **Clamp** velocity reversals (spring overshoot protection).
9. **Sync** `localOffset` from body positions relative to leader.

---

## Design intent (summary)

| Group | Question it answers |
|-------|---------------------|
| **Cohort container** | Where is the group, how fast is it moving, which direction does it face? |
| **Cohort anchor** | What receives joystick input and defines formation origin? |
| **Soldier slot** | Where is each member relative to the group, and what does it look like? |
| **Canonical slot** | Where does this soldier belong in the default (unrotated) formation? |
| **Local offset** | Where is the soldier right now (may lag behind canonical slot during rotation)? |
| **Contact body** | What is the physics shape for collision with other soldiers? |
| **Enemy soldiers** | How do non-player units behave without a cohort? |

---

## Scope

This file specifies **target structure** for the cohort system. It describes both the intended hierarchy and the current Flutter / Forge2D implementation. For the internal structure of each soldier within a slot, see `soldier_structure.md`.
