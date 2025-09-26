# Design Document

## Overview

The Meal Plan & Shopping UI Flow is a comprehensive SwiftUI frontend module that integrates seamlessly into the existing TribeBoard app architecture. The design leverages the established design system, navigation patterns, and brand identity while introducing new HomeLife functionality. The module consists of three interconnected components: Meal Planning, Grocery & Shopping, and Task Integration, all accessible through a new navigation tab.

The design prioritizes family-oriented user experience with clear visual hierarchy, intuitive navigation flows, and consistent interaction patterns. All data is managed through placeholder models that mirror the existing TribeBoard data architecture, ensuring smooth integration when backend connectivity is added later.

## Architecture

### Navigation Integration

The HomeLife module integrates into the existing TribeBoard navigation system by extending the `NavigationTab` enum and updating the main navigation flow:

```swift
// Extension to NavigationTab enum
case homeLife = "homeLife"

// Navigation properties
var displayName: String {
    case .homeLife: return "HomeLife"
}

var icon: String {
    case .homeLife: return "house.heart"
}

var activeIcon: String {
    case .homeLife: return "house.heart.fill"
}
```

### Data Architecture

The module follows TribeBoard's established data patterns using ObservableObject view models and placeholder data structures:

```swift
// Core data models
struct MealPlan: Identifiable, Codable
struct Ingredient: Identifiable, Codable
struct GroceryItem: Identifiable, Codable
struct ShoppingTask: Identifiable, Codable

// View models
class MealPlanViewModel: ObservableObject
class GroceryListViewModel: ObservableObject
class TaskCreationViewModel: ObservableObject
```

### State Management

State management follows the existing AppState pattern with dedicated HomeLife state management:

```swift
extension AppState {
    // HomeLife navigation state
    @Published var homeLifeNavigationPath = NavigationPath()
    @Published var selectedHomeLifeTab: HomeLifeTab = .mealPlan
    
    // HomeLife data state
    @Published var currentMealPlan: MealPlan?
    @Published var groceryList: [GroceryItem] = []
    @Published var shoppingTasks: [ShoppingTask] = []
}
```

## Components and Interfaces

### 1. HomeLife Navigation Hub

**Purpose**: Central navigation point for all HomeLife features
**Location**: Accessible via bottom navigation tab

**Design Elements**:
- Grid layout with feature cards
- Each card shows icon, title, and brief description
- Cards use brand gradient backgrounds with white text
- Consistent with existing TribeBoard card design patterns

**Navigation Cards**:
- 🍽️ Meal Plan - "Plan your family meals"
- 🛒 Grocery List - "Manage shopping lists"
- ✅ Tasks - "Assign shopping tasks"
- 📋 Pantry - "Check what you have"

### 2. Meal Plan Dashboard (MealPlanDashboardView)

**Purpose**: Display monthly meal plan with ingredient tracking

**Layout Structure**:
```
┌─────────────────────────────────┐
│ Navigation Bar: "Meal Plan"     │
├─────────────────────────────────┤
│ Month Selector (< October >)    │
├─────────────────────────────────┤
│ Calendar/List Toggle            │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ Meal Card - Monday          │ │
│ │ Spaghetti Bolognese         │ │
│ │ 🥕 Carrots, 🍅 Tomatoes     │ │
│ │ [Check Pantry] Button       │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ Meal Card - Tuesday         │ │
│ │ Chicken Stir Fry            │ │
│ │ 🐔 Chicken, 🥦 Broccoli     │ │
│ │ [Check Pantry] Button       │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

**Design Specifications**:
- Uses DesignSystem.Typography.headlineMedium for meal names
- Ingredient lists use DesignSystem.Typography.bodySmall with emoji icons
- Cards have DesignSystem.Shadow.medium and BrandStyle.cornerRadius
- "Check Pantry" buttons use brand primary color with white text

### 3. Pantry Check View (PantryCheckView)

**Purpose**: Allow users to check off available ingredients

**Layout Structure**:
```
┌─────────────────────────────────┐
│ Navigation: "Pantry Check"      │
│ Week of Oct 14-20               │
├─────────────────────────────────┤
│ ☐ Carrots (2 cups)             │
│ ☑ Tomatoes (4 medium)          │
│ ☐ Ground Beef (1 lb)           │
│ ☑ Onions (1 large)             │
│ ☐ Pasta (1 box)                │
├─────────────────────────────────┤
│ [Generate Grocery List] Button  │
└─────────────────────────────────┘
```

**Interaction Design**:
- Checkboxes use brand primary color when selected
- Smooth animation when toggling items (DesignSystem.Animation.quick)
- Haptic feedback on checkbox interactions
- Generate button becomes prominent when items are unchecked

### 4. Grocery List View (GroceryListView)

**Purpose**: Manage weekly grocery lists and urgent additions

**Tab Structure**:
```
┌─────────────────────────────────┐
│ [Weekly List] [Urgent Items]    │
├─────────────────────────────────┤
│ Weekly Grocery List Tab:        │
│ ┌─────────────────────────────┐ │
│ │ Carrots (2 cups)            │ │
│ │ For: Spaghetti Bolognese    │ │
│ │ Added by: Mom               │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ Pasta (1 box)               │ │
│ │ For: Spaghetti Bolognese    │ │
│ │ Added by: System            │ │
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│ [Order Online] Button           │
└─────────────────────────────────┘
```

**Design Features**:
- Segmented control for tab switching
- Item cards show hierarchy: Item name (large), meal context (medium), attribution (small)
- Empty states with encouraging messaging and illustrations
- Swipe actions for item management (edit, delete)

### 5. Order Platform Selection (OrderPlatformSelectionView)

**Purpose**: Choose grocery delivery platform

**Layout Design**:
```
┌─────────────────────────────────┐
│ "Choose Delivery Platform"      │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ [Woolworths Logo]           │ │
│ │ Woolies Dash                │ │
│ │ "Fast delivery in 2 hours"  │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ [Checkers Logo]             │ │
│ │ Checkers Sixty60            │ │
│ │ "Delivery within 60 mins"   │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ [Pick n Pay Logo]           │ │
│ │ Pick n Pay asap!            │ │
│ │ "Same day delivery"         │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

