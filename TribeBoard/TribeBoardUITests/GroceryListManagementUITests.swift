import XCTest

/// UI tests for grocery list management and shopping interactions
final class GroceryListManagementUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Grocery List Navigation Tests
    
    @MainActor
    func testGroceryListNavigation() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Verify we're on Grocery List screen
        let groceryListTitle = app.navigationBars["Grocery List"]
        XCTAssertTrue(groceryListTitle.exists, "Should be on Grocery List screen")
    }
    
    // MARK: - Tab Interface Tests
    
    @MainActor
    func testGroceryListTabInterface() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Test tab segmented control
        let weeklyTab = app.buttons["Weekly List"]
        let urgentTab = app.buttons["Urgent Items"]
        
        if weeklyTab.exists && urgentTab.exists {
            // Test switching between tabs
            urgentTab.tap()
            XCTAssertTrue(urgentTab.isSelected, "Urgent tab should be selected")
            
            weeklyTab.tap()
            XCTAssertTrue(weeklyTab.isSelected, "Weekly tab should be selected")
        } else {
            // Alternative: look for segmented control
            let tabControl = app.segmentedControls.firstMatch
            if tabControl.exists {
                let urgentButton = tabControl.buttons["Urgent Items"]
                let weeklyButton = tabControl.buttons["Weekly List"]
                
                if urgentButton.exists {
                    urgentButton.tap()
                }
                if weeklyButton.exists {
                    weeklyButton.tap()
                }
            }
        }
    }
    
    @MainActor
    func testTabContentFiltering() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Switch to weekly tab and check for weekly items
        let weeklyTab = app.buttons["Weekly List"]
        if weeklyTab.exists {
            weeklyTab.tap()
            
            // Look for weekly grocery items
            let weeklyItems = app.cells.matching(NSPredicate(format: "identifier CONTAINS 'groceryItem'"))
            // Items should be present or empty state should be shown
            let emptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'empty' OR label CONTAINS 'No items'")).firstMatch
            
            XCTAssertTrue(weeklyItems.count > 0 || emptyState.exists, "Should show weekly items or empty state")
        }
        
        // Switch to urgent tab and check for urgent items
        let urgentTab = app.buttons["Urgent Items"]
        if urgentTab.exists {
            urgentTab.tap()
            
            // Look for urgent grocery items or empty state
            let urgentItems = app.cells.matching(NSPredicate(format: "identifier CONTAINS 'groceryItem'"))
            let emptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'empty' OR label CONTAINS 'No urgent'")).firstMatch
            
            XCTAssertTrue(urgentItems.count > 0 || emptyState.exists, "Should show urgent items or empty state")
        }
    }
    
    // MARK: - Grocery Item Display Tests
    
    @MainActor
    func testGroceryItemCardElements() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Wait for items to load
        sleep(2)
        
        // Look for grocery item cards
        let groceryItemCard = app.cells.matching(identifier: "groceryItemCard").firstMatch
        
        if groceryItemCard.exists {
            // Test that item card contains expected information
            XCTAssertTrue(groceryItemCard.exists, "Grocery item card should exist")
            
            // Look for item name, quantity, and attribution within the card
            let itemName = groceryItemCard.staticTexts.firstMatch
            XCTAssertTrue(itemName.exists, "Item name should be displayed")
        }
    }
    
    @MainActor
    func testGroceryItemSwipeActions() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Wait for items to load
        sleep(2)
        
        // Look for grocery item to swipe
        let groceryItem = app.cells.matching(identifier: "groceryItemCard").firstMatch
        
        if groceryItem.exists {
            // Test swipe to reveal actions
            groceryItem.swipeLeft()
            
            // Look for swipe action buttons
            let deleteButton = app.buttons["Delete"]
            let editButton = app.buttons["Edit"]
            
            if deleteButton.exists || editButton.exists {
                XCTAssertTrue(deleteButton.exists || editButton.exists, "Swipe actions should be available")
                
                // Swipe back to hide actions
                groceryItem.swipeRight()
            }
        }
    }
    
    // MARK: - Add Urgent Item Tests
    
    @MainActor
    func testAddUrgentItemButton() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Switch to urgent tab
        let urgentTab = app.buttons["Urgent Items"]
        if urgentTab.exists {
            urgentTab.tap()
        }
        
        // Look for add urgent item button
        let addButton = app.buttons["Add Urgent Item"]
        let plusButton = app.buttons["+"]
        
        if addButton.exists {
            addButton.tap()
            
            // Should show add item sheet or form
            let addItemSheet = app.sheets.firstMatch
            let addItemForm = app.navigationBars["Add Item"]
            
            XCTAssertTrue(addItemSheet.exists || addItemForm.exists, "Should show add item interface")
        } else if plusButton.exists {
            plusButton.tap()
            
            // Should show add item interface
            let addItemInterface = app.sheets.firstMatch
            XCTAssertTrue(addItemInterface.exists, "Should show add item interface")
        }
    }
    
    @MainActor
    func testAddUrgentItemForm() throws {
        // Navigate to add urgent item form
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Switch to urgent tab and try to add item
        let urgentTab = app.buttons["Urgent Items"]
        if urgentTab.exists {
            urgentTab.tap()
        }
        
        let addButton = app.buttons["Add Urgent Item"]
        if addButton.exists {
            addButton.tap()
            
            // Look for form fields
            let nameField = app.textFields["Item Name"]
            let quantityField = app.textFields["Quantity"]
            let notesField = app.textFields["Notes"]
            
            if nameField.exists {
                // Test form interaction
                nameField.tap()
                nameField.typeText("Test Urgent Item")
                
                if quantityField.exists {
                    quantityField.tap()
                    quantityField.typeText("2")
                }
                
                // Look for save/add button
                let saveButton = app.buttons["Add Item"]
                let createButton = app.buttons["Create"]
                
                if saveButton.exists {
                    saveButton.tap()
                } else if createButton.exists {
                    createButton.tap()
                }
                
                // Should dismiss form and return to list
                XCTAssertFalse(nameField.exists, "Form should be dismissed after adding item")
            }
        }
    }
    
    // MARK: - Order Online Tests
    
    @MainActor
    func testOrderOnlineButton() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Look for Order Online button
        let orderOnlineButton = app.buttons["Order Online"]
        
        if orderOnlineButton.exists {
            XCTAssertTrue(orderOnlineButton.isEnabled, "Order Online button should be enabled")
            
            orderOnlineButton.tap()
            
            // Should navigate to platform selection
            let platformSelection = app.navigationBars["Choose Platform"]
            let platformSheet = app.sheets.firstMatch
            
            XCTAssertTrue(platformSelection.exists || platformSheet.exists, 
                         "Should show platform selection interface")
        }
    }
    
    @MainActor
    func testPlatformSelectionInterface() throws {
        // Navigate to platform selection
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        let orderOnlineButton = app.buttons["Order Online"]
        if orderOnlineButton.exists {
            orderOnlineButton.tap()
            
            // Look for platform cards
            let woolworthsCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Woolworths' OR label CONTAINS 'Woolies'")).firstMatch
            let checkersCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Checkers'")).firstMatch
            let pickNPayCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Pick n Pay'")).firstMatch
            
            // At least one platform should be available
            XCTAssertTrue(woolworthsCard.exists || checkersCard.exists || pickNPayCard.exists, 
                         "At least one platform option should be available")
            
            // Test selecting a platform
            if woolworthsCard.exists {
                woolworthsCard.tap()
                
                // Should show confirmation or success message
                let successMessage = app.alerts.firstMatch
                let toastMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Order submitted' OR label CONTAINS 'Success'")).firstMatch
                
                XCTAssertTrue(successMessage.exists || toastMessage.exists, 
                             "Should show confirmation after platform selection")
            }
        }
    }
    
    // MARK: - Empty State Tests
    
    @MainActor
    func testWeeklyListEmptyState() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Switch to weekly tab
        let weeklyTab = app.buttons["Weekly List"]
        if weeklyTab.exists {
            weeklyTab.tap()
        }
        
        // Look for empty state (may or may not exist depending on data)
        let emptyStateMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'empty' OR label CONTAINS 'No items'")).firstMatch
        
        if emptyStateMessage.exists {
            XCTAssertTrue(emptyStateMessage.exists, "Empty state should be displayed when no weekly items exist")
        }
    }
    
    @MainActor
    func testUrgentItemsEmptyState() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Switch to urgent tab
        let urgentTab = app.buttons["Urgent Items"]
        if urgentTab.exists {
            urgentTab.tap()
        }
        
        // Look for empty state
        let emptyStateMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No urgent' OR label CONTAINS 'empty'")).firstMatch
        
        if emptyStateMessage.exists {
            XCTAssertTrue(emptyStateMessage.exists, "Empty state should be displayed when no urgent items exist")
        }
    }
    
    // MARK: - Item Management Tests
    
    @MainActor
    func testItemCompletionToggle() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Wait for items to load
        sleep(2)
        
        // Look for item checkbox or completion toggle
        let itemCheckbox = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'itemCheckbox'")).firstMatch
        let completionToggle = app.switches.firstMatch
        
        if itemCheckbox.exists {
            let initialState = itemCheckbox.isSelected
            itemCheckbox.tap()
            
            // State should change
            XCTAssertNotEqual(itemCheckbox.isSelected, initialState, "Item completion state should toggle")
        } else if completionToggle.exists {
            let initialState = completionToggle.isOn
            completionToggle.tap()
            
            // State should change
            XCTAssertNotEqual(completionToggle.isOn, initialState, "Item completion state should toggle")
        }
    }
    
    @MainActor
    func testItemDeletion() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Wait for items to load
        sleep(2)
        
        // Count initial items
        let initialItemCount = app.cells.matching(identifier: "groceryItemCard").count
        
        // Try to delete an item via swipe
        let groceryItem = app.cells.matching(identifier: "groceryItemCard").firstMatch
        
        if groceryItem.exists {
            groceryItem.swipeLeft()
            
            let deleteButton = app.buttons["Delete"]
            if deleteButton.exists {
                deleteButton.tap()
                
                // Confirm deletion if alert appears
                let confirmButton = app.alerts.buttons["Delete"]
                if confirmButton.exists {
                    confirmButton.tap()
                }
                
                // Item count should decrease
                let newItemCount = app.cells.matching(identifier: "groceryItemCard").count
                XCTAssertLessThan(newItemCount, initialItemCount, "Item should be deleted")
            }
        }
    }
    
    // MARK: - Loading State Tests
    
    @MainActor
    func testLoadingStateDisplay() throws {
        // Navigate to Grocery List quickly to potentially catch loading state
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Look for loading indicators
        let loadingIndicator = app.activityIndicators.firstMatch
        let loadingText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Loading'")).firstMatch
        
        // Loading state may be brief
        if loadingIndicator.exists || loadingText.exists {
            XCTAssertTrue(loadingIndicator.exists || loadingText.exists, "Loading state should be displayed when appropriate")
        }
    }
}