# Dungeon Business

**Dungeon Business** is a Roblox dungeon-management game being developed by **Gruck Games**.

Instead of playing as the adventurer, you run the dungeon.

Build rooms, hire monsters, maintain traps, survive adventurer raids, collect loot, and grow your dungeon into a more profitable and dangerous operation.

> Early development / prototype stage.

---

## The Idea

Dungeon Business flips the usual dungeon crawler around.

Adventurers enter your dungeon looking for treasure. Your job is to make sure the dungeon is prepared for them.

Players will manage things such as:

- Dungeon rooms
- Traps
- Monsters and employees
- Repairs and maintenance
- Wages and operating costs
- Loot and dungeon income
- Dungeon expansion
- Adventurer raids

The dungeon is both a dangerous fantasy dungeon and a business that needs to stay profitable.

---

## Core Loop

The current direction is:

1. Build and arrange dungeon rooms.
2. Hire monsters to work in those rooms.
3. Maintain rooms and traps.
4. Open the dungeon to adventurers.
5. Watch the raid play out.
6. Earn loot and resources.
7. Repair damage and pay operating costs.
8. Upgrade and expand.
9. Repeat against increasingly capable adventurers.

Adventurers will eventually become better at dealing with dungeon mechanics, including things such as identifying or disarming traps.

---

## Current Prototype

The current playable slice focuses on proving the basic management loop.

Implemented or currently being developed:

- Bronze currency
- Dungeon room system
- Room condition / maintenance
- Repair interactions
- Monster hiring
- Monster wages
- Raid simulation
- Raid event log
- Loot / spoils
- Reputation progression
- Continuous raids
- Dungeon room asset loading
- Trap rooms
- Crypt rooms
- Treasure rooms
- Hallway assets
- Room connection markers
- Server-side validation for player actions

The dungeon layout system is still being developed and will continue to change as room connections, hallways, and dungeon generation are expanded.

---

## Room System

Dungeon rooms use a shared structure to keep art assets predictable for the game code.

A typical room looks roughly like:

```text
Room
├── Structure
│   ├── Floor
│   ├── Walls
│   └── Ceiling
├── Gameplay
│   ├── Connections
│   └── RepairSpot
└── Environment
    └── Decorations