**Interaction Design**:
- Platform cards have hover/press states with scale animation
- Success feedback with checkmark animation after selection
- Toast notification confirming list sent to platform

### 6. Task Creation View (TaskCreationView)

**Purpose**: Convert grocery items into family tasks

**Form Layout**:
```
┌─────────────────────────────────┐
│ "Create Shopping Task"          │
├─────────────────────────────────┤
│ Items to Purchase:              │
│ • Carrots (2 cups)              │
│ • Pasta (1 box)                 │
├─────────────────────────────────┤
│ Assign to: [Family Member ▼]    │
│ Task Type: [Shop Run ▼]         │
│ Due Time: [Today 5:00 PM ▼]     │
│ Notes: [Text Field]             │
├─────────────────────────────────┤
│ Location (if applicable):       │
│ [Map Placeholder View]          │
├─────────────────────────────────┤
│ [Create Task] Button            │
└─────────────────────────────────┘
```

**Design Elements**:
- Form follows TribeBoard's input styling
- Dropdown menus use native iOS picker style
- Map placeholder shows generic location pin
- Create button uses brand gradient background

### 7. Task List View (TaskListView)

**Purpose**: Display and filter shopping tasks

**List Design**:
```
┌─────────────────────────────────┐
│ "Shopping Tasks"                │
│ [All ▼] [Due Today ▼] [Person ▼]│
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 🛒 Shop Run                 │ │
│ │ Assigned to: Sarah          │ │
│ │ Due: Today 5:00 PM          │ │
│ │ Status: [Pending]           │ │
│ │ Items: Carrots, Pasta       │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ 🚗🛒 School Run + Shop      │ │
│ │ Assigned to: Dad            │ │
│ │ Due: Tomorrow 3:30 PM       │ │
│ │ Status: [In Progress]       │ │
│ │ Items: Milk, Bread          │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

**Status Design**:
- Status badges use semantic colors (yellow for pending, blue for in progress, green for complete)
- Task cards show priority with left border color
- Swipe actions for task management

## Data Models

### Core Models

```swift
struct MealPlan: Identifiable, Codable {
    let id = UUID()
    let month: Date
    let meals: [PlannedMeal]
}

struct PlannedMeal: Identifiable, Codable {
    let id = UUID()
    let name: String
    let date: Date
    let ingredients: [Ingredient]
    let servings: Int
}

struct Ingredient: Identifiable, Codable {
    let id = UUID()
    let name: String
    let quantity: String
    let unit: String
    let emoji: String
    var isAvailableInPantry: Bool = false
}

struct GroceryItem: Identifiable, Codable {
    let id = UUID()
    let ingredient: Ingredient
    let linkedMeal: String?
    let addedBy: String
    let addedDate: Date
    let isUrgent: Bool
}

struct ShoppingTask: Identifiable, Codable {
    let id = UUID()
    let items: [GroceryItem]
    let assignedTo: String
    let taskType: TaskType
    let dueDate: Date
    let notes: String?
    let location: TaskLocation?
    var status: TaskStatus
}

enum TaskType: String, CaseIterable {
    case shopRun = "Shop Run"
    case schoolRunPlusShop = "School Run + Shop Stop"
}

