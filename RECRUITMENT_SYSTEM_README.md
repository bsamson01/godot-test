# NPC Recruitment System

This document describes the implementation of the NPC recruitment system as requested.

## Overview

The recruitment system allows gang members to recruit specific NPCs after they have been alive for at least 4 days. The process involves:

1. Commander gives a recruit order at the base
2. Gang member leaves base to find the target NPC
3. Gang member approaches and chats with the NPC
4. Gang member returns to base with the recruited NPC
5. NPC joins the faction and changes color

## Key Components

### 1. NPC Age Tracking (`scripts/components/npc_component.gd`)

- Added 4-day minimum age requirement for recruitment
- NPCs can only be recruited after `current_day - spawn_day >= 4`
- Updated `can_be_recruited()` method to check age

### 2. New Order Type (`scripts/models/order.gd`)

- Added `RECRUIT_SPECIFIC_NPC` order type
- Configured with appropriate travel, work, and return times
- Requires 2000 funds and has 70% success chance

### 3. Order Execution (`scripts/components/order_component.gd`)

- Added special execution logic for recruit specific NPC orders
- Validates target NPC exists and can be recruited
- Ensures order is given at base (within 5 units of faction base)

### 4. Commander AI (`scripts/ai/commander.gd`)

- Added logic to give recruit specific NPC orders when:
  - Faction has > 2000 funds
  - Faction has < 8 members
  - There are recruitable NPCs available
- Added `_get_recruitable_npcs()` method to find valid targets

### 5. Gang Member Behavior (`scripts/components/gang_member_component.gd`)

- Added `_get_target_npc_location()` method for recruit specific NPC orders
- Updated movement logic to handle the new order type

### 6. AI Behavior System (`ai/tasks/shared/execute_order.gd`)

- Integrated recruit specific NPC behavior directly into order execution
- Implements the complete recruitment flow:
  - **Find NPC**: Locate target NPC and validate it can be recruited
  - **Approach NPC**: Move to within 3 units of the NPC
  - **Chat with NPC**: Spend 6 seconds convincing the NPC (with progress display)
  - **Return to Base**: Lead the recruited NPC back to faction base
  - **Complete Recruitment**: Convert NPC to gang member and add to faction

### 7. Faction Integration

- NPCs are converted to gang members when they reach the base
- Visual nodes are updated with faction colors
- NPCs are added to the faction's member list
- Events are emitted for successful recruitment

## Recruitment Flow

1. **Order Creation**: Commander creates a `RECRUIT_SPECIFIC_NPC` order targeting a specific NPC
2. **Order Assignment**: Order is assigned to an available gang member
3. **Execution**: Gang member executes the recruitment behavior:
   - Leaves base to find target NPC
   - Approaches NPC (tracks moving NPCs)
   - Chats with NPC for 6 seconds
   - Returns to base with recruited NPC
4. **Completion**: NPC joins faction, changes color, and becomes a gang member

## Key Features

- **Age Requirement**: NPCs must be alive for 4+ days before recruitment
- **Base-Only Orders**: Recruit orders can only be given at the faction base
- **Dynamic Tracking**: System tracks moving NPCs during recruitment
- **Visual Feedback**: Progress indicators and status updates during recruitment
- **Faction Integration**: Seamless conversion from NPC to gang member
- **Color Changes**: Recruited NPCs change to faction colors

## Testing

A test script (`test/recruitment_test.gd`) is provided to verify the system works correctly. It checks for:
- NPC generation and age tracking
- Faction and commander availability
- Order creation and assignment
- Recruitment flow execution

## Usage

The system works automatically - commanders will give recruit orders when conditions are met, and gang members will execute them. No manual intervention is required, but the system can be tested using the provided test script.