enum TaskStatus: String, CaseIterable {
    case pending = "Pending"
    case inProgress = "In Progress"
    case completed = "Completed"
}
```

### Placeholder Data Structure

```swift
class MealPlanDataProvider {
    static func mockMealPlan() -> MealPlan
    static func mockIngredients() -> [Ingredient]
    static func mockGroceryItems() -> [GroceryItem]
    static func mockShoppingTasks() -> [ShoppingTask]
}
```

## Error Handling

### Error States

1. **Empty States**:
   - No meals planned: "Start planning your family meals"
   - Empty grocery list: "Your grocery list is empty"
   - No tasks: "No shopping tasks assigned"

2. **Loading States**:
   - Meal plan loading: Skeleton cards with shimmer effect
   - Generating grocery list: Progress indicator with "Analyzing pantry..."
   - Creating task: Button loading state with spinner

3. **Error Recovery**:
   - Failed to load data: Retry button with error message
   - Network issues: Offline mode indicator
   - Invalid form data: Inline validation messages

### Error Handling Implementation

```swift
enum HomeLifeError: LocalizedError {
    case mealPlanLoadFailed
    case groceryListGenerationFailed
    case taskCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .mealPlanLoadFailed:
            return "Unable to load meal plan. Please try again."
        case .groceryListGenerationFailed:
            return "Failed to generate grocery list. Please check your selections."
        case .taskCreationFailed:
            return "Unable to create task. Please verify all fields."
        }
    }
}
```

## Testing Strategy

### Unit Testing

1. **View Model Testing**:
   - Test meal plan data loading and filtering
   - Test grocery list generation logic
   - Test task creation validation
   - Test state management and navigation

2. **Model Testing**:
   - Test data model serialization/deserialization
   - Test placeholder data generation
   - Test data validation rules

### UI Testing

1. **Navigation Testing**:
   - Test HomeLife tab integration
   - Test navigation between HomeLife screens
   - Test back navigation and state preservation

2. **Interaction Testing**:
   - Test pantry check interactions
   - Test grocery list management
   - Test task creation flow
   - Test platform selection

3. **Accessibility Testing**:
   - Test VoiceOver navigation
   - Test Dynamic Type support
   - Test high contrast mode
   - Test reduced motion preferences

### Integration Testing

1. **AppState Integration**:
   - Test HomeLife state management within AppState
   - Test navigation coordination with existing tabs
   - Test data persistence during app lifecycle

2. **Design System Integration**:
   - Test consistent styling across all views
   - Test brand color usage
   - Test typography consistency
   - Test spacing and layout adherence

### Testing Implementation

```swift
// Example test structure
class MealPlanViewModelTests: XCTestCase {
    func testMealPlanLoading()
    func testIngredientFiltering()
    func testGroceryListGeneration()
}

class HomeLifeNavigationTests: XCTestCase {
    func testTabIntegration()
    func testScreenNavigation()
    func testStatePreservation()
}

class HomeLifeAccessibilityTests: XCTestCase {
    func testVoiceOverSupport()
    func testDynamicTypeSupport()
    func testHighContrastSupport()
}
```

## Design System Integration

### Typography Usage

- **Display fonts**: Feature titles and main headings
- **Headline fonts**: Screen titles and section headers
- **Title fonts**: Card titles and component headers
- **Body fonts**: Main content and descriptions
- **Label fonts**: Form labels and UI elements
- **Caption fonts**: Secondary information and metadata

### Color Palette

- **Brand Primary**: Main action buttons, selected states
- **Brand Secondary**: Secondary actions, accents
- **Brand Gradient**: Feature cards, hero sections
- **System Colors**: Status indicators, semantic meanings
- **Adaptive Colors**: Text and backgrounds that adapt to light/dark mode

### Spacing and Layout

- **Screen Padding**: DesignSystem.Spacing.screenPadding (20pt)
- **Card Padding**: DesignSystem.Spacing.cardPadding (16pt)
- **Element Spacing**: DesignSystem.Spacing.elementSpacing (16pt)
- **Component Spacing**: DesignSystem.Spacing.componentSpacing (24pt)
- **Section Spacing**: DesignSystem.Spacing.sectionSpacing (32pt)

### Animation and Transitions

- **Quick animations**: Checkbox toggles, button presses (0.2s)
- **Standard animations**: Screen transitions, state changes (0.3s)
- **Smooth animations**: Page navigation, major transitions (0.4s)
- **Spring animations**: Success states, playful interactions

### Accessibility Compliance

1. **VoiceOver Support**:
   - All interactive elements have accessibility labels
   - Proper heading hierarchy for screen readers
   - Meaningful accessibility hints for complex interactions

2. **Dynamic Type**:
   - All text scales with user's preferred text size
   - Layout adapts to larger text sizes
   - Minimum touch target sizes maintained

3. **Color and Contrast**:
   - High contrast mode support
   - Color is not the only way to convey information
   - Status indicators use both color and text/icons

4. **Reduced Motion**:
   - Respects user's reduced motion preferences
   - Essential animations can be disabled
   - Alternative static states for motion-sensitive users

This design ensures the Meal Plan & Shopping UI Flow integrates seamlessly with TribeBoard's existing architecture while providing a comprehensive, family-friendly experience for meal planning and grocery management.